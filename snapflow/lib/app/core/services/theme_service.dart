import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Manages the app's theme mode and persists the user's choice locally.
class ThemeService extends GetxService {
  static const _storageKey = 'theme_mode';

  /// Current theme mode (defaults to system until a saved value is loaded).
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  /// Load the persisted theme, if any. Safe to call multiple times.
  Future<void> init() async {
    try {
      final box = GetStorage();
      final stored = box.read<String>(_storageKey);

      if (stored != null) {
        themeMode.value = _parseThemeMode(stored);
      }
    } catch (error) {
      // Non-critical: fall back to system theme.
      debugPrint('ThemeService init failed: $error');
    }
  }

  void setLight() => _setTheme(ThemeMode.light);
  void setDark() => _setTheme(ThemeMode.dark);
  void setSystem() => _setTheme(ThemeMode.system);

  void _setTheme(ThemeMode mode) {
    if (themeMode.value == mode) return;
    themeMode.value = mode;

    try {
      final box = GetStorage();
      box.write(_storageKey, mode.name);
    } catch (error) {
      debugPrint('ThemeService persist failed: $error');
    }
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
