import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/track_summary.dart';
import '../learn_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseLearnRepository implements LearnRepository {
  const SupabaseLearnRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<LessonContent?> getLessonById(String lessonId) async {
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

  @override
  Future<List<TrackSummary>> getTracks() async {
    final rows = await _client
        .from('learning_tracks')
        .select('id,title,description,total_modules,completed_modules')
        .eq('is_published', true)
        .order('position', ascending: true);

    return rows
        .map<TrackSummary>(
          (dynamic row) => _mapTrack(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<List<LearningModuleSummary>> getTrackModules(String trackId) async {
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

  @override
  Future<TrackSummary?> getTrackById(String trackId) async {
    final row = await _client
        .from('learning_tracks')
        .select('id,title,description,total_modules,completed_modules')
        .eq('id', trackId)
        .eq('is_published', true)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return _mapTrack(row);
  }

  TrackSummary _mapTrack(Map<String, dynamic> row) {
    final totalModules = SupabaseMappingUtils.intValue(row, const [
      'total_modules',
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
      ], fallback: 0),
      totalModules: totalModules,
    );
  }
}
