import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:commsly/core/network/models/nearby_server.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================
// ROOM MODEL
// ============================================================

class ClientRoom {
  final String id;
  final String name;
  final int memberCount;
  final bool isJoined;

  const ClientRoom({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.isJoined,
  });

  factory ClientRoom.fromJson(Map<String, dynamic> json) {
    return ClientRoom(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      isJoined: json['isJoined'] == true,
    );
  }
}

// ============================================================
// CLIENT STATE
// ============================================================

class ClientState {
  final DiscoveredServer? server;
  final bool isConnecting;
  final String? error;
  final List<ClientRoom> rooms;

  const ClientState({
    this.server,
    this.isConnecting = false,
    this.error,
    this.rooms = const [],
  });

  bool get isConnected => server != null;

  List<ClientRoom> get joinedRooms =>
      rooms.where((room) => room.isJoined).toList();

  ClientState copyWith({
    DiscoveredServer? server,
    bool? isConnecting,
    String? error,
    List<ClientRoom>? rooms,
    bool clearError = false,
  }) {
    return ClientState(
      server: server ?? this.server,
      isConnecting: isConnecting ?? this.isConnecting,
      error: clearError ? null : (error ?? this.error),
      rooms: rooms ?? this.rooms,
    );
  }
}

// ============================================================
// PROVIDER
// ============================================================

final commslyClientProvider = NotifierProvider<CommslyClient, ClientState>(
  CommslyClient.new,
);

// ============================================================
// CLIENT
// ============================================================

class CommslyClient extends Notifier<ClientState> {
  WebSocket? _socket;

  // Prevent an older socket from changing state after
  // the user leaves or starts a new connection.
  int _connectionVersion = 0;

  @override
  ClientState build() {
    ref.onDispose(() {
      _connectionVersion++;

      final socket = _socket;
      _socket = null;

      if (socket != null) {
        unawaited(socket.close());
      }
    });

    return const ClientState();
  }

  // ==========================================================
  // JOIN SERVER
  // ==========================================================

  Future<bool> joinServer({
    required DiscoveredServer server,
    required String displayName,
    String? pin,
  }) async {
    if (state.isConnected || state.isConnecting) {
      return false;
    }

    final host = ref.read(serverControllerProvider);

    if (host.isRunning || host.isBusy) {
      state = const ClientState(
        error: 'End your hosted server before joining another.',
      );
      return false;
    }

    if (displayName.trim().isEmpty) {
      state = const ClientState(error: 'Display name is required.');
      return false;
    }

    final version = ++_connectionVersion;

    state = const ClientState(isConnecting: true);

    WebSocket? socket;
    String? rejectionMessage;

    // Room data may arrive immediately after server:joined,
    // before we have updated ClientState to connected.
    List<ClientRoom> pendingRooms = [];

    final completer = Completer<bool>();

    bool isCurrent() => version == _connectionVersion;

    try {
      final uri = Uri(scheme: 'ws', host: server.address, port: server.port);

      developer.log('Connecting to $uri', name: 'CommslyClient');

      socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 8));

      if (!isCurrent()) {
        await socket.close();
        return false;
      }

      final currentSocket = socket;

      // Track the socket before receiving any messages.
      _socket = currentSocket;

      socket.listen(
        (message) {
          if (!isCurrent()) return;

          try {
            final decoded = jsonDecode(message.toString());

            if (decoded is! Map<String, dynamic>) return;

            final type = decoded['type'];

            developer.log('Received: $type', name: 'CommslyClient');

            switch (type) {
              // ----------------------------------------------
              // SERVER JOINED
              // ----------------------------------------------

              case 'server:joined':
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
                break;

              // ----------------------------------------------
              // SERVER REJECTED
              // ----------------------------------------------

              case 'server:rejected':
              case 'server:error':
                rejectionMessage =
                    decoded['message']?.toString() ??
                    'Server rejected the connection.';

                if (!completer.isCompleted) {
                  completer.complete(false);
                } else if (state.isConnected) {
                  state = state.copyWith(error: rejectionMessage);
                }
                break;

              // ----------------------------------------------
              // SERVER ENDED
              // ----------------------------------------------

              case 'server:ended':
                developer.log('Host ended the server', name: 'CommslyClient');

                if (!completer.isCompleted) {
                  completer.complete(false);
                }

                _handleDisconnect(
                  currentSocket,
                  version,
                  message: 'The host ended the server.',
                );
                break;

              // ----------------------------------------------
              // ROOM LIST UPDATED
              // ----------------------------------------------

              case 'room:list':
                final rawRooms = decoded['rooms'];

                if (rawRooms is! List) return;

                final updatedRooms = <ClientRoom>[];

                for (final item in rawRooms) {
                  if (item is Map<String, dynamic>) {
                    updatedRooms.add(ClientRoom.fromJson(item));
                  }
                }

                pendingRooms = updatedRooms;

                if (state.isConnected) {
                  state = state.copyWith(rooms: updatedRooms, clearError: true);
                }
                break;

              // ----------------------------------------------
              // ROOM JOINED
              // ----------------------------------------------

              case 'room:joined':
                developer.log(
                  'Joined room: ${decoded['roomId']}',
                  name: 'CommslyClient',
                );

                // The server broadcasts an updated room:list.
                break;

              // ----------------------------------------------
              // ROOM LEFT
              // ----------------------------------------------

              case 'room:left':
                developer.log(
                  'Left room: ${decoded['roomId']}',
                  name: 'CommslyClient',
                );

                // Wait for the updated room:list.
                break;

              // ----------------------------------------------
              // ROOM DELETED
              // ----------------------------------------------

              case 'room:deleted':
                developer.log(
                  'Room deleted: ${decoded['roomId']}',
                  name: 'CommslyClient',
                );

                // The next room:list removes this room.
                break;

              // ----------------------------------------------
              // ROOM ERROR
              // ----------------------------------------------

              case 'room:error':
                state = state.copyWith(
                  error:
                      decoded['message']?.toString() ??
                      'Unable to complete room action.',
                );
                break;

              default:
                developer.log(
                  'Unhandled message: $type',
                  name: 'CommslyClient',
                );
            }
          } catch (error) {
            developer.log(
              'Invalid incoming message: $error',
              name: 'CommslyClient',
            );
          }
        },

        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }

          _handleDisconnect(currentSocket, version);
        },

        onError: (Object error) {
          if (!completer.isCompleted) {
            rejectionMessage = error.toString();
            completer.complete(false);
          }

          _handleDisconnect(currentSocket, version, message: error.toString());
        },

        cancelOnError: true,
      );

      // ----------------------------------------------
      // SEND SERVER JOIN REQUEST
      // ----------------------------------------------

      currentSocket.add(
        jsonEncode({
          'type': 'server:join',
          'name': displayName.trim(),
          'pin': pin,
        }),
      );

      developer.log('Sent server:join', name: 'CommslyClient');

      // ----------------------------------------------
      // WAIT FOR SERVER ACKNOWLEDGEMENT
      // ----------------------------------------------

      final accepted = await completer.future.timeout(
        const Duration(seconds: 8),
      );

      if (!isCurrent()) return false;

      if (!accepted) {
        _socket = null;
        await currentSocket.close();

        state = ClientState(
          error: rejectionMessage ?? 'Unable to join this server.',
        );

        return false;
      }

      if (currentSocket.readyState != WebSocket.open) {
        _socket = null;

        state = const ClientState(error: 'The server disconnected.');

        return false;
      }

      // Connection is officially established.
      state = ClientState(server: server, rooms: pendingRooms);

      // Request the latest list again in case updates
      // arrived during the join handshake.
      refreshRooms();

      developer.log(
        'Successfully joined ${server.name}',
        name: 'CommslyClient',
      );

      return true;
    } catch (error) {
      developer.log('Connection failed: $error', name: 'CommslyClient');

      if (!isCurrent()) return false;

      _socket = null;

      await socket?.close();

      state = ClientState(error: rejectionMessage ?? error.toString());

      return false;
    }
  }

  // ==========================================================
  // JOIN ROOM
  // ==========================================================

  bool joinRoom(String roomId) {
    if (!state.isConnected || _socket == null) {
      state = state.copyWith(error: 'Connect to a server first.');
      return false;
    }

    final roomExists = state.rooms.any((room) => room.id == roomId);

    if (!roomExists) {
      state = state.copyWith(error: 'Room does not exist.');
      return false;
    }

    try {
      _socket!.add(jsonEncode({'type': 'room:join', 'roomId': roomId}));

      state = state.copyWith(clearError: true);

      developer.log('Sent room:join $roomId', name: 'CommslyClient');

      return true;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    }
  }

  // ==========================================================
  // LEAVE ROOM
  // ==========================================================

  bool leaveRoom(String roomId) {
    if (!state.isConnected || _socket == null) {
      return false;
    }

    final isJoined = state.joinedRooms.any((room) => room.id == roomId);

    if (!isJoined) {
      state = state.copyWith(error: 'You are not in this room.');
      return false;
    }

    try {
      _socket!.add(jsonEncode({'type': 'room:leave', 'roomId': roomId}));

      state = state.copyWith(clearError: true);

      developer.log('Sent room:leave $roomId', name: 'CommslyClient');

      return true;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    }
  }

  // ==========================================================
  // REQUEST AVAILABLE ROOMS
  // ==========================================================

  void refreshRooms() {
    if (!state.isConnected || _socket == null) return;

    try {
      _socket!.add(jsonEncode({'type': 'room:list'}));
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  // ==========================================================
  // LEAVE SERVER
  // ==========================================================

  Future<void> leaveServer() async {
    _connectionVersion++;

    final socket = _socket;
    _socket = null;

    // Reset immediately so the UI updates.
    state = const ClientState();

    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.normalClosure);
      } catch (error) {
        developer.log('Error leaving server: $error', name: 'CommslyClient');
      }
    }
  }

  // ==========================================================
  // HANDLE DISCONNECTION
  // ==========================================================

  void _handleDisconnect(WebSocket socket, int version, {String? message}) {
    if (version != _connectionVersion) return;

    if (!identical(_socket, socket)) return;

    _socket = null;
    _connectionVersion++;

    state = ClientState(error: message ?? 'Disconnected from server.');

    unawaited(socket.close());

    developer.log(message ?? 'Disconnected from server', name: 'CommslyClient');
  }

  // ==========================================================
  // CLEAR ERROR
  // ==========================================================

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
