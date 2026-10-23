import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:commsly/core/network/models/nearby_server.dart';

class CommslyDiscovery {
  static const String serviceType = '_commsly._tcp';
  BonsoirDiscovery? _bonsoirDiscovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;
  final Map<String, NearbyServer> _nearby = {};
  final _serversController = StreamController<List<NearbyServer>>.broadcast();
  bool _isStarting = false;
  bool _isDisposed = false;
  bool get isSearching => _bonsoirDiscovery != null;
  List<NearbyServer> get nearbyServers => List.unmodifiable(_nearby.values);
  Stream<List<NearbyServer>> get serversStream => _serversController.stream;

  // START DISCOVERY
  Future<void> startDiscovery() async {
    if (_isDisposed) {
      throw StateError('Discovery service disposed');
    }

    if (isSearching || _isStarting) return;

    _isStarting = true;

    try {
      _nearby.clear();
      _emitServers();
      final discovery = BonsoirDiscovery(type: serviceType);
      _bonsoirDiscovery = discovery;
      await discovery.initialize();
      // Listen before starting discovery
      _subscription = discovery.eventStream!.listen(
        (event) => _handleEvent(event, discovery),
        onError: (Object error) {
          developer.log('Discovery stream error', error: error);
        },
      );
      await discovery.start();
      developer.log('Commsly discovery started');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to start discovery',
        error: e,
        stackTrace: stackTrace,
      );
      await stopDiscovery();
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  // HANDLE BONSOIR EVENTS
  void _handleEvent(BonsoirDiscoveryEvent event, BonsoirDiscovery discovery) {
    if (event is BonsoirDiscoveryServiceFoundEvent) {
      developer.log('Server found: ${event.service.name}');
      // Resolve hostname, address and port.
      unawaited(
        event.service.resolve(discovery.serviceResolver).catchError((
          Object error,
        ) {
          developer.log(
            'Failed to resolve ${event.service.name}',
            error: error,
          );
        }),
      );
    }

    if (event is BonsoirDiscoveryServiceResolvedEvent) {
      _addOrUpdateServer(event.service);
    } else if (event is BonsoirDiscoveryServiceUpdatedEvent) {
      _addOrUpdateServer(event.service);
    }

    if (event is BonsoirDiscoveryServiceLostEvent) {
      _removeServer(event.service);
    }
  }

  // ADD OR UPDATE DISCOVERED SERVER
  void _addOrUpdateServer(BonsoirService service) {
    String? ipv4;
    for (final address in service.hostAddresses) {
      final parsed = InternetAddress.tryParse(address);
      if (parsed?.type == InternetAddressType.IPv4) {
        ipv4 = address;
        break;
      }
    }

    if (ipv4 == null) {
      developer.log('No IPv4 address for ${service.name}');
      return;
    }

    final server = NearbyServer(
      name: service.name,
      address: ipv4,
      port: service.port,
    );
    _nearby[service.name] = server;
    _emitServers();
    developer.log('Server resolved: $server');
  }

  // REMOVE SERVER
  void _removeServer(BonsoirService service) {
    final removed = _nearby.remove(service.name);

    if (removed != null) {
      _emitServers();
      developer.log('Server lost: ${service.name}');
    }
  }

  // NOTIFY LISTENERS
  void _emitServers() {
    if (_isDisposed) return;
    _serversController.add(List.unmodifiable(_nearby.values));
  }

  // STOP DISCOVERY
  Future<void> stopDiscovery() async {
    await _subscription?.cancel();
    _subscription = null;
    final discovery = _bonsoirDiscovery;
    _bonsoirDiscovery = null;
    try {
      await discovery?.stop();
    } finally {
      _nearby.clear();
      _emitServers();
    }

    developer.log('Commsly discovery stopped');
  }

  // CLEANUP
  Future<void> dispose() async {
    if (_isDisposed) return;
    await stopDiscovery();
    _isDisposed = true;
    await _serversController.close();
  }
}
