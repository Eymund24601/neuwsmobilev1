# Article + Word Coverage Plan (February 11, 2026)

## Objective
Deliver a repeatable Supabase seed baseline that lets Edvin test all current article/word behaviors in one session:
- multilingual article render in polyglot mode,
- cross-language term highlight behavior via focus-vocab chips,
- canonical localization + canonical-to-target alignment storage,
- word collection writes (`user_vocab_events`, `user_vocab_progress`),
- per-article vocab focus packs + inline vocab spans.

## Seed Design
- Use real seeded creator identities already in Supabase, plus Edvin as one author.
- Keep content idempotent via deterministic UUIDs.
- Keep reader bodies long-form (500+ words per localization) so split-mode scroll and sync are stress-tested.
- Keep localized text and vocab forms in native orthography (`å`, `ä`, `ö`, `é`, etc.), not ASCII transliteration.
- Seed alignments with word/sentence-friendly granularity (short rolling windows), not coarse 2-3 body-wide chunks.
- Use one canonical architecture path:
  - `articles` metadata + legacy reader compatibility fields,
  - `article_localizations` as source text variants,
  - `article_alignments` from canonical localization to non-canonical localizations,
  - `article_localization_tokens` + `article_token_vocab_links` token graph when migration is available,
  - `vocab_items` + `vocab_forms` + `vocab_entries`,
  - `article_focus_vocab` + `article_vocab_spans`,
  - sample `collect` rows in user vocab tables for validation.

## Coverage Matrix
- Languages covered: `en`, `fr`, `de`, `pt`, `sv`
- Seeded article set:
  - `stockholm-social-infrastructure` (top `en`, bottom `fr`, extra `sv`)
  - `vienna-election-volunteers` (top `de`, bottom `fr`, canonical `en`)
  - `baltic-night-train-journal` (top `en`, bottom `de`, extra `fr`)
  - `porto-urban-startup-loop` (top `pt`, bottom `fr`, canonical `en`)
  - `copenhagen-climate-blocks` (top `de`, bottom `sv`, canonical `en`)
  - `helsinki-grid-storage-coops` (top `sv`, bottom `en`, extra `de`)
- Focus vocab per article: 5 items each
- Span coverage: seeded per article/vocab/localization where surface form exists in body
- Collection coverage:
  - `alex.tester@neuws.local`
  - `edvin@kollberg.se`

## Fake Account Author Mapping
- `anna.meyer@neuws.local` -> Stockholm story
- `lukas.brenner@neuws.local` -> Vienna story
- `lea.novak@neuws.local` -> Baltic story
- `miguel.sousa@neuws.local` -> Porto story
- `sofia.rosen@neuws.local` -> Copenhagen story
- `edvin@kollberg.se` -> Helsinki story

## Execution Artifacts
- Migration: `supabase/migrations/20260211113000_articles_legacy_reader_compat.sql`
- Migration: `supabase/migrations/20260212153000_polyglot_token_graph.sql`
- Migration: `supabase/migrations/20260212170000_polyglot_token_alignment_materialize.sql`
- Seed: `docs/supabase_article_word_coverage_seed.sql`

## Verification Queries (Built into Seed)
The seed script prints:
- per-article localization/alignment/focus-vocab counts,
- localization language distribution,
- vocab-progress totals for target test users.

## Execution Safety (Important)
- Run the seed with a single transaction in `psql` (`-1`) because the script uses temp tables with `on commit drop`.
- If `docs/supabase_rich_seed.sql` is executed after this coverage seed, execute this coverage seed again so localization bodies, alignments, and token-graph rows stay synchronized.
