import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../models/track_summary.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class LearnTrackPage extends ConsumerWidget {
  const LearnTrackPage({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final tracksAsync = ref.watch(tracksProvider);
    final modulesAsync = ref.watch(trackModulesProvider(trackId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track'),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load track: $error'),
          ),
        ),
        data: (tracks) {
          final track = _findTrack(tracks, trackId);
          if (track == null) {
            return const Center(child: Text('Track not found.'));
          }
          return modulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Could not load modules: $error'),
              ),
            ),
            data: (modules) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(track.title, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text(
                    track.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 16),
                  for (final module in modules) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            module.isCompleted
                                ? Icons.check_circle
                                : (module.isLocked ? Icons.lock_outline : Icons.radio_button_checked),
                            color: module.isCompleted
                                ? Colors.green
                                : (module.isLocked ? palette.muted : Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(module.title, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          FilledButton.tonal(
                            onPressed: module.isLocked
                                ? null
                                : () {
                                    context.pushNamed(
                                      AppRouteName.lesson,
                                      pathParameters: {'lessonId': module.lessonId},
                                    );
                                  },
                            child: Text(module.isCompleted ? 'Review' : 'Start'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  TrackSummary? _findTrack(List<TrackSummary> tracks, String id) {
    for (final item in tracks) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}
