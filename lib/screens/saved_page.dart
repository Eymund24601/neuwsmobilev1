import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_in_required_view.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSession = ref.watch(hasSupabaseSessionProvider);
    final savedAsync = ref.watch(savedArticlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Saved', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !hasSession
          ? const SignInRequiredView(
              message: 'Sign in is required to view saved articles.',
            )
          : savedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load saved articles: $error'),
                ),
              ),
              data: (saved) {
                if (saved.isEmpty) {
                  return const Center(child: Text('No saved articles yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: saved.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => _SavedItem(
                    title: saved[index].title,
                    date: saved[index].dateLabel,
                    onTap: () {
                      if (saved[index].slug.isEmpty) {
                        return;
                      }
                      context.pushNamed(
                        AppRouteName.article,
                        pathParameters: {'slug': saved[index].slug},
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _SavedItem extends StatelessWidget {
  const _SavedItem({
    required this.title,
    required this.date,
    required this.onTap,
  });

  final String title;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
