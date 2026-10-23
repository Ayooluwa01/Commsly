import 'dart:async';

import 'package:commsly/core/network/discovery/commsly_discovery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/models/nearby_server.dart';

final commslyDiscoveryProvider = Provider<CommslyDiscovery>((ref) {
  final discovery = CommslyDiscovery();
  ref.onDispose(() {
    unawaited(discovery.dispose());
  });
  return discovery;
});

final nearbyServersProvider = StreamProvider<List<NearbyServer>>((ref) async* {
  final discovery = ref.read(commslyDiscoveryProvider);
  // Emit existing servers first.
  yield discovery.nearbyServers;

  // Then listen for discovery updates.
  yield* discovery.serversStream;
});
