import '../../models/track_summary.dart';
import '../learn_repository.dart';

class MockLearnRepository implements LearnRepository {
  static const _tracks = [
    TrackSummary(
      id: 'track-eu',
      title: 'How the EU actually works',
      description: 'Institutions, elections, and power in plain language.',
      completedModules: 3,
      totalModules: 6,
    ),
    TrackSummary(
      id: 'track-culture',
      title: 'Modern European culture',
      description: 'Cities, scenes, and movements shaping Europe right now.',
      completedModules: 1,
      totalModules: 5,
    ),
  ];

  static const _modules = [
    LearningModuleSummary(
      id: 'm1',
      trackId: 'track-eu',
      title: 'Parliament vs Commission',
      isLocked: false,
      isCompleted: true,
      lessonId: 'lesson-eu-1',
    ),
    LearningModuleSummary(
      id: 'm2',
      trackId: 'track-eu',
      title: 'Council voting explained',
      isLocked: false,
      isCompleted: false,
      lessonId: 'lesson-eu-2',
    ),
    LearningModuleSummary(
      id: 'm3',
      trackId: 'track-eu',
      title: 'How directives become law',
      isLocked: true,
      isCompleted: false,
      lessonId: 'lesson-eu-3',
    ),
    LearningModuleSummary(
      id: 'm4',
      trackId: 'track-culture',
      title: 'Spanish urban music 101',
      isLocked: false,
      isCompleted: false,
      lessonId: 'lesson-culture-1',
    ),
  ];

  static const _lessons = [
    LessonContent(
      id: 'lesson-eu-1',
      title: 'Parliament vs Commission',
      questions: [
        LessonQuestion(
          id: 'q1',
          prompt: 'Which body proposes new EU legislation?',
          options: ['The Commission', 'The Parliament', 'The Council', 'The Court'],
          correctIndex: 0,
        ),
        LessonQuestion(
          id: 'q2',
          prompt: 'Which body is directly elected by EU citizens?',
          options: ['Council', 'Commission', 'Parliament', 'Court'],
          correctIndex: 2,
        ),
      ],
    ),
    LessonContent(
      id: 'lesson-eu-2',
      title: 'Council voting explained',
      questions: [
        LessonQuestion(
          id: 'q3',
          prompt: 'Qualified majority voting needs a majority of what?',
          options: ['Countries only', 'Population only', 'Countries and population', 'Unanimity'],
          correctIndex: 2,
        ),
      ],
    ),
    LessonContent(
      id: 'lesson-culture-1',
      title: 'Spanish urban music 101',
      questions: [
        LessonQuestion(
          id: 'q4',
          prompt: 'Which city is strongly associated with modern Spanish trap scenes?',
          options: ['Madrid', 'Lisbon', 'Hamburg', 'Prague'],
          correctIndex: 0,
        ),
      ],
    ),
  ];

  @override
  Future<LessonContent?> getLessonById(String lessonId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final lesson in _lessons) {
      if (lesson.id == lessonId) {
        return lesson;
      }
    }
    return null;
  }

  @override
  Future<List<TrackSummary>> getTracks() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _tracks;
  }

  @override
  Future<List<LearningModuleSummary>> getTrackModules(String trackId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _modules.where((module) => module.trackId == trackId).toList();
  }

  @override
  Future<TrackSummary?> getTrackById(String trackId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final track in _tracks) {
      if (track.id == trackId) {
        return track;
      }
    }
    return null;
  }
}
