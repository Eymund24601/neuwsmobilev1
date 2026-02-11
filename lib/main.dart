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
  const NeuwsApp({super.key, this.enforceSupabaseConfig = true});

  final bool enforceSupabaseConfig;

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
        if (widget.enforceSupabaseConfig && !SupabaseBootstrap.isConfigured) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'nEUws',
            theme: buildNeuwsLightTheme(),
            darkTheme: buildNeuwsDarkTheme(),
            themeMode: mode,
            home: const _SupabaseConfigErrorScreen(),
          );
        }

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

class _SupabaseConfigErrorScreen extends StatefulWidget {
  const _SupabaseConfigErrorScreen();

  @override
  State<_SupabaseConfigErrorScreen> createState() =>
      _SupabaseConfigErrorScreenState();
}

class _SupabaseConfigErrorScreenState
    extends State<_SupabaseConfigErrorScreen> {
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dialogShown) {
      return;
    }
    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Supabase Config Missing'),
          content: const Text(
            'The app is blocked because Supabase runtime config is missing. '
            'Start with --dart-define-from-file=.env/supabase.local.json.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, size: 56),
              SizedBox(height: 12),
              Text(
                'Supabase configuration is required to run this app.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Use --dart-define-from-file=.env/supabase.local.json',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
