# nEUws Mobile Backend Outline (Current Supabase Handoff)

Last updated: February 10, 2026

## 1) Purpose
This file maps current Flutter repository contracts to active Supabase tables and runtime behavior.
Use this as a quick orientation file; `docs/backend_schema.md` remains the detailed source of truth.

## 2) Repository Mapping

### `ArticleRepository`
- `getTopStories()`
  - Tables: `articles`
  - Read: `is_published = true`, ordered by `published_at DESC`
- `getTopicFeed(topicOrCountryCode)`
  - Tables: `articles`
  - Read: topic/country filtering over published rows
- `getArticleDetailBySlug(slug)`
  - Tables: `articles`, optional `profiles`
  - Read: legacy detail payload for article page bootstrapping
- `getArticleBundleBySlug(slug, topLang, bottomLang, uiLang)`
  - Tables: `articles`, `article_localizations`, `article_alignments`, `article_focus_vocab`, `vocab_items`, `vocab_entries`, `vocab_forms`
  - Read: polyglot + vocab bundle
- `collectFocusVocab(articleId, items)`
  - Tables: `user_vocab_events`, `user_vocab_progress`
  - Write: event rows + progression upsert for signed-in users

### `LearnRepository`
- Primary schema path:
  - Tracks/modules are derived from `quiz_sets` grouped by `topic`
  - Lesson content is resolved from `quiz_sets` -> `quiz_questions` -> `quiz_options`
- Legacy fallback path remains:
  - `learning_tracks`, `learning_modules`, `quizzes` shape for older projects

### `GamesRepository`
- `getQuizCategories()`, `getQuizzesByCategory()`, `getQuizById()`
  - Tables: `quiz_sets` (legacy fallback to `quizzes`)
- `submitQuizAttempt(quizId, score, maxScore, duration)`
  - Tables: `quiz_attempts`
  - Write: signed-in users only
- Sudoku/Eurodle reads:
  - Tables: `game_catalog`, `game_rounds`

### `EventsRepository`
- `getUpcomingEvents()`, `getEventById()`
  - Tables: `events`
  - Handles new + legacy event column variants
- `registerForEvent(eventId)`
  - Tables: `event_registrations`
  - Write: signed-in users only

### `CreatorRepository`
- `getStudioSnapshot()`
  - Tables: `profiles`, `articles`
- `saveDraft(headline, topic, body)`
  - Tables: `articles`
  - Write: signed-in users only

### `CommunityRepository`
- Inbox/DM summaries:
  - Tables: `dm_threads`, `dm_thread_participants`, `dm_messages`, `profiles`
  - Read: thread list + latest message + counterpart profile
- Thread operations:
  - `getThreadMessages(threadId)`: reads `dm_messages` + sender profile context
  - `sendThreadMessage(threadId, body)`: writes `dm_messages`
  - `markThreadRead(threadId)`: updates caller row in `dm_thread_participants`
  - `createOrGetDmThread(targetUserId)`: RPC `create_or_get_dm_thread`
- Realtime:
  - Inbox and thread flows subscribe to realtime changes and refresh with debounce.

### `ProfileRepository`, `SettingsRepository`
- Profile writes include required compatibility fields for hosted schemas (notably `profiles.email`).
- Settings/profile save flows support username/display-name/bio/city/country/image URLs.
- Country selection is UI dropdown-backed (not raw country-code text entry).

## 3) Auth + Session Wiring
- Supabase client is initialized only when compile-time keys exist.
- UI sign-in route: `AppRoutePath.signIn` (`/sign-in`).
- Auth state provider in `lib/providers/repository_providers.dart` listens to `auth.onAuthStateChange`.
- Gated pages show a sign-in prompt with direct navigation to sign-in page.
- Sign-in profile bootstrap must be create-only for missing rows; never overwrite existing `profiles.username`/`profiles.display_name`.

## 4) Local Dev Data Utilities
- `docs/supabase_smoke_check.sql`
  - verifies critical table availability and row counts
- `docs/supabase_minimal_seed.sql`
  - seeds minimal article/quiz/event data
  - schema-adaptive and guarded against missing required columns
- `docs/supabase_rich_seed.sql`
  - seeds production-like multi-user content + DM + progression test data
  - includes schema-adaptive enum/required-column handling for legacy drift
  - prepares profile media storage bucket/policies for image upload testing

## 5) Known Practical Gaps
- Message thread pagination is not implemented yet (full refresh strategy).
- Message send path can still be improved with optimistic append for perceived latency.
- Auth UX currently supports email/password only (no social OAuth flow in-app).
