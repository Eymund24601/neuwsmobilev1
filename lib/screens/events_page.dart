import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load events: $error'),
          ),
        ),
        data: (events) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              return GestureDetector(
                onTap: () {
                  context.pushNamed(
                    AppRouteName.eventDetail,
                    pathParameters: {'eventId': event.id},
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              event.tag,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            event.dateLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            context.pushNamed(
                              AppRouteName.eventDetail,
                              pathParameters: {'eventId': event.id},
                            );
                          },
                          child: const Text('Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
