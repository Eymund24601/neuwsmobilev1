-- Quiz Clash seed categories and question bank
-- date: 2026-02-10

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

do $$
declare
  c record;
begin
  for c in
    select id, name, slug
    from public.quiz_clash_categories
    where is_active = true
  loop
    if c.slug = 'geography' then
      insert into public.quiz_clash_questions (
        category_id,
        prompt,
        option_a,
        option_b,
        option_c,
        option_d,
        correct_option_index,
        is_active
      )
      values
        (c.id, 'What is the capital of Canada?', 'Toronto', 'Ottawa', 'Vancouver', 'Montreal', 2, true),
        (c.id, 'Which city is the capital of Portugal?', 'Lisbon', 'Porto', 'Madrid', 'Milan', 1, true),
        (c.id, 'Which country has the city of Prague?', 'Poland', 'Czechia', 'Austria', 'Hungary', 2, true)
      on conflict (category_id, prompt) do update
      set option_a = excluded.option_a,
          option_b = excluded.option_b,
          option_c = excluded.option_c,
          option_d = excluded.option_d,
          correct_option_index = excluded.correct_option_index,
          is_active = excluded.is_active;

    elsif c.slug = 'space' then
      insert into public.quiz_clash_questions (
        category_id,
        prompt,
        option_a,
        option_b,
        option_c,
        option_d,
        correct_option_index,
        is_active
      )
      values
        (c.id, 'Which planet is called the Red Planet?', 'Venus', 'Mars', 'Jupiter', 'Mercury', 2, true),
        (c.id, 'What is the name of Earth''s natural satellite?', 'Titan', 'Europa', 'The Moon', 'Phobos', 3, true),
        (c.id, 'How many planets are in the solar system?', '7', '8', '9', '10', 2, true)
      on conflict (category_id, prompt) do update
      set option_a = excluded.option_a,
          option_b = excluded.option_b,
          option_c = excluded.option_c,
          option_d = excluded.option_d,
          correct_option_index = excluded.correct_option_index,
          is_active = excluded.is_active;

    else
      insert into public.quiz_clash_questions (
        category_id,
        prompt,
        option_a,
        option_b,
        option_c,
        option_d,
        correct_option_index,
        is_active
      )
      values
        (c.id, format('%s: Which option is marked as correct in this starter question 1?', c.name), 'Option A', 'Option B', 'Option C', 'Option D', 1, true),
        (c.id, format('%s: Which option is marked as correct in this starter question 2?', c.name), 'Option A', 'Option B', 'Option C', 'Option D', 2, true),
        (c.id, format('%s: Which option is marked as correct in this starter question 3?', c.name), 'Option A', 'Option B', 'Option C', 'Option D', 3, true)
      on conflict (category_id, prompt) do update
      set option_a = excluded.option_a,
          option_b = excluded.option_b,
          option_c = excluded.option_c,
          option_d = excluded.option_d,
          correct_option_index = excluded.correct_option_index,
          is_active = excluded.is_active;
    end if;
  end loop;
end
$$;
