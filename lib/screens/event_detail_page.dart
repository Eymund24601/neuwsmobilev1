import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load event: $error'),
          ),
        ),
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  event.imageAsset,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                event.title,
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 10),
              Text(
                '${event.location} · ${event.dateLabel}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {},
                child: const Text('RSVP (UI only)'),
              ),
            ],
          );
        },
      ),
    );
  }
}
