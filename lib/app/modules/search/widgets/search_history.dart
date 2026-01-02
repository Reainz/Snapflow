import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/search_controller.dart';

class SearchHistory extends GetView<SearchModuleController> {
  const SearchHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.searchHistory.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: controller.clearSearchHistory,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...controller.searchHistory.map((term) => _HistoryItem(term: term)),
          ],
        ),
      );
    });
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.term});
  final String term;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SearchModuleController>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history, color: Colors.grey),
      title: Text(term),
      trailing: IconButton(
        icon: const Icon(Icons.north_west, size: 18),
        onPressed: () => controller.searchFromHistory(term),
        tooltip: 'Search again',
      ),
      onTap: () => controller.searchFromHistory(term),
    );
  }
}
