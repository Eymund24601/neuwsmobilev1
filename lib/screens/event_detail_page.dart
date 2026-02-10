import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_image.dart';

class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  bool _submitting = false;
  bool _registered = false;

  Future<void> _register() async {
    if (_submitting || _registered) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(eventsRepositoryProvider).registerForEvent(widget.eventId);
      if (!mounted) {
        return;
      }
      setState(() => _registered = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('RSVP confirmed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '$error';
      if (message.toLowerCase().contains('sign in required')) {
        context.pushNamed(AppRouteName.signIn);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not RSVP: $error')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

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
              AdaptiveImage(
                source: event.imageAsset,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(14),
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
                '${event.location} | ${event.dateLabel}',
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
                onPressed: _registered || _submitting ? null : _register,
                child: Text(
                  _registered
                      ? 'RSVP Confirmed'
                      : (_submitting ? 'Sending RSVP...' : 'RSVP'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
