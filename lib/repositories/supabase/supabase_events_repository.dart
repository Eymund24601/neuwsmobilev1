import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/event_summary.dart';
import '../events_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseEventsRepository implements EventsRepository {
  const SupabaseEventsRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<EventSummary?> getEventById(String eventId) async {
    final row = await _client
        .from('events')
        .select('''
          id,
          title,
          location,
          location_label,
          city,
          country_code,
          start_date,
          start_at,
          tag,
          category,
          description,
          image_asset,
          cover_image_url,
          is_published
          ''')
        .eq('id', eventId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return _mapEvent(row);
  }

  @override
  Future<List<EventSummary>> getUpcomingEvents() async {
    final nowIso = DateTime.now().toIso8601String();
    List<dynamic> rows;
    try {
      rows = await _client
          .from('events')
          .select('''
            id,
            title,
            location,
            location_label,
            city,
            country_code,
            start_date,
            start_at,
            tag,
            category,
            description,
            image_asset,
            cover_image_url,
            is_published
            ''')
          .eq('is_published', true)
          .or('start_date.gte.$nowIso,start_at.gte.$nowIso')
          .order('start_at', ascending: true, nullsFirst: false)
          .order('start_date', ascending: true, nullsFirst: false)
          .limit(40);
    } on PostgrestException {
      rows = await _client
          .from('events')
          .select('''
            id,
            title,
            location,
            city,
            country_code,
            start_date,
            tag,
            category,
            description,
            image_asset,
            cover_image_url
            ''')
          .gte('start_date', nowIso)
          .order('start_date', ascending: true)
          .limit(40);
    }

    return rows
        .map<EventSummary>(
          (dynamic row) => _mapEvent(row as Map<String, dynamic>),
        )
        .toList();
  }

  EventSummary _mapEvent(Map<String, dynamic> row) {
    final date = SupabaseMappingUtils.dateTimeValue(row, const [
      'start_at',
      'start_date',
    ]);
    final month = date == null ? 'TBD' : _months[date.month - 1];
    final dateLabel = date == null
        ? 'DATE TBD'
        : '$month ${date.day.toString().padLeft(2, '0')} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final location = SupabaseMappingUtils.stringValue(
      row,
      const ['location', 'location_label'],
      fallback: [
        SupabaseMappingUtils.stringValue(row, const ['city']),
        SupabaseMappingUtils.stringValue(row, const ['country_code']),
      ].where((v) => v.isNotEmpty).join(', '),
    );

    return EventSummary(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: 'Upcoming event'),
      location: location.isEmpty ? 'Europe' : location,
      dateLabel: dateLabel,
      tag: SupabaseMappingUtils.stringValue(row, const [
        'tag',
        'category',
      ], fallback: 'Community'),
      description: SupabaseMappingUtils.stringValue(row, const [
        'description',
      ], fallback: 'Details will be announced soon.'),
      imageAsset: SupabaseMappingUtils.stringValue(row, const [
        'cover_image_url',
        'image_asset',
      ], fallback: 'assets/images/placeholder.jpg'),
    );
  }

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
}
