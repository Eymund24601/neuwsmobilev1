# nEUws AI Article Publish Contract (Supabase)

Last updated: February 12, 2026

## 1) Purpose
This document defines exactly how an external AI agent must format and publish:
- one source article,
- all translated localizations,
- canonical-to-target alignments,
- token graph rows and token IDs.

If the agent follows this contract, Supabase will be ready to serve article `X` in language pair `Y/Z` with stable token IDs.

## 2) Non-Negotiable Rules
- Use canonical routing only: `source -> canonical -> target` (no pairwise N^2 storage).
- Use UTF-16 code unit offsets for all span offsets.
- Preserve native orthography in text (for example `å`, `ä`, `ö`, `é`, `ç`, `ü`).
- Alignment units must be fine-grained (no 2-3 whole-body chunks).
- Prefer additive upserts; do not delete historical migrations.

## 3) Required DB Objects
The target Supabase project must include these migrations:
- `20260206164000_polyglot_core.sql`
- `20260211113000_articles_legacy_reader_compat.sql`
- `20260212153000_polyglot_token_graph.sql`
- `20260212170000_polyglot_token_alignment_materialize.sql`

The agent relies on these functions:
- `public.rebuild_article_token_graph(uuid, integer, text)`
- `public.rebuild_article_token_alignments(uuid, text)`

## 4) Author vs Reader Language Ownership
- Publisher/author input defines content (`canonical_lang`, localizations, alignments).
- Reader language pair (`topLang`, `bottomLang`) is a user setting and is selected at read time.
- Publisher payloads must **not** send `top_lang` or `bottom_lang`.

## 5) Hero Image Fields (Canonical vs Legacy)
- `hero_image_url`: canonical article hero image field. The app reads this first.
- `image_asset`: legacy compatibility field for older/local-asset paths.

Publisher contract rule:
- Send only `hero_image_url`.
- Publishing SQL can mirror `hero_image_url` into `image_asset` for old readers.

## 6) Input Payload Format (Agent -> Publisher)
Use this JSON envelope exactly (extra fields allowed, but required fields must exist):

```json
{
  "version": "publish_package_v1",
  "trace_id": "job-2026-02-12-0001",
  "article": {
    "slug": "stockholm-social-infrastructure",
    "title": "How Stockholm Rebuilt Belonging Through Public Spaces",
    "excerpt": "Libraries and local host budgets are reducing isolation.",
    "topic": "Culture",
    "country_code": "SE",
    "country_tags": ["SE", "DK", "NO"],
    "hero_image_url": "https://cdn.example.com/articles/stockholm-social-infrastructure/hero.jpg",
    "author_id": "UUID",
    "canonical_lang": "en",
    "published_at": "2026-02-12T15:00:00Z",
    "is_published": true
  },
  "localizations": [
    {
      "lang": "en",
      "title": "How Stockholm Rebuilt Belonging Through Public Spaces",
      "excerpt": "Libraries and local host budgets are reducing isolation.",
      "body": "..."
    },
    {
      "lang": "sv",
      "title": "Hur Stockholm bygger ny gemenskap i kvarteren",
      "excerpt": "Lokala platser och tydlig finansiering minskar isolering.",
      "body": "..."
    },
    {
      "lang": "fr",
      "title": "Comment Stockholm reconstruit le lien local",
      "excerpt": "Des lieux publics renforcent le lien social.",
      "body": "..."
    }
  ],
  "alignments": [
    {
      "target_lang": "sv",
      "algo_version": "my-aligner-v3",
      "quality_score": 0.92,
      "alignment_json": {
        "version": 1,
        "source_lang": "en",
        "target_lang": "sv",
        "offset_encoding": "utf16_code_units",
        "units": [
          { "c": [0, 48], "t": [0, 52], "score": 0.94 },
          { "c": [48, 96], "t": [52, 104], "score": 0.93 }
        ]
      }
    },
    {
      "target_lang": "fr",
      "algo_version": "my-aligner-v3",
      "quality_score": 0.91,
      "alignment_json": {
        "version": 1,
        "source_lang": "en",
        "target_lang": "fr",
        "offset_encoding": "utf16_code_units",
        "units": [
          { "c": [0, 48], "t": [0, 55], "score": 0.93 },
          { "c": [48, 96], "t": [55, 110], "score": 0.92 }
        ]
      }
    }
  ]
}
```

## 7) Publish Sequence (Exact Order)
Run all steps in one transaction.

1. Upsert `articles` by `slug`.
2. Upsert each `article_localizations` row by `(article_id, lang)`.
3. Set `articles.canonical_localization_id` to the localization matching `canonical_lang`.
4. Replace canonical->target rows in `article_alignments`.
5. Run token graph materialization:
   - `select public.rebuild_article_token_graph(:article_id, 3, :link_source);`
6. Run token alignment materialization:
   - `select public.rebuild_article_token_alignments(:article_id, :algo_version);`
7. Return token payload to caller (section 9 query).

## 8) SQL Template (Agent/Admin Path)
Use `psql -1 -v ON_ERROR_STOP=1` with a generated SQL script.

```sql
-- 1) Upsert article (example conflict key: slug)
insert into public.articles (
  slug,
  title,
  excerpt,
  topic,
  country_code,
  country_tags,
  hero_image_url,
  image_asset,
  author_id,
  canonical_lang,
  is_published,
  published_at
)
values (
  :slug,
  :title,
  :excerpt,
  :topic,
  :country_code,
  :country_tags,
  :hero_image_url,
  :hero_image_url,
  :author_id,
  :canonical_lang,
  :is_published,
  :published_at
)
on conflict (slug) do update set
  title = excluded.title,
  excerpt = excluded.excerpt,
  topic = excluded.topic,
  country_code = excluded.country_code,
  country_tags = excluded.country_tags,
  hero_image_url = excluded.hero_image_url,
  image_asset = excluded.image_asset,
  author_id = excluded.author_id,
  canonical_lang = excluded.canonical_lang,
  is_published = excluded.is_published,
  published_at = excluded.published_at;

-- 2) Resolve article_id
select id from public.articles where slug = :slug;

-- 3) Upsert localizations (repeat per language)
insert into public.article_localizations (
  article_id, lang, title, excerpt, body, content_hash, version
)
values (
  :article_id, :lang, :loc_title, :loc_excerpt, :loc_body, md5(:loc_body), 1
)
on conflict (article_id, lang) do update set
  title = excluded.title,
  excerpt = excluded.excerpt,
  body = excluded.body,
  content_hash = excluded.content_hash,
  version = excluded.version;

-- 4) Set canonical localization id
update public.articles a
set canonical_localization_id = l.id
from public.article_localizations l
where a.id = :article_id
  and l.article_id = :article_id
  and l.lang = :canonical_lang;

-- 5) Replace canonical->target alignments
delete from public.article_alignments
where article_id = :article_id
  and from_localization_id = :canonical_localization_id;

insert into public.article_alignments (
  article_id, from_localization_id, to_localization_id,
  alignment_json, algo_version, quality_score
)
values (
  :article_id, :canonical_localization_id, :target_localization_id,
  :alignment_json::jsonb, :alignment_algo_version, :alignment_quality_score
)
on conflict (from_localization_id, to_localization_id) do update set
  alignment_json = excluded.alignment_json,
  algo_version = excluded.algo_version,
  quality_score = excluded.quality_score;

-- 6) Materialize token rows + token links
select public.rebuild_article_token_graph(
  :article_id,
  3,
  :link_source
);

-- 7) Materialize canonical->target token edges
select public.rebuild_article_token_alignments(
  :article_id,
  :token_alignment_algo_version
);
```

## 9) Required Response Query (Supabase -> Agent)
Return this after publish. This is the payload your app expects for deterministic token mapping.

```sql
select
  l.lang,
  t.id as token_id,
  t.token_index,
  t.start_utf16,
  t.end_utf16,
  t.surface,
  t.normalized_surface,
  p.vocab_item_id as primary_vocab_item_id,
  p.match_type as primary_match_type,
  p.confidence as primary_confidence
from public.article_localizations l
join public.article_localization_tokens t
  on t.localization_id = l.id
left join lateral (
  select
    atl.vocab_item_id,
    atl.match_type,
    atl.confidence
  from public.article_token_vocab_links atl
  where atl.token_id = t.id
    and atl.is_primary = true
  order by atl.candidate_rank asc
  limit 1
) p on true
where l.article_id = :article_id
order by l.lang, t.token_index;
```

Optional edge payload:

```sql
select
  ata.canonical_token_id,
  ata.target_localization_id,
  ata.target_token_id,
  ata.score,
  ata.algo_version
from public.article_token_alignments ata
where ata.article_id = :article_id
order by ata.target_localization_id, ata.canonical_token_id;
```

## 10) PostgREST Path (Service Role)
If using PostgREST instead of SQL:
- Upsert `articles` at `/rest/v1/articles`.
- Upsert `article_localizations` at `/rest/v1/article_localizations`.
- Upsert `article_alignments` at `/rest/v1/article_alignments`.
- Call RPC:
  - `/rest/v1/rpc/rebuild_article_token_graph`
  - `/rest/v1/rpc/rebuild_article_token_alignments`

Headers:
- `apikey: <service-role-key>`
- `Authorization: Bearer <service-role-key>`
- `Prefer: resolution=merge-duplicates`

## 11) Quality Gates (Reject Publish If Failing)
Reject/mark job failed if any of these are true:
- Missing canonical localization.
- Any alignment pack has `offset_encoding != utf16_code_units`.
- Alignment unit count too low for long text (coarse pack / chunk-only pack).
- `rebuild_article_token_graph` returns `token_rows = 0`.
- Any required display language has zero tokens.
- Any tapped-word language pair is missing canonical->target token edges in `article_token_alignments`.
- Canonical lexical token coverage is incomplete (non-punctuation tokens missing from token graph).

Strict reader rule:
- If these gates are not met, do not publish. The app must not guess mappings.

### 11.1) Post-Publish Validation SQL (Required)
Run these checks after materialization and fail the job if any check returns bad rows/counts.

```sql
-- A) Canonical localization exists
select a.id, a.slug
from public.articles a
left join public.article_localizations l
  on l.id = a.canonical_localization_id
where a.id = :article_id
  and l.id is null;

-- B) Token rows exist for each localization
select l.lang, count(t.id) as token_count
from public.article_localizations l
left join public.article_localization_tokens t
  on t.localization_id = l.id
where l.article_id = :article_id
group by l.lang
having count(t.id) = 0;

-- C) Canonical->target token edges exist for each non-canonical localization
select l.lang, count(ata.target_token_id) as edge_count
from public.article_localizations l
left join public.article_token_alignments ata
  on ata.article_id = l.article_id
 and ata.target_localization_id = l.id
where l.article_id = :article_id
  and l.id <> (
    select canonical_localization_id
    from public.articles
    where id = :article_id
  )
group by l.lang
having count(ata.target_token_id) = 0;
```

## 12) Manual Token-ID Mode (Advanced, Optional)
Recommended default is DB-generated tokens via `rebuild_article_token_graph`.

If you must supply token IDs manually:
- Insert into `article_localization_tokens` with explicit `id` UUIDs.
- Ensure uniqueness per `(localization_id, token_index)`.
- Ensure offsets are UTF-16 and satisfy checks.
- Then upsert `article_token_vocab_links`, then run `rebuild_article_token_alignments`.

Use this only when your tokenizer is guaranteed to match app runtime expectations.

