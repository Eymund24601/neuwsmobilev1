import '../../models/event_summary.dart';
import '../events_repository.dart';

class MockEventsRepository implements EventsRepository {
  static const _events = [
    EventSummary(
      id: 'event-1',
      title: 'Vienna Culture Night',
      location: 'Vienna, Austria',
      dateLabel: 'FEB 14 - 19:00',
      tag: 'Culture',
      description:
          'A local creator meetup focused on music and city storytelling.',
      imageAsset: 'assets/images/placeholder.jpg',
    ),
    EventSummary(
      id: 'event-2',
      title: 'EU Elections Watch Party',
      location: 'Brussels, Belgium',
      dateLabel: 'FEB 18 - 20:00',
      tag: 'Politics',
      description:
          'Community screening and discussion with moderators from across Europe.',
      imageAsset: 'assets/images/placeholder.jpg',
    ),
    EventSummary(
      id: 'event-3',
      title: 'Nordic Design Meetup',
      location: 'Helsinki, Finland',
      dateLabel: 'FEB 21 - 18:30',
      tag: 'Design',
      description:
          'Talks from creators covering Nordic design and local creative economies.',
      imageAsset: 'assets/images/placeholder.jpg',
    ),
    EventSummary(
      id: 'event-4',
      title: 'Lisbon Product Builders Night',
      location: 'Lisbon, Portugal',
      dateLabel: 'FEB 25 - 18:00',
      tag: 'Tech',
      description:
          'Founders and creators discuss product, media, and European distribution.',
      imageAsset: 'assets/images/placeholder.jpg',
    ),
    EventSummary(
      id: 'event-5',
      title: 'Prague History Walk and Debate',
      location: 'Prague, Czechia',
      dateLabel: 'FEB 27 - 17:30',
      tag: 'History',
      description:
          'Guided city walk followed by a moderated discussion and Q&A.',
      imageAsset: 'assets/images/placeholder.jpg',
    ),
  ];

  @override
  Future<EventSummary?> getEventById(String eventId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final event in _events) {
      if (event.id == eventId) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<List<EventSummary>> getUpcomingEvents() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _events;
  }

  @override
  Future<void> registerForEvent(String eventId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}
