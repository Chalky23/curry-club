-- 002_richer_ratings.sql
-- Splits a rating into courses and adds experience scores. Safe to run once.
-- The old `food` column is left in place but no longer used by the app
-- (new ratings use `main`). Nothing is dropped.

alter table public.ratings
  add column if not exists main          int,
  add column if not exists main_dish     text,
  add column if not exists main_heat     int,
  add column if not exists poppadoms     int,
  add column if not exists starter       int,
  add column if not exists starter_dish  text,
  add column if not exists starter_heat  int,
  add column if not exists breads_rice   int,
  add column if not exists dessert       int,
  add column if not exists dessert_dish  text,
  add column if not exists ambience      int,
  add column if not exists portion       int,
  add column if not exists would_go_back boolean;

-- Range checks (nullable columns allow null; added only once).
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'ratings_richer_range') then
    alter table public.ratings add constraint ratings_richer_range check (
      (main        is null or main        between 1 and 10) and
      (poppadoms   is null or poppadoms   between 1 and 10) and
      (starter     is null or starter     between 1 and 10) and
      (breads_rice is null or breads_rice between 1 and 10) and
      (dessert     is null or dessert     between 1 and 10) and
      (ambience    is null or ambience    between 1 and 10) and
      (portion     is null or portion     between 1 and 10) and
      (main_heat    is null or main_heat    between 1 and 5) and
      (starter_heat is null or starter_heat between 1 and 5)
    );
  end if;
end $$;
