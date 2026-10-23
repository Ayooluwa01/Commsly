import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/core/widgets/bottom_nav.dart';
import 'package:commsly/features/screens/connected/screen/connected_screen.dart';
import 'package:commsly/features/screens/connected/screen/server_dashboard_screen.dart';
import 'package:commsly/features/screens/home/screens/create_server_screen.dart';
import 'package:commsly/features/screens/home/screens/home_screen.dart';
import 'package:commsly/features/screens/home/screens/join_server_screen.dart';
import 'package:commsly/features/screens/rooms/screen/rooms_screen.dart';
import 'package:commsly/features/screens/settings/screen/settings_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Replace these imports with your actual screen paths.

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _connectedNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _settingsNavigatorKey =
    GlobalKey<NavigatorState>();

final _roomsNavigatorKey = GlobalKey<NavigatorState>();
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: Routenames.homescreen,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BottomNav(navigationShell: navigationShell);
      },
      branches: [
        // HOME
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

        // CONNECTED
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

        // ROOMS
        StatefulShellBranch(
          navigatorKey: _roomsNavigatorKey,
          routes: [
            GoRoute(
              path: '/rooms',
              builder: (context, state) => const RoomsScreen(),
            ),
          ],
        ),
        // SETTINGS
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
