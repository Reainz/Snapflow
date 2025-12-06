import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapflow/app/core/services/theme_service.dart';

void main() {
  group('ThemeService', () {
    // Use testWidgets instead of test() to get Flutter bindings initialized
    testWidgets('defaults to system mode', (WidgetTester tester) async {
      final service = ThemeService();
      expect(service.themeMode.value, ThemeMode.system);
    });

    testWidgets('setLight updates theme mode to light', (WidgetTester tester) async {
      final service = ThemeService();
      service.setLight();
      expect(service.themeMode.value, ThemeMode.light);
    });

    testWidgets('setDark updates theme mode to dark', (WidgetTester tester) async {
      final service = ThemeService();
      service.setDark();
      expect(service.themeMode.value, ThemeMode.dark);
    });

    testWidgets('setSystem updates theme mode to system', (WidgetTester tester) async {
      final service = ThemeService();
      service.setLight();
      service.setSystem();
      expect(service.themeMode.value, ThemeMode.system);
    });

    testWidgets('themeMode is observable via Rx', (WidgetTester tester) async {
      final service = ThemeService();
      expect(service.themeMode.value, ThemeMode.system);

      service.setDark();
      expect(service.themeMode.value, ThemeMode.dark);

      service.setLight();
      expect(service.themeMode.value, ThemeMode.light);
    });

    testWidgets('multiple theme changes maintain correct state', (WidgetTester tester) async {
      final service = ThemeService();

      service.setDark();
      expect(service.themeMode.value, ThemeMode.dark);

      service.setLight();
      expect(service.themeMode.value, ThemeMode.light);

      service.setSystem();
      expect(service.themeMode.value, ThemeMode.system);

      service.setDark();
      expect(service.themeMode.value, ThemeMode.dark);
    });
  });
}
