-- Progression/events legacy bootstrap compatibility
-- Use before 20260206174000_progression_rewards_events.sql on projects
-- that may already have older table shapes.
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

alter table if exists public.progression_levels
  add column if not exists xp_required bigint,
  add column if not exists title text,
  add column if not exists created_at timestamptz not null default now();

alter table if exists public.user_progression
  add column if not exists total_xp bigint not null default 0,
  add column if not exists level int not null default 1,
  add column if not exists current_streak_days int not null default 0,
  add column if not exists best_streak_days int not null default 0,
  add column if not exists last_activity_date date,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.xp_ledger
  add column if not exists xp_delta int,
  add column if not exists source_type text,
  add column if not exists source_id uuid,
  add column if not exists dedupe_key text,
  add column if not exists meta_json jsonb,
  add column if not exists created_at timestamptz not null default now();

alter table if exists public.streak_events
  add column if not exists activity_date date,
  add column if not exists activity_type text,
  add column if not exists source_type text,
  add column if not exists source_id uuid,
  add column if not exists created_at timestamptz not null default now();

alter table if exists public.achievements
  add column if not exists achievement_key text,
  add column if not exists name text,
  add column if not exists description text,
  add column if not exists category text,
  add column if not exists condition_json jsonb,
  add column if not exists xp_reward int not null default 0,
  add column if not exists is_hidden boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

alter table if exists public.user_achievements
  add column if not exists progress_value numeric not null default 0,
  add column if not exists achieved_at timestamptz,
  add column if not exists claimed_at timestamptz,
  add column if not exists claim_status text not null default 'locked',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.perks_catalog
  add column if not exists perk_key text,
  add column if not exists name text,
  add column if not exists description text,
  add column if not exists perk_type text,
  add column if not exists cost_xp int not null default 0,
  add column if not exists max_uses int,
  add column if not exists duration_days int,
  add column if not exists metadata_json jsonb,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default now();

alter table if exists public.user_perks
  add column if not exists source_type text,
  add column if not exists source_id uuid,
  add column if not exists status text not null default 'available',
  add column if not exists remaining_uses int,
  add column if not exists granted_at timestamptz not null default now(),
  add column if not exists expires_at timestamptz,
  add column if not exists consumed_at timestamptz;

alter table if exists public.perk_redemptions
  add column if not exists context_type text,
  add column if not exists context_id uuid,
  add column if not exists redeemed_at timestamptz not null default now(),
  add column if not exists meta_json jsonb;

alter table if exists public.events
  add column if not exists slug text,
  add column if not exists topic text,
  add column if not exists location_label text,
  add column if not exists start_at timestamptz default now(),
  add column if not exists end_at timestamptz,
  add column if not exists is_published boolean not null default false,
  add column if not exists completion_xp int not null default 0,
  add column if not exists completion_perk_id uuid,
  add column if not exists created_by_user_id uuid,
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.event_registrations
  add column if not exists status text not null default 'registered',
  add column if not exists registered_at timestamptz not null default now(),
  add column if not exists checked_in_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists xp_awarded int not null default 0,
  add column if not exists granted_user_perk_id uuid;

alter table if exists public.event_activity_events
  add column if not exists event_type text,
  add column if not exists occurred_at timestamptz not null default now(),
  add column if not exists meta_json jsonb;

