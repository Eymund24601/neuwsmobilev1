-- Ensure DM tables are part of Supabase realtime publication.
-- Additive and idempotent.

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'dm_messages'
    ) then
      alter publication supabase_realtime add table public.dm_messages;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'dm_thread_participants'
    ) then
      alter publication supabase_realtime add table public.dm_thread_participants;
    end if;
  end if;
end
$$;
