import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:snapflow/main.dart' as app;

Finder _textFieldWithHint(String hint) {
  return find.byWidgetPredicate((widget) {
    if (widget is! TextField) return false;
    return widget.decoration?.hintText == hint;
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  
  // Debug: Print what's actually on screen
  final allText = find.byType(Text).evaluate();
  final visibleTexts = allText.map((e) {
    final text = e.widget as Text;
    return text.data ?? '';
  }).where((t) => t.isNotEmpty).take(10).join(', ');
  
  throw TestFailure(
    'Timed out waiting for: $finder\n'
    'Current screen shows: ${visibleTexts.isEmpty ? "No text found" : visibleTexts}'
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');
  final hasCreds = email.isNotEmpty && password.isNotEmpty;

  testWidgets(
    'Login -> Home -> Profile -> Logout',
    (tester) async {
      if (!hasCreds) {
        throw TestFailure('Set --dart-define=E2E_EMAIL and E2E_PASSWORD');
      }
      await app.main();

      // Wait for integration test framework overlay to clear
      // The "Test starting..." overlay can persist and block widget detection
      // Use aggressive pumping to let the framework finish initialization
      await tester.pump(const Duration(seconds: 2));
      
      // Pump and settle multiple times to ensure overlay clears
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Check if we can see app widgets (overlay is gone)
        final canSeeApp = find.text('Welcome Back').evaluate().isNotEmpty ||
                         find.text('Sign In').evaluate().isNotEmpty ||
                         find.byType(Scaffold).evaluate().isNotEmpty ||
                         find.byType(NavigationBar).evaluate().isNotEmpty;
        if (canSeeApp) break;
      }
      
      // Final settle to ensure UI is stable
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // If a force-update is enabled in Firestore, the app will be blocked here.
      expect(find.text('Update Required'), findsNothing);

      // Wait for either login screen or home screen to appear
      // Check for "Sign in" button or "Welcome Back" text (both indicate login screen)
      final loginScreenFound = find.text('Welcome Back').evaluate().isNotEmpty || 
                               find.text('Sign In').evaluate().isNotEmpty;
      final homeScreenFound = find.byType(NavigationBar).evaluate().isNotEmpty;
      
      // If neither found, wait a bit more and check again
      if (!loginScreenFound && !homeScreenFound) {
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }
      
      final isLoggedIn = find.byType(NavigationBar).evaluate().isNotEmpty;
      
      if (isLoggedIn) {
        // Already logged in - log out first
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await _pumpUntilFound(tester, find.byIcon(Icons.settings));
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log out'));
        await tester.pumpAndSettle();
        await _pumpUntilFound(tester, find.text('Log out?'));
        // Find the "Log out" text inside the AlertDialog (not the menu item)
        final dialogLogoutText = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Log out'),
        );
        await tester.tap(dialogLogoutText);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Login screen - wait for either "Welcome Back" text or "Sign In" button
      // Check for both and wait for whichever appears first
      bool welcomeBackFound = find.text('Welcome Back').evaluate().isNotEmpty;
      bool signInFound = find.text('Sign In').evaluate().isNotEmpty;
      
      if (!welcomeBackFound && !signInFound) {
        // Wait for either to appear - try both finders
        final end = DateTime.now().add(const Duration(seconds: 30));
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 200));
          welcomeBackFound = find.text('Welcome Back').evaluate().isNotEmpty;
          signInFound = find.text('Sign In').evaluate().isNotEmpty;
          if (welcomeBackFound || signInFound) break;
        }
        
        if (!welcomeBackFound && !signInFound) {
          throw TestFailure('Timed out waiting for login screen (Welcome Back or Sign In)');
        }
      }
      await tester.enterText(_textFieldWithHint('Enter your email'), email);
      await tester.enterText(_textFieldWithHint('Enter your password'), password);
      await tester.tap(find.text('Sign In'));

      // Home screen.
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await _pumpUntilFound(tester, find.byType(NavigationBar));
      expect(find.text('Feed'), findsWidgets);
      expect(find.text('Upload'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);

      // Go to Profile tab.
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Open settings menu in Profile (embedded tab shows a settings icon).
      await _pumpUntilFound(tester, find.byIcon(Icons.settings));
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Log out.
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Log out?'));
      // The button is FilledButton.icon - find it by icon first, then tap
      // Or find the "Log out" text that's inside the dialog (not the menu item)
      // Since there are two "Log out" texts (menu and button), find the one in AlertDialog
      final dialogLogoutText = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Log out'),
      );
      await tester.tap(dialogLogoutText);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Back to login.
      await _pumpUntilFound(tester, find.text('Welcome Back'));
    },
  );
}

