import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_in_required_view.dart';

class CreatorStudioPage extends ConsumerWidget {
  const CreatorStudioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final useMockData = ref.watch(useMockDataProvider);
    final hasSession = ref.watch(hasSupabaseSessionProvider);
    final creatorAsync = ref.watch(creatorStudioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Creative Studio')),
      body: (!useMockData && !hasSession)
          ? const SignInRequiredView(
              message: 'Sign in is required to access Creative Studio.',
            )
          : creatorAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load creator studio: $error'),
                ),
              ),
              data: (data) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _StatCard(
                      title: 'Drafts',
                      value: '${data.drafts}',
                      palette: palette,
                    ),
                    const SizedBox(height: 10),
                    _StatCard(
                      title: 'Published this month',
                      value: '${data.publishedThisMonth}',
                      palette: palette,
                    ),
                    const SizedBox(height: 10),
                    _StatCard(
                      title: 'Estimated earnings',
                      value: data.estimatedEarnings,
                      palette: palette,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.pushNamed(AppRouteName.write),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Open Write Flow'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.palette,
  });

  final String title;
  final String value;
  final NeuwsPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
