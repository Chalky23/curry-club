# Curry Club: project context for Claude Code

How to use this file: paste it as your first message in Claude Code, from inside the `curry-club` repo folder. Then save the same text as `CLAUDE.md` in the repo root so every future session starts with it. Put the infrastructure playbook in the repo as `docs/infrastructure-playbook.md`.

---

## What this is

Curry Club is a small group of friends who visit local curry houses together, in the style of a book club. This web app lets every member log a visit, rate it, and see a shared ranking of venues. It is used on phones. The organiser is not a professional developer, so explain steps plainly and say what you changed after each task.

Use British English in all replies and in the app copy. Do not use em dashes.

## Read order and which document wins

1. This file.
2. `docs/infrastructure-playbook.md`, written in a different chat for a similar app.
3. `index.html`, the whole app as it stands.

The playbook describes a no-login, honour-system version of this stack. Curry Club was built differently on purpose. Where the two disagree, this file wins:

| Topic | Playbook says | Curry Club does |
|---|---|---|
| Accounts | No logins | Supabase Auth, email and password. Sign-up needs a club code. Email confirmation is off. |
| Database access | Open `anon` policies on every table | Row Level Security for the `authenticated` role only. Everyone can read. Each person can write only their own rows. |
| Identity | Name in `localStorage` | The signed-in user's id (`auth.uid()`), with a display name in `profiles` |
| Admin | Client-side passphrase | None built. If admin features are needed, propose a database-backed approach first. |
| Hosting | Netlify drag and drop | GitHub Pages from the `main` branch. Deploy by committing and pushing. |
| Supabase library | `supabase-js@2.45.4` | `supabase-js@2.58.0`, pinned, loaded from jsDelivr. Keep it, because this project uses a publishable key. |
| Seeding and wiping data with the `anon` key | Allowed | Will not work and must not be worked around. Use SQL in the Supabase SQL Editor. |

The playbook's other ideas still apply: one static `index.html`, vanilla JS, no build step, a pinned CDN version, mobile first, and theme tokens as CSS variables. Its serialised write queue and hash routing are optional. Adopt them only if a feature needs them.

## Supabase project

- Project URL: `https://vmklxqyibmuguwzafhvg.supabase.co`
- Publishable key (safe in browser code, already in `index.html`): `sb_publishable_-lgK6Iji95NLHogpmT9ubA_fcmdlz4L`
- Never ask for, store or commit the database password, the `service_role` key, any secret key, or the club code. If any of these appear in a file, stop and tell me.

## Database as built

All tables are in the `public` schema with Row Level Security on.

- `club_settings` (`id int pk default 1`, `join_code text`). No policies, so the browser cannot read it. Only the sign-up trigger reads it.
- `profiles` (`id uuid pk` references `auth.users`, `display_name text`). Any signed-in user can read. A user can update their own row.
- `venues` (`id uuid pk`, `name`, `area`, `created_by` default `auth.uid()`, `created_at`).
- `visits` (`id uuid pk`, `venue_id` references `venues` on delete cascade, `visited_on date`, `created_by` default `auth.uid()`).
- `ratings` (`id uuid pk`, `visit_id` references `visits` on delete cascade, `user_id` default `auth.uid()`, `food`, `service`, `value` as ints from 1 to 10, `notes`). Unique on `(visit_id, user_id)`, so one rating per person per visit and the app upserts.

Policies on `venues`, `visits` and `ratings`: any authenticated user can select. Insert, update and delete are allowed only where `created_by` (or `user_id` for ratings) equals `auth.uid()`.

Sign-up trigger: `handle_new_user()` runs after insert on `auth.users`. It compares `raw_user_meta_data->>'club_code'` with `club_settings.join_code` and raises `Invalid club code` on a mismatch. Otherwise it inserts the profile using `display_name` from the same metadata. The app shows "That club code is wrong" when Supabase returns a "database error".

The database may already hold real data. Never drop or recreate tables. The first setup script began with `drop table` lines, so never rerun it. All changes go in as new migrations.

## App as built

- One file, `index.html`. State object, string-template render functions, and event delegation using `data-action` attributes.
- Escape every piece of user content with the existing `esc()` helper before it goes into HTML.
- Screens: log in or join, ranking (a card per venue with an average score ring and meters for food, service and value), log a visit, and a rating dialog with three sliders and notes.
- Design: dark aubergine background with turmeric as the accent. Tokens: `--bg #26172B`, `--panel #36213D`, `--panel-2 #432A4B`, `--line #5A3F63`, `--text #F6EEE3`, `--muted #BFAEC4`, `--turmeric #F0B429`, `--chilli #F08A80`, `--coriander #9CCB78`. Fonts are Bricolage Grotesque for display and Figtree for body. The score ring is the one memorable visual, so keep everything else quiet.
- Copy is plain, sentence case and uses active verbs. Errors say what went wrong and how to fix it.
- Not built yet: password reset.

## Hosting and deploy

- GitHub Pages, served from the `main` branch root. The site URL is `https://YOURNAME.github.io/curry-club`.
- Deploying means committing and pushing to `main`. Pages rebuilds in about a minute.
- Netlify is not used. Its drag and drop upload failed from a phone.
- Free Supabase projects can pause after a period of inactivity. If the app suddenly cannot load data, check the Supabase dashboard for a paused project before debugging code.

## Working rules

1. Plan first for anything that touches the database. Show me the proposed tables and columns in plain language, wait for approval, then write the SQL.
2. Put schema changes in `supabase/migrations/NNN_short_name.sql`, numbered in order. Write them to be safe to run once, keep Row Level Security on for every new table, and give every write policy an ownership check. Never add an `anon` write policy or a blanket `using (true)` write policy. I will paste the SQL into the Supabase SQL Editor myself, so tell me when I need to.
3. Test changes in a browser against the live project, served from a local web server (for example `python3 -m http.server`), before you push. Do not create real accounts or write rows to the live database without asking. A sign-up with a wrong club code is a safe test, because the trigger rejects it.
4. Keep the app a single static file with no build step.
5. Use small commits with clear messages. Push to `main` once a change is tested, then tell me what changed and when it will be live.
6. Ask before deleting files, changing the Supabase project settings, or changing how sign-up and the club code work.

## What the club wants to track

Collected at the first Curry Club night, plus suggestions. Treat this as the backlog, not a spec.

Per visit:
- Location, accessibility and parking
- Who was there (an attendance stamp for each member)
- Aesthetics and environment, including heat, music and noise
- Poppadoms and condiments
- Starters, mains, breads and rice, and optional desserts
- Price: total bill, cost per head, and drinks arrangements
- Service, and wait time for food
- Cuisine style, portion size, cleanliness and toilets
- Freebies, booking needed, and takeaway or delivery available
- Who picked the venue, so the choice can rotate

Per person:
- Scores for each area above
- Dish ordered and its heat level
- Favourite dish of the night
- Would go back: yes or no
- A photo of the table

Statistics wanted:
- Attendance leaderboard with streaks
- Harshest and most generous scorer
- Average spend per head by venue
- Who orders the hottest curry on average

Currently built: food, service and value from 1 to 10, plus notes. Everything else above is new.

## First task

Do not change any files yet.

1. Read `index.html` and `docs/infrastructure-playbook.md`.
2. Summarise in a few sentences how the app works today and where the playbook conflicts with this file.
3. Propose a data model for the backlog above. Separate what belongs to a visit, what belongs to one person's rating, and what is an attendance stamp. Say whether each category score should be its own column or live in a flexible JSON column, and why.
4. Suggest the order to build things in, smallest useful step first, and show the new visit form layout in words.

Then wait for my answers.
