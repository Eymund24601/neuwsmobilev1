-- Sudoku + Eurodle backend setup
-- date: 2026-02-06

create extension if not exists pgcrypto;

-- Safety bootstrap: if prior migrations were skipped, create core game tables.
create table if not exists public.game_catalog (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  payload_schema jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.game_rounds (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.game_catalog(id) on delete cascade,
  round_key text not null,
  difficulty text,
  skill_point int,
  seed text,
  compact_payload jsonb not null,
  solution_hash text,
  is_active boolean not null default true,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (game_id, round_key)
);

alter table if exists public.game_rounds
  add column if not exists skill_point int;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'game_rounds'
  )
  and not exists (
    select 1
    from pg_constraint
    where conname = 'game_rounds_skill_point_range'
  ) then
    alter table public.game_rounds
      add constraint game_rounds_skill_point_range
        check (skill_point is null or skill_point between 1 and 5);
  end if;
end
$$;

create index if not exists idx_game_rounds_game_skill_active
  on public.game_rounds(game_id, skill_point, is_active, published_at desc, id desc);

insert into public.game_catalog (slug, name, description, payload_schema, is_active)
values
  (
    'sudoku',
    'Sudoku',
    'Classic 9x9 Sudoku puzzle rounds.',
    '{
      "type":"sudoku",
      "size":9,
      "encoding":"row_major_string",
      "blank_value":"0",
      "fields":["puzzle_grid","solution_grid","skill_point"]
    }'::jsonb,
    true
  ),
  (
    'eurodle',
    'Eurodle',
    'Wordle-style daily puzzle with EU-focused words.',
    '{
      "type":"eurodle",
      "fields":["target_word","word_length","max_attempts","allowed_words","hint"]
    }'::jsonb,
    true
  )
on conflict (slug) do update
set name = excluded.name,
    description = excluded.description,
    payload_schema = excluded.payload_schema,
    is_active = excluded.is_active;

with sudoku as (
  select id as game_id from public.game_catalog where slug = 'sudoku'
)
insert into public.game_rounds (
  game_id,
  round_key,
  difficulty,
  skill_point,
  seed,
  compact_payload,
  solution_hash,
  is_active,
  published_at
)
select
  sudoku.game_id,
  v.round_key,
  v.difficulty,
  v.skill_point,
  v.seed,
  v.compact_payload,
  v.solution_hash,
  true,
  now()
from sudoku
cross join (
  values
    (
      'sudoku-s1-base',
      'easy',
      1,
      's1-base',
      '{
        "puzzle_grid":"534678912672195348198342567859761423426853791713924856961537284287419600340286179",
        "solution_grid":"534678912672195348198342567859761423426853791713924856961537284287419635345286179",
        "skill_point":1
      }'::jsonb,
      md5('sudoku-s1-solution')
    ),
    (
      'sudoku-s2-base',
      'easy',
      2,
      's2-base',
      '{
        "puzzle_grid":"534678912672195348198342567859761423426853791713924856961530284287419600340286179",
        "solution_grid":"534678912672195348198342567859761423426853791713924856961537284287419635345286179",
        "skill_point":2
      }'::jsonb,
      md5('sudoku-s2-solution')
    ),
    (
      'sudoku-s3-base',
      'medium',
      3,
      's3-base',
      '{
        "puzzle_grid":"530678912672195300198342567859761423426803791713924856961537284287419600305286179",
        "solution_grid":"534678912672195348198342567859761423426853791713924856961537284287419635345286179",
        "skill_point":3
      }'::jsonb,
      md5('sudoku-s3-solution')
    ),
    (
      'sudoku-s4-base',
      'hard',
      4,
      's4-base',
      '{
        "puzzle_grid":"530070912672190300198302567859761023426803701703924856901537204287410635305086179",
        "solution_grid":"534678912672195348198342567859761423426853791713924856961537284287419635345286179",
        "skill_point":4
      }'::jsonb,
      md5('sudoku-s4-solution')
    ),
    (
      'sudoku-s5-base',
      'hard',
      5,
      's5-base',
      '{
        "puzzle_grid":"530070000600195000098000060800060003400803001700020006060000280000419005000080079",
        "solution_grid":"534678912672195348198342567859761423426853791713924856961537284287419635345286179",
        "skill_point":5
      }'::jsonb,
      md5('sudoku-s5-solution')
    )
) as v(round_key, difficulty, skill_point, seed, compact_payload, solution_hash)
on conflict (game_id, round_key) do update
set difficulty = excluded.difficulty,
    skill_point = excluded.skill_point,
    seed = excluded.seed,
    compact_payload = excluded.compact_payload,
    solution_hash = excluded.solution_hash,
    is_active = excluded.is_active,
    published_at = excluded.published_at;

with eurodle as (
  select id as game_id from public.game_catalog where slug = 'eurodle'
)
insert into public.game_rounds (
  game_id,
  round_key,
  difficulty,
  seed,
  compact_payload,
  solution_hash,
  is_active,
  published_at
)
select
  eurodle.game_id,
  'eurodle-base-001',
  'medium',
  'eurodle-base-001',
  '{
    "target_word":"union",
    "word_length":5,
    "max_attempts":6,
    "allowed_words":["union","treat","eurox","euroa","voter","euros"],
    "hint":"Shared political and economic project."
  }'::jsonb,
  md5('eurodle-union'),
  true,
  now()
from eurodle
on conflict (game_id, round_key) do update
set difficulty = excluded.difficulty,
    seed = excluded.seed,
    compact_payload = excluded.compact_payload,
    solution_hash = excluded.solution_hash,
    is_active = excluded.is_active,
    published_at = excluded.published_at;
