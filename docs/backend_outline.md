# nEUws Mobile Backend Outline (Supabase Handoff)

## 1) Purpose
This document maps current Flutter repository contracts to planned Supabase tables/queries so mock data can be replaced without breaking UI flows.

## 2) Repository Mapping

### `ArticleRepository`
- `getTopStories()`
  - Tables: `articles`, `profiles`
  - Read: published articles ordered by `published_at DESC`
  - Join: author display fields from `profiles`
- `getTopicFeed(topicOrCountryCode)`
  - Tables: `articles`, `profiles`
  - Read: filter by `category` OR `country_tags @> [code]`
- `getArticleDetailBySlug(slug)`
  - Tables: `articles`, `profiles`
  - Read: single article by `slug`, join author profile

### `LearnRepository`
- `getTracks()`
  - Tables: `learning_tracks`
  - Read: published tracks by language/user prefs
- `getTrackById(trackId)`
  - Tables: `learning_tracks`
  - Read: single track
- `getTrackModules(trackId)`
  - Tables: `learning_modules`, `user_progress`
  - Read: modules + completion/lock projection for current user
- `getLessonById(lessonId)`
  - Tables: `quizzes`, `quiz_questions`
  - Read: lesson quiz and ordered questions

### `GamesRepository`
- `getQuizCategories()`
  - Tables: `quizzes`
  - Read: distinct categories where published
- `getQuizzesByCategory(category)`
  - Tables: `quizzes`
  - Read: by category and publish state
- `getQuizById(quizId)`
  - Tables: `quizzes`
  - Read: single quiz summary/detail

### `EventsRepository`
- `getUpcomingEvents()`
  - Tables: `events`, `profiles`
  - Read: upcoming events ordered by `start_date`
- `getEventById(eventId)`
  - Tables: `events`, `profiles`, `event_attendees`
  - Read: event detail + attendee count + user RSVP state

### `ProfileRepository`
- `getCurrentProfile()`
  - Tables: `profiles`
  - Read: current signed-in user profile by auth uid

### `CreatorRepository`
- `getStudioSnapshot()`
  - Tables: `profiles`, `articles`, `quiz_attempts` (or creator earnings source)
  - Read: drafts count, publish stats, payout estimate input

### `SettingsRepository`
- `getSettings()`
  - Tables: `profiles` (or dedicated `user_settings`)
  - Read: language + preferences + feature toggles

## 3) Read/Write Ownership
- Client reads:
  - most feed/detail endpoints through RLS-safe selects
- Client writes:
  - bookmarks, likes, comments, event RSVP, quiz attempts, settings updates
- Server/service-role writes (recommended):
  - article create/update publish flows
  - moderation/admin operations
  - payout/earnings updates

## 4) Auth and Session
- Use Supabase auth session as source of truth.
- Every repository method requiring identity should resolve current user id from session before querying user-scoped tables.

## 5) Migration Path (Mock -> Supabase)
1. Keep repository interfaces unchanged.
2. Implement each `Supabase*Repository` class method with matching return models.
3. Flip provider wiring from mock to Supabase (single switch in provider layer).
4. Run route/flow smoke tests after each repository swap.
5. Add caching layer under repositories after parity is stable.

## 6) Known Gaps (Intentional)
- UI write flows are still scaffold-only (no insert/update for articles, comments, RSVP, likes, bookmarks, quiz attempts).
- No auth gating on UI routes yet.
- No offline sync adapter wired yet.

## 7) Runtime Wiring Notes
- `lib/services/supabase/supabase_bootstrap.dart` initializes Supabase only when compile-time env vars exist.
- Supported env keys:
  - `SUPABASE_URL` or `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_ANON_KEY` or `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `lib/providers/repository_providers.dart` automatically uses mock repositories when those keys are missing.
