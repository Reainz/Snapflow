import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../controllers/profile_controller.dart';
import '../../../core/services/auth_service.dart';
import '../../../routes/app_routes.dart';

class EditProfileView extends GetView<ProfileController> {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = controller.user.value;
    final displayNameController = TextEditingController(text: user.displayName);
    final usernameController = TextEditingController(text: user.username);
    final bioController = TextEditingController(text: user.bio);
    final websiteController = TextEditingController(text: user.website);
    final locationController = TextEditingController(text: user.location);

    final selectedImage = Rx<XFile?>(null);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121218) : colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D3A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              onSelected: (value) async {
                if (value == 'logout' || value == 'switch') {
                  final confirmed = await Get.dialog<bool>(
                    AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text(
                          'You will be signed out and can then log in with another account.'),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          onPressed: () => Get.back(result: true),
                          icon: const Icon(Icons.logout),
                          label: const Text('Log out'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await Get.find<AuthService>().signOut();
                      Get.offAllNamed(Routes.login);
                    } catch (e) {
                      Get.snackbar('Error', 'Failed to log out: $e');
                    }
                  }
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: [
                      Icon(Icons.switch_account_outlined, 
                        color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 12),
                      Text('Switch account',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      const Text('Log out', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Obx(() {
        final reactiveUser = controller.user.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.6),
                            colorScheme.secondary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF121218) : Colors.white,
                        ),
                        child: CircleAvatar(
                          key: ValueKey<String>('${reactiveUser.avatarUrl}_${selectedImage.value?.path ?? ''}'),
                          radius: 56,
                          backgroundColor: isDark 
                              ? const Color(0xFF2D2D3A)
                              : colorScheme.primaryContainer,
                          backgroundImage: selectedImage.value != null
                              ? FileImage(File(selectedImage.value!.path))
                              : (reactiveUser.avatarUrl.isNotEmpty
                                        ? NetworkImage(reactiveUser.avatarUrl)
                                        : null)
                                    as ImageProvider?,
                          child: selectedImage.value == null && reactiveUser.avatarUrl.isEmpty
                              ? Icon(Icons.person, size: 56, 
                                  color: isDark ? Colors.white54 : colorScheme.onPrimaryContainer)
                              : null,
                        ),
                      ),
                    ),
                    // Progress overlay while uploading avatar
                    Obx(() {
                      if (!controller.isUploadingAvatar.value) return const SizedBox.shrink();
                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              value: controller.uploadProgress.value == 0
                                  ? null
                                  : controller.uploadProgress.value,
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primary,
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                            onSelected: (value) async {
                              if (value == 'pick') {
                                final image = await controller.pickProfileImage();
                                if (image != null) {
                                  selectedImage.value = image;
                                }
                              } else if (value == 'remove') {
                                await controller.removeProfileImage();
                                selectedImage.value = null;
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'pick',
                                child: Row(
                                  children: [
                                    Icon(Icons.photo_library_outlined,
                                      color: isDark ? Colors.white70 : Colors.black54),
                                    const SizedBox(width: 12),
                                    Text('Change photo',
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    const SizedBox(width: 12),
                                    const Text('Remove photo', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Form Fields
              _buildTextField(
                context: context,
                controller: displayNameController,
                label: 'Display Name',
                icon: Icons.person_outline,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: usernameController,
                label: 'Username',
                icon: Icons.alternate_email,
                prefix: '@',
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: bioController,
                label: 'Bio',
                icon: Icons.info_outline,
                hint: 'Tell people about yourself...',
                maxLines: 3,
                maxLength: 150,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: websiteController,
                label: 'Website',
                icon: Icons.link,
                hint: 'https://example.com',
                keyboardType: TextInputType.url,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                context: context,
                controller: locationController,
                label: 'Location',
                icon: Icons.location_on_outlined,
                hint: 'City, Country',
                isDark: isDark,
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: controller.isEditLoading.value
                        ? null
                        : () => _saveProfile(
                            displayNameController,
                            usernameController,
                            bioController,
                            websiteController,
                            locationController,
                            selectedImage.value,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: controller.isEditLoading.value
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    String? prefix,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 14,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 22,
          ),
          prefixText: prefix,
          prefixStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          counterStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        textCapitalization: label == 'Username' 
            ? TextCapitalization.none 
            : TextCapitalization.sentences,
      ),
    );
  }

  Future<void> _saveProfile(
    TextEditingController displayNameController,
    TextEditingController usernameController,
    TextEditingController bioController,
    TextEditingController websiteController,
    TextEditingController locationController,
    XFile? selectedImage,
  ) async {
    String? avatarUrl;

    // Upload new profile image if selected
    if (selectedImage != null) {
      avatarUrl = await controller.uploadProfileImage(selectedImage);
      if (avatarUrl == null) {
        Get.snackbar('Error', 'Failed to upload profile image');
        return;
      }
    }

    // Update profile
    await controller.updateProfile(
      displayName: displayNameController.text.trim(),
      username: usernameController.text.trim(),
      bio: bioController.text.trim(),
      website: websiteController.text.trim(),
      location: locationController.text.trim(),
      avatarUrl: avatarUrl,
    );

    // Always show a confirmation toast in this screen for better UX
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      Get.snackbar('Success', 'Profile photo updated');
    } else {
      Get.snackbar('Success', 'Profile updated');
    }
  }
}
