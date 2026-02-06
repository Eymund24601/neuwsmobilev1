-- nEUws backend foundation extension:
-- social, media, messaging, games, quizzes, retention analytics
-- date: 2026-02-06

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- Media assets (single source for profile, wallpaper, article, quiz, game)
-- ============================================================
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references public.profiles(id) on delete set null,
  bucket text not null default 'public',
  object_path text not null,
  kind text not null,
  mime_type text,
  bytes bigint,
  width int,
  height int,
  blurhash text,
  metadata_json jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bucket, object_path)
);

create index if not exists idx_media_assets_owner_created
  on public.media_assets(owner_user_id, created_at desc);
create index if not exists idx_media_assets_kind_created
  on public.media_assets(kind, created_at desc);

drop trigger if exists trg_media_assets_updated_at on public.media_assets;
create trigger trg_media_assets_updated_at
before update on public.media_assets
for each row execute function public.set_updated_at();

-- Optional compatibility extensions on existing tables.
alter table if exists public.articles
  add column if not exists hero_media_id uuid references public.media_assets(id) on delete set null,
  add column if not exists kicker text,
  add column if not exists subtitle text,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.article_localizations
  add column if not exists kicker text,
  add column if not exists subtitle text,
  add column if not exists hero_media_id uuid references public.media_assets(id) on delete set null;

alter table if exists public.profiles
  add column if not exists avatar_media_id uuid references public.media_assets(id) on delete set null,
  add column if not exists wallpaper_media_id uuid references public.media_assets(id) on delete set null,
  add column if not exists gender text,
  add column if not exists age_bracket text,
  add column if not exists birth_year int;

create table if not exists public.article_media (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  localization_id uuid references public.article_localizations(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete cascade,
  role text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_article_media_article_role
  on public.article_media(article_id, role, sort_order);
create index if not exists idx_article_media_localization
  on public.article_media(localization_id);

-- ============================================================
-- Direct messages
-- ============================================================
create table if not exists public.dm_threads (
  id uuid primary key default gen_random_uuid(),
  created_by_user_id uuid references public.profiles(id) on delete set null,
  thread_type text not null default 'dm',
  last_message_id uuid,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dm_thread_participants (
  thread_id uuid not null references public.dm_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_message_id uuid,
  last_read_at timestamptz,
  muted_at timestamptz,
  archived_at timestamptz,
  primary key (thread_id, user_id)
);

create table if not exists public.dm_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.dm_threads(id) on delete cascade,
  sender_user_id uuid references public.profiles(id) on delete set null,
  body text not null default '',
  media_asset_id uuid references public.media_assets(id) on delete set null,
  payload_json jsonb,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.dm_message_reads (
  message_id uuid not null references public.dm_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists idx_dm_threads_last_message_at
  on public.dm_threads(last_message_at desc, id desc);
create index if not exists idx_dm_participants_user_active
  on public.dm_thread_participants(user_id, archived_at, joined_at desc);
create index if not exists idx_dm_messages_thread_created
  on public.dm_messages(thread_id, created_at desc, id desc);
create index if not exists idx_dm_reads_user
  on public.dm_message_reads(user_id, read_at desc);

drop trigger if exists trg_dm_threads_updated_at on public.dm_threads;
create trigger trg_dm_threads_updated_at
before update on public.dm_threads
for each row execute function public.set_updated_at();

create or replace function public.dm_touch_thread_on_message_insert()
returns trigger
language plpgsql
as $$
begin
  update public.dm_threads
  set last_message_id = new.id,
      last_message_at = new.created_at,
      updated_at = now()
  where id = new.thread_id;
  return new;
end;
$$;

drop trigger if exists trg_dm_messages_touch_thread on public.dm_messages;
create trigger trg_dm_messages_touch_thread
after insert on public.dm_messages
for each row execute function public.dm_touch_thread_on_message_insert();

-- ============================================================
-- Games (compact payloads for puzzle rounds)
-- ============================================================
create table if not exists public.game_catalog (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  image_media_id uuid references public.media_assets(id) on delete set null,
  payload_schema jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.game_rounds (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.game_catalog(id) on delete cascade,
  round_key text not null,
  difficulty text,
  seed text,
  compact_payload jsonb not null,
  solution_hash text,
  image_media_id uuid references public.media_assets(id) on delete set null,
  published_at timestamptz,
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (game_id, round_key)
);

create table if not exists public.user_game_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  game_id uuid not null references public.game_catalog(id) on delete cascade,
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  status text not null default 'in_progress',
  score int not null default 0,
  max_score int,
  moves_count int not null default 0,
  duration_ms bigint not null default 0,
  state_json jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.user_game_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.user_game_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  event_at timestamptz not null default now(),
  payload_json jsonb
);

create index if not exists idx_game_rounds_active
  on public.game_rounds(game_id, is_active, published_at desc, id desc);
create index if not exists idx_user_game_sessions_user_started
  on public.user_game_sessions(user_id, started_at desc, id desc);
create index if not exists idx_user_game_sessions_round
  on public.user_game_sessions(round_id, status);
create index if not exists idx_user_game_events_session
  on public.user_game_events(session_id, event_at desc);

drop trigger if exists trg_user_game_sessions_updated_at on public.user_game_sessions;
create trigger trg_user_game_sessions_updated_at
before update on public.user_game_sessions
for each row execute function public.set_updated_at();

-- ============================================================
-- Quizzes
-- ============================================================
create table if not exists public.quiz_sets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  lang text not null,
  title text not null,
  description text,
  topic text,
  image_media_id uuid references public.media_assets(id) on delete set null,
  is_published boolean not null default false,
  created_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_set_id uuid not null references public.quiz_sets(id) on delete cascade,
  position int not null,
  prompt text not null,
  image_media_id uuid references public.media_assets(id) on delete set null,
  explanation text,
  metadata_json jsonb,
  created_at timestamptz not null default now(),
  unique (quiz_set_id, position)
);

create table if not exists public.quiz_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.quiz_questions(id) on delete cascade,
  position int not null,
  option_text text not null,
  is_correct boolean not null default false,
  created_at timestamptz not null default now(),
  unique (question_id, position)
);

create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_set_id uuid not null references public.quiz_sets(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  score int not null default 0,
  max_score int not null default 0,
  duration_ms bigint not null default 0,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_attempt_answers (
  attempt_id uuid not null references public.quiz_attempts(id) on delete cascade,
  question_id uuid not null references public.quiz_questions(id) on delete cascade,
  selected_option_id uuid references public.quiz_options(id) on delete set null,
  is_correct boolean not null default false,
  duration_ms bigint not null default 0,
  answered_at timestamptz not null default now(),
  primary key (attempt_id, question_id)
);

create index if not exists idx_quiz_sets_published_topic
  on public.quiz_sets(is_published, topic, created_at desc);
create index if not exists idx_quiz_questions_quiz_position
  on public.quiz_questions(quiz_set_id, position);
create index if not exists idx_quiz_attempts_user_completed
  on public.quiz_attempts(user_id, completed_at desc, started_at desc);

drop trigger if exists trg_quiz_sets_updated_at on public.quiz_sets;
create trigger trg_quiz_sets_updated_at
before update on public.quiz_sets
for each row execute function public.set_updated_at();

-- ============================================================
-- Social graph + settings + saves + collections
-- ============================================================
create table if not exists public.user_follows (
  follower_user_id uuid not null references public.profiles(id) on delete cascade,
  followed_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_user_id, followed_user_id),
  check (follower_user_id <> followed_user_id)
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  ui_lang text,
  reading_lang_top text,
  reading_lang_bottom text,
  home_topics text[] not null default '{}',
  home_sort_mode text not null default 'hybrid',
  push_notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.article_bookmarks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  article_id uuid not null references public.articles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, article_id)
);

create table if not exists public.user_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.collection_items (
  collection_id uuid not null references public.user_collections(id) on delete cascade,
  article_id uuid not null references public.articles(id) on delete cascade,
  saved_by_user_id uuid not null references public.profiles(id) on delete cascade,
  note text,
  sort_order int,
  created_at timestamptz not null default now(),
  primary key (collection_id, article_id)
);

create table if not exists public.article_reposts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  article_id uuid not null references public.articles(id) on delete cascade,
  commentary text,
  created_at timestamptz not null default now(),
  unique (user_id, article_id)
);

create index if not exists idx_user_follows_followed_created
  on public.user_follows(followed_user_id, created_at desc);
create index if not exists idx_user_follows_follower_created
  on public.user_follows(follower_user_id, created_at desc);
create index if not exists idx_article_bookmarks_user_created
  on public.article_bookmarks(user_id, created_at desc);
create index if not exists idx_user_collections_user_updated
  on public.user_collections(user_id, updated_at desc, id desc);
create index if not exists idx_collection_items_collection_sort
  on public.collection_items(collection_id, sort_order, created_at desc);
create index if not exists idx_article_reposts_article_created
  on public.article_reposts(article_id, created_at desc);

drop trigger if exists trg_user_settings_updated_at on public.user_settings;
create trigger trg_user_settings_updated_at
before update on public.user_settings
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_collections_updated_at on public.user_collections;
create trigger trg_user_collections_updated_at
before update on public.user_collections
for each row execute function public.set_updated_at();

-- ============================================================
-- Notifications + moderation
-- ============================================================
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  kind text not null,
  entity_type text,
  entity_id uuid,
  payload_json jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create table if not exists public.user_blocks (
  blocker_user_id uuid not null references public.profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_user_id uuid references public.profiles(id) on delete set null,
  target_article_id uuid references public.articles(id) on delete set null,
  target_message_id uuid references public.dm_messages(id) on delete set null,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  review_note text
);

create index if not exists idx_notifications_user_unread
  on public.notifications(user_id, is_read, created_at desc);
create index if not exists idx_reports_status_created
  on public.reports(status, created_at desc);

-- ============================================================
-- Retention analytics + counters
-- ============================================================
create table if not exists public.article_engagement_events (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  session_id text,
  event_type text not null,
  duration_ms bigint,
  scroll_depth numeric,
  occurred_at timestamptz not null default now(),
  meta_json jsonb
);

create table if not exists public.article_counters (
  article_id uuid primary key references public.articles(id) on delete cascade,
  click_count bigint not null default 0,
  open_count bigint not null default 0,
  save_count bigint not null default 0,
  repost_count bigint not null default 0,
  total_read_ms bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.article_metrics_daily (
  article_id uuid not null references public.articles(id) on delete cascade,
  metric_date date not null,
  click_count bigint not null default 0,
  open_count bigint not null default 0,
  unique_open_users bigint not null default 0,
  save_count bigint not null default 0,
  repost_count bigint not null default 0,
  total_read_ms bigint not null default 0,
  primary key (article_id, metric_date)
);

create table if not exists public.user_stats (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  follower_count int not null default 0,
  following_count int not null default 0,
  published_article_count int not null default 0,
  draft_article_count int not null default 0,
  saved_article_count int not null default 0,
  repost_count int not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists idx_article_events_article_time
  on public.article_engagement_events(article_id, occurred_at desc);
create index if not exists idx_article_events_user_time
  on public.article_engagement_events(user_id, occurred_at desc);
create index if not exists idx_article_events_type_time
  on public.article_engagement_events(event_type, occurred_at desc);
create index if not exists idx_article_metrics_daily_date
  on public.article_metrics_daily(metric_date desc, article_id);

drop trigger if exists trg_article_counters_updated_at on public.article_counters;
create trigger trg_article_counters_updated_at
before update on public.article_counters
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_stats_updated_at on public.user_stats;
create trigger trg_user_stats_updated_at
before update on public.user_stats
for each row execute function public.set_updated_at();

create or replace function public.ensure_article_counter(p_article_id uuid)
returns void
language plpgsql
as $$
begin
  insert into public.article_counters (article_id)
  values (p_article_id)
  on conflict (article_id) do nothing;
end;
$$;

create or replace function public.bump_article_counter_on_event()
returns trigger
language plpgsql
as $$
begin
  perform public.ensure_article_counter(new.article_id);

  if new.event_type in ('click', 'open') then
    update public.article_counters
    set click_count = click_count + case when new.event_type = 'click' then 1 else 0 end,
        open_count = open_count + case when new.event_type = 'open' then 1 else 0 end,
        total_read_ms = total_read_ms + coalesce(new.duration_ms, 0)
    where article_id = new.article_id;
  else
    update public.article_counters
    set total_read_ms = total_read_ms + coalesce(new.duration_ms, 0)
    where article_id = new.article_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_article_events_bump_counter on public.article_engagement_events;
create trigger trg_article_events_bump_counter
after insert on public.article_engagement_events
for each row execute function public.bump_article_counter_on_event();

create or replace function public.bump_article_counter_on_bookmark()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    perform public.ensure_article_counter(new.article_id);
    update public.article_counters
    set save_count = save_count + 1
    where article_id = new.article_id;
    return new;
  end if;

  perform public.ensure_article_counter(old.article_id);
  update public.article_counters
  set save_count = greatest(save_count - 1, 0)
  where article_id = old.article_id;
  return old;
end;
$$;

drop trigger if exists trg_bookmarks_bump_counter on public.article_bookmarks;
create trigger trg_bookmarks_bump_counter
after insert or delete on public.article_bookmarks
for each row execute function public.bump_article_counter_on_bookmark();

create or replace function public.bump_article_counter_on_repost()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    perform public.ensure_article_counter(new.article_id);
    update public.article_counters
    set repost_count = repost_count + 1
    where article_id = new.article_id;
    return new;
  end if;

  perform public.ensure_article_counter(old.article_id);
  update public.article_counters
  set repost_count = greatest(repost_count - 1, 0)
  where article_id = old.article_id;
  return old;
end;
$$;

drop trigger if exists trg_reposts_bump_counter on public.article_reposts;
create trigger trg_reposts_bump_counter
after insert or delete on public.article_reposts
for each row execute function public.bump_article_counter_on_repost();

-- ============================================================
-- Optional indexes on existing article table, if columns exist.
-- ============================================================
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'articles'
      and column_name = 'author_id'
  ) then
    create index if not exists idx_articles_author_publish_created
      on public.articles(author_id, is_published, created_at desc, id desc);
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'articles'
      and column_name = 'topic'
  ) then
    create index if not exists idx_articles_topic_published_at
      on public.articles(topic, is_published, published_at desc, id desc);
  end if;
end
$$;

-- ============================================================
-- RLS scaffolding (minimal defaults)
-- ============================================================
alter table public.dm_threads enable row level security;
alter table public.dm_thread_participants enable row level security;
alter table public.dm_messages enable row level security;
alter table public.dm_message_reads enable row level security;
alter table public.user_settings enable row level security;
alter table public.article_bookmarks enable row level security;
alter table public.user_collections enable row level security;
alter table public.collection_items enable row level security;
alter table public.article_reposts enable row level security;
alter table public.user_follows enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_settings'
      and policyname = 'user_settings_self_select'
  ) then
    create policy user_settings_self_select
      on public.user_settings
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_settings'
      and policyname = 'user_settings_self_write'
  ) then
    create policy user_settings_self_write
      on public.user_settings
      for all
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'article_bookmarks'
      and policyname = 'bookmarks_self_all'
  ) then
    create policy bookmarks_self_all
      on public.article_bookmarks
      for all
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'article_reposts'
      and policyname = 'reposts_self_all'
  ) then
    create policy reposts_self_all
      on public.article_reposts
      for all
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_follows'
      and policyname = 'follows_public_read'
  ) then
    create policy follows_public_read
      on public.user_follows
      for select
      using (true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_follows'
      and policyname = 'follows_self_write'
  ) then
    create policy follows_self_write
      on public.user_follows
      for all
      using (follower_user_id = auth.uid())
      with check (follower_user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'dm_thread_participants'
      and policyname = 'dm_participants_self'
  ) then
    create policy dm_participants_self
      on public.dm_thread_participants
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'dm_messages'
      and policyname = 'dm_messages_participant_select'
  ) then
    create policy dm_messages_participant_select
      on public.dm_messages
      for select
      using (
        exists (
          select 1
          from public.dm_thread_participants p
          where p.thread_id = dm_messages.thread_id
            and p.user_id = auth.uid()
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'dm_messages'
      and policyname = 'dm_messages_participant_insert'
  ) then
    create policy dm_messages_participant_insert
      on public.dm_messages
      for insert
      with check (
        sender_user_id = auth.uid()
        and exists (
          select 1
          from public.dm_thread_participants p
          where p.thread_id = dm_messages.thread_id
            and p.user_id = auth.uid()
        )
      );
  end if;
end
$$;
