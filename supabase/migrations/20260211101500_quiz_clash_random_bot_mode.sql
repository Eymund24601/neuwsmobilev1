-- Quiz Clash random opponent -> bot mode (development)
-- date: 2026-02-11

create extension if not exists pgcrypto;

create table if not exists public.quiz_clash_bot_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.quiz_clash_bot_profiles enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'quiz_clash_bot_profiles'
      and policyname = 'quiz_clash_bot_profiles_select_authenticated'
  ) then
    create policy quiz_clash_bot_profiles_select_authenticated
      on public.quiz_clash_bot_profiles
      for select
      using (auth.role() = 'authenticated');
  end if;
end
$$;

alter table public.quiz_clash_matches
  add column if not exists is_bot_match boolean not null default false;

create index if not exists idx_quiz_clash_matches_bot_active
  on public.quiz_clash_matches(is_bot_match, updated_at desc)
  where status = 'active';

insert into public.quiz_clash_bot_profiles (user_id, is_active)
select p.id, true
from public.profiles p
where p.id in (
  '22222222-2222-4222-8222-222222222222'::uuid,
  '33333333-3333-4333-8333-333333333333'::uuid,
  '44444444-4444-4444-8444-444444444444'::uuid,
  '55555555-5555-4555-8555-555555555555'::uuid,
  '66666666-6666-4666-8666-666666666666'::uuid
)
on conflict (user_id) do update
set is_active = excluded.is_active;

create or replace function public.quiz_clash_pick_bot_user(
  p_requester_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bot_user_id uuid;
begin
  select bp.user_id
  into v_bot_user_id
  from public.quiz_clash_bot_profiles bp
  where bp.is_active = true
    and bp.user_id <> p_requester_user_id
  order by random()
  limit 1;

  if v_bot_user_id is not null then
    return v_bot_user_id;
  end if;

  select p.id
  into v_bot_user_id
  from public.profiles p
  where p.id <> p_requester_user_id
    and coalesce(lower(p.username), '') in (
      'annameyer',
      'lukasbrenner',
      'leanovak',
      'miguelsousa',
      'sofiarosen'
    )
  order by random()
  limit 1;

  return v_bot_user_id;
end;
$$;

create or replace function public.quiz_clash_generate_bot_answers(
  p_question_ids uuid[]
)
returns int[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_answers int[] := '{}'::int[];
  v_idx int;
  v_correct int;
  v_choice int;
begin
  if coalesce(array_length(p_question_ids, 1), 0) = 0 then
    return array[1, 1, 1];
  end if;

  for v_idx in 1..array_length(p_question_ids, 1)
  loop
    select q.correct_option_index
    into v_correct
    from public.quiz_clash_questions q
    where q.id = p_question_ids[v_idx];

    if v_correct is null then
      v_choice := floor(random() * 4)::int + 1;
    elsif random() < 0.68 then
      v_choice := v_correct;
    else
      v_choice := floor(random() * 4)::int + 1;
      if v_choice = v_correct then
        v_choice := (v_choice % 4) + 1;
      end if;
    end if;

    v_answers := array_append(v_answers, greatest(least(v_choice, 4), 1));
  end loop;

  while array_length(v_answers, 1) < 3
  loop
    v_answers := array_append(v_answers, floor(random() * 4)::int + 1);
  end loop;

  return v_answers;
end;
$$;

create or replace function public.quiz_clash_generate_bot_durations(
  p_count int default 3
)
returns int[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result int[] := '{}'::int[];
  v_idx int;
begin
  for v_idx in 1..greatest(p_count, 1)
  loop
    v_result := array_append(v_result, 2500 + floor(random() * 9500)::int);
  end loop;
  return v_result;
end;
$$;

create or replace function public.quiz_clash_send_invite(
  p_opponent_user_id uuid default null,
  p_random boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_target_user_id uuid;
  v_existing_invite_id uuid;
  v_existing_match_id uuid;
  v_invite_id uuid;
  v_match_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  if p_random then
    v_target_user_id := public.quiz_clash_pick_bot_user(v_user_id);
    if v_target_user_id is null then
      raise exception 'No bot opponent available';
    end if;

    select m.id
    into v_existing_match_id
    from public.quiz_clash_matches m
    where m.status = 'active'
      and coalesce(m.is_bot_match, false) = true
      and (
        (m.player_a_user_id = v_user_id and m.player_b_user_id = v_target_user_id)
        or (m.player_a_user_id = v_target_user_id and m.player_b_user_id = v_user_id)
      )
    order by m.updated_at desc
    limit 1;

    if v_existing_match_id is not null then
      return v_existing_match_id;
    end if;

    insert into public.quiz_clash_invites (
      sender_user_id,
      recipient_user_id,
      status,
      created_at,
      responded_at,
      expires_at
    )
    values (
      v_user_id,
      v_target_user_id,
      'accepted',
      now(),
      now(),
      now() + interval '48 hours'
    )
    returning id into v_invite_id;

    insert into public.quiz_clash_matches (
      invite_id,
      player_a_user_id,
      player_b_user_id,
      status,
      total_rounds,
      current_round_index,
      current_picker_user_id,
      current_turn_user_id,
      turn_deadline_at,
      score_player_a,
      score_player_b,
      is_bot_match,
      created_at,
      updated_at
    )
    values (
      v_invite_id,
      v_user_id,
      v_target_user_id,
      'active',
      6,
      1,
      v_user_id,
      v_user_id,
      now() + interval '48 hours',
      0,
      0,
      true,
      now(),
      now()
    )
    returning id into v_match_id;

    perform public.quiz_clash_create_round(
      v_match_id,
      1,
      v_user_id,
      v_target_user_id,
      null
    );

    return v_match_id;
  end if;

  v_target_user_id := p_opponent_user_id;

  if v_target_user_id is null then
    raise exception 'No opponent found';
  end if;

  if v_target_user_id = v_user_id then
    raise exception 'Cannot invite yourself';
  end if;

  select m.id
  into v_existing_match_id
  from public.quiz_clash_matches m
  where m.status = 'active'
    and (
      (m.player_a_user_id = v_user_id and m.player_b_user_id = v_target_user_id)
      or (m.player_a_user_id = v_target_user_id and m.player_b_user_id = v_user_id)
    )
  order by m.updated_at desc
  limit 1;

  if v_existing_match_id is not null then
    return v_existing_match_id;
  end if;

  select i.id
  into v_existing_invite_id
  from public.quiz_clash_invites i
  where i.status = 'pending'
    and (
      (i.sender_user_id = v_user_id and i.recipient_user_id = v_target_user_id)
      or (i.sender_user_id = v_target_user_id and i.recipient_user_id = v_user_id)
    )
  order by i.created_at desc
  limit 1;

  if v_existing_invite_id is not null then
    return v_existing_invite_id;
  end if;

  insert into public.quiz_clash_invites (
    sender_user_id,
    recipient_user_id,
    status,
    created_at,
    expires_at
  )
  values (
    v_user_id,
    v_target_user_id,
    'pending',
    now(),
    now() + interval '48 hours'
  )
  returning id into v_invite_id;

  perform public.quiz_clash_notify(
    v_target_user_id,
    'quiz_clash_invite',
    'quiz_clash_invite',
    v_invite_id,
    jsonb_build_object('invite_id', v_invite_id, 'sender_user_id', v_user_id)
  );

  return v_invite_id;
end;
$$;

create or replace function public.quiz_clash_advance_bot_turn(
  p_match_id uuid,
  p_force boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_human_user_id uuid;
  v_bot_user_id uuid;
  v_match record;
  v_round record;
  v_answers int[];
  v_durations int[];
  v_correct_count int;
  v_next_round int;
  v_next_picker_user_id uuid;
  v_next_responder_user_id uuid;
  v_winner_user_id uuid;
  v_already_submitted boolean;
  v_changed boolean := false;
  v_guard int := 0;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  select *
  into v_match
  from public.quiz_clash_matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if not (v_match.player_a_user_id = v_user_id or v_match.player_b_user_id = v_user_id) then
    raise exception 'You are not a participant in this match';
  end if;

  if v_match.status <> 'active' or coalesce(v_match.is_bot_match, false) = false then
    return false;
  end if;

  v_human_user_id := v_user_id;
  v_bot_user_id := case
    when v_match.player_a_user_id = v_human_user_id then v_match.player_b_user_id
    else v_match.player_a_user_id
  end;

  if v_match.current_turn_user_id is null or v_match.current_turn_user_id <> v_bot_user_id then
    return false;
  end if;

  if not p_force and v_match.updated_at > now() - interval '4 seconds' then
    return false;
  end if;

  while v_guard < 6
  loop
    v_guard := v_guard + 1;

    select *
    into v_round
    from public.quiz_clash_rounds
    where match_id = p_match_id
      and round_index = v_match.current_round_index
    for update;

    if not found then
      exit;
    end if;

    if v_round.status = 'awaiting_picker' and v_round.picker_user_id = v_bot_user_id then
      update public.quiz_clash_rounds
      set selected_category_id = v_round.category_option_ids[1],
          question_ids = public.quiz_clash_pick_questions(v_round.category_option_ids[1], 3),
          status = 'awaiting_picker_answers',
          updated_at = now()
      where id = v_round.id;

      v_changed := true;

      select *
      into v_match
      from public.quiz_clash_matches
      where id = p_match_id
      for update;

      if v_match.current_turn_user_id <> v_bot_user_id then
        exit;
      end if;
      continue;
    end if;

    if v_round.status = 'awaiting_picker_answers' and v_round.picker_user_id = v_bot_user_id then
      select exists (
        select 1
        from public.quiz_clash_round_submissions s
        where s.round_id = v_round.id
          and s.user_id = v_bot_user_id
      )
      into v_already_submitted;

      if not v_already_submitted then
        v_answers := public.quiz_clash_generate_bot_answers(v_round.question_ids);
        v_durations := public.quiz_clash_generate_bot_durations(3);
        v_correct_count := public.quiz_clash_score_answers(v_round.question_ids, v_answers);

        insert into public.quiz_clash_round_submissions (
          round_id,
          user_id,
          answers,
          duration_ms,
          correct_count,
          submitted_at
        )
        values (
          v_round.id,
          v_bot_user_id,
          v_answers,
          v_durations,
          v_correct_count,
          now()
        );

        update public.quiz_clash_matches
        set score_player_a = score_player_a + case when player_a_user_id = v_bot_user_id then v_correct_count else 0 end,
            score_player_b = score_player_b + case when player_b_user_id = v_bot_user_id then v_correct_count else 0 end,
            current_turn_user_id = v_round.responder_user_id,
            turn_deadline_at = now() + interval '48 hours',
            updated_at = now()
        where id = p_match_id;

        update public.quiz_clash_rounds
        set status = 'awaiting_responder',
            updated_at = now()
        where id = v_round.id;

        v_changed := true;
      end if;

      select *
      into v_match
      from public.quiz_clash_matches
      where id = p_match_id
      for update;

      if v_match.current_turn_user_id <> v_bot_user_id then
        exit;
      end if;
      continue;
    end if;

    if v_round.status = 'awaiting_responder' and v_round.responder_user_id = v_bot_user_id then
      select exists (
        select 1
        from public.quiz_clash_round_submissions s
        where s.round_id = v_round.id
          and s.user_id = v_bot_user_id
      )
      into v_already_submitted;

      if not v_already_submitted then
        v_answers := public.quiz_clash_generate_bot_answers(v_round.question_ids);
        v_durations := public.quiz_clash_generate_bot_durations(3);
        v_correct_count := public.quiz_clash_score_answers(v_round.question_ids, v_answers);

        insert into public.quiz_clash_round_submissions (
          round_id,
          user_id,
          answers,
          duration_ms,
          correct_count,
          submitted_at
        )
        values (
          v_round.id,
          v_bot_user_id,
          v_answers,
          v_durations,
          v_correct_count,
          now()
        );

        update public.quiz_clash_matches
        set score_player_a = score_player_a + case when player_a_user_id = v_bot_user_id then v_correct_count else 0 end,
            score_player_b = score_player_b + case when player_b_user_id = v_bot_user_id then v_correct_count else 0 end,
            updated_at = now()
        where id = p_match_id;
      end if;

      update public.quiz_clash_rounds
      set status = 'completed',
          updated_at = now()
      where id = v_round.id;

      v_next_round := v_round.round_index + 1;

      if v_next_round > v_match.total_rounds then
        select
          case
            when m.score_player_a > m.score_player_b then m.player_a_user_id
            when m.score_player_b > m.score_player_a then m.player_b_user_id
            else null
          end
        into v_winner_user_id
        from public.quiz_clash_matches m
        where m.id = p_match_id;

        update public.quiz_clash_matches
        set status = 'completed',
            current_round_index = v_match.total_rounds,
            current_picker_user_id = null,
            current_turn_user_id = null,
            turn_deadline_at = null,
            winner_user_id = v_winner_user_id,
            updated_at = now()
        where id = p_match_id;

        perform public.quiz_clash_notify(
          v_match.player_a_user_id,
          'quiz_clash_completed',
          'quiz_clash_match',
          p_match_id,
          jsonb_build_object('match_id', p_match_id)
        );

        perform public.quiz_clash_notify(
          v_match.player_b_user_id,
          'quiz_clash_completed',
          'quiz_clash_match',
          p_match_id,
          jsonb_build_object('match_id', p_match_id)
        );

        v_changed := true;
        exit;
      end if;

      v_next_picker_user_id := v_bot_user_id;
      v_next_responder_user_id := case
        when v_match.player_a_user_id = v_next_picker_user_id then v_match.player_b_user_id
        else v_match.player_a_user_id
      end;

      update public.quiz_clash_matches
      set current_round_index = v_next_round,
          current_picker_user_id = v_next_picker_user_id,
          current_turn_user_id = v_next_picker_user_id,
          turn_deadline_at = now() + interval '48 hours',
          updated_at = now()
      where id = p_match_id;

      perform public.quiz_clash_create_round(
        p_match_id,
        v_next_round,
        v_next_picker_user_id,
        v_next_responder_user_id,
        v_round.selected_category_id
      );

      v_changed := true;

      select *
      into v_match
      from public.quiz_clash_matches
      where id = p_match_id
      for update;

      if v_match.current_turn_user_id <> v_bot_user_id then
        exit;
      end if;
      continue;
    end if;

    exit;
  end loop;

  if v_changed then
    select *
    into v_match
    from public.quiz_clash_matches
    where id = p_match_id;

    if v_match.status = 'active' and v_match.current_turn_user_id = v_human_user_id then
      perform public.quiz_clash_notify(
        v_human_user_id,
        'quiz_clash_turn',
        'quiz_clash_match',
        p_match_id,
        jsonb_build_object(
          'match_id', p_match_id,
          'round_index', v_match.current_round_index,
          'message', 'Opponent played turn. Now it is your turn.'
        )
      );
    end if;
  end if;

  return v_changed;
end;
$$;

create or replace function public.quiz_clash_progress_bot_matches()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_match_id uuid;
  v_count int := 0;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  for v_match_id in
    select m.id
    from public.quiz_clash_matches m
    where m.status = 'active'
      and coalesce(m.is_bot_match, false) = true
      and (m.player_a_user_id = v_user_id or m.player_b_user_id = v_user_id)
      and m.current_turn_user_id is not null
      and m.current_turn_user_id <> v_user_id
    order by m.updated_at asc
    limit 10
  loop
    if public.quiz_clash_advance_bot_turn(v_match_id, false) then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.quiz_clash_send_invite(uuid, boolean) to authenticated;
grant execute on function public.quiz_clash_pick_bot_user(uuid) to authenticated;
grant execute on function public.quiz_clash_advance_bot_turn(uuid, boolean) to authenticated;
grant execute on function public.quiz_clash_progress_bot_matches() to authenticated;
