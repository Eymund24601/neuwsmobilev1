-- nEUws Supabase smoke check
-- Run after migrations to verify critical runtime contracts.

with required_tables as (
  select unnest(array[
    'articles',
    'article_localizations',
    'article_alignments',
    'article_focus_vocab',
    'quiz_sets',
    'quiz_questions',
    'quiz_options',
    'game_catalog',
    'game_rounds',
    'events',
    'user_settings',
    'user_progression',
    'event_registrations'
  ]) as table_name
)
select
  table_name,
  case when to_regclass('public.' || table_name) is null then 'missing' else 'ok' end as status
from required_tables
order by table_name;

select
  (select count(*) from public.articles where is_published = true) as published_articles,
  (select count(*) from public.quiz_sets where is_published = true) as published_quiz_sets,
  (select count(*) from public.game_rounds where is_active = true) as active_game_rounds,
  (select count(*) from public.events where is_published = true) as published_events;

-- Optional compatibility checks (safe on legacy/fresh projects).
select
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'articles'
      and column_name = 'canonical_lang'
  ) as has_articles_canonical_lang,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_perks'
      and column_name = 'status'
  ) as has_user_perks_status,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'events'
      and column_name = 'location_label'
  ) as has_events_location_label;
