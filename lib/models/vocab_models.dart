class VocabItem {
  const VocabItem({
    required this.id,
    required this.canonicalLang,
    required this.canonicalLemma,
    required this.pos,
    required this.difficulty,
    required this.createdAt,
  });

  final String id;
  final String canonicalLang;
  final String canonicalLemma;
  final String pos;
  final String difficulty;
  final DateTime? createdAt;

  factory VocabItem.fromJson(Map<String, dynamic> json) {
    return VocabItem(
      id: json['id'] as String,
      canonicalLang: json['canonicalLang'] as String? ?? '',
      canonicalLemma: json['canonicalLemma'] as String? ?? '',
      pos: json['pos'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'canonicalLang': canonicalLang,
      'canonicalLemma': canonicalLemma,
      'pos': pos,
      'difficulty': difficulty,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class VocabForm {
  const VocabForm({
    required this.id,
    required this.vocabItemId,
    required this.lang,
    required this.lemma,
    required this.surface,
    required this.notes,
  });

  final String id;
  final String vocabItemId;
  final String lang;
  final String lemma;
  final String surface;
  final String notes;

  factory VocabForm.fromJson(Map<String, dynamic> json) {
    return VocabForm(
      id: json['id'] as String,
      vocabItemId: json['vocabItemId'] as String,
      lang: json['lang'] as String? ?? '',
      lemma: json['lemma'] as String? ?? '',
      surface: json['surface'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vocabItemId': vocabItemId,
      'lang': lang,
      'lemma': lemma,
      'surface': surface,
      'notes': notes,
    };
  }
}

class VocabEntry {
  const VocabEntry({
    required this.id,
    required this.vocabItemId,
    required this.lang,
    required this.primaryDefinition,
    required this.usageNotes,
    required this.examples,
    required this.tags,
    required this.updatedAt,
    required this.updatedBy,
    required this.source,
  });

  final String id;
  final String vocabItemId;
  final String lang;
  final String primaryDefinition;
  final String usageNotes;
  final List<String> examples;
  final List<String> tags;
  final DateTime? updatedAt;
  final String updatedBy;
  final String source;

  factory VocabEntry.fromJson(Map<String, dynamic> json) {
    return VocabEntry(
      id: json['id'] as String,
      vocabItemId: json['vocabItemId'] as String,
      lang: json['lang'] as String? ?? '',
      primaryDefinition: json['primaryDefinition'] as String? ?? '',
      usageNotes: json['usageNotes'] as String? ?? '',
      examples: (json['examples'] as List<dynamic>?)?.cast<String>() ?? const [],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      updatedBy: json['updatedBy'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vocabItemId': vocabItemId,
      'lang': lang,
      'primaryDefinition': primaryDefinition,
      'usageNotes': usageNotes,
      'examples': examples,
      'tags': tags,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'source': source,
    };
  }
}

class FocusVocabItem {
  const FocusVocabItem({
    required this.rank,
    required this.item,
    required this.entry,
    required this.forms,
  });

  final int rank;
  final VocabItem item;
  final VocabEntry? entry;
  final List<VocabForm> forms;

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'item': item.toJson(),
      'entry': entry?.toJson(),
      'forms': forms.map((form) => form.toJson()).toList(),
    };
  }

  factory FocusVocabItem.fromJson(Map<String, dynamic> json) {
    return FocusVocabItem(
      rank: json['rank'] as int? ?? 1,
      item: VocabItem.fromJson(json['item'] as Map<String, dynamic>),
      entry: json['entry'] == null
          ? null
          : VocabEntry.fromJson(json['entry'] as Map<String, dynamic>),
      forms: (json['forms'] as List<dynamic>? ?? const [])
          .map((item) => VocabForm.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ArticleFocusVocab {
  const ArticleFocusVocab({
    required this.articleId,
    required this.items,
  });

  final String articleId;
  final List<FocusVocabItem> items;

  Map<String, dynamic> toJson() {
    return {
      'articleId': articleId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory ArticleFocusVocab.fromJson(Map<String, dynamic> json) {
    return ArticleFocusVocab(
      articleId: json['articleId'] as String,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => FocusVocabItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UserVocabProgress {
  const UserVocabProgress({
    required this.userId,
    required this.vocabItemId,
    required this.level,
    required this.xp,
    required this.lastSeenAt,
    required this.nextReviewAt,
  });

  final String userId;
  final String vocabItemId;
  final String level;
  final int xp;
  final DateTime? lastSeenAt;
  final DateTime? nextReviewAt;

  factory UserVocabProgress.fromJson(Map<String, dynamic> json) {
    return UserVocabProgress(
      userId: json['userId'] as String,
      vocabItemId: json['vocabItemId'] as String,
      level: json['level'] as String? ?? 'bronze',
      xp: json['xp'] as int? ?? 0,
      lastSeenAt: json['lastSeenAt'] == null
          ? null
          : DateTime.tryParse(json['lastSeenAt'] as String),
      nextReviewAt: json['nextReviewAt'] == null
          ? null
          : DateTime.tryParse(json['nextReviewAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'vocabItemId': vocabItemId,
      'level': level,
      'xp': xp,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'nextReviewAt': nextReviewAt?.toIso8601String(),
    };
  }
}

class UserVocabEvent {
  const UserVocabEvent({
    required this.id,
    required this.userId,
    required this.vocabItemId,
    required this.articleId,
    required this.eventType,
    required this.occurredAt,
    required this.metaJson,
  });

  final String id;
  final String userId;
  final String vocabItemId;
  final String articleId;
  final String eventType;
  final DateTime? occurredAt;
  final Object? metaJson;

  factory UserVocabEvent.fromJson(Map<String, dynamic> json) {
    return UserVocabEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      vocabItemId: json['vocabItemId'] as String,
      articleId: json['articleId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      occurredAt: json['occurredAt'] == null
          ? null
          : DateTime.tryParse(json['occurredAt'] as String),
      metaJson: json['metaJson'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'vocabItemId': vocabItemId,
      'articleId': articleId,
      'eventType': eventType,
      'occurredAt': occurredAt?.toIso8601String(),
      'metaJson': metaJson,
    };
  }
}
