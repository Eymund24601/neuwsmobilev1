import 'package:flutter/material.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static void setDarkMode(bool isDark) {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}
