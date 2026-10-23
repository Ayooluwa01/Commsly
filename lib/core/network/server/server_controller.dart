import 'package:commsly/core/network/server/commsly_server.dart';
import 'package:commsly/core/network/server/hosted_server_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ServerStatus { stopped, starting, running, stopping, failure }

// model
class ServerState {
  final ServerStatus status;
  final String? deviceName;
  final String? error;

  const ServerState({
    this.status = ServerStatus.stopped,
    this.deviceName,
    this.error,
  });

  bool get isRunning => status == ServerStatus.running;

  bool get isBusy =>
      status == ServerStatus.starting || status == ServerStatus.stopping;
}

final commslyServerProvider = Provider<CommslyServer>((ref) {
  final server = CommslyServer();
  ref.onDispose(() {
    // Cleanup on application ProviderScope disposal.
    // Fire-and-forget is necessary for this sync callback.
    server.stop();
  });
  return server;
});

final serverControllerProvider =
    NotifierProvider<ServerController, ServerState>(ServerController.new);

class ServerController extends Notifier<ServerState> {
  late CommslyServer _server;

  @override
  ServerState build() {
    _server = ref.read(commslyServerProvider);
    return const ServerState();
  }

  Future<bool> startServer({required String deviceName, String? pin}) async {
    if (state.isBusy || state.isRunning) return false;

    state = ServerState(status: ServerStatus.starting, deviceName: deviceName);

    try {
      final started = await _server.startServer(
        deviceName: deviceName,
        pin: pin,
      );

      if (!started) {
        state = ServerState(
          status: ServerStatus.failure,
          deviceName: deviceName,
          error: 'Unable to start the local server.',
        );
        return false;
      }

      state = ServerState(status: ServerStatus.running, deviceName: deviceName);

      return true;
    } catch (e) {
      state = ServerState(
        status: ServerStatus.failure,
        deviceName: deviceName,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> stopServer() async {
    if (state.isBusy || !state.isRunning) return;
    final name = state.deviceName;
    state = ServerState(status: ServerStatus.stopping, deviceName: name);
    try {
      await _server.stop();
      state = const ServerState();
      ref.read(hostedServerNameProvider.notifier).clear();
    } catch (e) {
      state = ServerState(
        status: ServerStatus.failure,
        deviceName: name,
        error: e.toString(),
      );
    }
  }
}
