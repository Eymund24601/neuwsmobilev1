-- Quiz legacy compatibility patch
-- Handles older projects where quiz_questions/quiz_attempts used quiz_id
-- instead of quiz_set_id.
-- date: 2026-02-06

create extension if not exists pgcrypto;

create table if not exists public.quiz_sets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  lang text not null,
  title text not null,
  description text,
  topic text,
  image_media_id uuid,
  is_published boolean not null default false,
  created_by_user_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'media_assets'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'quiz_sets_image_media_id_fkey'
  ) then
    alter table public.quiz_sets
      add constraint quiz_sets_image_media_id_fkey
      foreign key (image_media_id) references public.media_assets(id) on delete set null;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'profiles'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'quiz_sets_created_by_user_id_fkey'
  ) then
    alter table public.quiz_sets
      add constraint quiz_sets_created_by_user_id_fkey
      foreign key (created_by_user_id) references public.profiles(id) on delete set null;
  end if;
end
$$;

alter table if exists public.quiz_questions
  add column if not exists position int,
  add column if not exists quiz_set_id uuid;

alter table if exists public.quiz_attempts
  add column if not exists started_at timestamptz not null default now(),
  add column if not exists completed_at timestamptz,
  add column if not exists quiz_set_id uuid;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'quiz_questions'
      and column_name = 'quiz_set_id'
  ) and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'quiz_questions'
      and column_name = 'quiz_id'
      and udt_name = 'uuid'
  ) then
    execute '
      update public.quiz_questions
      set quiz_set_id = quiz_id
      where quiz_set_id is null
    ';
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'quiz_attempts'
      and column_name = 'quiz_set_id'
  ) and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'quiz_attempts'
      and column_name = 'quiz_id'
      and udt_name = 'uuid'
  ) then
    execute '
      update public.quiz_attempts
      set quiz_set_id = quiz_id
      where quiz_set_id is null
    ';
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'quiz_questions'
      and column_name = 'quiz_set_id'
  ) then
    create index if not exists idx_quiz_questions_quiz_position
      on public.quiz_questions(quiz_set_id, position);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'quiz_questions'
      and column_name = 'quiz_id'
  ) then
    create index if not exists idx_quiz_questions_quiz_position_legacy
      on public.quiz_questions(quiz_id, position);
  end if;
end
$$;
