# Security Scan Report — Hackathon India

Scanned with the **strix / ci-security-scanning** approach (repo-wide secret &
exposure review). Read-only scan — **no files were modified.**

## Result: 1 real issue found

| # | Severity | What | Where | Status |
|---|----------|------|-------|--------|
| 1 | **HIGH** | `submissions` table is publicly readable — anyone can read **every submitted email + title + description** | Supabase policy "public read submissions" (`database/setup.sql:80`) | FIX NEEDED |
| 2 | LOW | Public (publishable) Supabase key in frontend files | `index.html:184`, `preview.html:119`, `preview_real.html:119`, `lib/core/config.dart:6` | **Safe by design** — publishable keys are meant to be public |
| 3 | INFO | Service-role secret key referenced only as `sb_secret_...` placeholders | `AGENTS.md`, `README.md`, `NEXT_STEPS.md`, `fetch_hackathons.py` | **Safe** — real value never in repo |

## What was checked

- ✅ **Service role key (`sb_secret_...`)** — NOT anywhere in the repo or git history.
  Only exists as a GitHub Actions secret. Correct.
- ✅ **Git history** — no committed `.env`, token, or key files. Only `lib/core/config.dart`
  (publishable key, safe).
- ✅ **`.env` files** — none exist.
- ✅ **Git remote URL** — clean, no embedded credentials.
- ✅ **Other secrets** (AWS, Stripe, Slack, GitHub PAT, Google API, private keys) — none found.
- ✅ **Workflow file** — secrets passed via `${{ secrets.* }}`, never hardcoded.
- ⚠️ **Publishable key** can INSERT into `submissions` (spam risk) — accepted trade-off for a
  free no-login site; cannot touch `hackathons` (blocked by RLS, verified with 401).

## The one thing to hide

The app NEVER reads `submissions` (the "Post" form only writes to it). But the
database grants *public read* on it, so anyone with the public key (which is in
the HTML anyway) can list all submissions **including email addresses**.

**Fix (run once in Supabase → SQL Editor — I did NOT run it):**

```sql
-- keep insert (so the Post form still works), remove public read
drop policy "public read submissions" on submissions;
```

Optionally also lock down the insert against spam later, but that needs auth —
not worth it for a free anonymous site.

## What to do
1. Run the SQL above.
2. Everything else needs no action. The exposed "key" in the app is the
   publishable key — it is **supposed** to be public.
3. Never paste the service-role key into any file or chat if it can be avoided;
   it belongs only in GitHub Secrets.
