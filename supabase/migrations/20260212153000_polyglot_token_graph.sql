-- Polyglot token graph (article token occurrences <-> global vocab IDs)
-- date: 2026-02-12
-- additive only: enables full-word learning integration without breaking legacy reader paths

create extension if not exists pgcrypto;

create table if not exists public.article_localization_tokens (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  localization_id uuid not null references public.article_localizations(id) on delete cascade,
  token_index int not null,
  start_utf16 int not null,
  end_utf16 int not null,
  surface text not null,
  normalized_surface text not null,
  lemma_hint text,
  pos_hint text,
  created_at timestamptz not null default now(),
  unique (localization_id, token_index),
  check (token_index >= 1),
  check (start_utf16 >= 0),
  check (end_utf16 > start_utf16)
);

create table if not exists public.article_token_vocab_links (
  token_id uuid not null references public.article_localization_tokens(id) on delete cascade,
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  candidate_rank int not null default 1,
  is_primary boolean not null default false,
  match_type text not null default 'surface_form',
  confidence numeric,
  link_source text not null default 'pipeline',
  created_at timestamptz not null default now(),
  primary key (token_id, vocab_item_id),
  check (candidate_rank >= 1),
  check (confidence is null or (confidence >= 0 and confidence <= 1))
);

create table if not exists public.article_token_alignments (
  article_id uuid not null references public.articles(id) on delete cascade,
  canonical_token_id uuid not null references public.article_localization_tokens(id) on delete cascade,
  target_localization_id uuid not null references public.article_localizations(id) on delete cascade,
  target_token_id uuid not null references public.article_localization_tokens(id) on delete cascade,
  score numeric,
  algo_version text,
  created_at timestamptz not null default now(),
  primary key (canonical_token_id, target_token_id),
  check (score is null or (score >= 0 and score <= 1))
);

create index if not exists idx_article_tokens_article_localization_start
  on public.article_localization_tokens(article_id, localization_id, start_utf16);
create index if not exists idx_article_tokens_localization_surface
  on public.article_localization_tokens(localization_id, normalized_surface);
create index if not exists idx_article_tokens_article_surface
  on public.article_localization_tokens(article_id, normalized_surface);

create unique index if not exists idx_article_token_vocab_rank
  on public.article_token_vocab_links(token_id, candidate_rank);
create index if not exists idx_article_token_vocab_item_primary
  on public.article_token_vocab_links(vocab_item_id, is_primary, created_at desc);
create index if not exists idx_article_token_vocab_link_source
  on public.article_token_vocab_links(link_source, created_at desc);

create index if not exists idx_article_token_alignments_article_target
  on public.article_token_alignments(article_id, target_localization_id, canonical_token_id);
create index if not exists idx_article_token_alignments_target_token
  on public.article_token_alignments(target_token_id);

create or replace function public.normalize_vocab_token(p_text text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    lower(coalesce(p_text, '')),
    '[^[:alnum:]À-ÖØ-öø-ÿĀ-ž]+',
    '',
    'g'
  );
$$;

create or replace function public.rebuild_article_localization_tokens(p_localization_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_article_id uuid;
  v_inserted int := 0;
begin
  select l.article_id
  into v_article_id
  from public.article_localizations l
  where l.id = p_localization_id;

  if v_article_id is null then
    return 0;
  end if;

  delete from public.article_token_vocab_links atl
  where atl.token_id in (
    select t.id
    from public.article_localization_tokens t
    where t.localization_id = p_localization_id
  );

  delete from public.article_token_alignments ata
  where ata.canonical_token_id in (
          select t.id
          from public.article_localization_tokens t
          where t.localization_id = p_localization_id
        )
     or ata.target_token_id in (
          select t.id
          from public.article_localization_tokens t
          where t.localization_id = p_localization_id
        );

  delete from public.article_localization_tokens t
  where t.localization_id = p_localization_id;

  with src as (
    select l.article_id, l.id as localization_id, l.body
    from public.article_localizations l
    where l.id = p_localization_id
  ),
  chars as (
    select
      s.article_id,
      s.localization_id,
      g.pos,
      substr(s.body, g.pos, 1) as ch,
      (substr(s.body, g.pos, 1) ~ '[[:alnum:]À-ÖØ-öø-ÿĀ-ž''’-]') as is_word_char
    from src s
    cross join lateral generate_series(1, char_length(s.body)) as g(pos)
  ),
  marks as (
    select
      c.article_id,
      c.localization_id,
      c.pos,
      c.is_word_char,
      lag(c.is_word_char, 1, false) over (
        partition by c.article_id, c.localization_id
        order by c.pos
      ) as prev_is_word,
      lead(c.is_word_char, 1, false) over (
        partition by c.article_id, c.localization_id
        order by c.pos
      ) as next_is_word
    from chars c
  ),
  starts as (
    select
      m.article_id,
      m.localization_id,
      m.pos as start_pos,
      row_number() over (
        partition by m.article_id, m.localization_id
        order by m.pos
      ) as rn
    from marks m
    where m.is_word_char
      and not m.prev_is_word
  ),
  ends as (
    select
      m.article_id,
      m.localization_id,
      m.pos as end_pos,
      row_number() over (
        partition by m.article_id, m.localization_id
        order by m.pos
      ) as rn
    from marks m
    where m.is_word_char
      and not m.next_is_word
  ),
  tokens as (
    select
      s.article_id,
      s.localization_id,
      s.rn as token_index,
      s.start_pos,
      e.end_pos,
      substring(src.body from s.start_pos for (e.end_pos - s.start_pos + 1)) as surface
    from starts s
    join ends e
      on e.article_id = s.article_id
     and e.localization_id = s.localization_id
     and e.rn = s.rn
    join src
      on src.article_id = s.article_id
     and src.localization_id = s.localization_id
  )
  insert into public.article_localization_tokens (
    id,
    article_id,
    localization_id,
    token_index,
    start_utf16,
    end_utf16,
    surface,
    normalized_surface,
    lemma_hint,
    pos_hint
  )
  select
    gen_random_uuid(),
    t.article_id,
    t.localization_id,
    t.token_index,
    t.start_pos - 1,
    t.end_pos,
    t.surface,
    public.normalize_vocab_token(t.surface),
    null,
    null
  from tokens t
  where t.surface is not null
    and btrim(t.surface) <> ''
  order by t.token_index;

  get diagnostics v_inserted = row_count;
  return coalesce(v_inserted, 0);
end;
$$;

create or replace function public.rebuild_article_tokens_for_article(p_article_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_localization_id uuid;
  v_total int := 0;
begin
  for v_localization_id in
    select l.id
    from public.article_localizations l
    where l.article_id = p_article_id
    order by l.created_at asc, l.id asc
  loop
    v_total := v_total + public.rebuild_article_localization_tokens(v_localization_id);
  end loop;

  return v_total;
end;
$$;

create or replace function public.link_article_tokens_to_vocab(
  p_article_id uuid,
  p_max_candidates int default 3,
  p_link_source text default 'pipeline'
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max_candidates int := greatest(coalesce(p_max_candidates, 3), 1);
  v_inserted int := 0;
begin
  delete from public.article_token_vocab_links atl
  using public.article_localization_tokens t
  where atl.token_id = t.id
    and t.article_id = p_article_id
    and atl.link_source = p_link_source;

  with tokens as (
    select
      t.id as token_id,
      t.normalized_surface,
      l.lang
    from public.article_localization_tokens t
    join public.article_localizations l
      on l.id = t.localization_id
    where t.article_id = p_article_id
      and t.normalized_surface <> ''
  ),
  candidates as (
    select
      t.token_id,
      vf.vocab_item_id,
      'surface_form'::text as match_type,
      0.96::numeric as confidence
    from tokens t
    join public.vocab_forms vf
      on lower(vf.lang) = lower(t.lang)
     and t.normalized_surface = public.normalize_vocab_token(vf.surface)

    union all

    select
      t.token_id,
      vf.vocab_item_id,
      'lemma_form'::text as match_type,
      0.90::numeric as confidence
    from tokens t
    join public.vocab_forms vf
      on lower(vf.lang) = lower(t.lang)
     and t.normalized_surface = public.normalize_vocab_token(vf.lemma)

    union all

    select
      t.token_id,
      vi.id as vocab_item_id,
      'canonical_lemma'::text as match_type,
      0.82::numeric as confidence
    from tokens t
    join public.vocab_items vi
      on lower(vi.canonical_lang) = lower(t.lang)
     and t.normalized_surface = public.normalize_vocab_token(vi.canonical_lemma)
  ),
  deduped as (
    select
      c.token_id,
      c.vocab_item_id,
      c.match_type,
      c.confidence,
      row_number() over (
        partition by c.token_id, c.vocab_item_id
        order by c.confidence desc, c.match_type asc
      ) as per_vocab_rank
    from candidates c
  ),
  ranked as (
    select
      d.token_id,
      d.vocab_item_id,
      d.match_type,
      d.confidence,
      row_number() over (
        partition by d.token_id
        order by d.confidence desc, d.vocab_item_id
      ) as candidate_rank
    from deduped d
    where d.per_vocab_rank = 1
  )
  insert into public.article_token_vocab_links (
    token_id,
    vocab_item_id,
    candidate_rank,
    is_primary,
    match_type,
    confidence,
    link_source
  )
  select
    r.token_id,
    r.vocab_item_id,
    r.candidate_rank,
    (r.candidate_rank = 1),
    r.match_type,
    r.confidence,
    p_link_source
  from ranked r
  where r.candidate_rank <= v_max_candidates
  on conflict (token_id, vocab_item_id) do update
  set
    candidate_rank = excluded.candidate_rank,
    is_primary = excluded.is_primary,
    match_type = excluded.match_type,
    confidence = excluded.confidence,
    link_source = excluded.link_source;

  get diagnostics v_inserted = row_count;
  return coalesce(v_inserted, 0);
end;
$$;

create or replace function public.rebuild_article_token_graph(
  p_article_id uuid,
  p_max_candidates int default 3,
  p_link_source text default 'pipeline'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token_rows int := 0;
  v_link_rows int := 0;
begin
  v_token_rows := public.rebuild_article_tokens_for_article(p_article_id);
  v_link_rows := public.link_article_tokens_to_vocab(
    p_article_id,
    p_max_candidates,
    p_link_source
  );

  return jsonb_build_object(
    'article_id', p_article_id,
    'token_rows', v_token_rows,
    'link_rows', v_link_rows
  );
end;
$$;
