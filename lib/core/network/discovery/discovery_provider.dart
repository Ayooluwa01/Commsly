import 'dart:async';

import 'package:commsly/core/network/discovery/commsly_discovery.dart';
import 'package:commsly/core/network/models/nearby_server.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final commslyDiscoveryProvider = Provider<CommslyDiscovery>((ref) {
  final discovery = CommslyDiscovery();
  ref.onDispose(() => unawaited(discovery.dispose()));
  return discovery;
});

final nearbyServersProvider = StreamProvider<List<DiscoveredServer>>((
  ref,
) async* {
  final discovery = ref.watch(commslyDiscoveryProvider);
  final updates = StreamController<List<DiscoveredServer>>();
  final subscription = discovery.serversStream.listen(
    (servers) {
      if (!updates.isClosed) updates.add(servers);
    },
    onError: (Object error, StackTrace stack) {
      if (!updates.isClosed) updates.addError(error, stack);
    },
  );

  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(updates.close());
  });

  yield discovery.nearbyServers;
  if (!discovery.isSearching) await discovery.startDiscovery();
  yield discovery.nearbyServers;
  yield* updates.stream;
});
