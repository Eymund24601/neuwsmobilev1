import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article_bundle.dart';
import '../models/article_detail.dart';
import '../models/article_summary.dart';
import '../models/community_models.dart';
import '../models/event_summary.dart';
import '../models/game_round.dart';
import '../models/quiz_summary.dart';
import '../models/topic_feed.dart';
import '../models/track_summary.dart';
import '../models/user_profile.dart';
import '../repositories/creator_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/cache/cache_service.dart';
import 'cache_providers.dart';
import 'repository_providers.dart';

final enableStartupPrefetchProvider = Provider<bool>((ref) => true);

abstract class CachedAsyncNotifier<T> extends AsyncNotifier<T> {
  String get cacheKey;
  Duration get staleAfter => const Duration(minutes: 5);

  T decodePayload(Object? payload);
  Object? encodePayload(T value);
  Future<T> fetchFresh();

  @override
  Future<T> build() async {
    final cache = await ref.read(cacheServiceProvider.future);
    final cached = await cache.read<T>(cacheKey, decodePayload);
    if (cached != null) {
      final age = DateTime.now().difference(cached.updatedAt);
      if (age >= staleAfter) {
        unawaited(_refresh(cache, emitState: true));
      }
      return cached.value;
    }

    return _refresh(cache, emitState: false);
  }

  Future<T> _refresh(CacheService cache, {required bool emitState}) async {
    try {
      final fresh = await fetchFresh();
      await cache.write<T>(cacheKey, fresh, encodePayload);
      if (emitState) {
        state = AsyncData(fresh);
      }
      return fresh;
    } catch (error, stackTrace) {
      if (state.hasValue) {
        return state.requireValue;
      }
      if (emitState) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final cache = await ref.read(cacheServiceProvider.future);
    await _refresh(cache, emitState: true);
  }
}

final topStoriesProvider =
    AsyncNotifierProvider<TopStoriesNotifier, List<ArticleSummary>>(
      TopStoriesNotifier.new,
    );

class TopStoriesNotifier extends CachedAsyncNotifier<List<ArticleSummary>> {
  @override
  String get cacheKey => 'topStories:list:v1';

  @override
  List<ArticleSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map((item) => ArticleSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Object encodePayload(List<ArticleSummary> value) {
    return value.map((story) => story.toJson()).toList();
  }

  @override
  Future<List<ArticleSummary>> fetchFresh() {
    return ref.read(articleRepositoryProvider).getTopStories();
  }
}

final articleDetailBySlugProvider =
    AsyncNotifierProviderFamily<
      ArticleDetailBySlugNotifier,
      ArticleDetail?,
      String
    >(ArticleDetailBySlugNotifier.new);

class ArticleDetailBySlugNotifier
    extends FamilyAsyncNotifier<ArticleDetail?, String> {
  @override
  Future<ArticleDetail?> build(String slug) async {
    final cache = await ref.read(cacheServiceProvider.future);
    final key = 'articleDetail:$slug:v1';
    final cached = await cache.read<ArticleDetail?>(key, (payload) {
      if (payload == null) {
        return null;
      }
      return ArticleDetail.fromJson(payload as Map<String, dynamic>);
    });
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(minutes: 5)) {
        unawaited(_refresh(slug, cache));
      }
      return cached.value;
    }
    return _refresh(slug, cache);
  }

  Future<ArticleDetail?> _refresh(String slug, CacheService cache) async {
    final fresh = await ref
        .read(articleRepositoryProvider)
        .getArticleDetailBySlug(slug);
    await cache.write<ArticleDetail?>(
      'articleDetail:$slug:v1',
      fresh,
      (value) => value?.toJson(),
    );
    state = AsyncData(fresh);
    return fresh;
  }
}

final articleBundleBySlugProvider =
    AsyncNotifierProviderFamily<
      ArticleBundleBySlugNotifier,
      ArticleBundle?,
      ArticleBundleRequest
    >(ArticleBundleBySlugNotifier.new);

class ArticleBundleBySlugNotifier
    extends FamilyAsyncNotifier<ArticleBundle?, ArticleBundleRequest> {
  @override
  Future<ArticleBundle?> build(ArticleBundleRequest request) async {
    return ref
        .read(articleRepositoryProvider)
        .getArticleBundleBySlug(
          request.slug,
          request.topLang,
          request.bottomLang,
          request.uiLang,
        );
  }
}

final messageThreadsProvider =
    AsyncNotifierProvider<MessageThreadsNotifier, List<MessageThreadSummary>>(
      MessageThreadsNotifier.new,
    );

class MessageThreadsNotifier
    extends CachedAsyncNotifier<List<MessageThreadSummary>> {
  @override
  String get cacheKey => 'messages:threads:v1';

  @override
  List<MessageThreadSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) => MessageThreadSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<MessageThreadSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<MessageThreadSummary>> fetchFresh() {
    return ref.read(communityRepositoryProvider).getMessageThreads();
  }
}

final messageContactsProvider =
    AsyncNotifierProvider<MessageContactsNotifier, List<MessageContactSummary>>(
      MessageContactsNotifier.new,
    );

class MessageContactsNotifier
    extends CachedAsyncNotifier<List<MessageContactSummary>> {
  @override
  String get cacheKey => 'messages:contacts:v1';

  @override
  List<MessageContactSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) =>
              MessageContactSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<MessageContactSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<MessageContactSummary>> fetchFresh() {
    return ref.read(communityRepositoryProvider).getMessageContacts();
  }
}

final messageThreadMessagesProvider =
    AsyncNotifierProviderFamily<
      MessageThreadMessagesNotifier,
      List<DirectMessage>,
      String
    >(MessageThreadMessagesNotifier.new);

class MessageThreadMessagesNotifier
    extends FamilyAsyncNotifier<List<DirectMessage>, String> {
  String? _threadId;

  @override
  Future<List<DirectMessage>> build(String threadId) async {
    _threadId = threadId;
    final cache = await ref.read(cacheServiceProvider.future);
    final key = _cacheKey(threadId);
    final cached = await cache.read<List<DirectMessage>>(key, (payload) {
      final list = payload as List<dynamic>;
      return list
          .map((item) => DirectMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    });
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(seconds: 45)) {
        unawaited(_refresh(threadId, cache));
      }
      return cached.value;
    }
    return _refresh(threadId, cache);
  }

  Future<void> refresh() async {
    final threadId = _threadId;
    if (threadId == null) {
      return;
    }
    final cache = await ref.read(cacheServiceProvider.future);
    await _refresh(threadId, cache);
  }

  Future<void> sendMessage(String body) async {
    final threadId = _threadId;
    final trimmed = body.trim();
    if (threadId == null || trimmed.isEmpty) {
      return;
    }
    await ref
        .read(communityRepositoryProvider)
        .sendThreadMessage(threadId: threadId, body: trimmed);
    await ref.read(communityRepositoryProvider).markThreadRead(threadId);
    await refresh();
    await ref.read(messageThreadsProvider.notifier).refresh();
  }

  Future<void> markRead() async {
    final threadId = _threadId;
    if (threadId == null) {
      return;
    }
    await ref.read(communityRepositoryProvider).markThreadRead(threadId);
    await ref.read(messageThreadsProvider.notifier).refresh();
  }

  Future<List<DirectMessage>> _refresh(
    String threadId,
    CacheService cache,
  ) async {
    final fresh = await ref
        .read(communityRepositoryProvider)
        .getThreadMessages(threadId);
    await cache.write<List<DirectMessage>>(
      _cacheKey(threadId),
      fresh,
      (value) => value.map((item) => item.toJson()).toList(),
    );
    state = AsyncData(fresh);
    return fresh;
  }

  String _cacheKey(String threadId) => 'messages:thread:$threadId:v1';
}

final savedArticlesProvider =
    AsyncNotifierProvider<SavedArticlesNotifier, List<SavedArticleSummary>>(
      SavedArticlesNotifier.new,
    );

class SavedArticlesNotifier
    extends CachedAsyncNotifier<List<SavedArticleSummary>> {
  @override
  String get cacheKey => 'saved:articles:v1';

  @override
  List<SavedArticleSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) => SavedArticleSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<SavedArticleSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<SavedArticleSummary>> fetchFresh() {
    return ref.read(communityRepositoryProvider).getSavedArticles();
  }
}

final userCollectionsProvider =
    AsyncNotifierProvider<UserCollectionsNotifier, List<UserCollectionSummary>>(
      UserCollectionsNotifier.new,
    );

class UserCollectionsNotifier
    extends CachedAsyncNotifier<List<UserCollectionSummary>> {
  @override
  String get cacheKey => 'user:collections:v1';

  @override
  List<UserCollectionSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) =>
              UserCollectionSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<UserCollectionSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<UserCollectionSummary>> fetchFresh() {
    return ref.read(communityRepositoryProvider).getUserCollections();
  }
}

final userPerksProvider =
    AsyncNotifierProvider<UserPerksNotifier, List<UserPerkSummary>>(
      UserPerksNotifier.new,
    );

class UserPerksNotifier extends CachedAsyncNotifier<List<UserPerkSummary>> {
  @override
  String get cacheKey => 'user:perks:v1';

  @override
  List<UserPerkSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map((item) => UserPerkSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Object encodePayload(List<UserPerkSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<UserPerkSummary>> fetchFresh() {
    return ref.read(communityRepositoryProvider).getUserPerks();
  }
}

final userProgressionProvider =
    AsyncNotifierProvider<UserProgressionNotifier, UserProgressionSummary?>(
      UserProgressionNotifier.new,
    );

class UserProgressionNotifier
    extends CachedAsyncNotifier<UserProgressionSummary?> {
  @override
  String get cacheKey => 'user:progression:v1';

  @override
  UserProgressionSummary? decodePayload(Object? payload) {
    if (payload == null) {
      return null;
    }
    return UserProgressionSummary.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Object? encodePayload(UserProgressionSummary? value) {
    return value?.toJson();
  }

  @override
  Future<UserProgressionSummary?> fetchFresh() {
    return ref.read(communityRepositoryProvider).getUserProgression();
  }
}

final repostedArticlesProvider =
    AsyncNotifierProvider<
      RepostedArticlesNotifier,
      List<RepostedArticleSummary>
    >(RepostedArticlesNotifier.new);

class RepostedArticlesNotifier
    extends CachedAsyncNotifier<List<RepostedArticleSummary>> {
  @override
  String get cacheKey => 'user:reposts:v1';

  @override
  List<RepostedArticleSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) =>
              RepostedArticleSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<RepostedArticleSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<RepostedArticleSummary>> fetchFresh() {
    return ref.read(communityRepositoryProvider).getRepostedArticles();
  }
}

final tracksProvider =
    AsyncNotifierProvider<TracksNotifier, List<TrackSummary>>(
      TracksNotifier.new,
    );

class TracksNotifier extends CachedAsyncNotifier<List<TrackSummary>> {
  @override
  String get cacheKey => 'tracks:list:v1';

  @override
  List<TrackSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map((item) => TrackSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Object encodePayload(List<TrackSummary> value) {
    return value.map((track) => track.toJson()).toList();
  }

  @override
  Future<List<TrackSummary>> fetchFresh() {
    return ref.read(learnRepositoryProvider).getTracks();
  }
}

final trackModulesProvider =
    AsyncNotifierProviderFamily<
      TrackModulesNotifier,
      List<LearningModuleSummary>,
      String
    >(TrackModulesNotifier.new);

class TrackModulesNotifier
    extends FamilyAsyncNotifier<List<LearningModuleSummary>, String> {
  @override
  Future<List<LearningModuleSummary>> build(String trackId) async {
    final cache = await ref.read(cacheServiceProvider.future);
    final key = 'trackModules:$trackId:v1';
    final cached = await cache.read<List<LearningModuleSummary>>(key, (
      payload,
    ) {
      final list = payload as List<dynamic>;
      return list
          .map(
            (item) =>
                LearningModuleSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    });
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(minutes: 5)) {
        unawaited(_refresh(trackId, cache));
      }
      return cached.value;
    }
    return _refresh(trackId, cache);
  }

  Future<List<LearningModuleSummary>> _refresh(
    String trackId,
    CacheService cache,
  ) async {
    final fresh = await ref
        .read(learnRepositoryProvider)
        .getTrackModules(trackId);
    await cache.write<List<LearningModuleSummary>>(
      'trackModules:$trackId:v1',
      fresh,
      (value) => value.map((module) => module.toJson()).toList(),
    );
    state = AsyncData(fresh);
    return fresh;
  }
}

final lessonProvider =
    AsyncNotifierProviderFamily<LessonNotifier, LessonContent?, String>(
      LessonNotifier.new,
    );

class LessonNotifier extends FamilyAsyncNotifier<LessonContent?, String> {
  @override
  Future<LessonContent?> build(String lessonId) async {
    final cache = await ref.read(cacheServiceProvider.future);
    final key = 'lesson:$lessonId:v1';
    final cached = await cache.read<LessonContent?>(key, (payload) {
      if (payload == null) {
        return null;
      }
      return LessonContent.fromJson(payload as Map<String, dynamic>);
    });
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(minutes: 5)) {
        unawaited(_refresh(lessonId, cache));
      }
      return cached.value;
    }
    return _refresh(lessonId, cache);
  }

  Future<LessonContent?> _refresh(String lessonId, CacheService cache) async {
    final fresh = await ref
        .read(learnRepositoryProvider)
        .getLessonById(lessonId);
    await cache.write<LessonContent?>(
      'lesson:$lessonId:v1',
      fresh,
      (value) => value?.toJson(),
    );
    state = AsyncData(fresh);
    return fresh;
  }
}

final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<EventSummary>>(
      EventsNotifier.new,
    );

class EventsNotifier extends CachedAsyncNotifier<List<EventSummary>> {
  @override
  String get cacheKey => 'events:list:v1';

  @override
  List<EventSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map((item) => EventSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Object encodePayload(List<EventSummary> value) {
    return value.map((event) => event.toJson()).toList();
  }

  @override
  Future<List<EventSummary>> fetchFresh() {
    return ref.read(eventsRepositoryProvider).getUpcomingEvents();
  }
}

final eventDetailProvider =
    AsyncNotifierProviderFamily<EventDetailNotifier, EventSummary?, String>(
      EventDetailNotifier.new,
    );

class EventDetailNotifier extends FamilyAsyncNotifier<EventSummary?, String> {
  @override
  Future<EventSummary?> build(String eventId) async {
    final cache = await ref.read(cacheServiceProvider.future);
    final key = 'event:$eventId:v1';
    final cached = await cache.read<EventSummary?>(key, (payload) {
      if (payload == null) {
        return null;
      }
      return EventSummary.fromJson(payload as Map<String, dynamic>);
    });
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(minutes: 5)) {
        unawaited(_refresh(eventId, cache));
      }
      return cached.value;
    }
    return _refresh(eventId, cache);
  }

  Future<EventSummary?> _refresh(String eventId, CacheService cache) async {
    final fresh = await ref
        .read(eventsRepositoryProvider)
        .getEventById(eventId);
    await cache.write<EventSummary?>(
      'event:$eventId:v1',
      fresh,
      (value) => value?.toJson(),
    );
    state = AsyncData(fresh);
    return fresh;
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends CachedAsyncNotifier<UserProfile> {
  @override
  String get cacheKey => 'profile:current:v1';

  @override
  UserProfile decodePayload(Object? payload) {
    return UserProfile.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Object encodePayload(UserProfile value) {
    return value.toJson();
  }

  @override
  Future<UserProfile> fetchFresh() {
    return ref.read(profileRepositoryProvider).getCurrentProfile();
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends CachedAsyncNotifier<AppSettings> {
  @override
  String get cacheKey => 'settings:current:v1';

  @override
  AppSettings decodePayload(Object? payload) {
    final map = payload as Map<String, dynamic>;
    return AppSettings(
      readingLanguage: map['readingLanguage'] as String,
      notificationsEnabled: map['notificationsEnabled'] as bool,
      offlineModeEnabled: map['offlineModeEnabled'] as bool,
    );
  }

  @override
  Object encodePayload(AppSettings value) {
    return {
      'readingLanguage': value.readingLanguage,
      'notificationsEnabled': value.notificationsEnabled,
      'offlineModeEnabled': value.offlineModeEnabled,
    };
  }

  @override
  Future<AppSettings> fetchFresh() {
    return ref.read(settingsRepositoryProvider).getSettings();
  }

  Future<void> save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).saveSettings(settings);
    final cache = await ref.read(cacheServiceProvider.future);
    await cache.write<AppSettings>(cacheKey, settings, encodePayload);
    state = AsyncData(settings);
  }
}

final creatorStudioProvider =
    AsyncNotifierProvider<CreatorStudioNotifier, CreatorStudioSnapshot>(
      CreatorStudioNotifier.new,
    );

class CreatorStudioNotifier extends CachedAsyncNotifier<CreatorStudioSnapshot> {
  @override
  String get cacheKey => 'creatorStudio:current:v1';

  @override
  CreatorStudioSnapshot decodePayload(Object? payload) {
    final map = payload as Map<String, dynamic>;
    return CreatorStudioSnapshot(
      drafts: map['drafts'] as int,
      publishedThisMonth: map['publishedThisMonth'] as int,
      estimatedEarnings: map['estimatedEarnings'] as String,
    );
  }

  @override
  Object encodePayload(CreatorStudioSnapshot value) {
    return {
      'drafts': value.drafts,
      'publishedThisMonth': value.publishedThisMonth,
      'estimatedEarnings': value.estimatedEarnings,
    };
  }

  @override
  Future<CreatorStudioSnapshot> fetchFresh() {
    return ref.read(creatorRepositoryProvider).getStudioSnapshot();
  }
}

final quizCategoriesProvider =
    AsyncNotifierProvider<QuizCategoriesNotifier, List<String>>(
      QuizCategoriesNotifier.new,
    );

final sudokuSkillRoundsProvider =
    AsyncNotifierProvider<SudokuSkillRoundsNotifier, List<SudokuRound>>(
      SudokuSkillRoundsNotifier.new,
    );

class SudokuSkillRoundsNotifier extends CachedAsyncNotifier<List<SudokuRound>> {
  @override
  String get cacheKey => 'games:sudokuSkillRounds:v1';

  @override
  List<SudokuRound> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map((item) => SudokuRound.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Object encodePayload(List<SudokuRound> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<SudokuRound>> fetchFresh() {
    return ref.read(gamesRepositoryProvider).getSudokuSkillRounds();
  }
}

final eurodleRoundProvider =
    AsyncNotifierProvider<EurodleRoundNotifier, EurodleRound?>(
      EurodleRoundNotifier.new,
    );

class EurodleRoundNotifier extends CachedAsyncNotifier<EurodleRound?> {
  @override
  String get cacheKey => 'games:eurodleRound:v1';

  @override
  EurodleRound? decodePayload(Object? payload) {
    if (payload == null) {
      return null;
    }
    return EurodleRound.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Object? encodePayload(EurodleRound? value) {
    return value?.toJson();
  }

  @override
  Future<EurodleRound?> fetchFresh() {
    return ref.read(gamesRepositoryProvider).getActiveEurodleRound();
  }
}

class QuizCategoriesNotifier extends CachedAsyncNotifier<List<String>> {
  @override
  String get cacheKey => 'quizCategories:list:v1';

  @override
  List<String> decodePayload(Object? payload) {
    return (payload as List<dynamic>).cast<String>();
  }

  @override
  Object encodePayload(List<String> value) {
    return value;
  }

  @override
  Future<List<String>> fetchFresh() {
    return ref.read(gamesRepositoryProvider).getQuizCategories();
  }
}

final quizByIdProvider =
    AsyncNotifierProviderFamily<QuizByIdNotifier, QuizSummary?, String>(
      QuizByIdNotifier.new,
    );

class QuizByIdNotifier extends FamilyAsyncNotifier<QuizSummary?, String> {
  @override
  Future<QuizSummary?> build(String quizId) async {
    final cache = await ref.read(cacheServiceProvider.future);
    final key = 'quiz:$quizId:v1';
    final cached = await cache.read<QuizSummary?>(key, (payload) {
      if (payload == null) {
        return null;
      }
      return QuizSummary.fromJson(payload as Map<String, dynamic>);
    });
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(minutes: 5)) {
        unawaited(_refresh(quizId, cache));
      }
      return cached.value;
    }
    return _refresh(quizId, cache);
  }

  Future<QuizSummary?> _refresh(String quizId, CacheService cache) async {
    final fresh = await ref.read(gamesRepositoryProvider).getQuizById(quizId);
    await cache.write<QuizSummary?>(
      'quiz:$quizId:v1',
      fresh,
      (value) => value?.toJson(),
    );
    state = AsyncData(fresh);
    return fresh;
  }
}

final topicFeedProvider =
    AsyncNotifierProviderFamily<TopicFeedNotifier, TopicFeed, String>(
      TopicFeedNotifier.new,
    );

class TopicFeedNotifier extends FamilyAsyncNotifier<TopicFeed, String> {
  @override
  Future<TopicFeed> build(String topicOrCountryCode) async {
    final cache = await ref.read(cacheServiceProvider.future);
    final key = 'topicFeed:$topicOrCountryCode:v1';
    final cached = await cache.read<TopicFeed>(
      key,
      (payload) => TopicFeed.fromJson(payload as Map<String, dynamic>),
    );
    if (cached != null) {
      if (DateTime.now().difference(cached.updatedAt) >=
          const Duration(minutes: 5)) {
        unawaited(_refresh(topicOrCountryCode, cache));
      }
      return cached.value;
    }
    return _refresh(topicOrCountryCode, cache);
  }

  Future<TopicFeed> _refresh(
    String topicOrCountryCode,
    CacheService cache,
  ) async {
    final fresh = await ref
        .read(articleRepositoryProvider)
        .getTopicFeed(topicOrCountryCode);
    await cache.write<TopicFeed>(
      'topicFeed:$topicOrCountryCode:v1',
      fresh,
      (value) => value.toJson(),
    );
    state = AsyncData(fresh);
    return fresh;
  }
}

final startupPrefetchProvider = FutureProvider<void>((ref) async {
  final topStories = await ref.read(topStoriesProvider.future);
  final tracks = await ref.read(tracksProvider.future);
  final events = await ref.read(eventsProvider.future);
  await ref.read(profileProvider.future);
  final categories = await ref.read(quizCategoriesProvider.future);

  final shouldPrefetchUserScoped =
      ref.read(useMockDataProvider) || ref.read(hasSupabaseSessionProvider);
  if (shouldPrefetchUserScoped) {
    await Future.wait([
      ref.read(messageThreadsProvider.future),
      ref.read(savedArticlesProvider.future),
      ref.read(userPerksProvider.future),
      ref.read(userCollectionsProvider.future),
      ref.read(userProgressionProvider.future),
    ]);
  }

  if (topStories.isNotEmpty) {
    unawaited(
      ref.read(articleDetailBySlugProvider(topStories.first.slug).future),
    );
  }

  if (tracks.isNotEmpty) {
    unawaited(ref.read(trackModulesProvider(tracks.first.id).future));
  }
  if (events.isNotEmpty) {
    unawaited(ref.read(eventDetailProvider(events.first.id).future));
  }
  if (categories.isNotEmpty) {
    final quizzes = await ref
        .read(gamesRepositoryProvider)
        .getQuizzesByCategory(categories.first);
    if (quizzes.isNotEmpty) {
      unawaited(ref.read(quizByIdProvider(quizzes.first.id).future));
    }
  }

  unawaited(ref.read(sudokuSkillRoundsProvider.future));
  unawaited(ref.read(eurodleRoundProvider.future));
});
