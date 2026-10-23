import 'package:commsly/core/router/routeNames.dart';
import 'package:commsly/core/widgets/bottom_nav.dart';
import 'package:commsly/features/screens/home/screens/connected/screen/connected_screen.dart';
import 'package:commsly/features/screens/home/screens/home_screen.dart';
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
