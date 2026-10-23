import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:commsly/core/network/models/nearby_server.dart';
import 'package:commsly/core/network/server/server_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClientState {
  final DiscoveredServer? server;
  final bool isConnecting;
  final String? error;
  const ClientState({this.server, this.isConnecting = false, this.error});
  bool get isConnected => server != null;
}

final commslyClientProvider = NotifierProvider<CommslyClient, ClientState>(
  CommslyClient.new,
);

class CommslyClient extends Notifier<ClientState> {
  WebSocket? _socket;

  @override
  ClientState build() {
    ref.onDispose(() {
      final socket = _socket;
      _socket = null;
      if (socket != null) {
        unawaited(socket.close());
      }
    });
    return const ClientState();
  }

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
    String? rejectionMessage;
    state = const ClientState(isConnecting: true);
    WebSocket? socket;
    try {
      final uri = Uri(scheme: 'ws', host: server.address, port: server.port);
      socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 8));
      final completer = Completer<bool>();
      final currentSocket = socket;
      socket.listen(
        (message) {
          try {
            final data = jsonDecode(message.toString());
            if (data is! Map<String, dynamic>) return;
            switch (data['type']) {
              case 'server:joined':
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
                break;
              case 'server:rejected':
                rejectionMessage =
                    data['message']?.toString() ?? 'Connection rejected';

                if (!completer.isCompleted) {
                  completer.complete(false);
                }
                break;
              case 'server:error':
                if (!completer.isCompleted) {
                  completer.complete(false);
                }
                break;
              case 'server:ended':
                if (identical(_socket, currentSocket)) {
                  developer.log("SERVER ENDED");
                  _socket = null;
                  state = const ClientState();
                }
                unawaited(currentSocket.close());
                break;
            }
          } catch (_) {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }

          if (identical(_socket, currentSocket)) {
            _socket = null;
            state = const ClientState();
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }

          if (identical(_socket, currentSocket)) {
            _socket = null;
            state = ClientState(error: error.toString());
          }
        },
      );

      socket.add(
        jsonEncode({
          'type': 'server:join',
          'name': displayName.trim(),
          'pin': pin,
        }),
      );

      final accepted = await completer.future.timeout(
        const Duration(seconds: 8),
      );

      if (!accepted) {
        await socket.close();
        state = ClientState(
          error: rejectionMessage ?? 'Server rejected the connection.',
        );
        return false;
      }

      // The socket must still be open when
      // the join acknowledgement is received.
      if (socket.readyState != WebSocket.open) {
        state = const ClientState(error: 'The server disconnected.');
        return false;
      }

      _socket = socket;
      state = ClientState(server: server);

      return true;
    } catch (error) {
      await socket?.close();

      state = ClientState(error: error.toString());
      return false;
    }
  }

  Future<void> leaveServer() async {
    final socket = _socket;
    _socket = null;

    await socket?.close(WebSocketStatus.normalClosure);

    state = const ClientState();
  }
}
