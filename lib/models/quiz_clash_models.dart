class QuizClashCategoryOption {
  const QuizClashCategoryOption({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  factory QuizClashCategoryOption.fromJson(Map<String, dynamic> json) {
    return QuizClashCategoryOption(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'slug': slug, 'name': name};
  }
}

class QuizClashInviteSummary {
  const QuizClashInviteSummary({
    required this.id,
    required this.opponentUserId,
    required this.opponentDisplayName,
    required this.opponentUsername,
    required this.status,
    required this.isIncoming,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String opponentUserId;
  final String opponentDisplayName;
  final String opponentUsername;
  final String status;
  final bool isIncoming;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory QuizClashInviteSummary.fromJson(Map<String, dynamic> json) {
    return QuizClashInviteSummary(
      id: json['id'] as String,
      opponentUserId: json['opponentUserId'] as String,
      opponentDisplayName: json['opponentDisplayName'] as String,
      opponentUsername: json['opponentUsername'] as String,
      status: json['status'] as String,
      isIncoming: json['isIncoming'] as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'opponentUserId': opponentUserId,
      'opponentDisplayName': opponentDisplayName,
      'opponentUsername': opponentUsername,
      'status': status,
      'isIncoming': isIncoming,
      'createdAt': createdAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}

class QuizClashMatchSummary {
  const QuizClashMatchSummary({
    required this.id,
    required this.status,
    required this.currentRoundIndex,
    required this.totalRounds,
    required this.scoreMe,
    required this.scoreOpponent,
    required this.isMyTurn,
    required this.turnDeadlineAt,
    required this.opponentUserId,
    required this.opponentDisplayName,
    required this.opponentUsername,
    required this.canMessageOpponent,
  });

  final String id;
  final String status;
  final int currentRoundIndex;
  final int totalRounds;
  final int scoreMe;
  final int scoreOpponent;
  final bool isMyTurn;
  final DateTime? turnDeadlineAt;
  final String opponentUserId;
  final String opponentDisplayName;
  final String opponentUsername;
  final bool canMessageOpponent;

  factory QuizClashMatchSummary.fromJson(Map<String, dynamic> json) {
    return QuizClashMatchSummary(
      id: json['id'] as String,
      status: json['status'] as String,
      currentRoundIndex: json['currentRoundIndex'] as int,
      totalRounds: json['totalRounds'] as int,
      scoreMe: json['scoreMe'] as int,
      scoreOpponent: json['scoreOpponent'] as int,
      isMyTurn: json['isMyTurn'] as bool,
      turnDeadlineAt: json['turnDeadlineAt'] == null
          ? null
          : DateTime.tryParse(json['turnDeadlineAt'] as String),
      opponentUserId: json['opponentUserId'] as String,
      opponentDisplayName: json['opponentDisplayName'] as String,
      opponentUsername: json['opponentUsername'] as String,
      canMessageOpponent: json['canMessageOpponent'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'currentRoundIndex': currentRoundIndex,
      'totalRounds': totalRounds,
      'scoreMe': scoreMe,
      'scoreOpponent': scoreOpponent,
      'isMyTurn': isMyTurn,
      'turnDeadlineAt': turnDeadlineAt?.toIso8601String(),
      'opponentUserId': opponentUserId,
      'opponentDisplayName': opponentDisplayName,
      'opponentUsername': opponentUsername,
      'canMessageOpponent': canMessageOpponent,
    };
  }
}

class QuizClashQuestion {
  const QuizClashQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.timeLimitSeconds,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int timeLimitSeconds;

  factory QuizClashQuestion.fromJson(Map<String, dynamic> json) {
    return QuizClashQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List<dynamic>).cast<String>(),
      timeLimitSeconds: json['timeLimitSeconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'options': options,
      'timeLimitSeconds': timeLimitSeconds,
    };
  }
}

class QuizClashTurnState {
  const QuizClashTurnState({
    required this.matchId,
    required this.status,
    required this.roundIndex,
    required this.totalRounds,
    required this.scoreMe,
    required this.scoreOpponent,
    required this.isMyTurn,
    required this.turnDeadlineAt,
    required this.isPickerTurn,
    required this.canMessageOpponent,
    required this.opponentUserId,
    required this.opponentDisplayName,
    required this.opponentUsername,
    required this.categoryOptions,
    required this.selectedCategoryId,
    required this.selectedCategoryName,
    required this.questions,
  });

  final String matchId;
  final String status;
  final int roundIndex;
  final int totalRounds;
  final int scoreMe;
  final int scoreOpponent;
  final bool isMyTurn;
  final DateTime? turnDeadlineAt;
  final bool isPickerTurn;
  final bool canMessageOpponent;
  final String opponentUserId;
  final String opponentDisplayName;
  final String opponentUsername;
  final List<QuizClashCategoryOption> categoryOptions;
  final String? selectedCategoryId;
  final String? selectedCategoryName;
  final List<QuizClashQuestion> questions;

  bool get isAwaitingCategoryPick =>
      status == 'active' &&
      isMyTurn &&
      isPickerTurn &&
      selectedCategoryId == null;

  bool get isAwaitingAnswerSubmission =>
      status == 'active' &&
      isMyTurn &&
      questions.isNotEmpty &&
      selectedCategoryId != null;

  factory QuizClashTurnState.fromJson(Map<String, dynamic> json) {
    return QuizClashTurnState(
      matchId: json['matchId'] as String,
      status: json['status'] as String,
      roundIndex: json['roundIndex'] as int,
      totalRounds: json['totalRounds'] as int,
      scoreMe: json['scoreMe'] as int,
      scoreOpponent: json['scoreOpponent'] as int,
      isMyTurn: json['isMyTurn'] as bool,
      turnDeadlineAt: json['turnDeadlineAt'] == null
          ? null
          : DateTime.tryParse(json['turnDeadlineAt'] as String),
      isPickerTurn: json['isPickerTurn'] as bool,
      canMessageOpponent: json['canMessageOpponent'] as bool,
      opponentUserId: json['opponentUserId'] as String,
      opponentDisplayName: json['opponentDisplayName'] as String,
      opponentUsername: json['opponentUsername'] as String,
      categoryOptions: (json['categoryOptions'] as List<dynamic>)
          .map(
            (item) =>
                QuizClashCategoryOption.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      selectedCategoryId: json['selectedCategoryId'] as String?,
      selectedCategoryName: json['selectedCategoryName'] as String?,
      questions: (json['questions'] as List<dynamic>)
          .map(
            (item) => QuizClashQuestion.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'status': status,
      'roundIndex': roundIndex,
      'totalRounds': totalRounds,
      'scoreMe': scoreMe,
      'scoreOpponent': scoreOpponent,
      'isMyTurn': isMyTurn,
      'turnDeadlineAt': turnDeadlineAt?.toIso8601String(),
      'isPickerTurn': isPickerTurn,
      'canMessageOpponent': canMessageOpponent,
      'opponentUserId': opponentUserId,
      'opponentDisplayName': opponentDisplayName,
      'opponentUsername': opponentUsername,
      'categoryOptions': categoryOptions.map((item) => item.toJson()).toList(),
      'selectedCategoryId': selectedCategoryId,
      'selectedCategoryName': selectedCategoryName,
      'questions': questions.map((item) => item.toJson()).toList(),
    };
  }
}
