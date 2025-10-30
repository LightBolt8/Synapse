import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<double> textScaleFactor = ValueNotifier<double>(1.0);
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  void setTextScale(double scale) {
    // Clamp between 0.8 and 1.4 for usability
    final double clamped = scale.clamp(0.8, 1.4);
    textScaleFactor.value = clamped;
  }

  void setLocale(Locale? newLocale) {
    locale.value = newLocale;
  }
}


