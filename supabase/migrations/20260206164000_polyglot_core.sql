-- nEUws polyglot/vocab core schema
-- date: 2026-02-06

create extension if not exists pgcrypto;

-- Compatibility updates on existing articles table.
alter table if exists public.articles
  add column if not exists canonical_lang text,
  add column if not exists canonical_localization_id uuid;

create table if not exists public.article_localizations (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  lang text not null,
  title text,
  excerpt text,
  body text not null,
  content_hash text,
  version int not null default 1,
  created_at timestamptz not null default now(),
  unique (article_id, lang)
);

create table if not exists public.article_alignments (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  from_localization_id uuid not null references public.article_localizations(id) on delete cascade,
  to_localization_id uuid not null references public.article_localizations(id) on delete cascade,
  alignment_json jsonb not null,
  algo_version text,
  quality_score numeric,
  created_at timestamptz not null default now(),
  unique (from_localization_id, to_localization_id)
);

create table if not exists public.vocab_items (
  id uuid primary key default gen_random_uuid(),
  canonical_lang text not null,
  canonical_lemma text not null,
  pos text,
  difficulty text,
  created_at timestamptz not null default now()
);

create table if not exists public.vocab_forms (
  id uuid primary key default gen_random_uuid(),
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  lang text not null,
  lemma text,
  surface text not null,
  notes text
);

create table if not exists public.vocab_entries (
  id uuid primary key default gen_random_uuid(),
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  lang text not null,
  primary_definition text,
  usage_notes text,
  examples text[],
  tags text[],
  updated_at timestamptz not null default now(),
  updated_by uuid,
  source text,
  unique (vocab_item_id, lang)
);

create table if not exists public.article_focus_vocab (
  article_id uuid not null references public.articles(id) on delete cascade,
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  rank int not null default 1,
  created_at timestamptz not null default now(),
  primary key (article_id, vocab_item_id)
);

create table if not exists public.article_vocab_spans (
  article_id uuid not null references public.articles(id) on delete cascade,
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  localization_id uuid not null references public.article_localizations(id) on delete cascade,
  spans_json jsonb not null,
  primary key (article_id, vocab_item_id, localization_id)
);

create table if not exists public.user_vocab_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  level text not null default 'bronze',
  xp int not null default 0,
  last_seen_at timestamptz,
  next_review_at timestamptz,
  primary key (user_id, vocab_item_id)
);

create table if not exists public.user_vocab_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  article_id uuid references public.articles(id) on delete set null,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  meta_json jsonb
);

create table if not exists public.user_article_reads (
  user_id uuid not null references public.profiles(id) on delete cascade,
  article_id uuid not null references public.articles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, article_id)
);

create table if not exists public.vocab_entry_suggestions (
  id uuid primary key default gen_random_uuid(),
  vocab_item_id uuid not null references public.vocab_items(id) on delete cascade,
  lang text not null,
  suggestion_type text not null,
  proposed_text text,
  proposed_examples text[],
  proposed_tags text[],
  proposer_user_id uuid references public.profiles(id) on delete set null,
  status text not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now()
);

create table if not exists public.publishing_jobs (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  status text not null default 'queued',
  step text,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_article_localizations_article
  on public.article_localizations(article_id);
create index if not exists idx_article_alignments_article
  on public.article_alignments(article_id);
create index if not exists idx_article_focus_vocab_article_rank
  on public.article_focus_vocab(article_id, rank);
create index if not exists idx_article_vocab_spans_article
  on public.article_vocab_spans(article_id, localization_id);
create index if not exists idx_vocab_entries_vocab_lang
  on public.vocab_entries(vocab_item_id, lang);
create index if not exists idx_user_vocab_progress_user
  on public.user_vocab_progress(user_id, level, xp desc);
create index if not exists idx_user_vocab_events_user_time
  on public.user_vocab_events(user_id, occurred_at desc);
create index if not exists idx_publishing_jobs_status_created
  on public.publishing_jobs(status, created_at desc);
create index if not exists idx_publishing_jobs_article_created
  on public.publishing_jobs(article_id, created_at desc);

create or replace function public.set_updated_at_if_present()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_publishing_jobs_updated_at on public.publishing_jobs;
create trigger trg_publishing_jobs_updated_at
before update on public.publishing_jobs
for each row execute function public.set_updated_at_if_present();

-- startPublishingJob RPC helper for edge functions
create or replace function public.start_publishing_job(p_article_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_id uuid;
begin
  insert into public.publishing_jobs (article_id, status, step)
  values (p_article_id, 'queued', 'queued')
  returning id into v_job_id;

  return v_job_id;
end;
$$;
