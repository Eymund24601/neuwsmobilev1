import '../models/event_summary.dart';

abstract class EventsRepository {
  Future<List<EventSummary>> getUpcomingEvents();
  Future<EventSummary?> getEventById(String eventId);
  Future<void> registerForEvent(String eventId);
}
