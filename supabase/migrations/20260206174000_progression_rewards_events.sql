-- nEUws progression + rewards + events
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
-- Progression: levels + XP + streaks
-- ============================================================
create table if not exists public.progression_levels (
  level int primary key,
  xp_required bigint not null unique,
  title text,
  created_at timestamptz not null default now(),
  check (level >= 1),
  check (xp_required >= 0)
);

insert into public.progression_levels (level, xp_required, title)
values
  (1, 0, 'Bronze I'),
  (2, 100, 'Bronze II'),
  (3, 250, 'Bronze III'),
  (4, 450, 'Silver I'),
  (5, 700, 'Silver II'),
  (6, 1000, 'Silver III'),
  (7, 1400, 'Gold I'),
  (8, 1850, 'Gold II'),
  (9, 2350, 'Gold III'),
  (10, 2900, 'Platinum I')
on conflict (level) do nothing;

create table if not exists public.user_progression (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  total_xp bigint not null default 0,
  level int not null default 1 references public.progression_levels(level),
  current_streak_days int not null default 0,
  best_streak_days int not null default 0,
  last_activity_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (total_xp >= 0),
  check (current_streak_days >= 0),
  check (best_streak_days >= 0)
);

create table if not exists public.xp_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  xp_delta int not null,
  source_type text not null,
  source_id uuid,
  dedupe_key text,
  meta_json jsonb,
  created_at timestamptz not null default now(),
  check (xp_delta <> 0)
);

create unique index if not exists idx_xp_ledger_user_dedupe
  on public.xp_ledger(user_id, dedupe_key)
  where dedupe_key is not null;

create index if not exists idx_xp_ledger_user_created
  on public.xp_ledger(user_id, created_at desc, id desc);
create index if not exists idx_xp_ledger_source
  on public.xp_ledger(source_type, source_id, created_at desc);

create table if not exists public.streak_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_date date not null,
  activity_type text not null,
  source_type text,
  source_id uuid,
  created_at timestamptz not null default now(),
  unique (user_id, activity_date, activity_type)
);

create index if not exists idx_streak_events_user_date
  on public.streak_events(user_id, activity_date desc);

-- ============================================================
-- Achievements + perks
-- ============================================================
create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  achievement_key text not null unique,
  name text not null,
  description text,
  category text,
  condition_json jsonb,
  xp_reward int not null default 0,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.user_achievements (
  user_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete cascade,
  progress_value numeric not null default 0,
  achieved_at timestamptz,
  claimed_at timestamptz,
  claim_status text not null default 'locked',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create index if not exists idx_user_achievements_user_status
  on public.user_achievements(user_id, claim_status, achieved_at desc);

create table if not exists public.perks_catalog (
  id uuid primary key default gen_random_uuid(),
  perk_key text not null unique,
  name text not null,
  description text,
  perk_type text not null,
  cost_xp int not null default 0,
  max_uses int,
  duration_days int,
  metadata_json jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.user_perks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  perk_id uuid not null references public.perks_catalog(id) on delete cascade,
  source_type text not null,
  source_id uuid,
  status text not null default 'available',
  remaining_uses int,
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  consumed_at timestamptz
);

create table if not exists public.perk_redemptions (
  id uuid primary key default gen_random_uuid(),
  user_perk_id uuid not null references public.user_perks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  perk_id uuid not null references public.perks_catalog(id) on delete cascade,
  context_type text,
  context_id uuid,
  redeemed_at timestamptz not null default now(),
  meta_json jsonb
);

create index if not exists idx_user_perks_user_status_expires
  on public.user_perks(user_id, status, expires_at, granted_at desc);
create index if not exists idx_perk_redemptions_user_time
  on public.perk_redemptions(user_id, redeemed_at desc);

-- ============================================================
-- Events (community / live / in-app)
-- ============================================================
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  topic text,
  location_label text,
  start_at timestamptz not null,
  end_at timestamptz,
  image_media_id uuid references public.media_assets(id) on delete set null,
  capacity int,
  is_published boolean not null default false,
  completion_xp int not null default 0,
  completion_perk_id uuid references public.perks_catalog(id) on delete set null,
  created_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_registrations (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'registered',
  registered_at timestamptz not null default now(),
  checked_in_at timestamptz,
  completed_at timestamptz,
  xp_awarded int not null default 0,
  granted_user_perk_id uuid references public.user_perks(id) on delete set null,
  primary key (event_id, user_id)
);

create table if not exists public.event_activity_events (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  meta_json jsonb
);

create index if not exists idx_events_published_start
  on public.events(is_published, start_at asc, id asc);
create index if not exists idx_event_regs_user_status
  on public.event_registrations(user_id, status, registered_at desc);
create index if not exists idx_event_activity_event_time
  on public.event_activity_events(event_id, occurred_at desc);

drop trigger if exists trg_user_progression_updated_at on public.user_progression;
create trigger trg_user_progression_updated_at
before update on public.user_progression
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_achievements_updated_at on public.user_achievements;
create trigger trg_user_achievements_updated_at
before update on public.user_achievements
for each row execute function public.set_updated_at();

drop trigger if exists trg_events_updated_at on public.events;
create trigger trg_events_updated_at
before update on public.events
for each row execute function public.set_updated_at();

-- ============================================================
-- Progression functions
-- ============================================================
create or replace function public.level_for_xp(p_total_xp bigint)
returns int
language sql
stable
as $$
  select coalesce(max(level), 1)
  from public.progression_levels
  where xp_required <= p_total_xp;
$$;

create or replace function public.apply_xp_ledger_insert()
returns trigger
language plpgsql
as $$
declare
  v_total_xp bigint;
begin
  insert into public.user_progression (user_id, total_xp, level)
  values (new.user_id, greatest(new.xp_delta, 0), public.level_for_xp(greatest(new.xp_delta, 0)))
  on conflict (user_id) do update
    set total_xp = greatest(public.user_progression.total_xp + new.xp_delta, 0),
        level = public.level_for_xp(greatest(public.user_progression.total_xp + new.xp_delta, 0)),
        updated_at = now()
  returning total_xp into v_total_xp;

  update public.user_stats
  set updated_at = now()
  where user_id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_xp_ledger_apply on public.xp_ledger;
create trigger trg_xp_ledger_apply
after insert on public.xp_ledger
for each row execute function public.apply_xp_ledger_insert();

create or replace function public.apply_streak_event_insert()
returns trigger
language plpgsql
as $$
declare
  v_last_date date;
  v_current int;
  v_best int;
begin
  insert into public.user_progression (user_id, total_xp, level, current_streak_days, best_streak_days, last_activity_date)
  values (new.user_id, 0, 1, 1, 1, new.activity_date)
  on conflict (user_id) do nothing;

  select last_activity_date, current_streak_days, best_streak_days
  into v_last_date, v_current, v_best
  from public.user_progression
  where user_id = new.user_id;

  if v_last_date is null then
    v_current := 1;
  elsif new.activity_date = v_last_date then
    v_current := v_current;
  elsif new.activity_date = v_last_date + 1 then
    v_current := v_current + 1;
  elsif new.activity_date > v_last_date + 1 then
    v_current := 1;
  end if;

  v_best := greatest(coalesce(v_best, 0), coalesce(v_current, 0));

  update public.user_progression
  set current_streak_days = coalesce(v_current, 1),
      best_streak_days = coalesce(v_best, 1),
      last_activity_date = greatest(coalesce(v_last_date, new.activity_date), new.activity_date),
      updated_at = now()
  where user_id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_streak_events_apply on public.streak_events;
create trigger trg_streak_events_apply
after insert on public.streak_events
for each row execute function public.apply_streak_event_insert();

-- ============================================================
-- RLS scaffolding
-- ============================================================
alter table public.user_progression enable row level security;
alter table public.xp_ledger enable row level security;
alter table public.streak_events enable row level security;
alter table public.user_achievements enable row level security;
alter table public.user_perks enable row level security;
alter table public.perk_redemptions enable row level security;
alter table public.events enable row level security;
alter table public.event_registrations enable row level security;
alter table public.event_activity_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_progression'
      and policyname = 'user_progression_self_select'
  ) then
    create policy user_progression_self_select
      on public.user_progression
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'xp_ledger'
      and policyname = 'xp_ledger_self_select'
  ) then
    create policy xp_ledger_self_select
      on public.xp_ledger
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'xp_ledger'
      and policyname = 'xp_ledger_self_insert'
  ) then
    create policy xp_ledger_self_insert
      on public.xp_ledger
      for insert
      with check (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'streak_events'
      and policyname = 'streak_events_self_all'
  ) then
    create policy streak_events_self_all
      on public.streak_events
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
    where schemaname = 'public' and tablename = 'user_achievements'
      and policyname = 'user_achievements_self_select'
  ) then
    create policy user_achievements_self_select
      on public.user_achievements
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_perks'
      and policyname = 'user_perks_self_select'
  ) then
    create policy user_perks_self_select
      on public.user_perks
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'perk_redemptions'
      and policyname = 'perk_redemptions_self_select'
  ) then
    create policy perk_redemptions_self_select
      on public.perk_redemptions
      for select
      using (user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'events'
      and policyname = 'events_published_read'
  ) then
    create policy events_published_read
      on public.events
      for select
      using (is_published = true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'event_registrations'
      and policyname = 'event_registrations_self_all'
  ) then
    create policy event_registrations_self_all
      on public.event_registrations
      for all
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end
$$;
