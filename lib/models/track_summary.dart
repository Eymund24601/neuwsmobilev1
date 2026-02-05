class TrackSummary {
  const TrackSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.completedModules,
    required this.totalModules,
  });

  final String id;
  final String title;
  final String description;
  final int completedModules;
  final int totalModules;

  double get progress {
    if (totalModules == 0) {
      return 0;
    }
    return completedModules / totalModules;
  }

  factory TrackSummary.fromJson(Map<String, dynamic> json) {
    return TrackSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      completedModules: json['completedModules'] as int,
      totalModules: json['totalModules'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completedModules': completedModules,
      'totalModules': totalModules,
    };
  }
}

class LearningModuleSummary {
  const LearningModuleSummary({
    required this.id,
    required this.trackId,
    required this.title,
    required this.isLocked,
    required this.isCompleted,
    required this.lessonId,
  });

  final String id;
  final String trackId;
  final String title;
  final bool isLocked;
  final bool isCompleted;
  final String lessonId;

  factory LearningModuleSummary.fromJson(Map<String, dynamic> json) {
    return LearningModuleSummary(
      id: json['id'] as String,
      trackId: json['trackId'] as String,
      title: json['title'] as String,
      isLocked: json['isLocked'] as bool,
      isCompleted: json['isCompleted'] as bool,
      lessonId: json['lessonId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trackId': trackId,
      'title': title,
      'isLocked': isLocked,
      'isCompleted': isCompleted,
      'lessonId': lessonId,
    };
  }
}

class LessonQuestion {
  const LessonQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    return LessonQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List<dynamic>).cast<String>(),
      correctIndex: json['correctIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'options': options,
      'correctIndex': correctIndex,
    };
  }
}

class LessonContent {
  const LessonContent({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<LessonQuestion> questions;

  factory LessonContent.fromJson(Map<String, dynamic> json) {
    return LessonContent(
      id: json['id'] as String,
      title: json['title'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map((item) => LessonQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'questions': questions.map((question) => question.toJson()).toList(),
    };
  }
}
