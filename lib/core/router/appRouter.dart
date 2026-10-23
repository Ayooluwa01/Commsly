import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/core/widgets/bottom_nav.dart';

import 'package:commsly/features/screens/home/screens/home_screen.dart';
import 'package:commsly/features/screens/home/screens/create_server_screen.dart';
import 'package:commsly/features/screens/home/screens/join_server_screen.dart';

import 'package:commsly/features/screens/rooms/screen/rooms_screen.dart';
import 'package:commsly/features/screens/rooms/screen/room_detail_screen.dart';

import 'package:commsly/features/screens/connected/screen/connected_screen.dart';
import 'package:commsly/features/screens/connected/screen/server_dashboard_screen.dart';

import 'package:commsly/features/screens/settings/screen/settings_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _roomsNavigatorKey = GlobalKey<NavigatorState>();
final _connectedNavigatorKey = GlobalKey<NavigatorState>();
final _settingsNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: Routenames.homescreen,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BottomNav(navigationShell: navigationShell);
      },
      branches: [
        // 0 - HOME
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: Routenames.homescreen,
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'create-server',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const CreateServerScreen(),
                ),
                GoRoute(
                  path: 'join-server',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const JoinServerScreen(),
                ),
              ],
            ),
          ],
        ),

        // 1 - ROOMS
        StatefulShellBranch(
          navigatorKey: _roomsNavigatorKey,
          routes: [
            GoRoute(
              path: Routenames.rooms,
              builder: (context, state) => const RoomsScreen(),
              routes: [
                GoRoute(
                  path: ':roomId',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final roomId = state.pathParameters['roomId'] ?? '';

                    final roomName =
                        state.uri.queryParameters['name'] ?? 'Room';

                    return RoomDetailScreen(roomId: roomId, roomName: roomName);
                  },
                ),
              ],
            ),
          ],
        ),

        // 2 - CONNECTED
        StatefulShellBranch(
          navigatorKey: _connectedNavigatorKey,
          routes: [
            GoRoute(
              path: Routenames.connected,
              builder: (context, state) => const ConnectedScreen(),
              routes: [
                GoRoute(
                  path: 'server-dashboard',
                  builder: (context, state) => const ServerDashboardScreen(),
                ),
              ],
            ),
          ],
        ),

        // 3 - SETTINGS
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: Routenames.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
