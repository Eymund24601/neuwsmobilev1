-- nEUws article + word coverage seed
-- Purpose: full polyglot article/word baseline for backend and UI verification.
-- Idempotent: safe to run repeatedly.
-- Guardrails:
-- - localizations keep native orthography (do not ASCII-transliterate å/ä/ö/é/etc)
-- - alignment packs use many short windows (not 2-3 coarse chunks)

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

-- Legacy reader compatibility columns expected by current Flutter article detail flow.
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

create temporary table if not exists _seed_authors (
  account_key text primary key,
  preferred_id uuid not null
) on commit drop;

truncate _seed_authors;

insert into _seed_authors (account_key, preferred_id)
values
  ('creator_anna', '22222222-2222-4222-8222-222222222222'),
  ('creator_lukas', '33333333-3333-4333-8333-333333333333'),
  ('creator_lea', '44444444-4444-4444-8444-444444444444'),
  ('creator_miguel', '55555555-5555-4555-8555-555555555555'),
  ('creator_sofia', '66666666-6666-4666-8666-666666666666'),
  ('edvin', '0cbe99b0-bb6d-4edb-8311-b313f83931c9');

create temporary table if not exists _seed_author_runtime (
  account_key text primary key,
  author_id uuid not null,
  display_name text,
  city text,
  country_code text
) on commit drop;

truncate _seed_author_runtime;

insert into _seed_author_runtime (account_key, author_id, display_name, city, country_code)
select
  sa.account_key,
  coalesce(p.id, fallback.id) as author_id,
  coalesce(p.display_name, fallback.display_name, 'nEUws Creator') as display_name,
  coalesce(p.city, fallback.city, 'Europe') as city,
  coalesce(p.country_code, fallback.country_code, 'EU') as country_code
from _seed_authors sa
left join public.profiles p on p.id = sa.preferred_id
cross join lateral (
  select id, display_name, city, country_code
  from public.profiles
  order by created_at asc nulls last, id asc
  limit 1
) fallback;

create temporary table if not exists _seed_articles (
  slug text primary key,
  title text not null,
  excerpt text not null,
  topic text not null,
  country_code text not null,
  country_tags text[] not null,
  author_key text not null,
  canonical_lang text not null,
  top_lang text not null,
  bottom_lang text not null,
  published_hours_ago int not null
) on commit drop;

truncate _seed_articles;

insert into _seed_articles (
  slug, title, excerpt, topic, country_code, country_tags,
  author_key, canonical_lang, top_lang, bottom_lang, published_hours_ago
)
values
  (
    'stockholm-social-infrastructure',
    'How Stockholm Rebuilt Belonging Through Public Spaces',
    'Libraries, after-hours halls, and local host budgets are reducing isolation block by block.',
    'Culture',
    'SE',
    array['SE', 'DK', 'NO'],
    'creator_anna',
    'en',
    'en',
    'fr',
    1
  ),
  (
    'vienna-election-volunteers',
    'Why Vienna Is Training Election Volunteers Year-Round',
    'Election readiness now runs as a civic routine with district drills and transparent audits.',
    'Politics',
    'AT',
    array['AT', 'DE'],
    'creator_lukas',
    'en',
    'de',
    'fr',
    2
  ),
  (
    'baltic-night-train-journal',
    'A Night Train Diary From Riga to Vilnius',
    'Cross-border night routes expose how schedule quality shapes trust in regional transit.',
    'Lifestyle',
    'LV',
    array['LV', 'LT', 'EE'],
    'creator_lea',
    'en',
    'en',
    'de',
    3
  ),
  (
    'porto-urban-startup-loop',
    'Why Porto Feels Like a Prototype for Mid-Sized EU Cities',
    'Founders tie municipal pilots to mentor networks, budget discipline, and public audits.',
    'Tech',
    'PT',
    array['PT', 'ES'],
    'creator_miguel',
    'en',
    'pt',
    'fr',
    4
  ),
  (
    'copenhagen-climate-blocks',
    'Copenhagen''s Block-Level Climate Plans Are Going Hyper-Local',
    'District ballots now directly guide adaptation budgets and local resilience checks.',
    'Climate',
    'DK',
    array['DK', 'SE'],
    'creator_sofia',
    'en',
    'de',
    'sv',
    5
  ),
  (
    'helsinki-grid-storage-coops',
    'Helsinki Is Testing Neighborhood Battery Co-Ops',
    'Residents co-finance storage pilots and review each audit before scaling citywide transit charging.',
    'Energy',
    'FI',
    array['FI', 'SE', 'EE'],
    'edvin',
    'en',
    'sv',
    'en',
    6
  );

create temporary table if not exists _seed_localizations (
  article_slug text not null,
  lang text not null,
  title text not null,
  excerpt text not null,
  body text not null,
  primary key (article_slug, lang)
) on commit drop;

truncate _seed_localizations;

insert into _seed_localizations (article_slug, lang, title, excerpt, body)
values
  (
    'stockholm-social-infrastructure',
    'en',
    'How Stockholm Rebuilt Belonging Through Public Spaces',
    'Libraries, after-hours halls, and local host budgets are reducing isolation block by block.',
    'Stockholm opened a community room in each district and tied a yearly budget to local hosts. The city tracks resilience through monthly check-ins and long-term cooperation with schools and clubs.'
  ),
  (
    'stockholm-social-infrastructure',
    'fr',
    'Comment Stockholm reconstruit le lien local',
    'Des lieux publics de proximité renforcent le lien social.',
    'Stockholm a ouvert un espace de communauté dans chaque district et lié un budget annuel aux animateurs locaux. La ville suit la résilience avec des bilans mensuels et une coopération durable avec les écoles et les clubs.'
  ),
  (
    'stockholm-social-infrastructure',
    'sv',
    'Hur Stockholm bygger ny gemenskap i kvarteren',
    'Lokala platser och tydlig finansiering minskar isolering.',
    'Stockholm öppnade en plats för gemenskap i varje distrikt och kopplade årlig budget till lokala värdar. Staden följer resiliens med månadsvisa avstämningar och långsiktigt samarbete med skolor och föreningar.'
  ),

  (
    'vienna-election-volunteers',
    'en',
    'Why Vienna Is Training Election Volunteers Year-Round',
    'Election readiness now runs as a civic routine with district drills and transparent audits.',
    'Vienna runs one district drill every month so each ballot process is rehearsed before election week. Teams publish every audit, compare resilience gaps, and deepen cooperation between schools and civic groups.'
  ),
  (
    'vienna-election-volunteers',
    'de',
    'Warum Wien Wahlhelfer das ganze Jahr trainiert',
    'Wahlbereitschaft wird als regelmäßige Aufgabe organisiert.',
    'Wien führt in jedem Bezirk monatlich eine Übung durch, damit jeder Stimmzettel-Prozess vor der Wahlwoche trainiert ist. Teams veröffentlichen jede Prüfung, messen Resilienz-Lücken und stärken die Zusammenarbeit zwischen Schulen und Bürgergruppen.'
  ),
  (
    'vienna-election-volunteers',
    'fr',
    'Pourquoi Vienne forme des volontaires électoraux toute l''année',
    'La préparation électorale devient une routine civique.',
    'Vienne organise chaque mois un exercice de district pour que chaque procédure de bulletin soit testée avant la semaine électorale. Les équipes publient chaque audit, mesurent les écarts de résilience et renforcent la coopération entre écoles et associations.'
  ),

  (
    'baltic-night-train-journal',
    'en',
    'A Night Train Diary From Riga to Vilnius',
    'Cross-border night routes expose how schedule quality shapes trust in regional transit.',
    'On the Riga to Vilnius line, passengers compare each schedule update with station notices before departure. Reliable transit depends on practical cooperation between operators, visible community stewards, and resilience plans when storms delay service.'
  ),
  (
    'baltic-night-train-journal',
    'de',
    'Nachtzug Notizen von Riga nach Vilnius',
    'Grenzüberschreitende Linien zeigen die Bedeutung klarer Fahrpläne.',
    'Auf der Strecke Riga Vilnius vergleichen Fahrgäste jeden Fahrplan mit den Anzeigen am Bahnsteig. Verlässlicher Verkehr braucht praktische Zusammenarbeit zwischen Betreibern, sichtbare Gemeinschaftshelfer und Resilienz-Pläne bei Unwettern.'
  ),
  (
    'baltic-night-train-journal',
    'fr',
    'Carnet de train de nuit de Riga à Vilnius',
    'Le trajet met en lumière le rôle des horaires clairs.',
    'Sur la ligne Riga Vilnius, les voyageurs comparent chaque horaire avec les panneaux de quai avant le départ. Un transport fiable dépend d''une coopération concrète entre opérateurs, de relais de communauté visibles et de plans de résilience en cas de tempête.'
  ),

  (
    'porto-urban-startup-loop',
    'en',
    'Why Porto Feels Like a Prototype for Mid-Sized EU Cities',
    'Founders tie municipal pilots to mentor networks, budget discipline, and public audits.',
    'Porto founders pair each mentor session with a public budget checkpoint before launching a municipal pilot. The city publishes each audit result so cooperation between startups and schools can scale with resilience instead of hype.'
  ),
  (
    'porto-urban-startup-loop',
    'pt',
    'Porque o Porto parece um protótipo para cidades médias da UE',
    'Pilotos urbanos unem mentorias, controlo de orçamento e auditoria pública.',
    'No Porto, equipas de startup ligam cada sessão de mentor a um controlo de orçamento antes de lançar um piloto municipal. A cidade publica cada auditoria para que a cooperação entre empresas e escolas cresça com resiliência.'
  ),
  (
    'porto-urban-startup-loop',
    'fr',
    'Pourquoi Porto ressemble à un prototype pour les villes européennes moyennes',
    'Les pilotes urbains lient mentorat, budget et audit public.',
    'À Porto, les équipes associent chaque session de mentor à un contrôle de budget avant de lancer un pilote municipal. La ville publie chaque audit pour que la coopération entre startups et écoles se développe avec résilience.'
  ),

  (
    'copenhagen-climate-blocks',
    'en',
    'Copenhagen''s Block-Level Climate Plans Are Going Hyper-Local',
    'District ballots now directly guide adaptation budgets and local resilience checks.',
    'Copenhagen asks each district board to rank shade, drainage, and route upgrades before the annual budget vote. Every audit is public, and each community panel reports resilience progress after implementation.'
  ),
  (
    'copenhagen-climate-blocks',
    'de',
    'Kopenhagens Klimapläne werden blockweise umgesetzt',
    'Bezirk Abstimmungen steuern das lokale Anpassungsbudget.',
    'Kopenhagen lässt jeden Bezirk Schatten, Entwässerung und Schulwege vor der Budgetabstimmung priorisieren. Jede Prüfung ist öffentlich, und jedes Gemeinschaftspanel berichtet den Resilienz-Fortschritt nach der Umsetzung.'
  ),
  (
    'copenhagen-climate-blocks',
    'sv',
    'Köpenhamn gör klimatplaner på kvartersnivå',
    'Distriktomröstningar styr lokal anpassningsbudget.',
    'Köpenhamn låter varje distrikt prioritera skugga, avvattning och skolvägar före årlig budgetomröstning. Varje granskning är offentlig och varje gemenskapspanel rapporterar resiliens efter genomförande.'
  ),

  (
    'helsinki-grid-storage-coops',
    'en',
    'Helsinki Is Testing Neighborhood Battery Co-Ops',
    'Residents co-finance storage pilots and review each audit before scaling citywide transit charging.',
    'Helsinki neighborhoods formed a cooperation model where residents vote on a shared budget for battery blocks. The city posts every audit and links each transit charging milestone to a resilience checklist.'
  ),
  (
    'helsinki-grid-storage-coops',
    'sv',
    'Helsingfors testar lokala batterikooperativ',
    'Boende finansierar lagring och granskar varje steg.',
    'Helsingfors kvarter byggde en samarbetsmodell där boende röstar om gemensam budget för batterikvarter. Staden publicerar varje granskning och kopplar varje trafikladdningsmål till en resilienschecklista.'
  ),
  (
    'helsinki-grid-storage-coops',
    'de',
    'Helsinki testet lokale Batterie Genossenschaften',
    'Bewohner finanzieren Speicherpilotprojekte mit klarer Prüfung.',
    'In Helsinki nutzen Nachbarschaften ein Zusammenarbeitsmodell, bei dem Bewohner über ein gemeinsames Budget für Batterieblöcke abstimmen. Die Stadt veröffentlicht jede Prüfung und koppelt jeden Verkehrslade-Meilenstein an eine Resilienz-Checkliste.'
  );

-- Force long-form reader payloads for scroll/split-performance validation.
-- 20x repetition keeps each localized body well above 500 words.
update _seed_localizations
set body = trim(repeat(body || ' ', 20));

create temporary table if not exists _seed_lexicon (
  vocab_key text primary key,
  canonical_lemma text not null,
  pos text not null,
  difficulty text not null,
  def_en text not null,
  def_fr text not null,
  def_de text not null,
  def_sv text not null,
  def_pt text not null,
  form_en text not null,
  form_fr text not null,
  form_de text not null,
  form_sv text not null,
  form_pt text not null
) on commit drop;

truncate _seed_lexicon;

insert into _seed_lexicon (
  vocab_key, canonical_lemma, pos, difficulty,
  def_en, def_fr, def_de, def_sv, def_pt,
  form_en, form_fr, form_de, form_sv, form_pt
)
values
  ('community', 'community', 'noun', 'A2', 'A local social network with shared activity.', 'Réseau social local avec activité commune.', 'Lokales soziales Netzwerk mit gemeinsamer Aktivität.', 'Lokalt socialt nätverk med gemensam aktivitet.', 'Rede social local com atividade comum.', 'community', 'communauté', 'gemeinschaft', 'gemenskap', 'comunidade'),
  ('resilience', 'resilience', 'noun', 'B1', 'Capacity to absorb stress and recover quickly.', 'Capacité à absorber le stress et se relever vite.', 'Fähigkeit, Belastung aufzunehmen und sich schnell zu erholen.', 'Förmåga att hantera belastning och komma tillbaka snabbt.', 'Capacidade de absorver pressão e recuperar rapidamente.', 'resilience', 'résilience', 'resilienz', 'resiliens', 'resiliência'),
  ('district', 'district', 'noun', 'A2', 'A defined local administrative area.', 'Zone administrative locale définie.', 'Abgegrenzter lokaler Verwaltungsbereich.', 'Avgränsat lokalt förvaltningsområde.', 'Área administrativa local definida.', 'district', 'district', 'bezirk', 'distrikt', 'distrito'),
  ('budget', 'budget', 'noun', 'A2', 'Planned allocation of money for work.', 'Allocation planifiée des ressources financières.', 'Geplante Verteilung von Geld für Aufgaben.', 'Planerad fördelning av pengar för arbete.', 'Distribuição planeada de recursos financeiros.', 'budget', 'budget', 'budget', 'budget', 'orçamento'),
  ('cooperation', 'cooperation', 'noun', 'B1', 'People or groups working together for a goal.', 'Groupes qui travaillent ensemble vers un objectif.', 'Gruppen arbeiten gemeinsam an einem Ziel.', 'Grupper arbetar tillsammans mot ett mål.', 'Grupos trabalham juntos para um objetivo.', 'cooperation', 'coopération', 'zusammenarbeit', 'samarbete', 'cooperação'),
  ('ballot', 'ballot', 'noun', 'B2', 'A formal vote choice submitted by a voter.', 'Choix de vote formel déposé par un électeur.', 'Formale Wahlentscheidung eines Wählers.', 'Formellt röstval som lämnas av en röstande.', 'Escolha formal de voto submetida por eleitor.', 'ballot', 'bulletin', 'stimmzettel', 'valsedel', 'boletim'),
  ('audit', 'audit', 'noun', 'B1', 'A structured review of a process or account.', 'Vérification structurée d''un processus ou compte.', 'Strukturierte Prüfung eines Prozesses oder Kontos.', 'Strukturerad granskning av process eller konto.', 'Revisão estruturada de processo ou conta.', 'audit', 'audit', 'prüfung', 'granskning', 'auditoria'),
  ('transit', 'transit', 'noun', 'A2', 'Public movement of people across a network.', 'Déplacement public des personnes sur un réseau.', 'Öffentliche Bewegung von Personen im Netz.', 'Offentlig förflyttning av personer i ett nät.', 'Movimento público de pessoas numa rede.', 'transit', 'transport', 'verkehr', 'trafik', 'trânsito'),
  ('schedule', 'schedule', 'noun', 'A2', 'Planned timetable for services and tasks.', 'Horaire planifié pour services et tâches.', 'Geplanter Fahrplan für Dienste und Aufgaben.', 'Planerat schema för tjänster och uppgifter.', 'Horário planeado para serviços e tarefas.', 'schedule', 'horaire', 'fahrplan', 'schema', 'horário'),
  ('mentor', 'mentor', 'noun', 'A2', 'An experienced guide supporting skill growth.', 'Guide expérimenté qui soutient la progression.', 'Erfahrener Begleiter für Kompetenzaufbau.', 'Erfaren handledare som stöttar utveckling.', 'Guia experiente que apoia desenvolvimento.', 'mentor', 'mentor', 'mentor', 'mentor', 'mentor');

create temporary table if not exists _seed_article_focus (
  article_slug text not null,
  rank int not null,
  vocab_key text not null,
  primary key (article_slug, rank)
) on commit drop;

truncate _seed_article_focus;

insert into _seed_article_focus (article_slug, rank, vocab_key)
values
  ('stockholm-social-infrastructure', 1, 'community'),
  ('stockholm-social-infrastructure', 2, 'resilience'),
  ('stockholm-social-infrastructure', 3, 'district'),
  ('stockholm-social-infrastructure', 4, 'budget'),
  ('stockholm-social-infrastructure', 5, 'cooperation'),

  ('vienna-election-volunteers', 1, 'ballot'),
  ('vienna-election-volunteers', 2, 'audit'),
  ('vienna-election-volunteers', 3, 'resilience'),
  ('vienna-election-volunteers', 4, 'district'),
  ('vienna-election-volunteers', 5, 'cooperation'),

  ('baltic-night-train-journal', 1, 'transit'),
  ('baltic-night-train-journal', 2, 'schedule'),
  ('baltic-night-train-journal', 3, 'cooperation'),
  ('baltic-night-train-journal', 4, 'community'),
  ('baltic-night-train-journal', 5, 'resilience'),

  ('porto-urban-startup-loop', 1, 'mentor'),
  ('porto-urban-startup-loop', 2, 'budget'),
  ('porto-urban-startup-loop', 3, 'audit'),
  ('porto-urban-startup-loop', 4, 'cooperation'),
  ('porto-urban-startup-loop', 5, 'resilience'),

  ('copenhagen-climate-blocks', 1, 'district'),
  ('copenhagen-climate-blocks', 2, 'budget'),
  ('copenhagen-climate-blocks', 3, 'resilience'),
  ('copenhagen-climate-blocks', 4, 'audit'),
  ('copenhagen-climate-blocks', 5, 'community'),

  ('helsinki-grid-storage-coops', 1, 'cooperation'),
  ('helsinki-grid-storage-coops', 2, 'budget'),
  ('helsinki-grid-storage-coops', 3, 'audit'),
  ('helsinki-grid-storage-coops', 4, 'transit'),
  ('helsinki-grid-storage-coops', 5, 'resilience');

-- Upsert main article rows with compatibility fields populated.
insert into public.articles (
  slug, title, excerpt, topic, country_code, country_tags,
  language_top, language_bottom, body_top, body_bottom,
  canonical_lang, content, is_published, published_at,
  author_id, byline, author_name, author_location,
  image_asset, hero_image_url, topics, updated_at
)
select
  a.slug,
  a.title,
  a.excerpt,
  a.topic,
  a.country_code,
  a.country_tags,
  a.top_lang,
  a.bottom_lang,
  top_loc.body,
  bottom_loc.body,
  a.canonical_lang,
  canonical_loc.body,
  true,
  now() - make_interval(hours => a.published_hours_ago),
  ar.author_id,
  'nEUws Editorial Desk',
  ar.display_name,
  trim(both ', ' from concat_ws(', ', ar.city, ar.country_code)),
  'assets/images/placeholder.jpg',
  'assets/images/placeholder.jpg',
  array[a.topic, a.country_code],
  now()
from _seed_articles a
join _seed_author_runtime ar on ar.account_key = a.author_key
join _seed_localizations canonical_loc
  on canonical_loc.article_slug = a.slug
 and canonical_loc.lang = a.canonical_lang
join _seed_localizations top_loc
  on top_loc.article_slug = a.slug
 and top_loc.lang = a.top_lang
join _seed_localizations bottom_loc
  on bottom_loc.article_slug = a.slug
 and bottom_loc.lang = a.bottom_lang
on conflict (slug) do update
set
  title = excluded.title,
  excerpt = excluded.excerpt,
  topic = excluded.topic,
  country_code = excluded.country_code,
  country_tags = excluded.country_tags,
  language_top = excluded.language_top,
  language_bottom = excluded.language_bottom,
  body_top = excluded.body_top,
  body_bottom = excluded.body_bottom,
  canonical_lang = excluded.canonical_lang,
  content = excluded.content,
  is_published = excluded.is_published,
  published_at = excluded.published_at,
  author_id = excluded.author_id,
  byline = excluded.byline,
  author_name = excluded.author_name,
  author_location = excluded.author_location,
  image_asset = excluded.image_asset,
  hero_image_url = excluded.hero_image_url,
  topics = excluded.topics,
  updated_at = excluded.updated_at;

create temporary table if not exists _seed_article_ids (
  slug text primary key,
  article_id uuid not null,
  canonical_lang text not null
) on commit drop;

truncate _seed_article_ids;

insert into _seed_article_ids (slug, article_id, canonical_lang)
select a.slug, ar.id, a.canonical_lang
from _seed_articles a
join public.articles ar on ar.slug = a.slug;

insert into public.article_localizations (
  id, article_id, lang, title, excerpt, body, content_hash, version
)
select
  pg_temp.seed_uuid('polyglot-loc:' || l.article_slug || ':' || l.lang),
  m.article_id,
  l.lang,
  l.title,
  l.excerpt,
  l.body,
  md5(l.article_slug || ':' || l.lang || ':' || l.body),
  1
from _seed_localizations l
join _seed_article_ids m on m.slug = l.article_slug
on conflict (article_id, lang) do update
set
  title = excluded.title,
  excerpt = excluded.excerpt,
  body = excluded.body,
  content_hash = excluded.content_hash,
  version = excluded.version;

update public.articles a
set
  canonical_localization_id = loc.id,
  canonical_lang = m.canonical_lang
from _seed_article_ids m
join public.article_localizations loc
  on loc.article_id = m.article_id
 and loc.lang = m.canonical_lang
where a.id = m.article_id;

delete from public.article_alignments aa
where aa.article_id in (select article_id from _seed_article_ids);

insert into public.article_alignments (
  id, article_id, from_localization_id, to_localization_id,
  alignment_json, algo_version, quality_score
)
select
  pg_temp.seed_uuid('polyglot-align:' || m.slug || ':' || tgt.lang),
  m.article_id,
  src.id,
  tgt.id,
  jsonb_build_object(
    'version', 1,
    'source_lang', src.lang,
    'target_lang', tgt.lang,
    'offset_encoding', 'utf16_code_units',
    'units', window_units.units
  ),
  'polyglot-seed-v2',
  0.9
from _seed_article_ids m
join public.article_localizations src
  on src.article_id = m.article_id
 and src.lang = m.canonical_lang
join public.article_localizations tgt
  on tgt.article_id = m.article_id
 and tgt.lang <> m.canonical_lang
cross join lateral (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'c', jsonb_build_array(w.c_start, w.c_end),
        't', jsonb_build_array(w.t_start, w.t_end),
        'score', 0.88
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
        least(gs + 48, char_length(src.body)) as c_end,
        floor(
          (gs::numeric / greatest(char_length(src.body), 1)) *
          char_length(tgt.body)
        )::int as t_start,
        ceil(
          (least(gs + 48, char_length(src.body))::numeric /
          greatest(char_length(src.body), 1)) * char_length(tgt.body)
        )::int as t_end_raw
      from generate_series(
        0,
        greatest(char_length(src.body) - 1, 0),
        48
      ) as gs
    ) raw
    where c_end > c_start
  ) w
) as window_units
on conflict (from_localization_id, to_localization_id) do update
set
  alignment_json = excluded.alignment_json,
  algo_version = excluded.algo_version,
  quality_score = excluded.quality_score;

insert into public.vocab_items (
  id, canonical_lang, canonical_lemma, pos, difficulty
)
select
  pg_temp.seed_uuid('polyglot-vocab:' || l.vocab_key),
  'en',
  l.canonical_lemma,
  l.pos,
  l.difficulty
from _seed_lexicon l
on conflict (id) do update
set
  canonical_lang = excluded.canonical_lang,
  canonical_lemma = excluded.canonical_lemma,
  pos = excluded.pos,
  difficulty = excluded.difficulty;

insert into public.vocab_entries (
  id, vocab_item_id, lang, primary_definition, usage_notes, examples, tags, source
)
select
  pg_temp.seed_uuid('polyglot-entry:' || l.vocab_key || ':' || lang_map.lang),
  pg_temp.seed_uuid('polyglot-vocab:' || l.vocab_key),
  lang_map.lang,
  case lang_map.lang
    when 'en' then l.def_en
    when 'fr' then l.def_fr
    when 'de' then l.def_de
    when 'sv' then l.def_sv
    when 'pt' then l.def_pt
    else l.def_en
  end,
  'Seeded for polyglot article and word collection validation.',
  array[
    'Seed context for ' || l.canonical_lemma,
    'Tap and collect flow validation.'
  ],
  array['seed', 'polyglot', 'article'],
  'supabase_article_word_coverage_seed'
from _seed_lexicon l
cross join (
  values ('en'), ('fr'), ('de'), ('sv'), ('pt')
) as lang_map(lang)
on conflict (vocab_item_id, lang) do update
set
  primary_definition = excluded.primary_definition,
  usage_notes = excluded.usage_notes,
  examples = excluded.examples,
  tags = excluded.tags,
  source = excluded.source;

insert into public.vocab_forms (
  id, vocab_item_id, lang, lemma, surface, notes
)
select
  pg_temp.seed_uuid('polyglot-form:' || l.vocab_key || ':' || lang_map.lang),
  pg_temp.seed_uuid('polyglot-vocab:' || l.vocab_key),
  lang_map.lang,
  case lang_map.lang
    when 'en' then l.form_en
    when 'fr' then l.form_fr
    when 'de' then l.form_de
    when 'sv' then l.form_sv
    when 'pt' then l.form_pt
    else l.form_en
  end,
  case lang_map.lang
    when 'en' then l.form_en
    when 'fr' then l.form_fr
    when 'de' then l.form_de
    when 'sv' then l.form_sv
    when 'pt' then l.form_pt
    else l.form_en
  end,
  'Polyglot surface form seed'
from _seed_lexicon l
cross join (
  values ('en'), ('fr'), ('de'), ('sv'), ('pt')
) as lang_map(lang)
on conflict (id) do update
set
  lang = excluded.lang,
  lemma = excluded.lemma,
  surface = excluded.surface,
  notes = excluded.notes;

delete from public.article_focus_vocab afv
where afv.article_id in (select article_id from _seed_article_ids);

insert into public.article_focus_vocab (
  article_id, vocab_item_id, rank
)
select
  m.article_id,
  pg_temp.seed_uuid('polyglot-vocab:' || f.vocab_key),
  f.rank
from _seed_article_focus f
join _seed_article_ids m on m.slug = f.article_slug
on conflict (article_id, vocab_item_id) do update
set rank = excluded.rank;

delete from public.article_vocab_spans avs
where avs.article_id in (select article_id from _seed_article_ids);

insert into public.article_vocab_spans (
  article_id, vocab_item_id, localization_id, spans_json
)
select
  afv.article_id,
  afv.vocab_item_id,
  al.id as localization_id,
  jsonb_build_object(
    'version', 1,
    'offset_encoding', 'utf16_code_units',
    'spans', jsonb_build_array(
      jsonb_build_object(
        'start', pos.pos_start - 1,
        'end', pos.pos_start - 1 + char_length(vf.surface),
        'surface', vf.surface,
        'lemma', vf.lemma
      )
    )
  )
from public.article_focus_vocab afv
join _seed_article_ids m on m.article_id = afv.article_id
join public.article_localizations al
  on al.article_id = afv.article_id
join public.vocab_forms vf
  on vf.vocab_item_id = afv.vocab_item_id
 and vf.lang = al.lang
cross join lateral (
  select strpos(lower(al.body), lower(vf.surface)) as pos_start
) pos
where pos.pos_start > 0
on conflict (article_id, vocab_item_id, localization_id) do update
set spans_json = excluded.spans_json;

create temporary table if not exists _seed_collect_users (
  user_id uuid primary key
) on commit drop;

truncate _seed_collect_users;

insert into _seed_collect_users (user_id)
select p.id
from public.profiles p
where p.id in (
  '11111111-1111-4111-8111-111111111111'::uuid,
  '0cbe99b0-bb6d-4edb-8311-b313f83931c9'::uuid
);

-- Keep Edvin account defaults aligned with expected reader start pair.
insert into public.user_settings (
  user_id,
  ui_lang,
  reading_lang_top,
  reading_lang_bottom,
  push_notifications_enabled
)
select
  u.id,
  'English',
  'en',
  'sv',
  true
from auth.users u
where u.email = 'edvin@kollberg.se'
on conflict (user_id) do update
set
  ui_lang = excluded.ui_lang,
  reading_lang_top = excluded.reading_lang_top,
  reading_lang_bottom = excluded.reading_lang_bottom,
  push_notifications_enabled = excluded.push_notifications_enabled;

insert into public.user_vocab_events (
  id, user_id, vocab_item_id, article_id, event_type, occurred_at, meta_json
)
select
  pg_temp.seed_uuid(
    'polyglot-collect:' || u.user_id::text || ':' || afv.article_id::text || ':' || afv.vocab_item_id::text
  ),
  u.user_id,
  afv.vocab_item_id,
  afv.article_id,
  'collect',
  now() - interval '1 day',
  jsonb_build_object('source', 'article_word_coverage_seed')
from _seed_collect_users u
join public.article_focus_vocab afv on true
join _seed_article_ids m on m.article_id = afv.article_id
where m.slug in (
  'stockholm-social-infrastructure',
  'vienna-election-volunteers'
)
on conflict (id) do nothing;

insert into public.user_vocab_progress (
  user_id, vocab_item_id, level, xp, last_seen_at, next_review_at
)
select
  e.user_id,
  e.vocab_item_id,
  case
    when count(*) * 10 >= 120 then 'gold'
    when count(*) * 10 >= 60 then 'silver'
    else 'bronze'
  end as level,
  count(*)::int * 10 as xp,
  max(e.occurred_at) as last_seen_at,
  max(e.occurred_at) + interval '3 days' as next_review_at
from public.user_vocab_events e
join _seed_collect_users u on u.user_id = e.user_id
where e.event_type = 'collect'
group by e.user_id, e.vocab_item_id
on conflict (user_id, vocab_item_id) do update
set
  level = excluded.level,
  xp = excluded.xp,
  last_seen_at = excluded.last_seen_at,
  next_review_at = excluded.next_review_at;

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
      'seed:article_word_coverage'
    );
    if to_regprocedure('public.rebuild_article_token_alignments(uuid,text)') is not null then
      perform public.rebuild_article_token_alignments(
        m.article_id,
        'seed:token_window_v1'
      );
    end if;
  end loop;
end $$;

-- Verification output.
select
  a.slug,
  p.display_name as author,
  a.canonical_lang,
  a.language_top,
  a.language_bottom,
  max(a.published_at) as published_at,
  count(distinct al.lang) as localization_langs,
  count(distinct aa.id) as alignments,
  count(distinct afv.vocab_item_id) as focus_vocab
from public.articles a
left join public.profiles p on p.id = a.author_id
left join public.article_localizations al on al.article_id = a.id
left join public.article_alignments aa on aa.article_id = a.id
left join public.article_focus_vocab afv on afv.article_id = a.id
where a.slug in (select slug from _seed_articles)
group by a.slug, p.display_name, a.canonical_lang, a.language_top, a.language_bottom
order by published_at desc nulls last, a.slug;

select
  l.lang,
  count(*) as localization_rows
from public.article_localizations l
join _seed_article_ids m on m.article_id = l.article_id
group by l.lang
order by localization_rows desc, l.lang;

select
  p.email,
  count(*) as vocab_progress_rows,
  coalesce(sum(uvp.xp), 0) as total_vocab_xp
from _seed_collect_users u
join public.profiles p on p.id = u.user_id
left join public.user_vocab_progress uvp on uvp.user_id = u.user_id
group by p.email
order by p.email;

select
  a.slug,
  count(distinct t.id) as token_rows,
  count(distinct (atl.token_id, atl.vocab_item_id)) as token_vocab_links,
  count(distinct atl.token_id) filter (where atl.is_primary) as primary_links,
  count(distinct ata.target_token_id) as token_alignment_edges
from public.articles a
left join public.article_localization_tokens t on t.article_id = a.id
left join public.article_token_vocab_links atl on atl.token_id = t.id
left join public.article_token_alignments ata on ata.article_id = a.id
where a.slug in (select slug from _seed_articles)
group by a.slug
order by a.slug;
