# Quiz Clash Rollout Outline
Date: February 10, 2026
Status: Implemented in this session

## Scope
- Move `Words` from bottom navigation to drawer as a large highlighted button.
- Split bottom navigation into `Quizzes` and `Puzzles`.
- Keep `Puzzles` for Sudoku + Eurodle only.
- Build async turn-based `Quiz Clash` (invites, 6 rounds, category picks, turn deadlines, result resolution).
- Add in-match message shortcut when players mutually follow each other.
- Update migrations, seeds, and architecture docs.

## Delivery Phases
1. Navigation/IA refactor
- Added new tab flow: `Home`, `Messages`, `Quizzes`, `Puzzles`, `You`.
- Added drawer CTA `Words` above theme switch.
- Added route compatibility redirect from `/learn` to `/words`.

2. Quizzes and Puzzles split
- Created `QuizzesPage` hub with `Quiz Clash` and `Normal Quizzes` cards.
- Removed quiz shortcut from `GamesPage` so it remains puzzle-only.
- Kept existing normal quiz flow via `quiz_categories_page` + `quiz_play_page`.

3. Quiz Clash backend contracts
- Added core schema migration with:
  - categories/questions bank
  - invites
  - matches
  - rounds
  - round submissions
  - indexes, RLS, realtime publication
- Added RPC migration with async turn loop:
  - send/accept invite
  - pick category
  - submit picker/responder turns
  - claim timeout forfeit

4. Quiz Clash frontend + data wiring
- Added domain models for invites, matches, turn state, and questions.
- Extended `GamesRepository` mock + Supabase implementations.
- Added providers:
  - `quizClashInvitesProvider`
  - `quizClashMatchesProvider`
  - `quizClashTurnStateProvider`
- Added screens:
  - `quiz_clash_lobby_page.dart`
  - `quiz_clash_match_page.dart`

5. Messaging button and social gate
- Match header includes `Message Opponent` button.
- Button enabled only when `user_follows` is mutual for both players.
- Button opens/creates DM thread via existing `createOrGetDmThread` flow.

6. Seed and docs updates
- Added Quiz Clash seed coverage in:
  - `docs/supabase_minimal_seed.sql`
  - `docs/supabase_rich_seed.sql`
- Updated architecture docs:
  - `docs/backend_schema.md`
  - `docs/backend_outline.md`

7. Verification
- Updated widget tests for new nav and routing expectations.
- Static analysis and tests executed at end of session.
