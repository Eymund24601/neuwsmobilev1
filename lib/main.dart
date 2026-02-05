import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_router.dart';
import 'services/supabase/supabase_bootstrap.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initializeIfConfigured();
  runApp(const ProviderScope(child: NeuwsApp()));
}

class NeuwsApp extends StatefulWidget {
  const NeuwsApp({super.key});

  @override
  State<NeuwsApp> createState() => _NeuwsAppState();
}

class _NeuwsAppState extends State<NeuwsApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'nEUws',
          theme: buildNeuwsLightTheme(),
          darkTheme: buildNeuwsDarkTheme(),
          themeMode: mode,
          routerConfig: _router,
        );
      },
    );
  }
}
