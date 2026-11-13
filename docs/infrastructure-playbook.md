# Infrastructure & Workflow Playbook
## A Claude-maintained, multi-user web app on Netlify + Supabase

Give this document to the Claude chat that will build your new app. It describes the
**infrastructure and workflow only** — the hosting, the database, the connection wiring,
the deploy steps, and how Claude keeps the app continually updatable. The **app itself**
(its screens, its data model, its features) is for that chat to design with you; this
document just pins down the "plumbing" so the new app works the same proven way as the
last one.

---

## 1. What this architecture is (in one paragraph)

A **single static `index.html` file** (plain HTML/CSS/vanilla JS — **no build step, no
framework, no bundler**) that talks **directly to a Supabase project** from the browser
using the official `@supabase/supabase-js` library loaded from a CDN. The file is hosted
on **Netlify** as a static site, so anyone with the link can open it on any phone or
laptop **with no login and no app install**. Supabase provides the shared Postgres
database plus **realtime** updates, so every visitor sees the same live data. Claude
owns and edits the `index.html`; you create the accounts and do the (trivial) deploy.

This stack is **free**, needs **no player accounts**, works on **everyone's own device**,
and is **continually updatable** by Claude because the entire app is one file plus a
database Claude can read and write directly.

---

## 2. Why this exact shape (the constraints that led here)

Keep these in mind — they're the reason not to "improve" it into something heavier:

- **Multiple people, their own devices, no accounts.** Rules out anything requiring
  sign-in. Access is honour-system; there's no sensitive data.
- **Shared, live state.** Everyone sees the same ratings/scores updating in near-real
  time. That needs a real shared backend (Supabase), not browser storage.
- **Free and low-maintenance**, able to stay live indefinitely.
- **Claude-updatable.** One self-contained file + a database Claude can touch directly =
  Claude can iterate on the app and the data without you wiring anything up.
- **Why not a Claude Artifact?** Artifacts can't make network calls to an outside
  database (locked-down CSP) **and** a database-backed Artifact is restricted to signed-in
  members of one org — so it can't be shared with people who don't have Claude accounts.
  That's exactly our audience, so a plain hosted static file is the right call.
- **No Next.js/Vercel build.** A single static file is simpler to host, simpler for Claude
  to maintain, and has nothing to break in a build pipeline. (Vercel + a framework is a
  fine alternative if you ever outgrow this, but you almost certainly won't for a club app.)

---

## 3. Who does what

**You (the human) — the two things Claude cannot do:**
1. **Create the Supabase project** and copy out two values (Project URL + anon public key).
2. **Create a free Netlify account** and drag a folder onto it to deploy / redeploy.

**Claude — everything else:**
- Writes and maintains the single `index.html`.
- Writes the SQL schema for you to paste into Supabase.
- Seeds, inspects, and resets data directly (the anon key + permissive policies let Claude
  do this via the Supabase REST API or a short script — see §7).
- Tests the app against your live database before you deploy, so you deploy known-good files.

---

## 4. PART A — Supabase (the database)

### 4a. Create the project (human, ~2 min)
1. [supabase.com](https://supabase.com) → sign in → **New project**.
2. Name it, set a database password (save it, you rarely need it), pick the nearest region,
   **Create**. Wait ~1 minute.
3. **Project Settings → API**, copy and give Claude:
   - **Project URL** — `https://<ref>.supabase.co`
   - **anon public** key — the long `eyJ…` string labelled *anon* / *public*.
     **Never** send the `service_role` secret key — it's not needed and must stay private.

The anon public key is **designed to be shipped in browser code**; it's safe for Claude to
bake it into the HTML. What protects the data is the Row Level Security policies below —
and for a casual club app we deliberately keep those wide open (honour system).

> **One Supabase project per app.** The curry club gets its *own* new project, separate
> from any previous app's data.

### 4b. The schema pattern (Claude writes this; human runs it)
Claude will generate a SQL script tailored to the app's data model and you paste it into
**Supabase → SQL Editor → New query → Run**. Every such script follows this **reusable
template** — the parts that make the stack work are the same every time; only the tables
change:

```sql
-- 1) TABLES — designed per app. Example shape for a rating app:
create table if not exists dinners (
  id         bigint generated always as identity primary key,
  name       text not null,
  venue      text,
  held_on    date,
  created_at timestamptz not null default now()
);

create table if not exists ratings (
  id         bigint generated always as identity primary key,
  dinner_id  bigint references dinners(id) on delete cascade,
  diner      text not null,              -- who rated (a name, no login)
  scores     jsonb not null default '{}',-- flexible metrics: {"heat":7,"flavour":9,...}
  note       text,
  updated_at timestamptz not null default now(),
  unique (dinner_id, diner)              -- one rating row per person per dinner
);

-- 2) ACCESS — no logins, so the public anon key may read/write. No sensitive data.
--    (This is the honour-system trade-off; anyone technical could poke the data.)
alter table dinners enable row level security;
alter table ratings enable row level security;
create policy "anon all dinners" on dinners for all to anon using (true) with check (true);
create policy "anon all ratings" on ratings for all to anon using (true) with check (true);

-- 3) REALTIME — so every device sees changes live.
alter publication supabase_realtime add table dinners;
alter publication supabase_realtime add table ratings;
alter table dinners replica identity full;
alter table ratings replica identity full;

-- 4) SEED (optional) — starter rows can go here, or Claude can seed via the API later.
```

**The three non-negotiable infrastructure bits** (keep these in any schema):
- `enable row level security` + a permissive `for all to anon` policy per table (no-login access).
- Add every table to the `supabase_realtime` publication **and** set `replica identity full`
  (so realtime update events carry the full row).
- Prefer a **natural uniqueness key** (like `unique (dinner_id, diner)`) so a person's
  repeated writes **upsert** one row instead of piling up duplicates.

Schema changes later are just more SQL pasted into the same SQL Editor — Claude will hand
you follow-up snippets as the app grows.

---

## 5. PART B — The app file (`index.html`) conventions

One file. These conventions are what make it robust and Claude-maintainable:

### 5a. Load Supabase + set the connection (top of the script)
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js"></script>
<script>
  const SUPABASE_URL  = "https://<ref>.supabase.co";   // from §4a
  const SUPABASE_ANON = "eyJ…";                          // anon public key — safe in browser
  const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);
</script>
```
Pin an exact library version (not `@2`) so a future CDN change can't alter behaviour.

### 5b. Realtime subscription pattern
Read once, then subscribe for live updates; always clean up old subscriptions on navigation:
```js
// initial load
const { data } = await sb.from("ratings").select("*");
render(data);
// live updates
const channel = sb.channel("ratings")
  .on("postgres_changes", { event: "*", schema: "public", table: "ratings" },
      payload => { /* payload.new / payload.old → update the view */ })
  .subscribe();
// later, when leaving the view: sb.removeChannel(channel);
```

### 5c. Writes — use a serialized write queue (IMPORTANT, hard-won lesson)
Firing an async `upsert` on every tap/edit causes a real bug: rapid writes can **complete
out of order**, so the database ends up a step behind the UI, and a table's own realtime
echo can clobber local state. **Fix: a tiny queue that always writes the latest state and
never overlaps two writes.** Reuse this pattern for any frequently-updated value:
```js
let saving = false, dirty = false;
function save() { dirty = true; pump(); }          // call this after any local change
async function pump() {
  if (saving || !dirty) return;
  saving = true; dirty = false;
  const snapshot = currentState();                 // capture latest
  try { await sb.from("ratings").upsert(snapshot, { onConflict: "dinner_id,diner" }); }
  catch (e) { dirty = true; }                       // retry on failure
  saving = false;
  if (dirty) pump();                                // state changed mid-write → write again
}
```
Also: a view where **one device is the sole author** of its own row shouldn't subscribe to
its *own* realtime echo (it just causes clobber races) — subscribe for *other* people's
data (e.g. the leaderboard), not your own in-progress edits.

### 5d. Other conventions worth keeping
- **Hash-based routing** (`#/`, `#/thing/<id>`) with small `renderX()` view functions and a
  `router()` on `hashchange`. No framework needed.
- **Theme-aware CSS using custom-property tokens** defined for light, `@media (prefers-color-scheme: dark)`, and `:root[data-theme="dark"]`, so it looks right in both themes.
- **Per-device identity via `localStorage`** when "who am I" should stick on a phone without a
  login (e.g. remember which club member you are).
- **Admin behind a client-side passphrase constant** — friction only, not security:
  ```js
  const ADMIN_PASSPHRASE = "changeme";   // gate an #/admin screen; it's not real security
  ```
  Use it for things like adding a new dinner or editing the metric list.
- **Mobile-first** layout — these get opened on phones.

---

## 6. PART C — Netlify (hosting)

### First deploy (human, ~3 min)
1. Put the `index.html` **inside a folder** (e.g. `curry-club/`). Netlify deploys a folder
   and serves `index.html` at the site root automatically.
2. [netlify.com](https://netlify.com) → **sign up** (free, no card) → **log in** (logging in
   first makes the site permanent and tied to your account).
3. Go to **[app.netlify.com/drop](https://app.netlify.com/drop)** and **drag the folder** on.
4. You get a public `https://<name>.netlify.app` URL — share it with the club.
   Optionally **Site configuration → Change site name** for a tidier URL.

Free-tier sites stay up **indefinitely** (~100 GB bandwidth/month — a club will use a
rounding error of that).

### Updating the live site
To ship a new version of the app: edit `index.html`, then **drag the folder onto the same
site again** (the site's **Deploys** tab has a drag-and-drop zone). Same URL, new version in
seconds. (If you prefer, connect the folder to a Git repo for auto-deploys — optional.)

> **Opening the file by double-clicking it does NOT work** — that's a `file://` page and the
> Supabase connection needs a real web origin. Always test via the Netlify URL (or a local
> web server), never by double-clicking the HTML.

---

## 7. PART D — The "continually update it via Claude" loop

This is the part that makes it feel magic. Because the whole app is one file and Claude has
the Supabase URL + anon key (with permissive policies), Claude can:

- **Edit the app**: change `index.html`, test it against your live database first (Claude can
  run it on a temporary local web server and drive it), then hand you the updated file to
  re-drag onto Netlify.
- **Change the data model**: hand you a new SQL snippet to paste into the Supabase SQL Editor.
- **Seed / inspect / reset data directly**: the anon key + `for all to anon` policies let
  Claude read and write every table — e.g. via the Supabase REST API:
  ```bash
  # read rows
  curl "$SUPABASE_URL/rest/v1/ratings?select=*" \
    -H "apikey: $SUPABASE_ANON" -H "Authorization: Bearer $SUPABASE_ANON"
  # wipe a table for a fresh start (reset)
  curl -X DELETE "$SUPABASE_URL/rest/v1/ratings?id=gt.0" \
    -H "apikey: $SUPABASE_ANON" -H "Authorization: Bearer $SUPABASE_ANON" \
    -H "Prefer: return=minimal"
  ```
  (Claude can also do this from a short Node/JS script using `@supabase/supabase-js`.) A good
  pattern is to build a small **passphrase-gated "admin" screen** into the app itself — e.g.
  "add dinner", "edit metrics", "reset all ratings" — so you can run the common operations
  yourself without going back to Claude each time.

**What to give the new chat to start:** this document, a description of the curry-club
features and metrics you want, and — once you've created it — the Supabase **Project URL**
and **anon public key**. From there the new chat designs the schema and the app, and you
deploy with the drag-and-drop above.

---

## 8. Security model & caveats (state these plainly to the club)

- **Honour system, by design.** No logins; the anon key is public in the page; policies are
  wide open. Anyone with the link (and a little technical skill) could edit data. That's an
  accepted trade-off for a fun club app — **put nothing sensitive in it.**
- **Admin passphrase is friction, not security** — it lives in the client code.
- **Supabase free tier pauses a project after 7 days of no activity.** During active use it
  never triggers; if it ever pauses, un-pausing is one click in the dashboard and no data is
  lost. (Keeps costing nothing.)
- **Netlify free tier**: permanent site, generous limits; nothing to pay.

---

## 9. Quick start checklist for the new app

1. [ ] Create a **new Supabase project**; copy **Project URL** + **anon public key**.
2. [ ] Tell the new Claude chat the app's features/metrics; paste it **this document** + those
       two values.
3. [ ] Run the **schema SQL** Claude gives you in the Supabase SQL Editor.
4. [ ] Let Claude build & test `index.html`; put it in a folder.
5. [ ] Create a **free Netlify account**, drag the folder onto **app.netlify.com/drop**.
6. [ ] Share the `*.netlify.app` link with the club.
7. [ ] Iterate forever: Claude edits the file / SQL → you re-drag the folder → done.
