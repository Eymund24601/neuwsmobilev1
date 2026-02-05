import '../models/track_summary.dart';

abstract class LearnRepository {
  Future<List<TrackSummary>> getTracks();
  Future<TrackSummary?> getTrackById(String trackId);
  Future<List<LearningModuleSummary>> getTrackModules(String trackId);
  Future<LessonContent?> getLessonById(String lessonId);
}
