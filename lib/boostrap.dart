import 'package:commsly/core/router/appRouter.dart';
import 'package:commsly/features/providers/theme_provider.dart';
import 'package:commsly/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Assuming appRouter is imported or defined in the same file / imported from router file:
// import 'path/to/app_router.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CommslyApp(),
    ),
  );
}

class CommslyApp extends ConsumerWidget {
  const CommslyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CommslyApp',
      theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
