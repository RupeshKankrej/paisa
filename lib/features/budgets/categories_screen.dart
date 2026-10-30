import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ref
          .watch(categoriesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load categories: $error')),
            data: (categories) => ListView(
              children: [
                for (final category in categories)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(category.color),
                    ),
                    title: Text(category.name),
                  ),
              ],
            ),
          ),
    );
  }
}
