class Routenames {
  static const String homescreen = '/homescreen';
  static const String rooms = '/rooms';
  static const String connected = '/connected';
  static const String settings = '/settings';

  static const String createServer = '/homescreen/create-server';
  static const String joinServer = '/homescreen/join-server';

  static const String serverDashboard = '/connected/server-dashboard';

  static const String roomDetail = '/rooms/:roomId';

  static String roomDetailPath(String roomId) =>
      '/rooms/${Uri.encodeComponent(roomId)}';
}

class RoutePaths {
  static const String homescreen = 'homescreen';
  static const String rooms = 'rooms';
  static const String connected = 'connected';
  static const String settings = 'settings';

  static const String createServer = 'create-server';
  static const String joinServer = 'join-server';
  static const String serverDashboard = 'server-dashboard';
  static const String roomDetail = 'room-detail';
}
