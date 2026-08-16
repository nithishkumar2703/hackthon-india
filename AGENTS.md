# AGENTS.md — Hackathon India

Instructions for any AI model editing this project. Read this FIRST. It prevents
breaking the code and leaking data.

## What this project is
A single-file web app (`index.html`) that lists Indian hackathons. Data is NOT
hardcoded — the page fetches it LIVE from a Supabase database every time it opens.
A GitHub Actions workflow runs daily at 9:00 AM India and auto-adds newly found
hackathons, so the site stays fresh with zero manual work.

## Data flow (DO NOT CHANGE THIS)
1. `index.html` calls the `api()` function (uses REST + publishable key) to load
   rows from the `hackathons` table.
2. `auto_finder/fetch_hackathons.py` scans Devpost, Unstop, news sites, Google News
   etc. every day (GitHub Actions, cron `30 3 * * *` = 9 AM IST) and inserts new
   hackathons.
3. Visitors can submit their own hackathon -> goes into the `submissions` table
   (pending review).

## Community posts (NO login required)
- Anyone can post without signing in. Their posts go into `user_hackathons` —
  NEVER into the auto-fetched `hackathons` table.
- NO auth, NO storage/uploads. Posts have: user_name, title, description,
  start_date (optional), deadline (required), website, contact, and a user-chosen
  6-digit `delete_pass` (required). To delete, the poster must type that password
  back — deletion goes through the `delete_post(id, pass)` RPC which checks it
  server-side, so nobody can delete someone else's post.
- The password column is hidden from the public (column-level grants: public can
  SELECT/INSERT only non-secret columns). The poster's browser keeps the password
  in localStorage (`hackindia_myposts`) so My Posts lists their posts.
- A post is auto-deleted from the DB the morning after its deadline passes
  (pg_cron job `delete-expired-community`, 22:30 UTC daily) and hidden from the
  UI immediately via `deadline=gte.<today>`.
- Schema: see `database/user_hackathons.sql` (run in Supabase SQL editor once).
  RLS: public read + insert; direct delete blocked; `my_posts()` lists the posts
  for a password list.

## Files
- `index.html` — THE app. Everything (HTML, CSS, JS) in one file. No build step.
- `auto_finder/fetch_hackathons.py` — the daily finder script.
- `.github/workflows/daily_finder.yml` — daily 9 AM trigger.
- `database/setup.sql` — schema (hackathons, states, organizers, submissions).
- `database/add_real_hackathons.sql` — 115-row seed data.
- `preview.html`, `preview_real.html` — static previews generated from the SQL by
  `build_preview_real.py`. NOT the live app. Regenerate, never hand-edit.
- `assets/` — logo, TN govt emblem etc.
- `sw.js`, `manifest.webmanifest` — PWA support. `sw.js` caches the app shell AND last-loaded Supabase data (network-first, offline fallback) so the app works with no internet. Keep the cache version string in sync with changes, and never break the Supabase fetch-caching branch.

## Database
`hackathons` table columns: id, title, tagline, description, state_id (FK states,
NULL = online), city, venue, mode (`online`|`offline`|`hybrid`), start_date,
end_date, deadline, thumbnail_url, website_url, organizer_id, prize_pool,
max_team_size, is_active, created_at.

`user_hackathons` (community) columns: id, user_name, title, description,
start_date, deadline, website, contact, delete_pass, is_active, created_at. RLS:
public read + insert, no direct delete (blocked); deletes go through the
`delete_post(id, pass)` RPC; `my_posts(passes)` RPC for the My Posts view. The
`delete_pass` column is excluded from the public select/insert grants. Expired
rows auto-deleted daily by pg_cron (`delete-expired-community`).

## GOLDEN RULES (breaking any of these = crash or leak)

1. NEVER hardcode hackathon data into `index.html`. It MUST keep fetching from
   Supabase through `api()`. Hardcoding data makes the daily updates stop working.
2. NEVER add any secret/API key to any frontend file. The ONLY key allowed in
   `index.html` is the existing publishable key (`sb_publishable_...`). The
   service role key (`sb_secret_...`) lives ONLY in GitHub Actions secrets —
   never print it, never write it to a file, never commit it. If asked for a key,
   say it belongs in GitHub Secrets.
3. `index.html` is one fragile file: a single JS syntax error blanks the whole
   page. Keep edits small, preserve existing style, keep the structure intact.
4. Do NOT add `crossorigin="anonymous"` back to thumbnail `<img>` tags — Devpost /
   CloudFront CDNs send no CORS headers and images break. Keep the fallback chain:
   real banner -> `assets/tn-govt.svg` (Tamil Nadu govt) -> Google favicon chip ->
   gradient with category emoji + title + mode badge (`thumbHTML()`/`phOf()`).
5. Keep the freshness features working: `updated-line` ("Updated daily at 9 AM
   IST"), `NEW` badge (`isNew()`, last 7 days), newest-first sort.
6. Vanilla JS only. No build tools, no npm, no new libraries/libraries CDNs beyond
   FontAwesome + Google Fonts. All Supabase calls (including community posts and
   the `delete_post` / `my_posts` RPCs) go through the existing `api()` REST
   helper — never add supabase-js back.
7. If you change the database schema, update `database/setup.sql` AND regenerate
   `preview_real.html` with `build_preview_real.py`. Never hand-edit generated files.
8. Don't delete the daily workflow or change its cron without the user's explicit
   request.

## How to verify your changes
- `index.html`: no build step — just open it in a browser. Check the console (F12)
  for zero errors, then confirm: hackathons load, thumbnails show, NEW badge and
  "Last refresh" line appear, search/filters work, detail view opens.
- `fetch_hackathons.py`: `py -m py_compile auto_finder/fetch_hackathons.py`.
- Run the daily finder manually: GitHub -> Actions -> Daily Hackathon Finder ->
  Run workflow.

## Git safety
Commit before risky edits so changes can be rolled back:
`git add . && git commit -m "backup before edit"`.
