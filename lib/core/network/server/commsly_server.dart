import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CommslyRoom {
  final String id;
  String name;
  final Set<WebSocketChannel> members = {};
  CommslyRoom({required this.id, required this.name});
}

class CommslyServer {
  static const int port = 8765;
  static const String serviceType = '_commsly._tcp';
  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  final Set<WebSocketChannel> _clients = {};
  final Map<String, CommslyRoom> _rooms = {};
  String? _serverName;
  String? _serverPin;
  bool _isStarting = false;
  bool get isRunning => _server != null;
  int get memberCount => _clients.length + (isRunning ? 1 : 0);
  List<CommslyRoom> get rooms => List.unmodifiable(_rooms.values);
  Future<bool> startServer({required String deviceName, String? pin}) async {
    if (isRunning || _isStarting) return false;
    _isStarting = true;
    try {
      _serverName = deviceName.trim();
      _serverPin = pin?.trim().isNotEmpty == true ? pin!.trim() : null;
      final handler = webSocketHandler((socket, _) {
        bool joined = false;
        developer.log('Client socket opened');
        socket.stream.listen(
          (message) {
            try {
              final data = jsonDecode(message.toString());

              if (data is! Map<String, dynamic>) {
                _send(socket, {
                  'type': 'server:error',
                  'message': 'Invalid message',
                });
                return;
              }

              final type = data['type'];

              // Join the server first.
              if (type == 'server:join') {
                if (joined) return;

                final displayName = data['name'];

                if (displayName is! String || displayName.trim().isEmpty) {
                  _send(socket, {
                    'type': 'server:rejected',
                    'message': 'Display name is required',
                  });
                  return;
                }

                if (_serverPin != null && data['pin'] != _serverPin) {
                  _send(socket, {
                    'type': 'server:rejected',
                    'code': 'INVALID_PIN',
                    'message': 'Incorrect server PIN',
                  });
                  return;
                }

                joined = true;
                _clients.add(socket);

                _send(socket, {
                  'type': 'server:joined',
                  'serverName': _serverName,
                });

                _sendRoomList(socket);
                _broadcastRoomLists();

                developer.log('Member joined: ${displayName.trim()}');
                return;
              }

              // All other actions require membership.
              if (!joined) {
                _send(socket, {
                  'type': 'server:rejected',
                  'message': 'Join the server first',
                });
                return;
              }

              switch (type) {
                case 'room:list':
                  _sendRoomList(socket);
                  break;

                case 'room:join':
                  final roomId = data['roomId'];
                  if (roomId is! String) {
                    _send(socket, {
                      'type': 'room:error',
                      'message': 'Room ID is required',
                    });
                    return;
                  }
                  _joinRoom(socket, roomId);
                  break;
                case 'room:leave':
                  final roomId = data['roomId'];
                  if (roomId is! String) {
                    _send(socket, {
                      'type': 'room:error',
                      'message': 'Room ID is required',
                    });
                    return;
                  }
                  _leaveRoom(socket, roomId);
                  break;
                default:
                  _send(socket, {
                    'type': 'server:error',
                    'message': 'Unknown event type',
                  });
              }
            } catch (error) {
              developer.log('Message processing error: $error');

              _send(socket, {
                'type': 'server:error',
                'message': 'Invalid request',
              });
            }
          },
          onDone: () => _disconnectClient(socket),
          onError: (Object error) {
            developer.log('Socket error: $error');
            _disconnectClient(socket);
          },
        );
      });

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

      final service = BonsoirService(
        name: _serverName!,
        type: serviceType,
        port: _server!.port,
      );
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
      developer.log('Server started: $_serverName');
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Unable to start server',
        error: error,
        stackTrace: stackTrace,
      );

      await stop();
      return false;
    } finally {
      _isStarting = false;
    }
  }

  // ------------------------------------------
  // HOST: CREATE ROOM
  // ------------------------------------------

  bool createRoom({required String roomId, required String roomName}) {
    if (!isRunning) return false;
    final id = roomId.trim();
    final name = roomName.trim();
    if (id.isEmpty || name.isEmpty) return false;
    if (_rooms.containsKey(id)) return false;
    if (_rooms.values.any(
      (room) => room.name.toLowerCase() == name.toLowerCase(),
    )) {
      return false;
    }
    final newRoom = CommslyRoom(id: id, name: name);
    // Add the new room to the rooms map
    _rooms[id] = newRoom;
    _broadcastRoomLists();
    developer.log('Room created: $name ($id)');
    return true;
  }

  // ------------------------------------------
  // HOST: DELETE ROOM
  // ------------------------------------------

  bool deleteRoom(String roomId) {
    final room = _rooms.remove(roomId);
    if (room == null) return false;

    for (final member in room.members) {
      _send(member, {'type': 'room:deleted', 'roomId': roomId});
    }

    _broadcastRoomLists();

    developer.log('Room deleted: ${room.name}');
    return true;
  }

  // ------------------------------------------
  // CLIENT: JOIN ROOM
  // ------------------------------------------

  void _joinRoom(WebSocketChannel socket, String roomId) {
    final room = _rooms[roomId];
    if (room == null) {
      _send(socket, {'type': 'room:error', 'message': 'Room does not exist'});
      return;
    }
    room.members.add(socket);
    _send(socket, {
      'type': 'room:joined',
      'roomId': room.id,
      'roomName': room.name,
    });

    _broadcastRoomLists();
    developer.log('Member joined room: ${room.name}');
  }

  // ------------------------------------------
  // CLIENT: LEAVE ROOM
  // ------------------------------------------

  void _leaveRoom(WebSocketChannel socket, String roomId) {
    final room = _rooms[roomId];
    if (room == null || !room.members.contains(socket)) {
      _send(socket, {
        'type': 'room:error',
        'message': 'You are not in this room',
      });
      return;
    }
    room.members.remove(socket);
    _send(socket, {'type': 'room:left', 'roomId': roomId});
    _broadcastRoomLists();
    developer.log('Member left room: ${room.name}');
  }

  // ------------------------------------------
  // ROOM LIST AND BROADCASTING
  // ------------------------------------------

  void _sendRoomList(WebSocketChannel socket) {
    _send(socket, {
      'type': 'room:list',
      'rooms': _rooms.values.map((room) {
        return {
          'id': room.id,
          'name': room.name,
          'memberCount': room.members.length,
          'isJoined': room.members.contains(socket),
        };
      }).toList(),
    });
  }

  void _broadcastRoomLists() {
    for (final socket in _clients.toList()) {
      _sendRoomList(socket);
    }
  }

  void _send(WebSocketChannel socket, Map<String, dynamic> data) {
    try {
      socket.sink.add(jsonEncode(data));
    } catch (error) {
      developer.log('Failed to send message: $error');
    }
  }

  // ------------------------------------------
  // DISCONNECT
  // ------------------------------------------

  void _disconnectClient(WebSocketChannel socket) {
    _clients.remove(socket);

    for (final room in _rooms.values) {
      room.members.remove(socket);
    }

    _broadcastRoomLists();

    developer.log('Client disconnected');
  }

  // ------------------------------------------
  // STOP SERVER
  // ------------------------------------------

  Future<void> stop() async {
    for (final client in _clients.toList()) {
      try {
        _send(client, {
          'type': 'server:ended',
          'message': 'The host ended the server',
        });

        await client.sink.close();
      } catch (error) {
        developer.log('Error closing client: $error');
      }
    }

    _clients.clear();
    _rooms.clear();

    try {
      await _broadcast?.stop();
    } finally {
      _broadcast = null;

      await _server?.close(force: true);
      _server = null;

      _serverName = null;
      _serverPin = null;
    }

    developer.log('Commsly server stopped');
  }
}
