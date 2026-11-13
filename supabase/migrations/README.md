# Migrations

The baseline schema (tables `club_settings`, `profiles`, `venues`, `visits`, `ratings`,
their Row Level Security policies, and the `handle_new_user()` sign-up trigger) is
**already live** in the Supabase project. It was created in an earlier chat and may hold
real data.

Do not recreate it. The original setup script began with `drop table` lines, so rerunning
it would wipe data. There is deliberately no `000_baseline.sql` here to run.

All future schema changes go in as new, numbered files:

```
001_short_name.sql
002_short_name.sql
```

Rules for every migration (from the project context):

- Safe to run once.
- Keep Row Level Security on for every new table.
- Every write policy has an ownership check (`created_by = auth.uid()` or
  `user_id = auth.uid()`).
- Never add an `anon` write policy or a blanket `using (true)` write policy.

Jack pastes these into the Supabase SQL Editor by hand.
