-- Allow users to mark their own DM participant rows as read/muted/archived.
-- Additive compatibility migration.

alter table if exists public.dm_thread_participants
  enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'dm_thread_participants'
      and policyname = 'dm_participants_self_update'
  ) then
    create policy dm_participants_self_update
      on public.dm_thread_participants
      for update
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end
$$;
