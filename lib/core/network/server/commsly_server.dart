import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CommslyServer {
  static const int port = 8765;
  static const String serviceType = '_commsly._tcp';
  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  final Set<WebSocketChannel> _clients = {};
  String? _serverName;
  String? _serverPin;
  bool _isStarting = false;
  bool get isRunning => _server != null;
  int get memberCount => _clients.length + (isRunning ? 1 : 0);
  Future<bool> startServer({required String deviceName, String? pin}) async {
    if (isRunning || _isStarting) return false;
    _isStarting = true;
    try {
      _serverName = deviceName.trim();
      _serverPin = pin?.trim().isNotEmpty == true ? pin!.trim() : null;
      final handler = webSocketHandler((socket, _) {
        developer.log('Client socket opened');
        bool joined = false;
        socket.stream.listen(
          (message) {
            try {
              final data = jsonDecode(message.toString());
              if (data is! Map<String, dynamic>) {
                throw const FormatException('Invalid message');
              }
              if (data['type'] == 'server:join') {
                final displayName = data['name'];
                final providedPin = data['pin'];

                if (displayName is! String || displayName.trim().isEmpty) {
                  socket.sink.add(
                    jsonEncode({
                      'type': 'server:rejected',
                      'message': 'Display name is required',
                    }),
                  );
                  return;
                }
                if (joined) return;
                if (_serverPin != null && providedPin != _serverPin) {
                  socket.sink.add(
                    jsonEncode({
                      'type': 'server:rejected',
                      'message': 'Incorrect server PIN',
                      'code': 'INVALID_PIN',
                    }),
                  );
                  return;
                }
                joined = true;
                _clients.add(socket);
                socket.sink.add(
                  jsonEncode({
                    'type': 'server:joined',
                    'serverName': _serverName,
                  }),
                );

                developer.log('Member joined: ${displayName.trim()}');
                return;
              }
              if (!joined) {
                socket.sink.add(
                  jsonEncode({
                    'type': 'server:rejected',
                    'message': 'Join the server first',
                  }),
                );
              }
            } catch (error) {
              socket.sink.add(
                jsonEncode({
                  'type': 'server:error',
                  'message': 'Invalid request',
                }),
              );
            }
          },
          onDone: () {
            _clients.remove(socket);
            developer.log('Client disconnected');
          },
          onError: (Object error) {
            _clients.remove(socket);
            developer.log('Client WebSocket error: $error');
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

      developer.log('Commsly server running: $_serverName');

      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to start server',
        error: error,
        stackTrace: stackTrace,
      );

      await stop();
      return false;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stop() async {
    // Tell joined clients the server is ending.
    for (final client in _clients.toList()) {
      try {
        client.sink.add(
          jsonEncode({
            'type': 'server:ended',
            'message': 'The host ended the server',
          }),
        );

        await client.sink.close();
      } catch (error) {
        developer.log('Error closing client: $error');
      }
    }

    _clients.clear();

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
