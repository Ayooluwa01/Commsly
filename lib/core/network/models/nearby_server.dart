class DiscoveredServer {
  final String id;
  final String name;
  final String address;
  final int port;
  final int? memberCount;
  final bool requiresPin;

  const DiscoveredServer({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    this.memberCount,
    this.requiresPin = false,
  });

  Uri get websocketUri => Uri(scheme: 'ws', host: address, port: port);
}
