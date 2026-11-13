-- 003_food_nullable.sql
-- The old `food` column was NOT NULL. It is retired (replaced by `main`) and
-- the app no longer writes it, so new ratings must be allowed to leave it null.
-- Safe to run once; drops no data.

alter table public.ratings alter column food drop not null;
