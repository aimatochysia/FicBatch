import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('theme_mode');
    if (raw == 'dark') {
      state = ThemeMode.dark;
    } else {
      // Default to light, no system option
      state = ThemeMode.light;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final sp = await SharedPreferences.getInstance();
    final raw = mode == ThemeMode.dark ? 'dark' : 'light';
    await sp.setString('theme_mode', raw);
  }
}
