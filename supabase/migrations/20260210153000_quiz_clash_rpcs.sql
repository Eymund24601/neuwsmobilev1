-- Quiz Clash async duel RPCs
-- date: 2026-02-10

create extension if not exists pgcrypto;

create or replace function public.quiz_clash_notify(
  p_user_id uuid,
  p_kind text,
  p_entity_type text,
  p_entity_id uuid,
  p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;

  insert into public.notifications (
    user_id,
    actor_user_id,
    kind,
    entity_type,
    entity_id,
    payload_json,
    is_read,
    created_at
  )
  values (
    p_user_id,
    auth.uid(),
    p_kind,
    p_entity_type,
    p_entity_id,
    coalesce(p_payload, '{}'::jsonb),
    false,
    now()
  );
exception
  when undefined_table then
    -- Keep compatibility with environments missing notifications table.
    return;
end;
$$;

create or replace function public.quiz_clash_pick_category_options(
  p_exclude_category_id uuid default null
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  select array_agg(id)
  into v_ids
  from (
    select c.id
    from public.quiz_clash_categories c
    where c.is_active = true
      and (p_exclude_category_id is null or c.id <> p_exclude_category_id)
    order by random()
    limit 3
  ) picked;

  if coalesce(array_length(v_ids, 1), 0) < 3 then
    select array_agg(id)
    into v_ids
    from (
      select c.id
      from public.quiz_clash_categories c
      where c.is_active = true
      order by random()
      limit 3
    ) fallback_picked;
  end if;

  return coalesce(v_ids, '{}'::uuid[]);
end;
$$;

create or replace function public.quiz_clash_pick_questions(
  p_category_id uuid,
  p_count int default 3
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
begin
  select array_agg(id)
  into v_ids
  from (
    select q.id
    from public.quiz_clash_questions q
    where q.category_id = p_category_id
      and q.is_active = true
    order by random()
    limit greatest(p_count, 1)
  ) picked;

  return coalesce(v_ids, '{}'::uuid[]);
end;
$$;

create or replace function public.quiz_clash_score_answers(
  p_question_ids uuid[],
  p_answers int[]
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_score int := 0;
  v_idx int;
  v_question_id uuid;
  v_correct int;
  v_answer int;
begin
  if coalesce(array_length(p_question_ids, 1), 0) = 0 then
    return 0;
  end if;

  for v_idx in 1..array_length(p_question_ids, 1)
  loop
    v_question_id := p_question_ids[v_idx];
    if v_question_id is null then
      continue;
    end if;

    select correct_option_index
    into v_correct
    from public.quiz_clash_questions
    where id = v_question_id;

    v_answer := null;
    if coalesce(array_length(p_answers, 1), 0) >= v_idx then
      v_answer := p_answers[v_idx];
    end if;

    if v_answer is not null and v_answer = v_correct then
      v_score := v_score + 1;
    end if;
  end loop;

  return v_score;
end;
$$;

create or replace function public.quiz_clash_create_round(
  p_match_id uuid,
  p_round_index int,
  p_picker_user_id uuid,
  p_responder_user_id uuid,
  p_exclude_category_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round_id uuid;
  v_category_option_ids uuid[];
begin
  v_category_option_ids := public.quiz_clash_pick_category_options(
    p_exclude_category_id
  );

  if coalesce(array_length(v_category_option_ids, 1), 0) < 3 then
    raise exception 'Not enough quiz clash categories available';
  end if;

  insert into public.quiz_clash_rounds (
    match_id,
    round_index,
    picker_user_id,
    responder_user_id,
    category_option_ids,
    status,
    created_at,
    updated_at
  )
  values (
    p_match_id,
    p_round_index,
    p_picker_user_id,
    p_responder_user_id,
    v_category_option_ids,
    'awaiting_picker',
    now(),
    now()
  )
  on conflict (match_id, round_index) do update
    set picker_user_id = excluded.picker_user_id,
        responder_user_id = excluded.responder_user_id,
        category_option_ids = excluded.category_option_ids,
        selected_category_id = null,
        question_ids = '{}'::uuid[],
        status = 'awaiting_picker',
        updated_at = now()
  returning id into v_round_id;

  return v_round_id;
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
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  if p_random then
    select p.id
    into v_target_user_id
    from public.profiles p
    where p.id <> v_user_id
    order by random()
    limit 1;
  else
    v_target_user_id := p_opponent_user_id;
  end if;

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

create or replace function public.quiz_clash_respond_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_invite record;
  v_match_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  select *
  into v_invite
  from public.quiz_clash_invites
  where id = p_invite_id
  for update;

  if not found then
    raise exception 'Invite not found';
  end if;

  if v_invite.recipient_user_id <> v_user_id then
    raise exception 'Only invite recipient can respond';
  end if;

  if v_invite.status <> 'pending' then
    if v_invite.status = 'accepted' then
      select id into v_match_id
      from public.quiz_clash_matches
      where invite_id = p_invite_id
      limit 1;
      return v_match_id;
    end if;
    return null;
  end if;

  if v_invite.expires_at < now() then
    update public.quiz_clash_invites
    set status = 'expired',
        responded_at = now()
    where id = p_invite_id;
    return null;
  end if;

  if not p_accept then
    update public.quiz_clash_invites
    set status = 'declined',
        responded_at = now()
    where id = p_invite_id;

    perform public.quiz_clash_notify(
      v_invite.sender_user_id,
      'quiz_clash_invite_declined',
      'quiz_clash_invite',
      p_invite_id,
      jsonb_build_object('invite_id', p_invite_id, 'recipient_user_id', v_user_id)
    );

    return null;
  end if;

  update public.quiz_clash_invites
  set status = 'accepted',
      responded_at = now()
  where id = p_invite_id;

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
    created_at,
    updated_at
  )
  values (
    p_invite_id,
    v_invite.sender_user_id,
    v_invite.recipient_user_id,
    'active',
    6,
    1,
    v_invite.sender_user_id,
    v_invite.sender_user_id,
    now() + interval '48 hours',
    0,
    0,
    now(),
    now()
  )
  on conflict do nothing
  returning id into v_match_id;

  if v_match_id is null then
    select id into v_match_id
    from public.quiz_clash_matches
    where invite_id = p_invite_id
    limit 1;
  end if;

  perform public.quiz_clash_create_round(
    v_match_id,
    1,
    v_invite.sender_user_id,
    v_invite.recipient_user_id,
    null
  );

  perform public.quiz_clash_notify(
    v_invite.sender_user_id,
    'quiz_clash_turn',
    'quiz_clash_match',
    v_match_id,
    jsonb_build_object('match_id', v_match_id, 'message', 'Your turn to pick category')
  );

  perform public.quiz_clash_notify(
    v_invite.recipient_user_id,
    'quiz_clash_match_started',
    'quiz_clash_match',
    v_match_id,
    jsonb_build_object('match_id', v_match_id)
  );

  return v_match_id;
end;
$$;

create or replace function public.quiz_clash_pick_category(
  p_match_id uuid,
  p_round_index int,
  p_selected_category_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_match record;
  v_round record;
  v_question_ids uuid[];
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

  if v_match.status <> 'active' then
    raise exception 'Match is not active';
  end if;

  if v_match.current_round_index <> p_round_index then
    raise exception 'Round index mismatch';
  end if;

  if v_match.current_turn_user_id <> v_user_id then
    raise exception 'Not your turn';
  end if;

  select *
  into v_round
  from public.quiz_clash_rounds
  where match_id = p_match_id
    and round_index = p_round_index
  for update;

  if not found then
    raise exception 'Round not found';
  end if;

  if v_round.picker_user_id <> v_user_id then
    raise exception 'Only round picker can pick category';
  end if;

  if v_round.status <> 'awaiting_picker' then
    raise exception 'Category already selected';
  end if;

  if not (p_selected_category_id = any(v_round.category_option_ids)) then
    raise exception 'Selected category is not in available options';
  end if;

  v_question_ids := public.quiz_clash_pick_questions(p_selected_category_id, 3);
  if coalesce(array_length(v_question_ids, 1), 0) < 3 then
    raise exception 'Not enough active questions for selected category';
  end if;

  update public.quiz_clash_rounds
  set selected_category_id = p_selected_category_id,
      question_ids = v_question_ids,
      status = 'awaiting_picker_answers',
      updated_at = now()
  where id = v_round.id;
end;
$$;

create or replace function public.quiz_clash_submit_picker_answers(
  p_match_id uuid,
  p_round_index int,
  p_answers int[],
  p_answer_durations_ms int[] default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_match record;
  v_round record;
  v_correct_count int;
  v_already_submitted boolean;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  if coalesce(array_length(p_answers, 1), 0) <> 3 then
    raise exception 'Exactly 3 answers required';
  end if;

  select *
  into v_match
  from public.quiz_clash_matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_match.status <> 'active' then
    raise exception 'Match is not active';
  end if;

  if v_match.current_round_index <> p_round_index then
    raise exception 'Round index mismatch';
  end if;

  if v_match.current_turn_user_id <> v_user_id then
    raise exception 'Not your turn';
  end if;

  select *
  into v_round
  from public.quiz_clash_rounds
  where match_id = p_match_id
    and round_index = p_round_index
  for update;

  if not found then
    raise exception 'Round not found';
  end if;

  if v_round.status <> 'awaiting_picker_answers' then
    raise exception 'Round not ready for picker answers';
  end if;

  if v_round.picker_user_id <> v_user_id then
    raise exception 'Only picker can submit this turn';
  end if;

  select exists (
    select 1
    from public.quiz_clash_round_submissions s
    where s.round_id = v_round.id
      and s.user_id = v_user_id
  )
  into v_already_submitted;

  if v_already_submitted then
    raise exception 'Turn already submitted';
  end if;

  v_correct_count := public.quiz_clash_score_answers(v_round.question_ids, p_answers);

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
    v_user_id,
    p_answers,
    coalesce(p_answer_durations_ms, '{}'::int[]),
    v_correct_count,
    now()
  );

  update public.quiz_clash_matches
  set score_player_a = score_player_a + case when player_a_user_id = v_user_id then v_correct_count else 0 end,
      score_player_b = score_player_b + case when player_b_user_id = v_user_id then v_correct_count else 0 end,
      current_turn_user_id = v_round.responder_user_id,
      turn_deadline_at = now() + interval '48 hours',
      updated_at = now()
  where id = p_match_id;

  update public.quiz_clash_rounds
  set status = 'awaiting_responder',
      updated_at = now()
  where id = v_round.id;

  perform public.quiz_clash_notify(
    v_round.responder_user_id,
    'quiz_clash_turn',
    'quiz_clash_match',
    p_match_id,
    jsonb_build_object(
      'match_id', p_match_id,
      'round_index', p_round_index,
      'message', 'Opponent played turn. Now it is your turn.'
    )
  );
end;
$$;

create or replace function public.quiz_clash_submit_responder_turn(
  p_match_id uuid,
  p_round_index int,
  p_answers int[],
  p_answer_durations_ms int[] default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_match record;
  v_round record;
  v_correct_count int;
  v_already_submitted boolean;
  v_next_round int;
  v_next_picker_user_id uuid;
  v_next_responder_user_id uuid;
  v_winner_user_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in required';
  end if;

  if coalesce(array_length(p_answers, 1), 0) <> 3 then
    raise exception 'Exactly 3 answers required';
  end if;

  select *
  into v_match
  from public.quiz_clash_matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_match.status <> 'active' then
    raise exception 'Match is not active';
  end if;

  if v_match.current_round_index <> p_round_index then
    raise exception 'Round index mismatch';
  end if;

  if v_match.current_turn_user_id <> v_user_id then
    raise exception 'Not your turn';
  end if;

  select *
  into v_round
  from public.quiz_clash_rounds
  where match_id = p_match_id
    and round_index = p_round_index
  for update;

  if not found then
    raise exception 'Round not found';
  end if;

  if v_round.status <> 'awaiting_responder' then
    raise exception 'Round not ready for responder answers';
  end if;

  if v_round.responder_user_id <> v_user_id then
    raise exception 'Only responder can submit this turn';
  end if;

  select exists (
    select 1
    from public.quiz_clash_round_submissions s
    where s.round_id = v_round.id
      and s.user_id = v_user_id
  )
  into v_already_submitted;

  if v_already_submitted then
    raise exception 'Turn already submitted';
  end if;

  v_correct_count := public.quiz_clash_score_answers(v_round.question_ids, p_answers);

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
    v_user_id,
    p_answers,
    coalesce(p_answer_durations_ms, '{}'::int[]),
    v_correct_count,
    now()
  );

  update public.quiz_clash_matches
  set score_player_a = score_player_a + case when player_a_user_id = v_user_id then v_correct_count else 0 end,
      score_player_b = score_player_b + case when player_b_user_id = v_user_id then v_correct_count else 0 end,
      updated_at = now()
  where id = p_match_id;

  update public.quiz_clash_rounds
  set status = 'completed',
      updated_at = now()
  where id = v_round.id;

  v_next_round := p_round_index + 1;

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

    return;
  end if;

  v_next_picker_user_id := v_user_id;
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

  perform public.quiz_clash_notify(
    v_next_picker_user_id,
    'quiz_clash_turn',
    'quiz_clash_match',
    p_match_id,
    jsonb_build_object(
      'match_id', p_match_id,
      'round_index', v_next_round,
      'message', 'Opponent played turn. Now it is your turn.'
    )
  );
end;
$$;

create or replace function public.quiz_clash_claim_timeout_forfeit(
  p_match_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_match record;
  v_winner_user_id uuid;
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

  if v_match.status <> 'active' then
    raise exception 'Match is not active';
  end if;

  if v_match.turn_deadline_at is null or now() <= v_match.turn_deadline_at then
    raise exception 'Turn timeout has not expired yet';
  end if;

  v_winner_user_id := case
    when v_match.current_turn_user_id = v_match.player_a_user_id then v_match.player_b_user_id
    else v_match.player_a_user_id
  end;

  update public.quiz_clash_matches
  set status = 'forfeit_timeout',
      winner_user_id = v_winner_user_id,
      forfeit_user_id = v_match.current_turn_user_id,
      current_picker_user_id = null,
      current_turn_user_id = null,
      turn_deadline_at = null,
      updated_at = now()
  where id = p_match_id;

  perform public.quiz_clash_notify(
    v_winner_user_id,
    'quiz_clash_forfeit_win',
    'quiz_clash_match',
    p_match_id,
    jsonb_build_object('match_id', p_match_id)
  );
end;
$$;

grant execute on function public.quiz_clash_send_invite(uuid, boolean) to authenticated;
grant execute on function public.quiz_clash_respond_invite(uuid, boolean) to authenticated;
grant execute on function public.quiz_clash_pick_category(uuid, int, uuid) to authenticated;
grant execute on function public.quiz_clash_submit_picker_answers(uuid, int, int[], int[]) to authenticated;
grant execute on function public.quiz_clash_submit_responder_turn(uuid, int, int[], int[]) to authenticated;
grant execute on function public.quiz_clash_claim_timeout_forfeit(uuid) to authenticated;
