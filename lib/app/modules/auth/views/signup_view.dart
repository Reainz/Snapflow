import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class SignupView extends GetView<AuthController> {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Reactive checkbox state
    final acceptTerms = false.obs;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121218) : Colors.grey.shade50,
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Get.back(),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Title
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join Snapflow and start sharing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 36),

                // Username TextField
                _buildInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Username',
                  hint: 'Choose a username',
                  icon: Icons.person_outline_rounded,
                  helperText: 'Minimum 3 characters',
                  onChanged: (value) => controller.username.value = value,
                ),
                const SizedBox(height: 16),

                // Email TextField
                _buildInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => controller.email.value = value,
                ),
                const SizedBox(height: 16),

                // Password TextField with visibility toggle
                Obx(() => _buildInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Password',
                  hint: 'Create a password',
                  icon: Icons.lock_outline_rounded,
                  helperText: 'Minimum 6 characters',
                  obscureText: !controller.isPasswordVisible.value,
                  onChanged: (value) => controller.password.value = value,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isPasswordVisible.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                    onPressed: controller.togglePasswordVisibility,
                  ),
                )),
                const SizedBox(height: 16),

                // Confirm Password TextField with visibility toggle
                Obx(() => _buildInputField(
                  context: context,
                  isDark: isDark,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: !controller.isConfirmPasswordVisible.value,
                  onChanged: (value) => controller.confirmPassword.value = value,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isConfirmPasswordVisible.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                    onPressed: controller.toggleConfirmPasswordVisibility,
                  ),
                )),
                const SizedBox(height: 20),

                // Terms & Conditions Checkbox
                Obx(
                  () => GestureDetector(
                    onTap: () => acceptTerms.value = !acceptTerms.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: acceptTerms.value 
                              ? colorScheme.primary.withValues(alpha: 0.5)
                              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                          width: acceptTerms.value ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: acceptTerms.value 
                                  ? colorScheme.primary 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: acceptTerms.value 
                                    ? colorScheme.primary 
                                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                                width: 2,
                              ),
                            ),
                            child: acceptTerms.value
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sign Up Button with reactive loading state
                Obx(() => _buildPrimaryButton(
                  context: context,
                  isDark: isDark,
                  label: 'Create Account',
                  isLoading: controller.isLoading.value,
                  isEnabled: acceptTerms.value,
                  onPressed: controller.signup,
                )),
                const SizedBox(height: 28),

                // Already have account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Get.toNamed(Routes.login),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            onChanged: onChanged,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required bool isDark,
    required String label,
    required bool isLoading,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = isEnabled && !isLoading;
    
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isActive 
            ? LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isActive 
                              ? Colors.white 
                              : (isDark ? Colors.white38 : Colors.grey.shade500),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: isActive 
                            ? Colors.white 
                            : (isDark ? Colors.white38 : Colors.grey.shade500),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
