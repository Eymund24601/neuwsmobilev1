import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article_bundle.dart';
import '../models/article_detail.dart';
import '../models/article_summary.dart';
import '../models/community_models.dart';
import '../models/event_summary.dart';
import '../models/game_round.dart';
import '../models/quiz_clash_models.dart';
import '../models/quiz_summary.dart';
import '../models/topic_feed.dart';
import '../models/track_summary.dart';
import '../models/user_profile.dart';
import '../repositories/creator_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/cache/cache_service.dart';
import '../services/performance/performance_budget.dart';
import 'cache_providers.dart';
import 'repository_providers.dart';

final enableStartupPrefetchProvider = Provider<bool>((ref) => true);
final aggressiveArticlePreloadLimitProvider = Provider<int>((ref) => 100);
final startupPrefetchBudgetProvider = Provider<StartupPrefetchBudget>(
  (ref) => const StartupPrefetchBudget(),
);
final startupPrefetchMetricsProvider = StateProvider<StartupPrefetchMetrics?>(
  (ref) => null,
);

class _StartupTaskTiming {
  const _StartupTaskTiming({
    required this.key,
    required this.elapsed,
    required this.success,
    this.errorType,
  });

  final String key;
  final Duration elapsed;
  final bool success;
  final String? errorType;
}

Future<void> _runMeasuredStartupTask({
  required String key,
  required Future<void> Function() action,
  required List<_StartupTaskTiming> timings,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    await action();
    stopwatch.stop();
    final timing = _StartupTaskTiming(
      key: key,
      elapsed: stopwatch.elapsed,
      success: true,
    );
    timings.add(timing);
    _logStartupTaskTiming(timing);
  } catch (error) {
    stopwatch.stop();
    final timing = _StartupTaskTiming(
      key: key,
      elapsed: stopwatch.elapsed,
      success: false,
      errorType: error.runtimeType.toString(),
    );
    timings.add(timing);
    _logStartupTaskTiming(timing);
    rethrow;
  }
}

void _logStartupTaskTiming(_StartupTaskTiming timing) {
  if (!kDebugMode) {
    return;
  }
  final elapsedMs = timing.elapsed.inMilliseconds;
  if (timing.success) {
    debugPrint('[PERF][TASK] ${timing.key}: ${elapsedMs}ms');
    return;
  }
  debugPrint(
    '[PERF][TASK][ERROR] ${timing.key}: ${elapsedMs}ms (${timing.errorType ?? 'UnknownError'})',
  );
}

void _logStartupTaskSummary(List<_StartupTaskTiming> timings) {
  if (!kDebugMode || timings.isEmpty) {
    return;
  }

  final sorted = [...timings]..sort((a, b) => b.elapsed.compareTo(a.elapsed));
  final topLimit = sorted.length < 10 ? sorted.length : 10;
  final topEntries = sorted
      .take(topLimit)
      .map((timing) => '${timing.key}=${timing.elapsed.inMilliseconds}ms')
      .join(', ');

  debugPrint(
    '[PERF][DETAIL] startup.top_tasks($topLimit/${sorted.length}): $topEntries',
  );

  final failedTasks = sorted.where((timing) => !timing.success).toList();
  if (failedTasks.isEmpty) {
    return;
  }
  final failedSummary = failedTasks
      .map((timing) => '${timing.key}:${timing.errorType ?? 'UnknownError'}')
      .join(', ');
  debugPrint('[PERF][DETAIL][ERROR] startup.failed_tasks: $failedSummary');
}

class StartupPrefetchBudget {
  const StartupPrefetchBudget({
    this.core = const Duration(milliseconds: 900),
    this.userScoped = const Duration(milliseconds: 1100),
    this.articleWarm = const Duration(milliseconds: 1800),
    this.total = const Duration(milliseconds: 2600),
  });

  final Duration core;
  final Duration userScoped;
  final Duration articleWarm;
  final Duration total;
}

class StartupPrefetchMetrics {
  const StartupPrefetchMetrics({
    required this.recordedAt,
    required this.core,
    required this.userScoped,
    required this.articleWarm,
    required this.total,
    required this.hadUserScopedFetch,
  });

  final DateTime recordedAt;
  final Duration core;
  final Duration userScoped;
  final Duration articleWarm;
  final Duration total;
  final bool hadUserScopedFetch;
}

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

String _userCacheScope(Ref ref) {
  final userId = ref.read(currentSupabaseUserIdProvider);
  if (userId.isEmpty) {
    return 'guest';
  }
  return userId;
}

abstract class UserScopedCachedAsyncNotifier<T> extends CachedAsyncNotifier<T> {
  String get userCacheScope => _userCacheScope(ref);

  @override
  Future<T> build() async {
    ref.watch(currentSupabaseUserIdProvider);
    return super.build();
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

final aggressiveArticleDetailsPreloadProvider = FutureProvider<void>((
  ref,
) async {
  final limit = ref.read(aggressiveArticlePreloadLimitProvider);
  final details = await ref
      .read(articleRepositoryProvider)
      .getRecentArticleDetails(limit: limit);
  if (details.isEmpty) {
    return;
  }

  final cache = await ref.read(cacheServiceProvider.future);
  for (final detail in details) {
    await cache.write<ArticleDetail?>(
      'articleDetail:${detail.slug}:v1',
      detail,
      (value) => value?.toJson(),
    );
  }
});

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
    extends UserScopedCachedAsyncNotifier<List<MessageThreadSummary>> {
  @override
  String get cacheKey => 'messages:threads:$userCacheScope:v1';

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
    extends UserScopedCachedAsyncNotifier<List<MessageContactSummary>> {
  @override
  String get cacheKey => 'messages:contacts:$userCacheScope:v1';

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
    ref.watch(currentSupabaseUserIdProvider);
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

  String _cacheKey(String threadId) =>
      'messages:thread:${_userCacheScope(ref)}:$threadId:v1';
}

final savedArticlesProvider =
    AsyncNotifierProvider<SavedArticlesNotifier, List<SavedArticleSummary>>(
      SavedArticlesNotifier.new,
    );

class SavedArticlesNotifier
    extends UserScopedCachedAsyncNotifier<List<SavedArticleSummary>> {
  @override
  String get cacheKey => 'saved:articles:$userCacheScope:v1';

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
    extends UserScopedCachedAsyncNotifier<List<UserCollectionSummary>> {
  @override
  String get cacheKey => 'user:collections:$userCacheScope:v1';

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

class UserPerksNotifier
    extends UserScopedCachedAsyncNotifier<List<UserPerkSummary>> {
  @override
  String get cacheKey => 'user:perks:$userCacheScope:v1';

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
    extends UserScopedCachedAsyncNotifier<UserProgressionSummary?> {
  @override
  String get cacheKey => 'user:progression:$userCacheScope:v1';

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
    extends UserScopedCachedAsyncNotifier<List<RepostedArticleSummary>> {
  @override
  String get cacheKey => 'user:reposts:$userCacheScope:v1';

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

class ProfileNotifier extends UserScopedCachedAsyncNotifier<UserProfile> {
  @override
  String get cacheKey => 'profile:current:$userCacheScope:v1';

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

class SettingsNotifier extends UserScopedCachedAsyncNotifier<AppSettings> {
  @override
  String get cacheKey => 'settings:current:$userCacheScope:v1';

  @override
  AppSettings decodePayload(Object? payload) {
    final map = payload as Map<String, dynamic>;
    return AppSettings(
      readingLanguage: map['readingLanguage'] as String,
      readingTopLanguage: map['readingTopLanguage'] as String? ?? 'en',
      readingBottomLanguage: map['readingBottomLanguage'] as String? ?? 'sv',
      notificationsEnabled: map['notificationsEnabled'] as bool,
      offlineModeEnabled: map['offlineModeEnabled'] as bool,
    );
  }

  @override
  Object encodePayload(AppSettings value) {
    return {
      'readingLanguage': value.readingLanguage,
      'readingTopLanguage': value.readingTopLanguage,
      'readingBottomLanguage': value.readingBottomLanguage,
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

class CreatorStudioNotifier
    extends UserScopedCachedAsyncNotifier<CreatorStudioSnapshot> {
  @override
  String get cacheKey => 'creatorStudio:current:$userCacheScope:v1';

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

final quizClashInvitesProvider =
    AsyncNotifierProvider<
      QuizClashInvitesNotifier,
      List<QuizClashInviteSummary>
    >(QuizClashInvitesNotifier.new);

class QuizClashInvitesNotifier
    extends UserScopedCachedAsyncNotifier<List<QuizClashInviteSummary>> {
  @override
  String get cacheKey => 'quizClash:invites:$userCacheScope:v1';

  @override
  Duration get staleAfter => const Duration(seconds: 20);

  @override
  List<QuizClashInviteSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) =>
              QuizClashInviteSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<QuizClashInviteSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<QuizClashInviteSummary>> fetchFresh() {
    return ref.read(gamesRepositoryProvider).getQuizClashInvites();
  }
}

final quizClashMatchesProvider =
    AsyncNotifierProvider<
      QuizClashMatchesNotifier,
      List<QuizClashMatchSummary>
    >(QuizClashMatchesNotifier.new);

class QuizClashMatchesNotifier
    extends UserScopedCachedAsyncNotifier<List<QuizClashMatchSummary>> {
  @override
  String get cacheKey => 'quizClash:matches:$userCacheScope:v1';

  @override
  Duration get staleAfter => const Duration(seconds: 20);

  @override
  List<QuizClashMatchSummary> decodePayload(Object? payload) {
    final list = payload as List<dynamic>;
    return list
        .map(
          (item) =>
              QuizClashMatchSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Object encodePayload(List<QuizClashMatchSummary> value) {
    return value.map((item) => item.toJson()).toList();
  }

  @override
  Future<List<QuizClashMatchSummary>> fetchFresh() {
    return ref.read(gamesRepositoryProvider).getQuizClashMatches();
  }
}

final quizClashTurnStateProvider =
    AsyncNotifierProviderFamily<
      QuizClashTurnStateNotifier,
      QuizClashTurnState?,
      String
    >(QuizClashTurnStateNotifier.new);

class QuizClashTurnStateNotifier
    extends FamilyAsyncNotifier<QuizClashTurnState?, String> {
  String? _matchId;

  @override
  Future<QuizClashTurnState?> build(String matchId) async {
    ref.watch(currentSupabaseUserIdProvider);
    _matchId = matchId;
    return _load(matchId);
  }

  Future<void> refresh() async {
    final matchId = _matchId;
    if (matchId == null || matchId.isEmpty) {
      return;
    }
    state = const AsyncLoading();
    state = AsyncData(await _load(matchId));
  }

  Future<QuizClashTurnState?> _load(String matchId) {
    return ref.read(gamesRepositoryProvider).getQuizClashTurnState(matchId);
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
  final budget = ref.read(startupPrefetchBudgetProvider);
  final totalStopwatch = Stopwatch()..start();
  final taskTimings = <_StartupTaskTiming>[];

  final coreStopwatch = Stopwatch()..start();
  await Future.wait([
    _runMeasuredStartupTask(
      key: 'startup.core.topStories',
      action: () async {
        await ref.read(topStoriesProvider.future);
      },
      timings: taskTimings,
    ),
    _runMeasuredStartupTask(
      key: 'startup.core.tracks',
      action: () async {
        await ref.read(tracksProvider.future);
      },
      timings: taskTimings,
    ),
    _runMeasuredStartupTask(
      key: 'startup.core.events',
      action: () async {
        await ref.read(eventsProvider.future);
      },
      timings: taskTimings,
    ),
    _runMeasuredStartupTask(
      key: 'startup.core.quizCategories',
      action: () async {
        await ref.read(quizCategoriesProvider.future);
      },
      timings: taskTimings,
    ),
  ]);
  coreStopwatch.stop();
  PerformanceBudgetReporter.report(
    key: 'startup.core',
    elapsed: coreStopwatch.elapsed,
    budget: budget.core,
  );

  final shouldPrefetchUserScoped = ref.read(hasSupabaseSessionProvider);
  var userScopedElapsed = Duration.zero;
  if (shouldPrefetchUserScoped) {
    final userScopedStopwatch = Stopwatch()..start();
    await Future.wait([
      _runMeasuredStartupTask(
        key: 'startup.user.profile',
        action: () async {
          await ref.read(profileProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.messageThreads',
        action: () async {
          await ref.read(messageThreadsProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.savedArticles',
        action: () async {
          await ref.read(savedArticlesProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.userPerks',
        action: () async {
          await ref.read(userPerksProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.userCollections',
        action: () async {
          await ref.read(userCollectionsProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.userProgression',
        action: () async {
          await ref.read(userProgressionProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.quizClashInvites',
        action: () async {
          await ref.read(quizClashInvitesProvider.future);
        },
        timings: taskTimings,
      ),
      _runMeasuredStartupTask(
        key: 'startup.user.quizClashMatches',
        action: () async {
          await ref.read(quizClashMatchesProvider.future);
        },
        timings: taskTimings,
      ),
    ]);
    userScopedStopwatch.stop();
    userScopedElapsed = userScopedStopwatch.elapsed;
    PerformanceBudgetReporter.report(
      key: 'startup.userScoped',
      elapsed: userScopedElapsed,
      budget: budget.userScoped,
    );
  }

  final articleWarmStopwatch = Stopwatch()..start();
  await _runMeasuredStartupTask(
    key: 'startup.articleWarm.preload',
    action: () async {
      await ref.read(aggressiveArticleDetailsPreloadProvider.future);
    },
    timings: taskTimings,
  );
  articleWarmStopwatch.stop();
  PerformanceBudgetReporter.report(
    key: 'startup.articleWarm',
    elapsed: articleWarmStopwatch.elapsed,
    budget: budget.articleWarm,
  );

  totalStopwatch.stop();
  final totalElapsed = totalStopwatch.elapsed;
  PerformanceBudgetReporter.report(
    key: 'startup.total',
    elapsed: totalElapsed,
    budget: budget.total,
  );
  _logStartupTaskSummary(taskTimings);
  ref
      .read(startupPrefetchMetricsProvider.notifier)
      .state = StartupPrefetchMetrics(
    recordedAt: DateTime.now(),
    core: coreStopwatch.elapsed,
    userScoped: userScopedElapsed,
    articleWarm: articleWarmStopwatch.elapsed,
    total: totalElapsed,
    hadUserScopedFetch: shouldPrefetchUserScoped,
  );

  unawaited(ref.read(sudokuSkillRoundsProvider.future));
  unawaited(ref.read(eurodleRoundProvider.future));
});
