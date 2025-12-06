import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes/app_routes.dart';

class AuthController extends GetxController {
  // Reactive variables for form fields
  final email = ''.obs;
  final password = ''.obs;
  final confirmPassword = ''.obs;
  final username = ''.obs;

  // Reactive boolean flags
  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;

  // Error message variable
  final errorMessage = ''.obs;

  // Toggle password visibility
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Toggle confirm password visibility
  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  // Clear error message
  void clearError() {
    errorMessage.value = '';
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    return emailRegex.hasMatch(email);
  }

  // Validate password (minimum 6 characters)
  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  // Login method
  Future<void> login() async {
    // Clear previous errors
    clearError();

    // Trim email and password
    final emailValue = email.value.trim();
    final passwordValue = password.value.trim();

    // Validation checks
    if (emailValue.isEmpty) {
      errorMessage.value = 'Please enter your email address';
      Get.snackbar(
        'Validation Error',
        'Please enter your email address',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_isValidEmail(emailValue)) {
      errorMessage.value = 'Please enter a valid email address';
      Get.snackbar(
        'Validation Error',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (passwordValue.isEmpty) {
      errorMessage.value = 'Please enter your password';
      Get.snackbar(
        'Validation Error',
        'Please enter your password',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_isValidPassword(passwordValue)) {
      errorMessage.value = 'Password must be at least 6 characters';
      Get.snackbar(
        'Validation Error',
        'Password must be at least 6 characters',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Set loading state
    isLoading.value = true;

    try {
      // Attempt to sign in with Firebase Auth
      await Get.find<AuthService>().signInWithEmail(emailValue, passwordValue);

      // Ensure admin role for existing accounts matching allow-list
      await Get.find<AuthService>().ensureAdminRoleIfAllowed();

      // Show success message
      Get.snackbar(
        'Success',
        'Login successful!',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      // Navigate to home screen and clear navigation stack
      Get.offAllNamed(Routes.home);
    } catch (e) {
      // Handle error
      errorMessage.value = e.toString();
      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      // Reset loading state
      isLoading.value = false;
    }
  }

  // Google Sign-In method
  Future<void> signInWithGoogle() async {
    // Clear previous errors
    clearError();

    // Set loading state
    isLoading.value = true;

    try {
      // Attempt to sign in with Google
      final userCredential = await Get.find<AuthService>().signInWithGoogle();

      // Check if user profile exists in Firestore, create if not
      final userRepository = Get.find<UserRepository>();
      final userId = userCredential.user!.uid;
      final userEmail = userCredential.user!.email ?? '';
      final userName = userCredential.user!.displayName ?? 'User';

      // Try to get existing user profile
      try {
        await userRepository.getUserById(userId);
      } catch (e) {
        // User profile doesn't exist, create one
        // Collect geographic data for analytics
        final analyticsService = Get.find<AnalyticsService>();
        final geoData = await analyticsService.collectGeographicData();
        
        await userRepository.createUserProfile(
          userId: userId,
          email: userEmail,
          username: userName.replaceAll(' ', '').toLowerCase(),
          displayName: userName,
          countryCode: geoData?['countryCode'],
          region: geoData?['region'],
        );
      }

  // Small delay to allow Cloud Function to set custom claims (best-effort)
      await Future.delayed(const Duration(seconds: 2));
  // Ensure admin role if allowed (for existing accounts)
  await Get.find<AuthService>().ensureAdminRoleIfAllowed();
      // Refresh admin claim so UI can immediately reflect admin access
      await Get.find<AuthService>().refreshAdminClaim();

      // Show success message
      Get.snackbar(
        'Success',
        'Signed in with Google successfully!',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      // Navigate to home screen and clear navigation stack
      Get.offAllNamed(Routes.home);
    } catch (e) {
      // Handle error
      errorMessage.value = e.toString();
      Get.snackbar(
        'Google Sign-In Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      // Reset loading state
      isLoading.value = false;
    }
  }

  // Signup method
  Future<void> signup() async {
    // Clear previous errors
    clearError();

    // Trim form values
    final emailValue = email.value.trim();
    final passwordValue = password.value.trim();
    final confirmPasswordValue = confirmPassword.value.trim();
    final usernameValue = username.value.trim();

    // Validation checks
    if (emailValue.isEmpty) {
      errorMessage.value = 'Please enter your email address';
      Get.snackbar(
        'Validation Error',
        'Please enter your email address',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_isValidEmail(emailValue)) {
      errorMessage.value = 'Please enter a valid email address';
      Get.snackbar(
        'Validation Error',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (usernameValue.isEmpty) {
      errorMessage.value = 'Please enter a username';
      Get.snackbar(
        'Validation Error',
        'Please enter a username',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (usernameValue.length < 3) {
      errorMessage.value = 'Username must be at least 3 characters';
      Get.snackbar(
        'Validation Error',
        'Username must be at least 3 characters',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (passwordValue.isEmpty) {
      errorMessage.value = 'Please enter a password';
      Get.snackbar(
        'Validation Error',
        'Please enter a password',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!_isValidPassword(passwordValue)) {
      errorMessage.value = 'Password must be at least 6 characters';
      Get.snackbar(
        'Validation Error',
        'Password must be at least 6 characters',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (confirmPasswordValue.isEmpty) {
      errorMessage.value = 'Please confirm your password';
      Get.snackbar(
        'Validation Error',
        'Please confirm your password',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Check if passwords match
    if (passwordValue != confirmPasswordValue) {
      errorMessage.value = 'Passwords do not match';
      Get.snackbar(
        'Validation Error',
        'Passwords do not match. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Set loading state
    isLoading.value = true;

    try {
      // Create Firebase Auth account
      final authService = Get.find<AuthService>();
      final userCredential = await authService.signUpWithEmail(
        emailValue,
        passwordValue,
      );

      // Collect geographic data for analytics
      final analyticsService = Get.find<AnalyticsService>();
      final geoData = await analyticsService.collectGeographicData();

      // Create user profile in Firestore
      await Get.find<UserRepository>().createUserProfile(
        userId: userCredential.user!.uid,
        email: emailValue,
        username: usernameValue,
        displayName: usernameValue,
        countryCode: geoData?['countryCode'],
        region: geoData?['region'],
      );

  // Best-effort: wait briefly for custom claims to be set and refresh token
      await Future.delayed(const Duration(seconds: 2));
  // Ensure admin role if allowed (for existing accounts)
  await authService.ensureAdminRoleIfAllowed();
      await authService.refreshAdminClaim();

      // Show success message
      Get.snackbar(
        'Success',
        'Account created successfully! Welcome to Snapflow.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      // Navigate to home screen and clear navigation stack
      Get.offAllNamed(Routes.home);
    } catch (e) {
      // Handle error
      errorMessage.value = e.toString();
      Get.snackbar(
        'Signup Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      // Reset loading state
      isLoading.value = false;
    }
  }

  // Forgot Password method with email input dialog
  Future<void> forgotPassword() async {
    // Clear previous errors
    clearError();

    // Create a text controller for the dialog input
    final TextEditingController emailController = TextEditingController();

    // Show dialog to get email input
    final result = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Get.back(result: emailController.text.trim());
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    // User cancelled the dialog
    if (result == null || result.isEmpty) {
      return;
    }

    // Validate email format
    if (!_isValidEmail(result)) {
      Get.snackbar(
        'Invalid Email',
        'Please enter a valid email address',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Set loading state
    isLoading.value = true;

    try {
      // Send password reset email via Firebase Auth
      await Get.find<AuthService>().sendPasswordResetEmail(result);

      // Show success message
      Get.snackbar(
        'Email Sent',
        'Password reset link has been sent to $result. Please check your email.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      // Handle error
      errorMessage.value = e.toString();
      Get.snackbar(
        'Reset Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      // Reset loading state
      isLoading.value = false;
    }
  }
}
