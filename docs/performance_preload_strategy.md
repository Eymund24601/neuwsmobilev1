# Performance + Smoothness Preload Strategy

Last updated: February 10, 2026

## Goal

Keep app navigation feeling instant without prediction-heavy logic:

- yes to aggressive preload
- no to overcomplicated prediction logic
- yes to stronger local cache backend

## Implemented In This Change

### 1) Aggressive article preload (prediction-free)

Files:

- `lib/repositories/article_repository.dart`
- `lib/repositories/supabase/supabase_article_repository.dart`
- `lib/providers/feature_data_providers.dart`

What was implemented:

- Added `getRecentArticleDetails({int limit = 100})` to article repository contract.
- Supabase implementation now supports bulk fetch of recent published article detail rows in one query path.
- Startup prefetch now launches `aggressiveArticleDetailsPreloadProvider`, which writes detail payloads into local cache by slug key (`articleDetail:<slug>:v1`).
- Supabase `getTopStories()` raised from 25 to 100 to align with aggressive preload target.

### 2) No prediction logic for "first click"

Files:

- `lib/providers/feature_data_providers.dart`

What was changed:

- Removed first-item speculative prefetch branches (first article detail, first track modules, first event detail, first quiz detail).
- Startup prefetch remains broad, but deterministic:
  - feed lists
  - user-scoped lists (when session exists)
  - bulk article detail warmup
  - game rounds

### 3) Stronger local cache backend

Files:

- `pubspec.yaml`
- `lib/services/cache/cache_service.dart`
- `lib/providers/cache_providers.dart`

What was implemented:

- Added `hive_flutter` dependency.
- `CacheService` now persists cached payloads into Hive (`neuws_cache_v2`) instead of relying only on `SharedPreferences`.
- Added legacy fallback read path from old `SharedPreferences` cache values; when found, values are migrated into Hive.
- `cacheServiceProvider` now builds cache service through `CacheService.create(...)`.

### 4) Duplicate refresh reduction + perf budget pass

Files:

- `lib/screens/messages_page.dart`
- `lib/screens/message_thread_page.dart`
- `lib/screens/you_page.dart`
- `lib/providers/feature_data_providers.dart`
- `lib/services/performance/performance_budget.dart`

What was implemented:

- Removed page-init duplicate refreshes in messages/you surfaces where providers already fetch from cache/build flow.
- Inbox realtime now refreshes thread summaries only (contacts are no longer refreshed on every DM insert).
- Thread realtime sync no longer executes redundant inbox refresh call after `markRead()`.
- Added startup perf-budget tracking and debug reporting for:
  - core preload stage
  - user-scoped preload stage
  - aggressive article warmup stage
  - total startup preload stage
- Added `startupPrefetchMetricsProvider` state snapshot for latest startup timing sample.

### 5) User-scoped cache safety (auth/profile regression hardening)

Files:

- `lib/providers/repository_providers.dart`
- `lib/providers/feature_data_providers.dart`

What was implemented:

- Added `currentSupabaseUserIdProvider`.
- Added `UserScopedCachedAsyncNotifier` base for user-scoped domains.
- User-scoped cache keys now include user scope (`guest` or authenticated user id).
- User-scoped providers watch auth user id, forcing rebuild on sign-in/sign-out transitions.
- Startup prefetch no longer loads profile in unauthenticated core stage; profile preload is now part of user-scoped stage only.

Why this matters:

- Prevents guest/default profile cache from being reused after login.
- Prevents cross-account cache leakage when switching users on the same device.

## Explicitly Not Covered Yet

These are intentionally out of current scope and still pending:

1. Binary image prefetch and image-size-aware caching policy (thumbnails vs full-size).
2. Cache eviction policy (max bytes / LRU / TTL by domain).
3. Games-specific preload tuning (Sudoku/Eurodle payload is currently only basic round prefetch).
4. Message thread pagination and incremental history warmup.
5. Dedicated offline-first local database for non-cache entities (for example, full feed/index tables with queryable local indices).

## Current Expected UX Result

- Home/feed data loads quickly from startup prefetch.
- Opening recently published articles should feel instant more often because full detail text is prewarmed and locally cached.
- Startup path avoids first-item guesswork and remains deterministic.
