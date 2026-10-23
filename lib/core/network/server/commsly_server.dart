import 'dart:developer' as developer;
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

class CommslyServer {
  static const int port = 8765;
  static const String serviceType = '_commsly._tcp';
  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  bool _isStarting = false;
  bool get isRunning => _server != null;
  Future<bool> startServer({required String deviceName}) async {
    if (isRunning || _isStarting) {
      developer.log('Server already running or starting');
      return false;
    }
    _isStarting = true;
    try {
      // 1. Create the WebSocket handler
      final handler = webSocketHandler((socket, _) {
        developer.log('Client connected');
        socket.stream.listen(
          (message) {
            developer.log('Received: $message');
            socket.sink.add('Commsly received: $message');
          },
          onDone: () {
            developer.log('Client disconnected');
          },
          onError: (Object error) {
            developer.log('WebSocket error: $error');
          },
        );
      });

      // 2. Start local WebSocket server
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      developer.log('WebSocket server listening on port ${_server!.port}');
      // 3. Create Bonjour service
      final service = BonsoirService(
        name: deviceName,
        type: serviceType,
        port: _server!.port,
      );
      // 4. Advertise the server on local Wi-Fi
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
      developer.log('Commsly server advertised: $deviceName');
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to start Commsly server',
        error: e,
        stackTrace: stackTrace,
      );
      await stop();
      return false;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stop() async {
    try {
      await _broadcast?.stop();
    } finally {
      _broadcast = null;

      await _server?.close(force: true);
      _server = null;
    }

    developer.log('Commsly server stopped');
  }
}
