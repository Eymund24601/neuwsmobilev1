-- Polyglot token alignment materialization
-- date: 2026-02-12
-- additive: computes canonical->target token edges from alignment units + token bounds

create or replace function public.rebuild_article_token_alignments(
  p_article_id uuid,
  p_algo_version text default 'token_window_v1'
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int := 0;
begin
  delete from public.article_token_alignments ata
  where ata.article_id = p_article_id;

  with alignment_units as (
    select
      aa.article_id,
      aa.from_localization_id as canonical_localization_id,
      aa.to_localization_id as target_localization_id,
      greatest(0, coalesce((unit->'c'->>0)::int, 0)) as c_start,
      greatest(0, coalesce((unit->'c'->>1)::int, 0)) as c_end,
      greatest(0, coalesce((unit->'t'->>0)::int, 0)) as t_start,
      greatest(0, coalesce((unit->'t'->>1)::int, 0)) as t_end,
      coalesce((unit->>'score')::numeric, aa.quality_score, 0.7::numeric) as unit_score
    from public.article_alignments aa
    cross join lateral jsonb_array_elements(
      coalesce(aa.alignment_json->'units', '[]'::jsonb)
    ) as unit
    where aa.article_id = p_article_id
  ),
  candidate_units as (
    select
      au.article_id,
      ct.id as canonical_token_id,
      au.target_localization_id,
      au.c_start,
      au.c_end,
      au.t_start,
      au.t_end,
      au.unit_score,
      ((ct.start_utf16 + ct.end_utf16)::numeric / 2.0) as canonical_center,
      greatest(au.c_end - au.c_start, 1)::numeric as c_len,
      greatest(au.t_end - au.t_start, 1)::numeric as t_len,
      greatest(
        least(ct.end_utf16, au.c_end) - greatest(ct.start_utf16, au.c_start),
        0
      ) as overlap_len,
      abs(
        ((ct.start_utf16 + ct.end_utf16)::numeric / 2.0) -
        ((au.c_start + au.c_end)::numeric / 2.0)
      ) as center_distance,
      row_number() over (
        partition by ct.id, au.target_localization_id
        order by
          case
            when greatest(
              least(ct.end_utf16, au.c_end) - greatest(ct.start_utf16, au.c_start),
              0
            ) > 0 then 0 else 1
          end asc,
          greatest(
            least(ct.end_utf16, au.c_end) - greatest(ct.start_utf16, au.c_start),
            0
          ) desc,
          abs(
            ((ct.start_utf16 + ct.end_utf16)::numeric / 2.0) -
            ((au.c_start + au.c_end)::numeric / 2.0)
          ) asc
      ) as rn
    from alignment_units au
    join public.article_localization_tokens ct
      on ct.article_id = au.article_id
     and ct.localization_id = au.canonical_localization_id
  ),
  best_unit as (
    select
      cu.article_id,
      cu.canonical_token_id,
      cu.target_localization_id,
      cu.t_start,
      cu.t_end,
      cu.unit_score,
      least(
        greatest(
          cu.t_start,
          cu.t_start + ((cu.canonical_center - cu.c_start) / cu.c_len) * cu.t_len
        ),
        cu.t_end
      ) as expected_target_center
    from candidate_units cu
    where cu.rn = 1
  ),
  mapped as (
    select
      bu.article_id,
      bu.canonical_token_id,
      bu.target_localization_id,
      tt.id as target_token_id,
      bu.unit_score,
      abs(
        ((tt.start_utf16 + tt.end_utf16)::numeric / 2.0) - bu.expected_target_center
      ) as target_center_distance,
      row_number() over (
        partition by bu.canonical_token_id, bu.target_localization_id
        order by
          case
            when tt.end_utf16 > bu.t_start and tt.start_utf16 < bu.t_end then 0 else 1
          end asc,
          abs(
            ((tt.start_utf16 + tt.end_utf16)::numeric / 2.0) - bu.expected_target_center
          ) asc
      ) as rn
    from best_unit bu
    join public.article_localization_tokens tt
      on tt.article_id = bu.article_id
     and tt.localization_id = bu.target_localization_id
  )
  insert into public.article_token_alignments (
    article_id,
    canonical_token_id,
    target_localization_id,
    target_token_id,
    score,
    algo_version
  )
  select
    m.article_id,
    m.canonical_token_id,
    m.target_localization_id,
    m.target_token_id,
    greatest(
      0::numeric,
      least(
        1::numeric,
        m.unit_score - (least(m.target_center_distance, 120::numeric) / 240::numeric)
      )
    ) as score,
    p_algo_version
  from mapped m
  where m.rn = 1
  on conflict (canonical_token_id, target_token_id) do update
  set
    score = excluded.score,
    algo_version = excluded.algo_version;

  get diagnostics v_inserted = row_count;
  return coalesce(v_inserted, 0);
end;
$$;
