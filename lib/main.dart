import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const NeuwsApp());
}

class NeuwsApp extends StatelessWidget {
  const NeuwsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'nEUws',
          theme: buildNeuwsLightTheme(),
          darkTheme: buildNeuwsDarkTheme(),
          themeMode: mode,
          home: const HomeShell(),
        );
      },
    );
  }
}
