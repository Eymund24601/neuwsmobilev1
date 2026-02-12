-- Legacy reader compatibility columns on articles.
-- Additive only: keep old-reader paths functional while polyglot localizations are primary.

alter table if exists public.articles
  add column if not exists topic text,
  add column if not exists country_code text,
  add column if not exists language_top text,
  add column if not exists language_bottom text,
  add column if not exists body_top text,
  add column if not exists body_bottom text,
  add column if not exists image_asset text,
  add column if not exists hero_image_url text,
  add column if not exists byline text,
  add column if not exists author_name text,
  add column if not exists author_location text;
