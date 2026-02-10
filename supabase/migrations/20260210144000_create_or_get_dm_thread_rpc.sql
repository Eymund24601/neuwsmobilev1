-- RPC for opening a direct-message thread with another user.
-- Reuses existing thread when present; otherwise creates one.

create or replace function public.create_or_get_dm_thread(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_thread_id uuid;
begin
  if v_me is null then
    raise exception 'Authentication required';
  end if;

  if p_other_user_id is null or p_other_user_id = v_me then
    raise exception 'Invalid participant';
  end if;

  if not exists (select 1 from public.profiles where id = p_other_user_id) then
    raise exception 'Target user not found';
  end if;

  select p1.thread_id
  into v_thread_id
  from public.dm_thread_participants p1
  join public.dm_thread_participants p2
    on p2.thread_id = p1.thread_id
  where p1.user_id = v_me
    and p2.user_id = p_other_user_id
  order by p1.joined_at desc
  limit 1;

  if v_thread_id is not null then
    return v_thread_id;
  end if;

  insert into public.dm_threads (
    created_by_user_id,
    thread_type,
    created_at,
    updated_at
  )
  values (v_me, 'dm', now(), now())
  returning id into v_thread_id;

  insert into public.dm_thread_participants (
    thread_id,
    user_id,
    joined_at,
    last_read_at
  )
  values
    (v_thread_id, v_me, now(), now()),
    (v_thread_id, p_other_user_id, now(), null)
  on conflict (thread_id, user_id) do nothing;

  return v_thread_id;
end;
$$;

revoke all on function public.create_or_get_dm_thread(uuid) from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.create_or_get_dm_thread(uuid) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.create_or_get_dm_thread(uuid) to authenticated;
  end if;
end
$$;
