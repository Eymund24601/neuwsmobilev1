# nEUws Backend Schema (Polyglot Reader + Vocab)

Last updated: February 5, 2026

## 1) ER-Style Overview (Tables + Relationships)

```mermaid
erDiagram
  articles ||--o{ article_localizations : has
  article_localizations ||--o{ article_alignments : from
  article_localizations ||--o{ article_alignments : to
  articles ||--o{ article_focus_vocab : has
  articles ||--o{ article_vocab_spans : has

  vocab_items ||--o{ vocab_forms : has
  vocab_items ||--o{ vocab_entries : has
  vocab_items ||--o{ article_focus_vocab : used_in
  vocab_items ||--o{ article_vocab_spans : highlighted_in

  profiles ||--o{ user_vocab_progress : tracks
  profiles ||--o{ user_vocab_events : logs

  vocab_items ||--o{ user_vocab_progress : learned_by
  vocab_items ||--o{ user_vocab_events : seen_in

  articles ||--o{ publishing_jobs : publishes
  profiles ||--o{ vocab_entry_suggestions : proposes
  vocab_items ||--o{ vocab_entry_suggestions : suggests_for
```

Routing example (canonical -> target):

```
FR tap -> align FR -> canonical -> align canonical -> SV
```

## 2) Key Decisions (Locked)

- Canonical routing: Store only canonical -> each translation alignments (O(N)).
  - Any pair resolves via canonical: FR -> canonical -> SV.
  - No precomputed N^2 pairs.
- Alignment strategy: Store alignment packs as JSON with canonical-to-translation spans.
  - Alignment packs are directional and stored per localization pair.
  - Inversion is computed at runtime (canonical <-> local).
- Text offset encoding: UTF-16 code unit offsets everywhere (Dart / Flutter native).
- Vocab item definition: A "vocab item" represents a canonical lemma + POS.
  - Language-specific forms (surface/lemma variants) live in `vocab_forms`.
  - Language-specific definitions/notes/examples live in `vocab_entries`.

## 3) SQL Schema (Supabase/Postgres)

Note: snake_case for SQL; camelCase in Dart models. Primary keys use UUIDs.

```sql
-- Content
create table if not exists articles (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text,
  excerpt text,
  topic text,
  category text,
  country_code text,
  country_tags text[],
  read_time_minutes int,
  image_asset text,
  hero_image_url text,
  language_top text,
  language_bottom text,
  body_top text,
  body_bottom text,
  canonical_lang text,
  canonical_localization_id uuid,
  is_published boolean default false,
  published_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists article_localizations (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles(id) on delete cascade,
  lang text not null,
  title text,
  excerpt text,
  body text not null,
  content_hash text,
  version int default 1,
  created_at timestamptz default now(),
  unique (article_id, lang)
);

create table if not exists article_alignments (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles(id) on delete cascade,
  from_localization_id uuid not null references article_localizations(id) on delete cascade,
  to_localization_id uuid not null references article_localizations(id) on delete cascade,
  alignment_json jsonb not null,
  algo_version text,
  quality_score numeric,
  created_at timestamptz default now(),
  unique (from_localization_id, to_localization_id)
);

-- Vocabulary
create table if not exists vocab_items (
  id uuid primary key default gen_random_uuid(),
  canonical_lang text not null,
  canonical_lemma text not null,
  pos text,
  difficulty text,
  created_at timestamptz default now()
);

create table if not exists vocab_forms (
  id uuid primary key default gen_random_uuid(),
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  lang text not null,
  lemma text,
  surface text not null,
  notes text
);

create table if not exists vocab_entries (
  id uuid primary key default gen_random_uuid(),
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  lang text not null,
  primary_definition text,
  usage_notes text,
  examples text[],
  tags text[],
  updated_at timestamptz default now(),
  updated_by uuid,
  source text,
  unique (vocab_item_id, lang)
);

create table if not exists article_focus_vocab (
  article_id uuid not null references articles(id) on delete cascade,
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  rank int not null default 1,
  created_at timestamptz default now(),
  unique (article_id, vocab_item_id)
);

create table if not exists article_vocab_spans (
  article_id uuid not null references articles(id) on delete cascade,
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  localization_id uuid not null references article_localizations(id) on delete cascade,
  spans_json jsonb not null,
  unique (article_id, vocab_item_id, localization_id)
);

-- Users
create table if not exists user_vocab_progress (
  user_id uuid not null references profiles(id) on delete cascade,
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  level text not null default 'bronze',
  xp int not null default 0,
  last_seen_at timestamptz,
  next_review_at timestamptz,
  unique (user_id, vocab_item_id)
);

create table if not exists user_vocab_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  article_id uuid references articles(id) on delete set null,
  event_type text not null,
  occurred_at timestamptz default now(),
  meta_json jsonb
);

create table if not exists user_article_reads (
  user_id uuid not null references profiles(id) on delete cascade,
  article_id uuid not null references articles(id) on delete cascade,
  read_at timestamptz default now(),
  unique (user_id, article_id)
);

-- Moderation
create table if not exists vocab_entry_suggestions (
  id uuid primary key default gen_random_uuid(),
  vocab_item_id uuid not null references vocab_items(id) on delete cascade,
  lang text not null,
  suggestion_type text not null,
  proposed_text text,
  proposed_examples text[],
  proposed_tags text[],
  proposer_user_id uuid references profiles(id) on delete set null,
  status text not null default 'pending',
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz default now()
);

-- Publishing pipeline
create table if not exists publishing_jobs (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles(id) on delete cascade,
  status text not null default 'queued',
  step text,
  error text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_article_localizations_article on article_localizations(article_id);
create index if not exists idx_article_alignments_article on article_alignments(article_id);
create index if not exists idx_article_focus_vocab_article on article_focus_vocab(article_id);
create index if not exists idx_article_vocab_spans_article on article_vocab_spans(article_id);
create index if not exists idx_user_vocab_progress_user on user_vocab_progress(user_id);
create index if not exists idx_user_vocab_events_user on user_vocab_events(user_id);
```

RLS notes (recommendations):

- Public read access for published articles, localizations, alignments, and vocab entries/forms.
- User-scoped access for `user_vocab_progress`, `user_vocab_events`, `user_article_reads`.
- `vocab_entry_suggestions` insert allowed for authenticated users; update restricted to moderators.
- `publishing_jobs` insert limited to service role or edge function; select for admin/staff.

## 4) JSON Formats

Alignment pack (canonical -> translation):

```json
{
  "version": 1,
  "source_lang": "en",
  "target_lang": "fr",
  "offset_encoding": "utf16_code_units",
  "units": [
    { "c": [120, 132], "t": [98, 110], "score": 0.92 },
    { "c": [133, 146], "t": [111, 129], "score": 0.84 }
  ]
}
```

Vocab spans (per localization, UTF-16 offsets):

```json
{
  "version": 1,
  "offset_encoding": "utf16_code_units",
  "spans": [
    { "start": 240, "end": 252, "surface": "loyalty", "lemma": "loyalty" },
    { "start": 410, "end": 419, "surface": "dismissals", "lemma": "dismissal" }
  ]
}
```

## 5) Query Patterns (App Reads)

When opening an article (polyglot reader):

1. `articles` by `slug` -> get `id`, `canonical_lang` (or fallback), optional `canonical_localization_id`.
2. `article_localizations` for canonical + top + bottom languages.
3. `article_alignments` where `from_localization_id = canonical` and `to_localization_id` in {top, bottom}.
4. `article_focus_vocab` -> `vocab_items`, `vocab_entries` for UI language, `vocab_forms` for top/bottom languages.
5. `article_vocab_spans` for focus vocab (optional; used for inline highlight and word collection).

When collecting words:

1. Insert `user_vocab_events` for each focus vocab item (event_type: `seen`, `collect`).
2. Upsert `user_vocab_progress` to bump xp/level and update review fields.

When showing collection:

1. `user_vocab_progress` by user_id (grouped by level).
2. Join `vocab_entries` (ui language) + `vocab_forms` (current study language) for display.

## 6) Migration Path / Compatibility

Existing fields (`body_top`, `body_bottom`, `language_top`, `language_bottom`, `content`) remain supported during migration:

- Phase A: dual-write from publishing pipeline into both `articles.body_*` and `article_localizations`.
- Phase B: reader UI starts using `article_localizations` + `article_alignments`.
- Phase C: remove UI dependency on `body_top/body_bottom` but keep columns until old clients are sunset.

Compatibility rules:

- If `article_localizations` is missing for a language, fall back to `articles.body_top/body_bottom`.
- `articles.canonical_lang` is optional; default to `language_top` until backfilled.
- `article_alignments` may be missing for early content; reader should degrade to non-aligned display.

## 7) Publishing Pipeline Responsibilities (Where Computation Happens)

Storage is in Supabase; heavy computation is in an external worker/service:

1. Read canonical localization from Supabase.
2. Generate translations (LLM/API).
3. Compute canonical->translation alignment packs (LLM or alignment model).
4. Select 3–5 focus vocab items (human or LLM suggestion + approval).
5. Generate vocab entries per language (definitions/notes/examples).
6. Compute article_vocab_spans per localization.
7. Write results back to Supabase and mark `publishing_jobs` complete.

Edge Function may start a job by creating `publishing_jobs` rows, but heavy work must run off-platform.

