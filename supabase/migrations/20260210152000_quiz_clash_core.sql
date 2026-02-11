-- Quiz Clash async duel core tables + RLS
-- date: 2026-02-10

create extension if not exists pgcrypto;

create table if not exists public.quiz_clash_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_clash_questions (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.quiz_clash_categories(id) on delete cascade,
  prompt text not null,
  option_a text not null,
  option_b text not null,
  option_c text not null,
  option_d text not null,
  correct_option_index int not null check (correct_option_index between 1 and 4),
  explanation text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_clash_invites (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null references public.profiles(id) on delete cascade,
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'expired', 'canceled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  expires_at timestamptz not null default (now() + interval '48 hours'),
  check (sender_user_id <> recipient_user_id)
);

create table if not exists public.quiz_clash_matches (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid references public.quiz_clash_invites(id) on delete set null,
  player_a_user_id uuid not null references public.profiles(id) on delete cascade,
  player_b_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'completed', 'forfeit_timeout', 'canceled')),
  total_rounds int not null default 6 check (total_rounds = 6),
  current_round_index int not null default 1 check (current_round_index between 1 and 6),
  current_picker_user_id uuid references public.profiles(id) on delete set null,
  current_turn_user_id uuid references public.profiles(id) on delete set null,
  turn_deadline_at timestamptz,
  score_player_a int not null default 0,
  score_player_b int not null default 0,
  winner_user_id uuid references public.profiles(id) on delete set null,
  forfeit_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (player_a_user_id <> player_b_user_id)
);

create table if not exists public.quiz_clash_rounds (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.quiz_clash_matches(id) on delete cascade,
  round_index int not null check (round_index between 1 and 6),
  picker_user_id uuid not null references public.profiles(id) on delete cascade,
  responder_user_id uuid not null references public.profiles(id) on delete cascade,
  category_option_ids uuid[] not null default '{}'::uuid[],
  selected_category_id uuid references public.quiz_clash_categories(id) on delete set null,
  question_ids uuid[] not null default '{}'::uuid[],
  status text not null default 'awaiting_picker'
    check (status in ('awaiting_picker', 'awaiting_picker_answers', 'awaiting_responder', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, round_index)
);

create table if not exists public.quiz_clash_round_submissions (
  round_id uuid not null references public.quiz_clash_rounds(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  answers int[] not null,
  duration_ms int[] not null default '{}'::int[],
  correct_count int not null default 0,
  submitted_at timestamptz not null default now(),
  primary key (round_id, user_id)
);

create unique index if not exists idx_quiz_clash_invites_pending_pair
  on public.quiz_clash_invites(sender_user_id, recipient_user_id)
  where status = 'pending';

create index if not exists idx_quiz_clash_invites_recipient_status
  on public.quiz_clash_invites(recipient_user_id, status, created_at desc);

create index if not exists idx_quiz_clash_matches_player_a
  on public.quiz_clash_matches(player_a_user_id, updated_at desc);

create index if not exists idx_quiz_clash_matches_player_b
  on public.quiz_clash_matches(player_b_user_id, updated_at desc);

create index if not exists idx_quiz_clash_rounds_match_round
  on public.quiz_clash_rounds(match_id, round_index);

create index if not exists idx_quiz_clash_questions_category
  on public.quiz_clash_questions(category_id, is_active, created_at desc);

create unique index if not exists idx_quiz_clash_questions_category_prompt
  on public.quiz_clash_questions(category_id, prompt);

drop trigger if exists trg_quiz_clash_matches_updated_at on public.quiz_clash_matches;
create trigger trg_quiz_clash_matches_updated_at
before update on public.quiz_clash_matches
for each row execute function public.set_updated_at();

drop trigger if exists trg_quiz_clash_rounds_updated_at on public.quiz_clash_rounds;
create trigger trg_quiz_clash_rounds_updated_at
before update on public.quiz_clash_rounds
for each row execute function public.set_updated_at();

alter table public.quiz_clash_categories enable row level security;
alter table public.quiz_clash_questions enable row level security;
alter table public.quiz_clash_invites enable row level security;
alter table public.quiz_clash_matches enable row level security;
alter table public.quiz_clash_rounds enable row level security;
alter table public.quiz_clash_round_submissions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_categories'
      and policyname = 'quiz_clash_categories_read'
  ) then
    create policy quiz_clash_categories_read
      on public.quiz_clash_categories
      for select
      using (is_active = true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_questions'
      and policyname = 'quiz_clash_questions_read'
  ) then
    create policy quiz_clash_questions_read
      on public.quiz_clash_questions
      for select
      using (is_active = true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_invites'
      and policyname = 'quiz_clash_invites_participants_select'
  ) then
    create policy quiz_clash_invites_participants_select
      on public.quiz_clash_invites
      for select
      using (sender_user_id = auth.uid() or recipient_user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_invites'
      and policyname = 'quiz_clash_invites_sender_insert'
  ) then
    create policy quiz_clash_invites_sender_insert
      on public.quiz_clash_invites
      for insert
      with check (sender_user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_matches'
      and policyname = 'quiz_clash_matches_participants_select'
  ) then
    create policy quiz_clash_matches_participants_select
      on public.quiz_clash_matches
      for select
      using (player_a_user_id = auth.uid() or player_b_user_id = auth.uid());
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_rounds'
      and policyname = 'quiz_clash_rounds_participants_select'
  ) then
    create policy quiz_clash_rounds_participants_select
      on public.quiz_clash_rounds
      for select
      using (
        exists (
          select 1
          from public.quiz_clash_matches m
          where m.id = quiz_clash_rounds.match_id
            and (m.player_a_user_id = auth.uid() or m.player_b_user_id = auth.uid())
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_round_submissions'
      and policyname = 'quiz_clash_round_submissions_participants_select'
  ) then
    create policy quiz_clash_round_submissions_participants_select
      on public.quiz_clash_round_submissions
      for select
      using (
        exists (
          select 1
          from public.quiz_clash_rounds r
          join public.quiz_clash_matches m on m.id = r.match_id
          where r.id = quiz_clash_round_submissions.round_id
            and (m.player_a_user_id = auth.uid() or m.player_b_user_id = auth.uid())
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'quiz_clash_invites'
  ) then
    alter publication supabase_realtime add table public.quiz_clash_invites;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'quiz_clash_matches'
  ) then
    alter publication supabase_realtime add table public.quiz_clash_matches;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'quiz_clash_rounds'
  ) then
    alter publication supabase_realtime add table public.quiz_clash_rounds;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'quiz_clash_round_submissions'
  ) then
    alter publication supabase_realtime add table public.quiz_clash_round_submissions;
  end if;
end
$$;
