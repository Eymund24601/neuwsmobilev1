class MessageThreadSummary {
  const MessageThreadSummary({
    required this.threadId,
    required this.displayName,
    required this.preview,
    required this.timeLabel,
    required this.unreadCount,
  });

  final String threadId;
  final String displayName;
  final String preview;
  final String timeLabel;
  final int unreadCount;

  factory MessageThreadSummary.fromJson(Map<String, dynamic> json) {
    return MessageThreadSummary(
      threadId: json['threadId'] as String,
      displayName: json['displayName'] as String,
      preview: json['preview'] as String,
      timeLabel: json['timeLabel'] as String,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'threadId': threadId,
      'displayName': displayName,
      'preview': preview,
      'timeLabel': timeLabel,
      'unreadCount': unreadCount,
    };
  }
}

class MessageContactSummary {
  const MessageContactSummary({
    required this.userId,
    required this.displayName,
    required this.relation,
  });

  final String userId;
  final String displayName;
  final String relation;

  factory MessageContactSummary.fromJson(Map<String, dynamic> json) {
    return MessageContactSummary(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      relation: json['relation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'displayName': displayName, 'relation': relation};
  }
}

class SavedArticleSummary {
  const SavedArticleSummary({
    required this.articleId,
    required this.slug,
    required this.title,
    required this.dateLabel,
  });

  final String articleId;
  final String slug;
  final String title;
  final String dateLabel;

  factory SavedArticleSummary.fromJson(Map<String, dynamic> json) {
    return SavedArticleSummary(
      articleId: json['articleId'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      dateLabel: json['dateLabel'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'articleId': articleId,
      'slug': slug,
      'title': title,
      'dateLabel': dateLabel,
    };
  }
}

class UserCollectionSummary {
  const UserCollectionSummary({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.isPublic,
  });

  final String id;
  final String name;
  final int itemCount;
  final bool isPublic;

  factory UserCollectionSummary.fromJson(Map<String, dynamic> json) {
    return UserCollectionSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      itemCount: json['itemCount'] as int? ?? 0,
      isPublic: json['isPublic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'itemCount': itemCount,
      'isPublic': isPublic,
    };
  }
}

class UserPerkSummary {
  const UserPerkSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.code,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final String code;

  factory UserPerkSummary.fromJson(Map<String, dynamic> json) {
    return UserPerkSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      code: json['code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'status': status,
      'code': code,
    };
  }
}

class UserProgressionSummary {
  const UserProgressionSummary({
    required this.totalXp,
    required this.level,
    required this.currentStreakDays,
    required this.bestStreakDays,
  });

  final int totalXp;
  final int level;
  final int currentStreakDays;
  final int bestStreakDays;

  factory UserProgressionSummary.fromJson(Map<String, dynamic> json) {
    return UserProgressionSummary(
      totalXp: json['totalXp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      currentStreakDays: json['currentStreakDays'] as int? ?? 0,
      bestStreakDays: json['bestStreakDays'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalXp': totalXp,
      'level': level,
      'currentStreakDays': currentStreakDays,
      'bestStreakDays': bestStreakDays,
    };
  }
}

class RepostedArticleSummary {
  const RepostedArticleSummary({
    required this.articleId,
    required this.slug,
    required this.title,
    required this.sourceLabel,
  });

  final String articleId;
  final String slug;
  final String title;
  final String sourceLabel;

  factory RepostedArticleSummary.fromJson(Map<String, dynamic> json) {
    return RepostedArticleSummary(
      articleId: json['articleId'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      sourceLabel: json['sourceLabel'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'articleId': articleId,
      'slug': slug,
      'title': title,
      'sourceLabel': sourceLabel,
    };
  }
}
