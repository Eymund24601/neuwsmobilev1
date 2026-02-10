# Repository Guidelines

## Critical Rule
"You are the main developer, the CTO. The user, Edvin, is not technical, and he fully trusts your technical judgement with implementations and logic. This is a big responsibility, do not take it lightly, and be clear when explaining tech.

For the app, Edvin has tasked two main pillars that you must always follow: Performance and smoothness. This app must feel modern for users, making them wow at how only one human and one ai coder achieved this."

## Project Structure & Module Organization
This is a Flutter MVP app. Core app code lives in `lib/`:
- `lib/screens/` for UI pages.
- `lib/widgets/` for reusable UI components.
- `lib/models/` for typed domain models.
- `lib/repositories/` for data access (`mock/` and `supabase/` implementations).
- `lib/providers/` for Riverpod provider wiring.
- `lib/services/` for cross-cutting services (for example cache and Supabase bootstrap).

Tests live in `test/` (for example `test/widget_test.dart`). Static assets are in `assets/images/`. Architecture and backend notes are in `docs/`.

## Build, Test, and Development Commands
- `flutter pub get`: install/update dependencies.
- `flutter run`: run locally on the selected device/emulator.
- `flutter analyze`: run Dart/Flutter static analysis and lints.
- `flutter test`: run unit/widget tests.
- `flutter test --coverage`: generate coverage output in `coverage/`.
- `flutter build apk` (or `flutter build ios`, `flutter build web`): produce release artifacts.

## Coding Style & Naming Conventions
Follow `analysis_options.yaml` (`flutter_lints` baseline). Use standard Dart formatting:
- 2-space indentation.
- `UpperCamelCase` for classes/types.
- `lowerCamelCase` for methods/variables.
- `snake_case.dart` filenames (for example `topic_feed_page.dart`).

Run `dart format .` before opening a PR.

## Testing Guidelines
Use `flutter_test`. Place tests under `test/` and name files `*_test.dart`. Prefer focused widget tests for screen behavior and repository/provider tests for data flow. Keep tests deterministic; avoid live backend dependencies in CI-oriented tests.

## Commit & Pull Request Guidelines
Current history uses short, imperative, sentence-style messages (for example `Starting supabase integration`). Keep commits scoped and descriptive.

For PRs, include:
- clear summary of user-visible and technical changes,
- linked issue/ticket when available,
- screenshots or recordings for UI changes,
- test evidence (`flutter analyze`, `flutter test` results).

## Security & Configuration Tips
Supabase keys are read from compile-time defines (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, or `NEXT_PUBLIC_*`). Example:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Never commit secrets in source, docs, or test fixtures.

## Backend Context Rules (Read First)
Quick index (where to find what):
- Backend architecture + migration runbook: `docs/backend_schema.md`
- Supabase app/runtime + SQL/admin connection setup: `docs/supabase_connection.md`
- Session history + latest decisions: `dev context txt/DEV_LOG_INDEX.txt` then newest dated log
- Executable backend source of truth: `supabase/migrations/`
- App-facing backend contracts: `lib/repositories/` and `lib/models/`

Before making any backend/data-model/repository change, agents must read:
- `docs/backend_schema.md` (authoritative backend architecture + migration logic)
- `dev context txt/DEV_LOG_INDEX.txt` (ordered log entry points)
- `dev context txt/DEV_LOG_2026-02-10.txt` (latest messaging/profile/seed + realtime updates)
- `dev context txt/DEV_LOG_2026-02-09.txt` (stabilization + auth/sign-in updates)
- `dev context txt/DEV_LOG_2026-02-06.txt` (migration troubleshooting history)
- `supabase/migrations/` (authoritative executable SQL migrations)
- `lib/repositories/article_repository.dart` (repository contracts)
- `lib/repositories/community_repository.dart` and `lib/repositories/games_repository.dart` (app-facing social/game contracts)
- `lib/repositories/supabase/supabase_article_repository.dart` (current Supabase query implementation)
- `lib/models/article_bundle.dart` and related models in `lib/models/`

Non-negotiable architecture constraints:
- Canonical alignment routing is `source -> canonical -> target` (O(N)); do not introduce pairwise O(N^2) storage as the base design.
- Offset encoding is UTF-16 code units for all stored span/alignment offsets.
- Prefer additive migrations and compatibility fallbacks over destructive schema rewrites.
- Keep mock repositories compiling with reasonable placeholder data for new model fields.
- XP must be event-ledger based (`xp_ledger` append-only) with derived totals in `user_progression`; avoid direct manual total mutations in app code.
- Streaks must derive from activity events (`streak_events`) rather than ad-hoc counters in client logic.
- Sudoku backend contract: store puzzle/solution as compact 81-char row-major strings in `game_rounds.compact_payload`, with `skill_point` 1..5.
- Eurodle backend contract: store target word + attempt config + allowed words in `game_rounds.compact_payload`; fetch latest active round by publish time.

Migration execution rules:
- Never assume `create table if not exists` will fix legacy columns; it only prevents table-creation errors.
- If schema drift appears (missing columns on existing tables), add a new compatibility migration (do not rewrite past migrations already applied in shared environments).
- For fresh/repair setup, use strict migration order documented in `docs/backend_schema.md` section "Migration Operations Runbook".

Local runtime rules:
- Use mock mode by default if Supabase defines are missing.
- Use `--dart-define-from-file=.env/supabase.local.json` for Supabase-backed app runs (both local and hosted Supabase). The filename is legacy; it is still the standard runtime config file.
- Never commit `.env/supabase.local.json`; only commit `.env/supabase.local.example.json`.
- For agent SQL/admin access setup (psql/pooler credentials), read `docs/supabase_connection.md`.

If implementation and docs diverge, update `docs/backend_schema.md` in the same change.
