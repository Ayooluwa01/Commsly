class NearbyServer {
  final String name;
  final String address;
  final int port;

  const NearbyServer({
    required this.name,
    required this.address,
    required this.port,
  });

  String get id => '$name:$address:$port';

  Uri get websocketUri => Uri(scheme: 'ws', host: address, port: port);

  @override
  String toString() {
    return 'NearbyServer(name: $name, '
        'address: $address, port: $port)';
  }
}
