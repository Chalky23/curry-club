-- 001_attendances.sql
-- Records who was at each visit. "Recorder ticks" model: whoever logs the
-- night ticks everyone present. Anyone can still remove themselves.
-- Safe to run once.

create table if not exists public.attendances (
  id          uuid primary key default gen_random_uuid(),
  visit_id    uuid not null references public.visits(id)   on delete cascade,
  member_id   uuid not null references public.profiles(id) on delete cascade,
  created_by  uuid not null default auth.uid() references auth.users(id),
  created_at  timestamptz not null default now(),
  unique (visit_id, member_id)
);

create index if not exists attendances_visit_idx on public.attendances(visit_id);

alter table public.attendances enable row level security;

-- Any signed-in member can read who was there (needed for the list and,
-- later, the attendance leaderboard).
create policy "attendances_select_authenticated"
  on public.attendances for select
  to authenticated
  using (true);

-- You add attendance rows only as yourself (recorded-by is you).
create policy "attendances_insert_own"
  on public.attendances for insert
  to authenticated
  with check (created_by = auth.uid());

-- You can remove a row you added, or remove yourself from any visit.
create policy "attendances_delete_own_or_self"
  on public.attendances for delete
  to authenticated
  using (created_by = auth.uid() or member_id = auth.uid());
