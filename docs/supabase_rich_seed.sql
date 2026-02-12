-- nEUws rich seed for local Supabase dev
-- Idempotent: safe to run repeatedly.
-- Creates: accounts, profiles, articles/localizations/vocab, DMs/follows,
-- saved/reposts/collections, progression/perks, events, quizzes.
-- Default password for seeded accounts: NeuwsTest123!

create extension if not exists pgcrypto;

create or replace function pg_temp.seed_uuid(p_input text)
returns uuid
language sql
immutable
as $$
  select (
    substr(md5(p_input), 1, 8) || '-' ||
    substr(md5(p_input), 9, 4) || '-' ||
    substr(md5(p_input), 13, 4) || '-' ||
    substr(md5(p_input), 17, 4) || '-' ||
    substr(md5(p_input), 21, 12)
  )::uuid;
$$;

create or replace function pg_temp.coerce_enum_payload(
  p_table_schema text,
  p_table_name text,
  p_payload jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_result jsonb := p_payload;
  c record;
  v_raw text;
  v_mapped text;
begin
  for c in
    select
      col.column_name,
      col.udt_schema,
      col.udt_name
    from information_schema.columns col
    where col.table_schema = p_table_schema
      and col.table_name = p_table_name
      and col.data_type = 'USER-DEFINED'
      and exists (
        select 1
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        where n.nspname = col.udt_schema
          and t.typname = col.udt_name
          and t.typtype = 'e'
      )
  loop
    if not (v_result ? c.column_name) then
      continue;
    end if;

    v_raw := v_result ->> c.column_name;
    if v_raw is null or btrim(v_raw) = '' then
      v_result := v_result - c.column_name;
      continue;
    end if;

    select coalesce(
      (
        select e.enumlabel
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        join pg_enum e on e.enumtypid = t.oid
        where n.nspname = c.udt_schema
          and t.typname = c.udt_name
          and e.enumlabel = v_raw
        limit 1
      ),
      (
        select e.enumlabel
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        join pg_enum e on e.enumtypid = t.oid
        where n.nspname = c.udt_schema
          and t.typname = c.udt_name
          and lower(e.enumlabel) = lower(v_raw)
        limit 1
      ),
      (
        select e.enumlabel
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        join pg_enum e on e.enumtypid = t.oid
        where n.nspname = c.udt_schema
          and t.typname = c.udt_name
          and lower(e.enumlabel) = lower(replace(v_raw, ' ', '_'))
        limit 1
      ),
      (
        select e.enumlabel
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        join pg_enum e on e.enumtypid = t.oid
        where n.nspname = c.udt_schema
          and t.typname = c.udt_name
          and lower(e.enumlabel) = lower(replace(v_raw, '-', '_'))
        limit 1
      ),
      (
        select e.enumlabel
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        join pg_enum e on e.enumtypid = t.oid
        where n.nspname = c.udt_schema
          and t.typname = c.udt_name
        order by e.enumsortorder asc
        limit 1
      )
    )
    into v_mapped;

    if v_mapped is null then
      v_result := v_result - c.column_name;
    else
      v_result := jsonb_set(v_result, array[c.column_name], to_jsonb(v_mapped), true);
    end if;
  end loop;

  return v_result;
end;
$$;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'public-media',
  'public-media',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'public_media_read'
  ) then
    create policy public_media_read
      on storage.objects
      for select
      to public
      using (bucket_id = 'public-media');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'public_media_auth_insert'
  ) then
    create policy public_media_auth_insert
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'public-media'
        and split_part(name, '/', 1) = 'users'
        and split_part(name, '/', 2) = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'public_media_auth_update'
  ) then
    create policy public_media_auth_update
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'public-media'
        and split_part(name, '/', 1) = 'users'
        and split_part(name, '/', 2) = auth.uid()::text
      )
      with check (
        bucket_id = 'public-media'
        and split_part(name, '/', 1) = 'users'
        and split_part(name, '/', 2) = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'public_media_auth_delete'
  ) then
    create policy public_media_auth_delete
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'public-media'
        and split_part(name, '/', 1) = 'users'
        and split_part(name, '/', 2) = auth.uid()::text
      );
  end if;
end $$;

create temporary table if not exists _seed_accounts (
  account_key text primary key,
  preferred_id uuid not null,
  email text not null,
  raw_password text not null,
  username text not null,
  display_name text not null,
  city text not null,
  country_code text not null,
  bio text not null,
  nationality_codes text[] not null,
  is_creator boolean not null default false
) on commit drop;

truncate _seed_accounts;

insert into _seed_accounts (
  account_key, preferred_id, email, raw_password, username, display_name,
  city, country_code, bio, nationality_codes, is_creator
)
values
  ('main_tester', '11111111-1111-4111-8111-111111111111', 'alex.tester@neuws.local', 'NeuwsTest123!', 'alextester', 'Alex Tester', 'Berlin', 'DE', 'Testing end-to-end UX, social flows, and content polish.', array['DE', 'SE'], false),
  ('creator_anna', '22222222-2222-4222-8222-222222222222', 'anna.meyer@neuws.local', 'NeuwsTest123!', 'annameyer', 'Anna Meyer', 'Stockholm', 'SE', 'Covering culture and civic life in the Nordics.', array['SE', 'DE'], true),
  ('creator_lukas', '33333333-3333-4333-8333-333333333333', 'lukas.brenner@neuws.local', 'NeuwsTest123!', 'lukasbrenner', 'Lukas Brenner', 'Vienna', 'AT', 'Politics and democratic resilience across Europe.', array['AT', 'DE'], true),
  ('creator_lea', '44444444-4444-4444-8444-444444444444', 'lea.novak@neuws.local', 'NeuwsTest123!', 'leanovak', 'Lea Novak', 'Ljubljana', 'SI', 'Human stories from mobility, rail, and border regions.', array['SI', 'HR'], true),
  ('creator_miguel', '55555555-5555-4555-8555-555555555555', 'miguel.sousa@neuws.local', 'NeuwsTest123!', 'miguelsousa', 'Miguel Sousa', 'Porto', 'PT', 'Urban innovation and startup ecosystems in EU cities.', array['PT', 'ES'], true),
  ('creator_sofia', '66666666-6666-4666-8666-666666666666', 'sofia.rosen@neuws.local', 'NeuwsTest123!', 'sofiarosen', 'Sofia Rosen', 'Copenhagen', 'DK', 'Climate policy and local adaptation stories.', array['DK', 'SE'], true);

create temporary table if not exists _seed_account_runtime (
  account_key text primary key,
  user_id uuid not null
) on commit drop;

truncate _seed_account_runtime;

do $$
declare
  acc record;
  v_user_id uuid;
  v_now timestamptz := now();
  v_profile_payload jsonb;
  v_profile_insert_cols text;
  v_profile_update_set text;
  v_profile_tier text;
  v_profile_tier_udt_schema text;
  v_profile_tier_udt_name text;
  v_profile_tier_data_type text;
  v_settings_payload jsonb;
  v_settings_insert_cols text;
  v_settings_update_set text;
begin
  for acc in select * from _seed_accounts order by account_key loop
    select id
    into v_user_id
    from auth.users
    where lower(email) = lower(acc.email)
    order by created_at asc
    limit 1;

    if v_user_id is null then
      v_user_id := acc.preferred_id;
    end if;

    insert into auth.users (
      id, aud, role, email, encrypted_password, email_confirmed_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at
    )
    values (
      v_user_id, 'authenticated', 'authenticated', lower(acc.email),
      crypt(acc.raw_password, gen_salt('bf')), v_now,
      '', '', '', '',
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', acc.username, 'display_name', acc.display_name),
      false, v_now, v_now
    )
    on conflict (id) do update
      set email = excluded.email,
          encrypted_password = excluded.encrypted_password,
          email_confirmed_at = excluded.email_confirmed_at,
          raw_app_meta_data = excluded.raw_app_meta_data,
          raw_user_meta_data = excluded.raw_user_meta_data,
          updated_at = excluded.updated_at;

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    )
    values (
      pg_temp.seed_uuid('identity:' || v_user_id::text || ':email'),
      v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', lower(acc.email), 'email_verified', true),
      'email',
      v_user_id::text,
      v_now, v_now, v_now
    )
    on conflict do nothing;

    v_profile_tier := case when acc.is_creator then 'creator' else 'premium' end;
    select c.udt_schema, c.udt_name, c.data_type
    into v_profile_tier_udt_schema, v_profile_tier_udt_name, v_profile_tier_data_type
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'profiles'
      and c.column_name = 'subscription_tier';

    if v_profile_tier_data_type = 'USER-DEFINED' then
      select coalesce(
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_profile_tier_udt_schema
            and t.typname = v_profile_tier_udt_name
            and e.enumlabel = v_profile_tier
          limit 1
        ),
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_profile_tier_udt_schema
            and t.typname = v_profile_tier_udt_name
            and e.enumlabel = 'premium'
          limit 1
        ),
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_profile_tier_udt_schema
            and t.typname = v_profile_tier_udt_name
            and e.enumlabel = 'free'
          limit 1
        ),
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_profile_tier_udt_schema
            and t.typname = v_profile_tier_udt_name
          order by e.enumsortorder asc
          limit 1
        )
      )
      into v_profile_tier;
    end if;
    v_profile_tier := coalesce(v_profile_tier, 'premium');

    v_profile_payload := jsonb_build_object(
      'id', v_user_id,
      'email', lower(acc.email),
      'username', acc.username,
      'display_name', acc.display_name,
      'city', acc.city,
      'country_code', acc.country_code,
      'bio', acc.bio,
      'nationality_codes', to_jsonb(acc.nationality_codes),
      'followers_count', 0,
      'following_count', 0,
      'joined_label', 'Joined February 2026',
      'joined_at', v_now,
      'birthdate', '1995-01-01',
      'show_age_public', false,
      'avatar_url', 'assets/images/placeholder-user.jpg',
      'wallpaper_url', 'assets/images/placeholder.jpg',
      'subscription_tier', v_profile_tier,
      'streak_days', 0,
      'points', 0,
      'is_creator', acc.is_creator,
      'created_at', v_now
    );
    v_profile_payload := pg_temp.coerce_enum_payload('public', 'profiles', v_profile_payload);

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_profile_insert_cols
    from jsonb_object_keys(v_profile_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'profiles'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_profile_update_set
    from jsonb_object_keys(v_profile_payload) as payload_keys(key)
    where payload_keys.key <> 'id'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'profiles'
          and c.column_name = payload_keys.key
      );

    if v_profile_insert_cols is not null and v_profile_update_set is not null then
      execute format(
        'insert into public.profiles (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.profiles, $1) ' ||
        'on conflict (id) do update set %2$s',
        v_profile_insert_cols,
        v_profile_update_set
      )
      using v_profile_payload;
    end if;

    insert into _seed_account_runtime (account_key, user_id)
    values (acc.account_key, v_user_id)
    on conflict (account_key) do update set user_id = excluded.user_id;

    v_settings_payload := jsonb_build_object(
      'user_id', v_user_id,
      'ui_lang', 'English',
      'reading_lang_top', 'en',
      'reading_lang_bottom', 'fr',
      'home_topics', to_jsonb(array['Today', 'Politics', 'Culture', 'Tech']),
      'home_sort_mode', 'hybrid',
      'push_notifications_enabled', true
    );
    v_settings_payload := pg_temp.coerce_enum_payload('public', 'user_settings', v_settings_payload);

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_settings_insert_cols
    from jsonb_object_keys(v_settings_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'user_settings'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_settings_update_set
    from jsonb_object_keys(v_settings_payload) as payload_keys(key)
    where payload_keys.key <> 'user_id'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'user_settings'
          and c.column_name = payload_keys.key
      );

    if v_settings_insert_cols is not null and v_settings_update_set is not null then
      execute format(
        'insert into public.user_settings (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.user_settings, $1) ' ||
        'on conflict (user_id) do update set %2$s',
        v_settings_insert_cols,
        v_settings_update_set
      )
      using v_settings_payload;
    end if;

    insert into public.user_stats (
      user_id, follower_count, following_count, published_article_count, draft_article_count, saved_article_count, repost_count
    )
    values (v_user_id, 0, 0, 0, 0, 0, 0)
    on conflict (user_id) do nothing;
  end loop;
end $$;

create temporary table if not exists _seed_target_users (
  user_id uuid primary key
) on commit drop;

truncate _seed_target_users;

insert into _seed_target_users (user_id)
select user_id
from _seed_account_runtime
where account_key = 'main_tester'
on conflict do nothing;

insert into _seed_target_users (user_id)
select u.id
from auth.users u
join public.profiles p on p.id = u.id
where u.id not in (
  select user_id from _seed_account_runtime where account_key like 'creator_%'
)
on conflict do nothing;

create temporary table if not exists _seed_articles (
  slug text primary key,
  title text not null,
  excerpt text not null,
  topic text not null,
  country_code text not null,
  country_tags text[] not null,
  author_key text not null,
  lang_top text not null,
  lang_bottom text not null,
  body_top text not null,
  body_bottom text not null,
  published_days_ago int not null
) on commit drop;

truncate _seed_articles;

insert into _seed_articles (
  slug, title, excerpt, topic, country_code, country_tags,
  author_key, lang_top, lang_bottom, body_top, body_bottom, published_days_ago
)
values
  ('stockholm-social-infrastructure', 'How Stockholm Rebuilt Belonging Through Public Spaces', 'Neighborhood libraries, late-night sports halls, and free cultural rooms are changing social isolation metrics.', 'Culture', 'SE', array['SE', 'DK', 'NO'], 'creator_anna', 'en', 'fr', 'Stockholm expanded access to public micro-spaces where residents can meet after work. The policy was simple: open doors, remove fees, and support local hosts.', 'Stockholm a elargi l''acces a des micro-espaces publics ou les residents peuvent se retrouver apres le travail. La politique etait simple: ouvrir les portes, supprimer les frais et soutenir les animateurs locaux.', 1),
  ('vienna-election-volunteers', 'Why Vienna Is Training Election Volunteers Year-Round', 'Local organizers say resilience comes from routine drills, not crisis-only mobilization.', 'Politics', 'AT', array['AT', 'DE'], 'creator_lukas', 'en', 'de', 'Volunteer coordinators in Vienna now run monthly simulation drills for polling-day disruptions. Organizers report faster response times and lower stress under pressure.', 'Freiwilligen-Teams in Wien fuehren inzwischen monatliche Uebungen fuer Stoerfaelle am Wahltag durch. Die Organisatoren melden schnellere Reaktionen und weniger Stress unter Druck.', 2),
  ('baltic-night-train-journal', 'A Night Train Diary From Riga to Vilnius', 'A cross-border route reveals how language, pricing, and station design shape travel behavior.', 'Lifestyle', 'LV', array['LV', 'LT', 'EE'], 'creator_lea', 'en', 'fr', 'The overnight route from Riga to Vilnius has become a moving forum: students, families, and shift workers all negotiate the same shared corridor.', 'La liaison de nuit entre Riga et Vilnius est devenue un forum mobile: etudiants, familles et travailleurs en horaires decales partagent le meme couloir.', 3),
  ('porto-urban-startup-loop', 'Why Porto Feels Like a Prototype for Mid-Sized EU Cities', 'Compact commutes and dense creator networks are pulling talent outside larger capitals.', 'Tech', 'PT', array['PT', 'ES'], 'creator_miguel', 'en', 'pt', 'In Porto, founders describe a practical loop: walkable neighborhoods, lower burn rates, and easier access to community mentors.', 'No Porto, fundadores descrevem um ciclo pratico: bairros caminhaveis, menores custos operacionais e acesso mais facil a mentores da comunidade.', 4),
  ('copenhagen-climate-blocks', 'Copenhagen''s Block-Level Climate Plans Are Going Hyper-Local', 'Residents now vote on neighborhood adaptation priorities before municipal budgeting rounds.', 'Climate', 'DK', array['DK', 'SE'], 'creator_sofia', 'en', 'de', 'Copenhagen tested district-level adaptation ballots where residents ranked drainage, shade, and school-route protection investments.', 'Kopenhagen testete abstimmungen auf bezirksebene, bei denen bewohner investitionen in entwasserung, schatten und sichere schulwege priorisierten.', 5);

do $$
declare
  a record;
  col record;
  v_author_id uuid;
  v_article_payload jsonb;
  v_article_insert_cols text;
  v_article_update_set text;
  v_required_missing text[];
  v_published_at timestamptz;
  v_enum_default text;
begin
  for a in select * from _seed_articles order by published_days_ago asc loop
    select user_id into v_author_id
    from _seed_account_runtime
    where account_key = a.author_key;

    if v_author_id is null then
      select id into v_author_id
      from public.profiles
      order by created_at asc
      limit 1;
    end if;

    v_published_at := now() - make_interval(days => a.published_days_ago);

    v_article_payload := jsonb_build_object(
      'slug', a.slug,
      'title', a.title,
      'excerpt', a.excerpt,
      'topic', a.topic,
      'country_code', a.country_code,
      'country_tags', to_jsonb(a.country_tags),
      'language_top', a.lang_top,
      'language_bottom', a.lang_bottom,
      'body_top', a.body_top,
      'body_bottom', a.body_bottom,
      'canonical_lang', a.lang_top,
      'is_published', true,
      'published_at', v_published_at,
      'author_id', v_author_id,
      'content', a.body_top,
      'created_at', v_published_at,
      'updated_at', now()
    );
    v_article_payload := pg_temp.coerce_enum_payload('public', 'articles', v_article_payload);

    if v_author_id is null then
      v_article_payload := v_article_payload - 'author_id';
    end if;

    -- If legacy schemas require enum columns without defaults (for example category),
    -- fill them with first enum value so seed stays executable.
    for col in
      select
        c.column_name,
        c.udt_schema,
        c.udt_name
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'articles'
        and c.is_nullable = 'NO'
        and c.column_default is null
        and c.data_type = 'USER-DEFINED'
        and not (v_article_payload ? c.column_name)
        and exists (
          select 1
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          where n.nspname = c.udt_schema
            and t.typname = c.udt_name
            and t.typtype = 'e'
        )
    loop
      select e.enumlabel
      into v_enum_default
      from pg_type t
      join pg_namespace n on n.oid = t.typnamespace
      join pg_enum e on e.enumtypid = t.oid
      where n.nspname = col.udt_schema
        and t.typname = col.udt_name
      order by e.enumsortorder asc
      limit 1;

      if v_enum_default is not null then
        v_article_payload := jsonb_set(
          v_article_payload,
          array[col.column_name],
          to_jsonb(v_enum_default),
          true
        );
      end if;
    end loop;

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'articles'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_article_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping article seed for %: missing required columns %',
        a.slug,
        array_to_string(v_required_missing, ', ');
      continue;
    end if;

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_article_insert_cols
    from jsonb_object_keys(v_article_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'articles'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_article_update_set
    from jsonb_object_keys(v_article_payload) as payload_keys(key)
    where payload_keys.key <> 'slug'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'articles'
          and c.column_name = payload_keys.key
      );

    if v_article_insert_cols is not null and v_article_update_set is not null then
      execute format(
        'insert into public.articles (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.articles, $1) ' ||
        'on conflict (slug) do update set %2$s',
        v_article_insert_cols,
        v_article_update_set
      )
      using v_article_payload;
    end if;
  end loop;
end $$;

create temporary table if not exists _seed_article_ids (
  slug text primary key,
  article_id uuid not null
) on commit drop;

truncate _seed_article_ids;

insert into _seed_article_ids (slug, article_id)
select a.slug, ar.id
from _seed_articles a
join public.articles ar on ar.slug = a.slug;

do $$
declare
  loc record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  if to_regclass('public.article_localizations') is null then
    return;
  end if;

  for loc in
    (
      select
        pg_temp.seed_uuid('loc:' || a.slug || ':top') as id,
        m.article_id,
        a.lang_top as lang,
        a.title,
        a.excerpt,
        a.body_top as body,
        md5(a.slug || ':top') as content_hash,
        1 as version
      from _seed_articles a
      join _seed_article_ids m on m.slug = a.slug
      union all
      select
        pg_temp.seed_uuid('loc:' || a.slug || ':bottom') as id,
        m.article_id,
        a.lang_bottom as lang,
        a.title,
        a.excerpt,
        a.body_bottom as body,
        md5(a.slug || ':bottom') as content_hash,
        1 as version
      from _seed_articles a
      join _seed_article_ids m on m.slug = a.slug
    )
  loop
    v_payload := jsonb_build_object(
      'id', loc.id,
      'article_id', loc.article_id,
      'lang', loc.lang,
      'title', loc.title,
      'excerpt', loc.excerpt,
      'body', loc.body,
      'content_hash', loc.content_hash,
      'version', loc.version
    );
    v_payload := pg_temp.coerce_enum_payload('public', 'article_localizations', v_payload);

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'article_localizations'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping article_localization seed for article %: missing required columns %',
        loc.article_id,
        array_to_string(v_required_missing, ', ');
      continue;
    end if;

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_insert_cols
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'article_localizations'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_update_set
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where payload_keys.key <> 'id'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'article_localizations'
          and c.column_name = payload_keys.key
      );

    if v_insert_cols is not null and v_update_set is not null then
      execute format(
        'insert into public.article_localizations (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.article_localizations, $1) ' ||
        'on conflict (id) do update set %2$s',
        v_insert_cols,
        v_update_set
      )
      using v_payload;
    end if;
  end loop;

  update public.articles ar
  set canonical_localization_id = al.id,
      canonical_lang = coalesce(ar.canonical_lang, al.lang)
  from _seed_articles a
  join _seed_article_ids m on m.slug = a.slug
  join public.article_localizations al
    on al.article_id = m.article_id
   and al.lang = a.lang_top
  where ar.id = m.article_id;
end $$;

do $$
begin
  if to_regclass('public.article_alignments') is null then
    return;
  end if;

  -- Seed with short rolling alignment windows so tap mapping has usable granularity.
  insert into public.article_alignments (
    id, article_id, from_localization_id, to_localization_id,
    alignment_json, algo_version, quality_score
  )
  select
    pg_temp.seed_uuid('align:' || a.slug || ':top-bottom'),
    m.article_id,
    top_loc.id,
    bottom_loc.id,
    jsonb_build_object(
      'version', 1,
      'source_lang', a.lang_top,
      'target_lang', a.lang_bottom,
      'offset_encoding', 'utf16_code_units',
      'units', window_units.units
    ),
    'seed-v1',
    0.9
  from _seed_articles a
  join _seed_article_ids m on m.slug = a.slug
  join public.article_localizations top_loc
    on top_loc.article_id = m.article_id
   and top_loc.lang = a.lang_top
  join public.article_localizations bottom_loc
    on bottom_loc.article_id = m.article_id
   and bottom_loc.lang = a.lang_bottom
  cross join lateral (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'c', jsonb_build_array(w.c_start, w.c_end),
          't', jsonb_build_array(w.t_start, w.t_end),
          'score', 0.86
        )
        order by w.c_start
      ),
      '[]'::jsonb
    ) as units
    from (
      select
        c_start,
        c_end,
        t_start,
        greatest(t_start + 1, t_end_raw) as t_end
      from (
        select
          gs as c_start,
          least(gs + 48, char_length(top_loc.body)) as c_end,
          floor(
            (gs::numeric / greatest(char_length(top_loc.body), 1)) *
            char_length(bottom_loc.body)
          )::int as t_start,
          ceil(
            (least(gs + 48, char_length(top_loc.body))::numeric /
            greatest(char_length(top_loc.body), 1)) *
            char_length(bottom_loc.body)
          )::int as t_end_raw
        from generate_series(
          0,
          greatest(char_length(top_loc.body) - 1, 0),
          48
        ) as gs
      ) raw
      where c_end > c_start
    ) w
  ) as window_units
  on conflict (from_localization_id, to_localization_id) do update
    set alignment_json = excluded.alignment_json,
        algo_version = excluded.algo_version,
        quality_score = excluded.quality_score;
end $$;

create temporary table if not exists _seed_vocab (
  article_slug text not null,
  rank int not null,
  canonical_lemma text not null,
  pos text not null,
  difficulty text not null,
  definition_en text not null,
  primary key (article_slug, rank)
) on commit drop;

truncate _seed_vocab;

insert into _seed_vocab (
  article_slug, rank, canonical_lemma, pos, difficulty, definition_en
)
select
  a.slug,
  g.rank,
  case g.rank when 1 then 'community' when 2 then 'resilience' else 'participation' end,
  'noun',
  case g.rank when 1 then 'A2' when 2 then 'B1' else 'B1' end,
  case g.rank
    when 1 then 'People linked by shared place, interest, or identity.'
    when 2 then 'Capacity to absorb stress and recover quickly.'
    else 'Taking part in a public, civic, or social activity.'
  end
from _seed_articles a
cross join generate_series(1, 3) as g(rank);

do $$
declare
  vocab_seed record;
  form_seed record;
  side_seed record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  if to_regclass('public.vocab_items') is null then
    return;
  end if;

  for vocab_seed in
    select *
    from _seed_vocab
    order by article_slug, rank
  loop
    v_payload := jsonb_build_object(
      'id', pg_temp.seed_uuid('vocab:' || vocab_seed.article_slug || ':' || vocab_seed.rank::text),
      'canonical_lang', 'en',
      'canonical_lemma', vocab_seed.canonical_lemma,
      'pos', vocab_seed.pos,
      'difficulty', vocab_seed.difficulty
    );
    v_payload := pg_temp.coerce_enum_payload('public', 'vocab_items', v_payload);

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'vocab_items'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping vocab_item seed for %/%: missing required columns %',
        vocab_seed.article_slug,
        vocab_seed.rank,
        array_to_string(v_required_missing, ', ');
      continue;
    end if;

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_insert_cols
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'vocab_items'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_update_set
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where payload_keys.key <> 'id'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'vocab_items'
          and c.column_name = payload_keys.key
      );

    if v_insert_cols is not null and v_update_set is not null then
      execute format(
        'insert into public.vocab_items (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.vocab_items, $1) ' ||
        'on conflict (id) do update set %2$s',
        v_insert_cols,
        v_update_set
      )
      using v_payload;
    end if;
  end loop;

  if to_regclass('public.vocab_entries') is not null then
    for vocab_seed in
      select *
      from _seed_vocab
      order by article_slug, rank
    loop
      v_payload := jsonb_build_object(
        'id', pg_temp.seed_uuid('entry:' || vocab_seed.article_slug || ':' || vocab_seed.rank::text || ':en'),
        'vocab_item_id', pg_temp.seed_uuid('vocab:' || vocab_seed.article_slug || ':' || vocab_seed.rank::text),
        'lang', 'en',
        'primary_definition', vocab_seed.definition_en,
        'usage_notes', 'Seeded for local UX testing.',
        'examples', to_jsonb(array['Seed example for ' || vocab_seed.canonical_lemma, 'Another usage in article context']),
        'tags', to_jsonb(array['seed', 'article']),
        'source', 'supabase_rich_seed'
      );
      v_payload := pg_temp.coerce_enum_payload('public', 'vocab_entries', v_payload);

      select array_agg(c.column_name order by c.ordinal_position)
      into v_required_missing
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'vocab_entries'
        and c.is_nullable = 'NO'
        and c.column_default is null
        and coalesce(c.identity_generation, '') = ''
        and not exists (
          select 1
          from jsonb_object_keys(v_payload) as payload_keys(key)
          where payload_keys.key = c.column_name
        );

      if coalesce(array_length(v_required_missing, 1), 0) > 0 then
        raise notice
          'Skipping vocab_entry seed for %/%: missing required columns %',
          vocab_seed.article_slug,
          vocab_seed.rank,
          array_to_string(v_required_missing, ', ');
        continue;
      end if;

      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'vocab_entries'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where payload_keys.key <> 'id'
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'vocab_entries'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        execute format(
          'insert into public.vocab_entries (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.vocab_entries, $1) ' ||
          'on conflict (id) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_payload;
      end if;
    end loop;
  end if;

  if to_regclass('public.vocab_forms') is not null then
    for form_seed in
      select
        sv.article_slug,
        sv.rank,
        sv.canonical_lemma,
        a.lang_top,
        a.lang_bottom
      from _seed_vocab sv
      join _seed_articles a on a.slug = sv.article_slug
      order by sv.article_slug, sv.rank
    loop
      for side_seed in
        select *
        from (
          values
            ('top', form_seed.lang_top, 'Top language surface form'),
            ('bottom', form_seed.lang_bottom, 'Bottom language surface form')
        ) as sides(side_key, lang, notes)
      loop
        v_payload := jsonb_build_object(
          'id', pg_temp.seed_uuid('form:' || form_seed.article_slug || ':' || form_seed.rank::text || ':' || side_seed.side_key),
          'vocab_item_id', pg_temp.seed_uuid('vocab:' || form_seed.article_slug || ':' || form_seed.rank::text),
          'lang', side_seed.lang,
          'lemma', form_seed.canonical_lemma,
          'surface', form_seed.canonical_lemma,
          'notes', side_seed.notes
        );
        v_payload := pg_temp.coerce_enum_payload('public', 'vocab_forms', v_payload);

        select array_agg(c.column_name order by c.ordinal_position)
        into v_required_missing
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'vocab_forms'
          and c.is_nullable = 'NO'
          and c.column_default is null
          and coalesce(c.identity_generation, '') = ''
          and not exists (
            select 1
            from jsonb_object_keys(v_payload) as payload_keys(key)
            where payload_keys.key = c.column_name
          );

        if coalesce(array_length(v_required_missing, 1), 0) > 0 then
          raise notice
            'Skipping vocab_form seed for %/%/%: missing required columns %',
            form_seed.article_slug,
            form_seed.rank,
            side_seed.side_key,
            array_to_string(v_required_missing, ', ');
          continue;
        end if;

        select string_agg(format('%I', payload_keys.key), ', ')
        into v_insert_cols
        from jsonb_object_keys(v_payload) as payload_keys(key)
        where exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'vocab_forms'
            and c.column_name = payload_keys.key
        );

        select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
        into v_update_set
        from jsonb_object_keys(v_payload) as payload_keys(key)
        where payload_keys.key <> 'id'
          and exists (
            select 1
            from information_schema.columns c
            where c.table_schema = 'public'
              and c.table_name = 'vocab_forms'
              and c.column_name = payload_keys.key
          );

        if v_insert_cols is not null and v_update_set is not null then
          execute format(
            'insert into public.vocab_forms (%1$s) ' ||
            'select %1$s from jsonb_populate_record(null::public.vocab_forms, $1) ' ||
            'on conflict (id) do update set %2$s',
            v_insert_cols,
            v_update_set
          )
          using v_payload;
        end if;
      end loop;
    end loop;
  end if;

  if to_regclass('public.article_focus_vocab') is not null then
    insert into public.article_focus_vocab (
      article_id, vocab_item_id, rank
    )
    select
      m.article_id,
      pg_temp.seed_uuid('vocab:' || v.article_slug || ':' || v.rank::text),
      v.rank
    from _seed_vocab v
    join _seed_article_ids m on m.slug = v.article_slug
    on conflict (article_id, vocab_item_id) do update
      set rank = excluded.rank;
  end if;
end $$;

do $$
declare
  m record;
begin
  if to_regprocedure('public.rebuild_article_token_graph(uuid,integer,text)') is null then
    return;
  end if;

  for m in
    select article_id
    from _seed_article_ids
  loop
    perform public.rebuild_article_token_graph(
      m.article_id,
      3,
      'seed:rich_seed'
    );
    if to_regprocedure('public.rebuild_article_token_alignments(uuid,text)') is not null then
      perform public.rebuild_article_token_alignments(
        m.article_id,
        'seed:token_window_v1'
      );
    end if;
  end loop;
end $$;

create temporary table if not exists _seed_pairs (
  target_user_id uuid not null,
  creator_user_id uuid not null,
  thread_id uuid not null,
  primary key (target_user_id, creator_user_id)
) on commit drop;

truncate _seed_pairs;

insert into _seed_pairs (target_user_id, creator_user_id, thread_id)
select
  t.user_id as target_user_id,
  c.user_id as creator_user_id,
  pg_temp.seed_uuid('dm-thread:' || t.user_id::text || ':' || c.user_id::text) as thread_id
from _seed_target_users t
cross join (
  select user_id
  from _seed_account_runtime
  where account_key like 'creator_%'
) c;

insert into public.user_follows (follower_user_id, followed_user_id)
select target_user_id, creator_user_id
from _seed_pairs
on conflict do nothing;

insert into public.user_follows (follower_user_id, followed_user_id)
select creator_user_id, target_user_id
from _seed_pairs
on conflict do nothing;

do $$
declare
  p record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  for p in
    select *
    from _seed_pairs
  loop
    v_payload := jsonb_build_object(
      'id', p.thread_id,
      'created_by_user_id', p.creator_user_id,
      'thread_type', 'dm',
      'last_message_at', now() - interval '3 hours'
    );
    v_payload := pg_temp.coerce_enum_payload('public', 'dm_threads', v_payload);

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'dm_threads'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping dm_thread seed for %: missing required columns %',
        p.thread_id,
        array_to_string(v_required_missing, ', ');
      continue;
    end if;

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_insert_cols
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'dm_threads'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_update_set
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where payload_keys.key <> 'id'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'dm_threads'
          and c.column_name = payload_keys.key
      );

    if v_insert_cols is not null and v_update_set is not null then
      execute format(
        'insert into public.dm_threads (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.dm_threads, $1) ' ||
        'on conflict (id) do update set %2$s',
        v_insert_cols,
        v_update_set
      )
      using v_payload;
    end if;
  end loop;
end $$;

insert into public.dm_thread_participants (
  thread_id, user_id, joined_at, last_read_at
)
select
  p.thread_id,
  p.target_user_id,
  now() - interval '12 days',
  now() - interval '2 days'
from _seed_pairs p
on conflict (thread_id, user_id) do update
  set last_read_at = excluded.last_read_at;

insert into public.dm_thread_participants (
  thread_id, user_id, joined_at, last_read_at
)
select
  p.thread_id,
  p.creator_user_id,
  now() - interval '12 days',
  now() - interval '1 hour'
from _seed_pairs p
on conflict (thread_id, user_id) do update
  set last_read_at = excluded.last_read_at;

insert into public.dm_messages (
  id, thread_id, sender_user_id, body, created_at
)
select
  pg_temp.seed_uuid('dm-msg-1:' || p.thread_id::text),
  p.thread_id,
  p.target_user_id,
  'Hey, I read your latest piece. Would love a quick follow-up.',
  now() - interval '5 hours'
from _seed_pairs p
on conflict (id) do update
  set body = excluded.body,
      created_at = excluded.created_at;

insert into public.dm_messages (
  id, thread_id, sender_user_id, body, created_at
)
select
  pg_temp.seed_uuid('dm-msg-2:' || p.thread_id::text),
  p.thread_id,
  p.creator_user_id,
  'Absolutely. I can share notes and a short context thread tonight.',
  now() - interval '3 hours'
from _seed_pairs p
on conflict (id) do update
  set body = excluded.body,
      created_at = excluded.created_at;

update public.dm_threads t
set last_message_id = m.id,
    last_message_at = m.created_at,
    updated_at = now()
from (
  select
    p.thread_id,
    pg_temp.seed_uuid('dm-msg-2:' || p.thread_id::text) as id,
    now() - interval '3 hours' as created_at
  from _seed_pairs p
) m
where t.id = m.thread_id;

create temporary table if not exists _seed_ranked_articles (
  article_id uuid not null,
  slug text not null,
  rn int not null,
  primary key (article_id)
) on commit drop;

truncate _seed_ranked_articles;

insert into _seed_ranked_articles (article_id, slug, rn)
select
  id,
  slug,
  row_number() over (order by published_at desc nulls last, id desc) as rn
from public.articles
where slug in (select slug from _seed_articles);

insert into public.article_bookmarks (user_id, article_id)
select t.user_id, a.article_id
from _seed_target_users t
join _seed_ranked_articles a on a.rn <= 3
on conflict do nothing;

insert into public.article_reposts (id, user_id, article_id, commentary, created_at)
select
  pg_temp.seed_uuid('repost:' || t.user_id::text || ':' || a.article_id::text),
  t.user_id,
  a.article_id,
  'Worth reading for context and practical takeaways.',
  now() - interval '1 day'
from _seed_target_users t
join _seed_ranked_articles a on a.rn in (2, 4)
on conflict (user_id, article_id) do update
  set commentary = excluded.commentary,
      created_at = excluded.created_at;

insert into public.user_collections (
  id, user_id, name, description, is_public
)
select
  pg_temp.seed_uuid('collection:signals:' || t.user_id::text),
  t.user_id,
  'Europe Signals',
  'Shortlist of policy and culture signals.',
  true
from _seed_target_users t
on conflict (id) do update
  set name = excluded.name,
      description = excluded.description,
      is_public = excluded.is_public;

insert into public.user_collections (
  id, user_id, name, description, is_public
)
select
  pg_temp.seed_uuid('collection:weekend:' || t.user_id::text),
  t.user_id,
  'Weekend Reads',
  'Longer reads for slower review.',
  false
from _seed_target_users t
on conflict (id) do update
  set name = excluded.name,
      description = excluded.description,
      is_public = excluded.is_public;

insert into public.collection_items (
  collection_id, article_id, saved_by_user_id, note, sort_order
)
select
  pg_temp.seed_uuid('collection:signals:' || t.user_id::text),
  a.article_id,
  t.user_id,
  'Signal watchlist',
  a.rn
from _seed_target_users t
join _seed_ranked_articles a on a.rn in (1, 2, 3)
on conflict (collection_id, article_id) do update
  set note = excluded.note,
      sort_order = excluded.sort_order;

insert into public.collection_items (
  collection_id, article_id, saved_by_user_id, note, sort_order
)
select
  pg_temp.seed_uuid('collection:weekend:' || t.user_id::text),
  a.article_id,
  t.user_id,
  'Weekend deep dive',
  a.rn
from _seed_target_users t
join _seed_ranked_articles a on a.rn in (3, 4, 5)
on conflict (collection_id, article_id) do update
  set note = excluded.note,
      sort_order = excluded.sort_order;

do $$
declare
  p record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  if to_regclass('public.perks_catalog') is null then
    return;
  end if;

  for p in
    select *
    from (
      values
        (
          '77777777-7777-4777-8777-777777777771'::uuid,
          'rail_discount_20',
          'Nordic Rail 20% Off',
          'Discount for regional rail routes.',
          'travel',
          0,
          1,
          30,
          '{"code":"NEUWS20"}'::jsonb,
          true
        ),
        (
          '77777777-7777-4777-8777-777777777772'::uuid,
          'coffee_pass_berlin',
          'Berlin Coffee Pass',
          'One week local partner pass.',
          'food',
          0,
          3,
          7,
          '{"code":"EUROBREW"}'::jsonb,
          true
        ),
        (
          '77777777-7777-4777-8777-777777777773'::uuid,
          'event_priority',
          'Event Priority Access',
          'Priority registration slot for selected events.',
          'events',
          0,
          null,
          30,
          '{"code":"EARLYEU"}'::jsonb,
          true
        )
    ) as seeded(id, perk_key, name, description, perk_type, cost_xp, max_uses, duration_days, metadata_json, is_active)
  loop
    v_payload := jsonb_build_object(
      'id', p.id,
      'perk_key', p.perk_key,
      'name', p.name,
      'description', p.description,
      'perk_type', p.perk_type,
      'cost_xp', p.cost_xp,
      'max_uses', p.max_uses,
      'duration_days', p.duration_days,
      'metadata_json', p.metadata_json,
      'is_active', p.is_active
    );
    v_payload := pg_temp.coerce_enum_payload('public', 'perks_catalog', v_payload);

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'perks_catalog'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping perks_catalog seed for %: missing required columns %',
        p.perk_key,
        array_to_string(v_required_missing, ', ');
      continue;
    end if;

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_insert_cols
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'perks_catalog'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_update_set
    from jsonb_object_keys(v_payload) as payload_keys(key)
    where payload_keys.key <> 'id'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'perks_catalog'
          and c.column_name = payload_keys.key
      );

    if v_insert_cols is not null and v_update_set is not null then
      execute format(
        'insert into public.perks_catalog (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.perks_catalog, $1) ' ||
        'on conflict (id) do update set %2$s',
        v_insert_cols,
        v_update_set
      )
      using v_payload;
    end if;
  end loop;
end $$;

do $$
declare
  t record;
  r record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  for t in
    select user_id
    from _seed_target_users
  loop
    for r in
      select *
      from (
        values
          (
            'rail',
            '77777777-7777-4777-8777-777777777771'::uuid,
            1,
            now() - interval '2 days',
            now() + interval '28 days'
          ),
          (
            'coffee',
            '77777777-7777-4777-8777-777777777772'::uuid,
            3,
            now() - interval '1 day',
            now() + interval '6 days'
          )
      ) as s(kind, perk_id, remaining_uses, granted_at, expires_at)
    loop
      v_payload := jsonb_build_object(
        'id', pg_temp.seed_uuid('user-perk:' || t.user_id::text || ':' || r.kind),
        'user_id', t.user_id,
        'perk_id', r.perk_id,
        'source_type', 'seed',
        'status', 'available',
        'remaining_uses', r.remaining_uses,
        'granted_at', r.granted_at,
        'expires_at', r.expires_at
      );
      v_payload := pg_temp.coerce_enum_payload('public', 'user_perks', v_payload);

      select array_agg(c.column_name order by c.ordinal_position)
      into v_required_missing
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'user_perks'
        and c.is_nullable = 'NO'
        and c.column_default is null
        and coalesce(c.identity_generation, '') = ''
        and not exists (
          select 1
          from jsonb_object_keys(v_payload) as payload_keys(key)
          where payload_keys.key = c.column_name
        );

      if coalesce(array_length(v_required_missing, 1), 0) > 0 then
        raise notice
          'Skipping user_perk seed for %/%: missing required columns %',
          t.user_id,
          r.kind,
          array_to_string(v_required_missing, ', ');
        continue;
      end if;

      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'user_perks'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where payload_keys.key <> 'id'
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'user_perks'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        execute format(
          'insert into public.user_perks (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.user_perks, $1) ' ||
          'on conflict (id) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_payload;
      end if;
    end loop;
  end loop;
end $$;

do $$
declare
  x record;
  s record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  if to_regclass('public.xp_ledger') is not null then
    for x in
      select
        t.user_id,
        g.n,
        case when g.n in (1, 2, 5) then 25 when g.n in (3, 4, 6) then 15 else 10 end as xp_delta,
        case when g.n in (1, 2) then 'article_read' when g.n in (3, 4) then 'quiz' when g.n in (5, 6) then 'event' else 'daily_streak' end as source_type,
        now() - make_interval(days => (8 - g.n)) as created_at
      from _seed_target_users t
      cross join generate_series(1, 8) as g(n)
    loop
      v_payload := jsonb_build_object(
        'id', pg_temp.seed_uuid('xp:' || x.user_id::text || ':' || x.n::text),
        'user_id', x.user_id,
        'xp_delta', x.xp_delta,
        'source_type', x.source_type,
        'dedupe_key', 'seed-xp-' || x.n::text,
        'meta_json', jsonb_build_object('seed', true, 'n', x.n),
        'created_at', x.created_at
      );
      v_payload := pg_temp.coerce_enum_payload('public', 'xp_ledger', v_payload);

      select array_agg(c.column_name order by c.ordinal_position)
      into v_required_missing
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'xp_ledger'
        and c.is_nullable = 'NO'
        and c.column_default is null
        and coalesce(c.identity_generation, '') = ''
        and not exists (
          select 1
          from jsonb_object_keys(v_payload) as payload_keys(key)
          where payload_keys.key = c.column_name
        );

      if coalesce(array_length(v_required_missing, 1), 0) > 0 then
        raise notice
          'Skipping xp_ledger seed for %/%: missing required columns %',
          x.user_id,
          x.n,
          array_to_string(v_required_missing, ', ');
        continue;
      end if;

      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'xp_ledger'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where payload_keys.key <> 'id'
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'xp_ledger'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        execute format(
          'insert into public.xp_ledger (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.xp_ledger, $1) ' ||
          'on conflict (id) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_payload;
      end if;
    end loop;
  end if;

  if to_regclass('public.streak_events') is not null then
    for s in
      select
        t.user_id,
        g.n,
        (current_date - (7 - g.n)) as activity_date,
        now() - make_interval(days => (7 - g.n)) as created_at
      from _seed_target_users t
      cross join generate_series(1, 7) as g(n)
    loop
      v_payload := jsonb_build_object(
        'id', pg_temp.seed_uuid('streak:' || s.user_id::text || ':' || s.n::text),
        'user_id', s.user_id,
        'activity_date', s.activity_date,
        'activity_type', 'article_read',
        'source_type', 'seed',
        'created_at', s.created_at
      );
      v_payload := pg_temp.coerce_enum_payload('public', 'streak_events', v_payload);

      select array_agg(c.column_name order by c.ordinal_position)
      into v_required_missing
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'streak_events'
        and c.is_nullable = 'NO'
        and c.column_default is null
        and coalesce(c.identity_generation, '') = ''
        and not exists (
          select 1
          from jsonb_object_keys(v_payload) as payload_keys(key)
          where payload_keys.key = c.column_name
        );

      if coalesce(array_length(v_required_missing, 1), 0) > 0 then
        raise notice
          'Skipping streak_event seed for %/%: missing required columns %',
          s.user_id,
          s.n,
          array_to_string(v_required_missing, ', ');
        continue;
      end if;

      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'streak_events'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where payload_keys.key <> 'id'
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'streak_events'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        delete from public.streak_events
        where user_id = s.user_id
          and activity_date = s.activity_date
          and activity_type = 'article_read';

        execute format(
          'insert into public.streak_events (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.streak_events, $1) ' ||
          'on conflict (id) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_payload;
      end if;
    end loop;
  end if;
end $$;

create temporary table if not exists _seed_events (
  slug text primary key,
  title text not null,
  description text not null,
  topic text not null,
  location_label text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  completion_xp int not null
) on commit drop;

truncate _seed_events;

insert into _seed_events (
  slug, title, description, topic, location_label, start_at, end_at, completion_xp
)
values
  ('seed-event-berlin-civic-night', 'Berlin Civic Night', 'In-person discussion with local organizers and readers.', 'Community', 'Berlin, DE', now() + interval '2 days', now() + interval '2 days 2 hours', 40),
  ('seed-event-stockholm-language-club', 'Stockholm Language Club', 'Reader-led language exchange around this week''s top stories.', 'Learning', 'Stockholm, SE', now() + interval '4 days', now() + interval '4 days 90 minutes', 30),
  ('seed-event-vienna-policy-lab', 'Vienna Policy Lab', 'Workshop on turning long-form stories into civic action plans.', 'Policy', 'Vienna, AT', now() + interval '6 days', now() + interval '6 days 2 hours', 45),
  ('seed-event-porto-city-futures', 'Porto City Futures', 'Urban creators discuss mobility, housing, and startup policy.', 'Tech', 'Porto, PT', now() + interval '8 days', now() + interval '8 days 2 hours', 35);

do $$
declare
  e record;
  v_event_payload jsonb;
  v_event_insert_cols text;
  v_event_update_set text;
  v_required_missing text[];
begin
  for e in
    select *
    from _seed_events
    order by slug
  loop
    v_event_payload := jsonb_build_object(
      'slug', e.slug,
      'title', e.title,
      'description', e.description,
      'topic', e.topic,
      'location_label', e.location_label,
      'location', e.location_label,
      'start_at', e.start_at,
      'start_date', e.start_at,
      'end_at', e.end_at,
      'is_published', true,
      'completion_xp', e.completion_xp
    );
    v_event_payload := pg_temp.coerce_enum_payload('public', 'events', v_event_payload);

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'events'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_event_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping event seed for %: missing required columns %',
        e.slug,
        array_to_string(v_required_missing, ', ');
      continue;
    end if;

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_event_insert_cols
    from jsonb_object_keys(v_event_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'events'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_event_update_set
    from jsonb_object_keys(v_event_payload) as payload_keys(key)
    where payload_keys.key <> 'slug'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'events'
          and c.column_name = payload_keys.key
      );

    if v_event_insert_cols is not null and v_event_update_set is not null then
      execute format(
        'insert into public.events (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.events, $1) ' ||
        'on conflict (slug) do update set %2$s',
        v_event_insert_cols,
        v_event_update_set
      )
      using v_event_payload;
    end if;
  end loop;
end $$;

create temporary table if not exists _seed_event_ids (
  slug text primary key,
  event_id uuid not null
) on commit drop;

truncate _seed_event_ids;

insert into _seed_event_ids (slug, event_id)
select slug, id
from public.events
where slug like 'seed-event-%';

do $$
declare
  t record;
  e record;
  v_payload jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  for t in
    select user_id
    from _seed_target_users
  loop
    for e in
      select event_id
      from _seed_event_ids
      where slug in ('seed-event-berlin-civic-night', 'seed-event-stockholm-language-club')
    loop
      v_payload := jsonb_build_object(
        'event_id', e.event_id,
        'user_id', t.user_id,
        'status', 'registered',
        'registered_at', now() - interval '1 day'
      );
      v_payload := pg_temp.coerce_enum_payload('public', 'event_registrations', v_payload);

      select array_agg(c.column_name order by c.ordinal_position)
      into v_required_missing
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'event_registrations'
        and c.is_nullable = 'NO'
        and c.column_default is null
        and coalesce(c.identity_generation, '') = ''
        and not exists (
          select 1
          from jsonb_object_keys(v_payload) as payload_keys(key)
          where payload_keys.key = c.column_name
        );

      if coalesce(array_length(v_required_missing, 1), 0) > 0 then
        raise notice
          'Skipping event_registration seed for %/%: missing required columns %',
          e.event_id,
          t.user_id,
          array_to_string(v_required_missing, ', ');
        continue;
      end if;

      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'event_registrations'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_payload) as payload_keys(key)
      where payload_keys.key not in ('event_id', 'user_id')
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'event_registrations'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        execute format(
          'insert into public.event_registrations (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.event_registrations, $1) ' ||
          'on conflict (event_id, user_id) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_payload;
      end if;
    end loop;
  end loop;
end $$;

alter table if exists public.quiz_sets
  add column if not exists difficulty text,
  add column if not exists estimated_minutes int,
  add column if not exists estimatedminutes int,
  add column if not exists is_premium boolean not null default false;

create temporary table if not exists _seed_quiz_sets (
  slug text primary key,
  lang text not null,
  title text not null,
  description text not null,
  topic text not null,
  difficulty text not null,
  estimated_minutes int not null,
  is_premium boolean not null
) on commit drop;

truncate _seed_quiz_sets;

insert into _seed_quiz_sets (
  slug, lang, title, description, topic, difficulty, estimated_minutes, is_premium
)
values
  ('seed-quiz-politics-1', 'en', 'EU Institutions Sprint', 'Fast check on institutions and mandates.', 'Politics', 'Easy', 3, false),
  ('seed-quiz-politics-2', 'en', 'Election Integrity Basics', 'Disinformation, volunteers, and safeguards.', 'Politics', 'Medium', 4, false),
  ('seed-quiz-culture-1', 'en', 'Nordic Culture Signals', 'Culture and social infrastructure in the Nordics.', 'Culture', 'Easy', 3, false),
  ('seed-quiz-culture-2', 'en', 'Rail and Border Stories', 'Mobility and cross-border behavior.', 'Culture', 'Medium', 4, false),
  ('seed-quiz-tech-1', 'en', 'City Innovation Pulse', 'Urban policy and startup ecosystems.', 'Tech', 'Medium', 5, false),
  ('seed-quiz-tech-2', 'en', 'Climate Adaptation Tactics', 'Block-level adaptation and funding choices.', 'Tech', 'Hard', 6, true);

do $$
declare
  q record;
  v_quiz_payload jsonb;
  v_quiz_insert_cols text;
  v_quiz_update_set text;
  v_quiz_creator_id uuid;
  v_quiz_difficulty text;
  v_quiz_diff_udt_schema text;
  v_quiz_diff_udt_name text;
  v_quiz_diff_data_type text;
begin
  select user_id
  into v_quiz_creator_id
  from _seed_account_runtime
  where account_key = 'creator_lukas';

  select c.udt_schema, c.udt_name, c.data_type
  into v_quiz_diff_udt_schema, v_quiz_diff_udt_name, v_quiz_diff_data_type
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'quiz_sets'
    and c.column_name = 'difficulty';

  for q in
    select *
    from _seed_quiz_sets
    order by slug
  loop
    v_quiz_difficulty := lower(q.difficulty);

    if v_quiz_diff_data_type = 'USER-DEFINED' then
      select coalesce(
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_quiz_diff_udt_schema
            and t.typname = v_quiz_diff_udt_name
            and lower(e.enumlabel) = lower(v_quiz_difficulty)
          limit 1
        ),
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_quiz_diff_udt_schema
            and t.typname = v_quiz_diff_udt_name
            and lower(e.enumlabel) = 'medium'
          limit 1
        ),
        (
          select e.enumlabel
          from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          join pg_enum e on e.enumtypid = t.oid
          where n.nspname = v_quiz_diff_udt_schema
            and t.typname = v_quiz_diff_udt_name
          order by e.enumsortorder asc
          limit 1
        )
      )
      into v_quiz_difficulty;
    end if;
    v_quiz_difficulty := coalesce(v_quiz_difficulty, lower(q.difficulty), 'medium');

    v_quiz_payload := jsonb_build_object(
      'slug', q.slug,
      'lang', q.lang,
      'title', q.title,
      'description', q.description,
      'topic', q.topic,
      'difficulty', v_quiz_difficulty,
      'estimated_minutes', q.estimated_minutes,
      'estimatedminutes', q.estimated_minutes,
      'is_premium', q.is_premium,
      'is_published', true,
      'created_by_user_id', v_quiz_creator_id
    );
    v_quiz_payload := pg_temp.coerce_enum_payload('public', 'quiz_sets', v_quiz_payload);

    select string_agg(format('%I', payload_keys.key), ', ')
    into v_quiz_insert_cols
    from jsonb_object_keys(v_quiz_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'quiz_sets'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_quiz_update_set
    from jsonb_object_keys(v_quiz_payload) as payload_keys(key)
    where payload_keys.key <> 'slug'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'quiz_sets'
          and c.column_name = payload_keys.key
      );

    if v_quiz_insert_cols is not null and v_quiz_update_set is not null then
      execute format(
        'insert into public.quiz_sets (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.quiz_sets, $1) ' ||
        'on conflict (slug) do update set %2$s',
        v_quiz_insert_cols,
        v_quiz_update_set
      )
      using v_quiz_payload;
    end if;
  end loop;
end $$;

create temporary table if not exists _seed_quiz_ids (
  slug text primary key,
  quiz_set_id uuid not null
) on commit drop;

truncate _seed_quiz_ids;

insert into _seed_quiz_ids (slug, quiz_set_id)
select q.slug, qs.id
from _seed_quiz_sets q
join public.quiz_sets qs on qs.slug = q.slug;

insert into public.quiz_questions (
  id, quiz_set_id, position, prompt
)
select
  pg_temp.seed_uuid('quiz-question:' || qi.slug || ':' || g.n::text),
  qi.quiz_set_id,
  g.n,
  format('%s - checkpoint %s', sq.title, g.n)
from _seed_quiz_ids qi
join _seed_quiz_sets sq on sq.slug = qi.slug
cross join generate_series(1, 3) as g(n)
on conflict (id) do update
  set prompt = excluded.prompt;

insert into public.quiz_options (
  id, question_id, position, option_text, is_correct
)
select
  pg_temp.seed_uuid('quiz-option:' || qq.id::text || ':' || o.pos::text),
  qq.id,
  o.pos,
  case o.pos when 1 then 'Correct answer' when 2 then 'Distractor A' when 3 then 'Distractor B' else 'Distractor C' end,
  (o.pos = 1)
from public.quiz_questions qq
join _seed_quiz_ids qi on qi.quiz_set_id = qq.quiz_set_id
cross join (values (1), (2), (3), (4)) as o(pos)
on conflict (id) do update
  set option_text = excluded.option_text,
      is_correct = excluded.is_correct;

insert into public.quiz_attempts (
  id, quiz_set_id, user_id, score, max_score, duration_ms, started_at, completed_at, created_at
)
select
  pg_temp.seed_uuid('quiz-attempt:' || t.user_id::text || ':' || qi.quiz_set_id::text),
  qi.quiz_set_id,
  t.user_id,
  2,
  3,
  180000,
  now() - interval '2 days',
  now() - interval '2 days' + interval '3 minutes',
  now() - interval '2 days'
from _seed_target_users t
join _seed_quiz_ids qi on qi.slug = 'seed-quiz-politics-1'
on conflict (id) do update
  set score = excluded.score,
      max_score = excluded.max_score,
      duration_ms = excluded.duration_ms,
      completed_at = excluded.completed_at;

update public.user_stats us
set follower_count = s.follower_count,
    following_count = s.following_count,
    saved_article_count = s.saved_article_count,
    repost_count = s.repost_count,
    published_article_count = s.published_article_count,
    updated_at = now()
from (
  select
    p.id as user_id,
    coalesce(followers.cnt, 0) as follower_count,
    coalesce(following.cnt, 0) as following_count,
    coalesce(saved.cnt, 0) as saved_article_count,
    coalesce(reposts.cnt, 0) as repost_count,
    coalesce(pub.cnt, 0) as published_article_count
  from public.profiles p
  left join (
    select followed_user_id as user_id, count(*)::int as cnt
    from public.user_follows
    group by followed_user_id
  ) followers on followers.user_id = p.id
  left join (
    select follower_user_id as user_id, count(*)::int as cnt
    from public.user_follows
    group by follower_user_id
  ) following on following.user_id = p.id
  left join (
    select user_id, count(*)::int as cnt
    from public.article_bookmarks
    group by user_id
  ) saved on saved.user_id = p.id
  left join (
    select user_id, count(*)::int as cnt
    from public.article_reposts
    group by user_id
  ) reposts on reposts.user_id = p.id
  left join (
    select author_id as user_id, count(*)::int as cnt
    from public.articles
    where is_published = true
      and author_id is not null
    group by author_id
  ) pub on pub.user_id = p.id
) s
where us.user_id = s.user_id;

select
  (select count(*) from _seed_account_runtime) as seeded_accounts,
  (select count(*) from public.articles where slug in (select slug from _seed_articles) and is_published = true) as seeded_published_articles,
  (select count(*) from public.dm_threads where id in (select thread_id from _seed_pairs)) as seeded_dm_threads,
  (select count(*) from public.quiz_sets where slug in (select slug from _seed_quiz_sets) and is_published = true) as seeded_quiz_sets,
  (select count(*) from public.events where slug like 'seed-event-%' and is_published = true) as seeded_events;

select
  a.account_key,
  a.email,
  a.raw_password as password,
  r.user_id
from _seed_accounts a
join _seed_account_runtime r using (account_key)
order by a.account_key;

-- Quiz Clash rich seed
do $$
begin
  if to_regclass('public.quiz_clash_categories') is null then
    return;
  end if;

  insert into public.quiz_clash_categories (slug, name, description, is_active)
  values
    ('geography', 'Geography', 'Capitals, countries, and places.', true),
    ('science', 'Science', 'Physics, biology, and chemistry.', true),
    ('space', 'Space', 'Planets, missions, and astronomy.', true),
    ('history', 'History', 'Past events and timelines.', true),
    ('politics', 'Politics', 'Governance and institutions.', true),
    ('economy', 'Economy', 'Markets, trade, and money.', true),
    ('culture', 'Culture', 'Arts, traditions, and society.', true),
    ('literature', 'Literature', 'Books, authors, and classics.', true),
    ('sports', 'Sports', 'Teams, tournaments, and records.', true),
    ('technology', 'Technology', 'Computers, internet, and innovation.', true),
    ('music', 'Music', 'Songs, genres, and artists.', true),
    ('cinema', 'Cinema', 'Films, directors, and awards.', true),
    ('food', 'Food', 'Cuisine and cooking knowledge.', true),
    ('nature', 'Nature', 'Animals, ecosystems, and climate.', true),
    ('health', 'Health', 'Medicine and wellbeing.', true),
    ('language', 'Language', 'Words, grammar, and linguistics.', true),
    ('eu', 'EU', 'European Union institutions and policy.', true),
    ('transport', 'Transport', 'Mobility and infrastructure.', true),
    ('business', 'Business', 'Companies and entrepreneurship.', true),
    ('media', 'Media', 'News, communication, and platforms.', true)
  on conflict (slug) do update
  set name = excluded.name,
      description = excluded.description,
      is_active = excluded.is_active;
end
$$;

do $$
begin
  if to_regclass('public.quiz_clash_bot_profiles') is null then
    return;
  end if;

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
end
$$;

do $$
declare
  c record;
  v_sender_id uuid;
  v_recipient_id uuid;
  v_match_id uuid;
  v_round_id uuid;
  v_category_options uuid[];
  v_selected_category uuid;
  v_question_ids uuid[];
begin
  if to_regclass('public.quiz_clash_questions') is null then
    return;
  end if;

  for c in
    select id, name, slug
    from public.quiz_clash_categories
    where is_active = true
  loop
    if c.slug = 'geography' then
      insert into public.quiz_clash_questions (
        category_id, prompt, option_a, option_b, option_c, option_d, correct_option_index, is_active
      )
      values
        (c.id, 'What is the capital of Canada?', 'Toronto', 'Ottawa', 'Vancouver', 'Montreal', 2, true),
        (c.id, 'Which city is the capital of Portugal?', 'Lisbon', 'Porto', 'Madrid', 'Milan', 1, true),
        (c.id, 'Which country has Prague?', 'Poland', 'Czechia', 'Austria', 'Hungary', 2, true)
      on conflict (category_id, prompt) do update
      set option_a = excluded.option_a,
          option_b = excluded.option_b,
          option_c = excluded.option_c,
          option_d = excluded.option_d,
          correct_option_index = excluded.correct_option_index,
          is_active = excluded.is_active;
    elsif c.slug = 'space' then
      insert into public.quiz_clash_questions (
        category_id, prompt, option_a, option_b, option_c, option_d, correct_option_index, is_active
      )
      values
        (c.id, 'Which planet is called the Red Planet?', 'Venus', 'Mars', 'Jupiter', 'Mercury', 2, true),
        (c.id, 'How many planets are in the solar system?', '7', '8', '9', '10', 2, true),
        (c.id, 'What is Earth''s natural satellite called?', 'Europa', 'Titan', 'The Moon', 'Phobos', 3, true)
      on conflict (category_id, prompt) do update
      set option_a = excluded.option_a,
          option_b = excluded.option_b,
          option_c = excluded.option_c,
          option_d = excluded.option_d,
          correct_option_index = excluded.correct_option_index,
          is_active = excluded.is_active;
    else
      insert into public.quiz_clash_questions (
        category_id, prompt, option_a, option_b, option_c, option_d, correct_option_index, is_active
      )
      values
        (c.id, format('%s starter question 1', c.name), 'Option A', 'Option B', 'Option C', 'Option D', 1, true),
        (c.id, format('%s starter question 2', c.name), 'Option A', 'Option B', 'Option C', 'Option D', 2, true),
        (c.id, format('%s starter question 3', c.name), 'Option A', 'Option B', 'Option C', 'Option D', 3, true)
      on conflict (category_id, prompt) do update
      set option_a = excluded.option_a,
          option_b = excluded.option_b,
          option_c = excluded.option_c,
          option_d = excluded.option_d,
          correct_option_index = excluded.correct_option_index,
          is_active = excluded.is_active;
    end if;
  end loop;

  if to_regclass('public.quiz_clash_matches') is null
     or to_regclass('public.quiz_clash_rounds') is null
     or to_regclass('public.quiz_clash_round_submissions') is null then
    return;
  end if;

  select user_id into v_sender_id
  from _seed_account_runtime
  where account_key = 'creator_lukas';

  select user_id into v_recipient_id
  from _seed_account_runtime
  where account_key = 'main_tester';

  if v_sender_id is null or v_recipient_id is null then
    return;
  end if;

  v_match_id := pg_temp.seed_uuid('quiz-clash-match:lukas:tester');

  insert into public.quiz_clash_matches (
    id,
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
    v_match_id,
    v_sender_id,
    v_recipient_id,
    'active',
    6,
    1,
    v_sender_id,
    v_recipient_id,
    now() + interval '36 hours',
    2,
    0,
    now() - interval '4 hours',
    now() - interval '10 minutes'
  )
  on conflict (id) do update
  set status = excluded.status,
      current_round_index = excluded.current_round_index,
      current_picker_user_id = excluded.current_picker_user_id,
      current_turn_user_id = excluded.current_turn_user_id,
      turn_deadline_at = excluded.turn_deadline_at,
      score_player_a = excluded.score_player_a,
      score_player_b = excluded.score_player_b,
      updated_at = excluded.updated_at;

  select array_agg(id)
  into v_category_options
  from (
    select id
    from public.quiz_clash_categories
    where is_active = true
    order by slug
    limit 3
  ) c;

  v_selected_category := v_category_options[1];

  select array_agg(id)
  into v_question_ids
  from (
    select q.id
    from public.quiz_clash_questions q
    where q.category_id = v_selected_category
      and q.is_active = true
    order by q.prompt
    limit 3
  ) q;

  v_round_id := pg_temp.seed_uuid('quiz-clash-round:lukas:tester:1');

  insert into public.quiz_clash_rounds (
    id,
    match_id,
    round_index,
    picker_user_id,
    responder_user_id,
    category_option_ids,
    selected_category_id,
    question_ids,
    status,
    created_at,
    updated_at
  )
  values (
    v_round_id,
    v_match_id,
    1,
    v_sender_id,
    v_recipient_id,
    v_category_options,
    v_selected_category,
    coalesce(v_question_ids, '{}'::uuid[]),
    'awaiting_responder',
    now() - interval '4 hours',
    now() - interval '15 minutes'
  )
  on conflict (match_id, round_index) do update
  set picker_user_id = excluded.picker_user_id,
      responder_user_id = excluded.responder_user_id,
      category_option_ids = excluded.category_option_ids,
      selected_category_id = excluded.selected_category_id,
      question_ids = excluded.question_ids,
      status = excluded.status,
      updated_at = excluded.updated_at;

  insert into public.quiz_clash_round_submissions (
    round_id,
    user_id,
    answers,
    duration_ms,
    correct_count,
    submitted_at
  )
  values (
    v_round_id,
    v_sender_id,
    array[2, 1, 2],
    array[9000, 12000, 11000],
    2,
    now() - interval '3 hours 50 minutes'
  )
  on conflict (round_id, user_id) do update
  set answers = excluded.answers,
      duration_ms = excluded.duration_ms,
      correct_count = excluded.correct_count,
      submitted_at = excluded.submitted_at;
end
$$;
