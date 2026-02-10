import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/track_summary.dart';
import '../learn_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseLearnRepository implements LearnRepository {
  const SupabaseLearnRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<LessonContent?> getLessonById(String lessonId) async {
    try {
      final setRow = await _client
          .from('quiz_sets')
          .select('id,title')
          .eq('id', lessonId)
          .eq('is_published', true)
          .maybeSingle();
      if (setRow == null) {
        return null;
      }

      final questionRows = await _client
          .from('quiz_questions')
          .select('''
            id,
            prompt,
            position,
            quiz_options(
              id,
              position,
              option_text,
              is_correct
            )
          ''')
          .eq('quiz_set_id', lessonId)
          .order('position', ascending: true);

      final questions = questionRows.map<LessonQuestion>((dynamic row) {
        final map = row as Map<String, dynamic>;
        final rawOptions = map['quiz_options'];
        var optionsWithCorrect = <Map<String, dynamic>>[];
        if (rawOptions is List) {
          optionsWithCorrect =
              rawOptions.whereType<Map<String, dynamic>>().toList()
                ..sort((a, b) {
                  final left = SupabaseMappingUtils.intValue(a, const [
                    'position',
                  ]);
                  final right = SupabaseMappingUtils.intValue(b, const [
                    'position',
                  ]);
                  return left.compareTo(right);
                });
        }

        final options = optionsWithCorrect
            .map(
              (option) => SupabaseMappingUtils.stringValue(option, const [
                'option_text',
              ], fallback: 'Option'),
            )
            .toList();
        var correctIndex = optionsWithCorrect.indexWhere(
          (option) => SupabaseMappingUtils.boolValue(option, const [
            'is_correct',
          ], fallback: false),
        );
        if (correctIndex < 0) {
          correctIndex = 0;
        }

        return LessonQuestion(
          id: SupabaseMappingUtils.stringValue(map, const ['id'], fallback: ''),
          prompt: SupabaseMappingUtils.stringValue(map, const [
            'prompt',
          ], fallback: 'Question'),
          options: options,
          correctIndex: correctIndex,
        );
      }).toList();

      return LessonContent(
        id: SupabaseMappingUtils.stringValue(setRow, const [
          'id',
        ], fallback: lessonId),
        title: SupabaseMappingUtils.stringValue(setRow, const [
          'title',
        ], fallback: 'Lesson'),
        questions: questions,
      );
    } on PostgrestException {
      return _getLegacyLessonById(lessonId);
    }
  }

  @override
  Future<List<TrackSummary>> getTracks() async {
    try {
      final rows = await _client
          .from('quiz_sets')
          .select('id,title,description,topic,is_published')
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final dynamic row in rows) {
        final map = row as Map<String, dynamic>;
        final topic = _normalizedTopic(
          SupabaseMappingUtils.stringValue(map, const [
            'topic',
          ], fallback: 'General'),
        );
        grouped.putIfAbsent(topic, () => <Map<String, dynamic>>[]).add(map);
      }

      if (grouped.isEmpty) {
        return const [];
      }

      final attemptedQuizIds = await _attemptedQuizIds();
      final tracks = <TrackSummary>[];
      for (final entry in grouped.entries) {
        final topic = entry.key;
        final sets = entry.value;
        final totalModules = sets.length;
        var completedModules = 0;
        for (final set in sets) {
          final quizId = SupabaseMappingUtils.stringValue(set, const ['id']);
          if (quizId.isNotEmpty && attemptedQuizIds.contains(quizId)) {
            completedModules++;
          }
        }

        final description = sets
            .map(
              (set) => SupabaseMappingUtils.stringValue(set, const [
                'description',
              ], fallback: ''),
            )
            .firstWhere((item) => item.isNotEmpty, orElse: () => '');

        tracks.add(
          TrackSummary(
            id: _topicTrackId(topic),
            title: topic,
            description: description.isEmpty
                ? 'Quiz-backed learning track'
                : description,
            completedModules: completedModules,
            totalModules: totalModules,
          ),
        );
      }
      tracks.sort((a, b) => a.title.compareTo(b.title));
      return tracks;
    } on PostgrestException {
      return _getLegacyTracks();
    }
  }

  @override
  Future<List<LearningModuleSummary>> getTrackModules(String trackId) async {
    try {
      final rows = await _client
          .from('quiz_sets')
          .select('id,title,topic,is_published')
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final modulesForTrack = rows
          .map((dynamic row) => row as Map<String, dynamic>)
          .where((row) {
            final topic = _normalizedTopic(
              SupabaseMappingUtils.stringValue(row, const [
                'topic',
              ], fallback: 'General'),
            );
            return _topicTrackId(topic) == trackId;
          })
          .toList();
      if (modulesForTrack.isEmpty) {
        return const [];
      }

      final attemptedQuizIds = await _attemptedQuizIds();
      final sorted = [...modulesForTrack]
        ..sort((a, b) {
          final leftTitle = SupabaseMappingUtils.stringValue(a, const [
            'title',
          ], fallback: '');
          final rightTitle = SupabaseMappingUtils.stringValue(b, const [
            'title',
          ], fallback: '');
          return leftTitle.compareTo(rightTitle);
        });

      var seenUnlocked = false;
      final modules = <LearningModuleSummary>[];
      for (final row in sorted) {
        final quizId = SupabaseMappingUtils.stringValue(row, const ['id']);
        final isCompleted =
            quizId.isNotEmpty && attemptedQuizIds.contains(quizId);
        final isLocked = seenUnlocked && !isCompleted;
        seenUnlocked = true;
        modules.add(
          LearningModuleSummary(
            id: quizId,
            trackId: trackId,
            title: SupabaseMappingUtils.stringValue(row, const [
              'title',
            ], fallback: 'Module'),
            isLocked: isLocked,
            isCompleted: isCompleted,
            lessonId: quizId,
          ),
        );
      }

      return modules;
    } on PostgrestException {
      return _getLegacyTrackModules(trackId);
    }
  }

  @override
  Future<TrackSummary?> getTrackById(String trackId) async {
    final tracks = await getTracks();
    for (final track in tracks) {
      if (track.id == trackId) {
        return track;
      }
    }
    return null;
  }

  TrackSummary _mapTrack(Map<String, dynamic> row) {
    final totalModules = SupabaseMappingUtils.intValue(row, const [
      'total_modules',
      'modules_count',
      'module_count',
      'lessons_count',
    ], fallback: 0);
    return TrackSummary(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: 'Learning track'),
      description: SupabaseMappingUtils.stringValue(row, const [
        'description',
      ], fallback: ''),
      completedModules: SupabaseMappingUtils.intValue(row, const [
        'completed_modules',
        'completed_count',
      ], fallback: 0),
      totalModules: totalModules,
    );
  }

  Future<List<TrackSummary>> _getLegacyTracks() async {
    final rows = await _client
        .from('learning_tracks')
        .select('*')
        .eq('is_published', true)
        .order('position', ascending: true);

    return rows
        .map<TrackSummary>(
          (dynamic row) => _mapTrack(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<LearningModuleSummary>> _getLegacyTrackModules(
    String trackId,
  ) async {
    final rows = await _client
        .from('learning_modules')
        .select('id,track_id,title,is_locked,is_completed,lesson_id')
        .eq('track_id', trackId)
        .order('position', ascending: true);

    return rows.map<LearningModuleSummary>((dynamic row) {
      final map = row as Map<String, dynamic>;
      return LearningModuleSummary(
        id: SupabaseMappingUtils.stringValue(map, const ['id'], fallback: ''),
        trackId: SupabaseMappingUtils.stringValue(map, const [
          'track_id',
        ], fallback: trackId),
        title: SupabaseMappingUtils.stringValue(map, const [
          'title',
        ], fallback: 'Module'),
        isLocked: SupabaseMappingUtils.boolValue(map, const [
          'is_locked',
        ], fallback: false),
        isCompleted: SupabaseMappingUtils.boolValue(map, const [
          'is_completed',
        ], fallback: false),
        lessonId: SupabaseMappingUtils.stringValue(map, const [
          'lesson_id',
        ], fallback: ''),
      );
    }).toList();
  }

  Future<LessonContent?> _getLegacyLessonById(String lessonId) async {
    final quizRow = await _client
        .from('quizzes')
        .select('id,title')
        .eq('id', lessonId)
        .maybeSingle();
    if (quizRow == null) {
      return null;
    }

    final questionsRows = await _client
        .from('quiz_questions')
        .select('id,prompt,options,correct_index')
        .eq('quiz_id', lessonId)
        .order('position', ascending: true);

    final questions = questionsRows.map<LessonQuestion>((dynamic row) {
      final map = row as Map<String, dynamic>;
      final options = map['options'] is List
          ? (map['options'] as List).map((item) => '$item').toList()
          : const <String>[];
      return LessonQuestion(
        id: SupabaseMappingUtils.stringValue(map, const ['id'], fallback: ''),
        prompt: SupabaseMappingUtils.stringValue(map, const [
          'prompt',
        ], fallback: 'Question'),
        options: options,
        correctIndex: SupabaseMappingUtils.intValue(map, const [
          'correct_index',
        ], fallback: 0),
      );
    }).toList();

    return LessonContent(
      id: SupabaseMappingUtils.stringValue(quizRow, const [
        'id',
      ], fallback: lessonId),
      title: SupabaseMappingUtils.stringValue(quizRow, const [
        'title',
      ], fallback: 'Lesson'),
      questions: questions,
    );
  }

  Future<Set<String>> _attemptedQuizIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const <String>{};
    }
    try {
      final rows = await _client
          .from('quiz_attempts')
          .select('quiz_set_id')
          .eq('user_id', userId)
          .not('completed_at', 'is', null);
      return rows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['quiz_set_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toSet();
    } on PostgrestException {
      return const <String>{};
    }
  }

  String _normalizedTopic(String topic) {
    final trimmed = topic.trim();
    return trimmed.isEmpty ? 'General' : trimmed;
  }

  String _topicTrackId(String topic) {
    final normalized = topic.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    return 'quiz-track-$normalized';
  }
}
