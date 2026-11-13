-- 004_venue_location.sql
-- Adds rough coordinates to venues for the map. Safe to run once; drops nothing.
-- Setting a venue's location is an update to venues, so the existing policy
-- (update only where created_by = auth.uid()) already covers it: whoever added
-- a venue can place or move its pin.

alter table public.venues
  add column if not exists lat double precision,
  add column if not exists lng double precision;
