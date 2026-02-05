class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.isPremium,
  });

  final String id;
  final String title;
  final String category;
  final String difficulty;
  final int estimatedMinutes;
  final bool isPremium;

  factory QuizSummary.fromJson(Map<String, dynamic> json) {
    return QuizSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      estimatedMinutes: json['estimatedMinutes'] as int,
      isPremium: json['isPremium'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'difficulty': difficulty,
      'estimatedMinutes': estimatedMinutes,
      'isPremium': isPremium,
    };
  }
}
