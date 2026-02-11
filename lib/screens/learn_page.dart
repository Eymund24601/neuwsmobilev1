import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../models/track_summary.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final tracksAsync = ref.watch(tracksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Words')),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load tracks: $error'),
          ),
        ),
        data: (tracks) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Short tracks on Europe, culture, and politics',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: palette.muted),
                ),
              ),
              const SizedBox(height: 18),
              for (final track in tracks) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TrackCard(track: track),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track});

  final TrackSummary track;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            track.description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: track.progress,
              minHeight: 6,
              backgroundColor: palette.progressBg,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${track.completedModules}/${track.totalModules} modules complete',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () {
                  context.pushNamed(
                    AppRouteName.learnTrack,
                    pathParameters: {'trackId': track.id},
                  );
                },
                child: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
