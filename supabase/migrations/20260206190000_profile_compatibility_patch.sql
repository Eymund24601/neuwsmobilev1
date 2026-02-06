-- Compatibility patch for existing Supabase projects where profiles/events
-- may not yet have all columns referenced by current app repositories.
-- date: 2026-02-06

alter table if exists public.profiles
  add column if not exists display_name text,
  add column if not exists username text,
  add column if not exists city text,
  add column if not exists country_code text,
  add column if not exists bio text,
  add column if not exists nationality_codes text[] default '{}',
  add column if not exists followers_count int not null default 0,
  add column if not exists following_count int not null default 0,
  add column if not exists joined_label text,
  add column if not exists joined_at timestamptz,
  add column if not exists birthdate date,
  add column if not exists show_age_public boolean not null default false,
  add column if not exists avatar_url text,
  add column if not exists wallpaper_url text,
  add column if not exists subscription_tier text not null default 'free',
  add column if not exists streak_days int not null default 0,
  add column if not exists points int not null default 0,
  add column if not exists is_creator boolean not null default false,
  add column if not exists reading_language text,
  add column if not exists notifications_enabled boolean not null default true,
  add column if not exists offline_mode_enabled boolean not null default false;

create unique index if not exists idx_profiles_username_unique
  on public.profiles(username)
  where username is not null;

-- Optional compatibility if old events table exists but new columns are missing.
alter table if exists public.events
  add column if not exists slug text,
  add column if not exists topic text,
  add column if not exists location_label text,
  add column if not exists start_at timestamptz,
  add column if not exists end_at timestamptz,
  add column if not exists is_published boolean default true,
  add column if not exists completion_xp int not null default 0,
  add column if not exists created_by_user_id uuid,
  add column if not exists updated_at timestamptz default now();
