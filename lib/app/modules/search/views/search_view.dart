import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_opacity.dart';
import '../controllers/search_controller.dart';
import '../widgets/search_history.dart';
import '../widgets/trending_section.dart';
import '../widgets/user_search_list.dart';
import '../widgets/video_search_grid.dart';

class SearchView extends GetView<SearchModuleController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text(
          'Search',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      ],
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: AppOpacity.lightOverlay),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    elevation: 1,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.transparent,
                    child: TextField(
                      controller: controller.textController,
                      onChanged: controller.onQueryChanged,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search videos, creators, or hashtags',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                        suffixIcon: Obx(
                          () => controller.query.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: controller.clearQuery,
                                )
                              : const SizedBox.shrink(),
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
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Results
          Expanded(
            child: Obx(() {
              if (controller.query.isEmpty) {
                // Show trending and history when no active query
                return ListView(
                  children: const [
                    TrendingSection(),
                    SearchHistory(),
                  ],
                );
              }

              if (controller.isSearching.value) {
                return const Center(child: CircularProgressIndicator());
              }

              return DefaultTabController(
                length: 2, // Videos, Users (Hashtags optional future)
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      tabs: const [
                        Tab(text: 'Videos'),
                        Tab(text: 'Users'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          VideoSearchGrid(),
                          UserSearchList(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
