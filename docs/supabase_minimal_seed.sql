-- nEUws minimal seed for local Supabase dev
-- Safe to run repeatedly; uses idempotent inserts/updates where possible.

do $$
declare
  v_article_id uuid;
  v_author_id uuid;
  v_has_author_id boolean;
  v_article_payload jsonb := '{}'::jsonb;
  v_quiz_payload jsonb := '{}'::jsonb;
  v_event_payload jsonb := '{}'::jsonb;
  v_insert_cols text;
  v_update_set text;
  v_required_missing text[];
begin
  v_has_author_id := exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'articles'
      and column_name = 'author_id'
  );

  if v_has_author_id then
    if to_regclass('public.profiles') is not null then
      begin
        execute 'select id from public.profiles limit 1' into v_author_id;
      exception
        when undefined_column then
          v_author_id := null;
      end;
    end if;

    if v_author_id is null then
      begin
        execute
          'select author_id from public.articles where author_id is not null limit 1'
          into v_author_id;
      exception
        when undefined_column then
          v_author_id := null;
      end;
    end if;
  end if;

  -- Build a payload first, then insert dynamically only for existing columns.
  -- This avoids hard failures on schema variants while still seeding useful data.
  v_article_payload := jsonb_build_object(
    'slug', 'supabase-seed-demo-1',
    'title', 'Supabase Seed Story',
    'is_published', true,
    'published_at', now(),
    'content', 'This is a seeded article content used for runtime checks.',
    'excerpt', 'A minimal seeded article for local runtime verification.',
    'topic', 'Seeded',
    'language_top', 'English',
    'language_bottom', 'French',
    'body_top', 'This is a seeded top-language body used for runtime checks.',
    'body_bottom', 'Ceci est un corps de texte seed pour les verifications locales.',
    'canonical_lang', 'en'
  );

  if v_has_author_id and v_author_id is not null then
    v_article_payload := v_article_payload || jsonb_build_object('author_id', v_author_id);
  end if;

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
      'Skipping article seed: articles has required columns without seed values: %',
      array_to_string(v_required_missing, ', ');
  else
    select string_agg(format('%I', payload_keys.key), ', ')
    into v_insert_cols
    from jsonb_object_keys(v_article_payload) as payload_keys(key)
    where exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'articles'
        and c.column_name = payload_keys.key
    );

    select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
    into v_update_set
    from jsonb_object_keys(v_article_payload) as payload_keys(key)
    where payload_keys.key <> 'slug'
      and exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'articles'
          and c.column_name = payload_keys.key
      );

    if v_insert_cols is not null and v_update_set is not null then
      execute format(
        'insert into public.articles (%1$s) ' ||
        'select %1$s from jsonb_populate_record(null::public.articles, $1) ' ||
        'on conflict (slug) do update set %2$s',
        v_insert_cols,
        v_update_set
      )
      using v_article_payload;
    end if;
  end if;

  select id into v_article_id
  from public.articles
  where slug = 'supabase-seed-demo-1';

  if v_article_id is null then
    return;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'excerpt'
  ) then
    update public.articles
    set excerpt = 'A minimal seeded article for local runtime verification.'
    where id = v_article_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'topic'
  ) then
    update public.articles
    set topic = 'Seeded'
    where id = v_article_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'language_top'
  ) then
    update public.articles
    set language_top = 'English'
    where id = v_article_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'language_bottom'
  ) then
    update public.articles
    set language_bottom = 'French'
    where id = v_article_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'body_top'
  ) then
    update public.articles
    set body_top = 'This is a seeded top-language body used for runtime checks.'
    where id = v_article_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'body_bottom'
  ) then
    update public.articles
    set body_bottom = 'Ceci est un corps de texte seed pour les verifications locales.'
    where id = v_article_id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public' and table_name = 'articles' and column_name = 'canonical_lang'
  ) then
    update public.articles
    set canonical_lang = 'en'
    where id = v_article_id;
  end if;

  if to_regclass('public.article_localizations') is not null then
    insert into public.article_localizations (article_id, lang, title, excerpt, body, content_hash)
    values
      (v_article_id, 'en', 'Supabase Seed Story', 'Seed excerpt', 'This is a seeded top-language body used for runtime checks.', 'seed-en-v1'),
      (v_article_id, 'fr', 'Supabase Seed Story', 'Extrait seed', 'Ceci est un corps de texte seed pour les verifications locales.', 'seed-fr-v1')
    on conflict (article_id, lang) do update
      set
        title = excluded.title,
        excerpt = excluded.excerpt,
        body = excluded.body,
        content_hash = excluded.content_hash;
  end if;

  if to_regclass('public.quiz_sets') is not null then
    v_quiz_payload := jsonb_build_object(
      'slug', 'seed-quiz-1',
      'lang', 'en',
      'title', 'Seed Quiz: Europe Basics',
      'description', 'Minimal quiz for local Learn/Quiz flow checks.',
      'topic', 'Seeded',
      'is_published', true
    );

    select array_agg(c.column_name order by c.ordinal_position)
    into v_required_missing
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'quiz_sets'
      and c.is_nullable = 'NO'
      and c.column_default is null
      and coalesce(c.identity_generation, '') = ''
      and not exists (
        select 1
        from jsonb_object_keys(v_quiz_payload) as payload_keys(key)
        where payload_keys.key = c.column_name
      );

    if coalesce(array_length(v_required_missing, 1), 0) > 0 then
      raise notice
        'Skipping quiz_sets seed: required columns without seed values: %',
        array_to_string(v_required_missing, ', ');
    else
      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_quiz_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'quiz_sets'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_quiz_payload) as payload_keys(key)
      where payload_keys.key <> 'slug'
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'quiz_sets'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        execute format(
          'insert into public.quiz_sets (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.quiz_sets, $1) ' ||
          'on conflict (slug) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_quiz_payload;
      end if;
    end if;
  end if;

  if to_regclass('public.events') is not null then
    v_event_payload := jsonb_build_object(
      'slug', 'seed-event-1',
      'title', 'Seed Community Event',
      'description', 'Minimal event for local events flow verification.',
      'topic', 'Seeded',
      'location_label', 'Remote / Localhost',
      'start_at', now() + interval '3 days',
      'is_published', true
    );

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
        'Skipping events seed: required columns without seed values: %',
        array_to_string(v_required_missing, ', ');
    else
      select string_agg(format('%I', payload_keys.key), ', ')
      into v_insert_cols
      from jsonb_object_keys(v_event_payload) as payload_keys(key)
      where exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'events'
          and c.column_name = payload_keys.key
      );

      select string_agg(format('%1$I = excluded.%1$I', payload_keys.key), ', ')
      into v_update_set
      from jsonb_object_keys(v_event_payload) as payload_keys(key)
      where payload_keys.key <> 'slug'
        and exists (
          select 1
          from information_schema.columns c
          where c.table_schema = 'public'
            and c.table_name = 'events'
            and c.column_name = payload_keys.key
        );

      if v_insert_cols is not null and v_update_set is not null then
        execute format(
          'insert into public.events (%1$s) ' ||
          'select %1$s from jsonb_populate_record(null::public.events, $1) ' ||
          'on conflict (slug) do update set %2$s',
          v_insert_cols,
          v_update_set
        )
        using v_event_payload;
      end if;
    end if;
  end if;
end $$;

-- Seed one question+options after quiz_set exists.
do $$
declare
  v_quiz_id uuid;
  v_question_id uuid;
  v_required_missing text[];
begin
  if to_regclass('public.quiz_sets') is null
     or to_regclass('public.quiz_questions') is null
     or to_regclass('public.quiz_options') is null then
    return;
  end if;

  select id into v_quiz_id
  from public.quiz_sets
  where slug = 'seed-quiz-1'
  limit 1;

  if v_quiz_id is null then
    return;
  end if;

  select array_agg(c.column_name order by c.ordinal_position)
  into v_required_missing
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'quiz_questions'
    and c.is_nullable = 'NO'
    and c.column_default is null
    and coalesce(c.identity_generation, '') = ''
    and c.column_name not in ('quiz_set_id', 'position', 'prompt');

  if coalesce(array_length(v_required_missing, 1), 0) > 0 then
    raise notice
      'Skipping quiz_questions seed: required columns without seed values: %',
      array_to_string(v_required_missing, ', ');
    return;
  end if;

  insert into public.quiz_questions (quiz_set_id, position, prompt)
  values (v_quiz_id, 1, 'Which city hosts many EU institutions?')
  on conflict (quiz_set_id, position) do update
    set prompt = excluded.prompt
  returning id into v_question_id;

  if v_question_id is null then
    select id into v_question_id
    from public.quiz_questions
    where quiz_set_id = v_quiz_id and position = 1
    limit 1;
  end if;

  if v_question_id is null then
    return;
  end if;

  select array_agg(c.column_name order by c.ordinal_position)
  into v_required_missing
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'quiz_options'
    and c.is_nullable = 'NO'
    and c.column_default is null
    and coalesce(c.identity_generation, '') = ''
    and c.column_name not in ('question_id', 'position', 'option_text', 'is_correct');

  if coalesce(array_length(v_required_missing, 1), 0) > 0 then
    raise notice
      'Skipping quiz_options seed: required columns without seed values: %',
      array_to_string(v_required_missing, ', ');
    return;
  end if;

  insert into public.quiz_options (question_id, position, option_text, is_correct)
  values
    (v_question_id, 1, 'Brussels', true),
    (v_question_id, 2, 'Madrid', false),
    (v_question_id, 3, 'Oslo', false),
    (v_question_id, 4, 'Zurich', false)
  on conflict (question_id, position) do update
    set
      option_text = excluded.option_text,
      is_correct = excluded.is_correct;
end $$;
