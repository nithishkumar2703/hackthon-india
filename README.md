# Hackathon India — Setup Guide (for beginners)

This is the app + database for a hackathon discovery platform. Everything here is **100% free**.

You already gave me your Supabase URL and key, and they are already plugged in. Follow the steps below in order.

---

## 🚀 QUICK START — The app works right now in your browser (NO installs!)

Your app is **`index.html`** — a real, working web app (and installable PWA). No downloads, no Flutter, no Android Studio.

1. **Double-click `index.html`** (or open it in Chrome/Edge).
2. It connects to your Supabase database and shows every hackathon as a card grid.
3. **Search** any state/city/hackathon — Google-style suggestions pop up as you type.
4. Tap a card → full detail with website / WhatsApp / Email / Call buttons.
5. Tap the ❤ on any card → saved in "FAVOURITES".
6. Tap **Post** → submit a hackathon you found (goes to your `submissions` table for review).

### 📱 Install it on your phone like a real app (no app store!)
- Open `index.html` on your phone's browser.
- **Chrome:** menu ⋮ → **Add to Home Screen** → Add.
- **iPhone/Safari:** Share button → **Add to Home Screen**.
- It now opens full-screen like an app, and even works offline.

> The app updates automatically every day (see the "How the daily auto-update works" section).

---

## 🗓️ STEP A — Fill the app with REAL hackathons (1 minute, browser only)

1. Open **Supabase** → your project → left sidebar → **SQL Editor** → **New query**.
2. Open this file on your PC: `database/add_real_hackathons.sql`
3. Copy everything → paste → click **Run**.
4. Done — the app now shows **110+ real hackathons** found right now across India
   (Tamil Nadu, Maharashtra, UP, Delhi, Karnataka, Rajasthan, … plus all Online ones),
   with real thumbnails, dates and deadlines.
5. Open `index.html` again → **ALL INDIA** → real events everywhere.

## 🔁 STEP B — Auto-update EVERY DAY for free (browser only, no installs)

GitHub Actions runs the finder every morning at 9:00 AM IST. One-time setup:

1. Go to https://github.com/new → name it `hackathon-india` → **Create repository** (public or private, your choice).
2. On your PC, open Command Prompt in this folder and push the code:
   ```cmd
   git init
   git add .
   git commit -m "hackathon india app + daily finder"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/hackathon-india.git
   git push -u origin main
   ```
   (GitHub will ask for your username + password; use a **Personal Access Token** as the password — make one at https://github.com/settings/tokens → "Generate new token" → tick `repo`.)
3. In the repo on GitHub: **Settings → Secrets and variables → Actions → New repository secret**:
   - `SUPABASE_URL` = `https://ciarlvcyhieieioxeyth.supabase.co`
   - `SUPABASE_KEY` = your project's **service_role** key (Project Settings → API → service_role. **Never paste this in chat** — only in the secret box.)
4. Open the **Actions** tab → the `Daily Hackathon Finder` workflow → **Run workflow**.

From now on it finds new hackathons every day at 9:00 AM and adds them automatically.

> **If anything breaks:** the finder writes everything to your `submissions` table first
> (safe mode) — approve rows there by copying them into `hackathons` when you're happy.

---

## Step 1 — Set up your database (5 minutes, browser only)

1. Go to https://supabase.com → sign in → **New project**.
2. Name it `hackathon-india` and set a database password (save it!).
3. Wait ~2 minutes for it to finish creating.
4. On the left sidebar click **SQL Editor** → **New query**.
5. Open this file on your PC: `database/setup.sql`
6. **Select all** the text, copy it, paste into the SQL editor, click **Run**.
7. You should see a green "Success" message. That's it — your database is ready with 34 states + sample hackathons.

## Step 2 — Install Flutter (30–60 minutes, one time)

1. Download Flutter for Windows from https://docs.flutter.dev/get-started/install/windows
2. Follow the "Install Flutter" instructions on that page (it tells you to download the zip, unzip to `C:\src\flutter`, and add it to PATH).
3. When done, open **Command Prompt** and run:
   ```
   flutter doctor
   ```
   It will tell you if Android Studio is recognized. Fix anything it complains about (usually: run `flutter doctor --android-licenses` and accept with `y`).

## Step 3 — Turn this folder into a working app (10 minutes)

1. Open **Command Prompt** and go to the app folder:
   ```
   cd "C:\Users\DELL\Desktop\hackthon search\hackathon_india"
   ```
2. Generate the Android/iOS project files (Flutter will add them — it does NOT overwrite the code I wrote):
   ```
   flutter create .
   ```
3. Download the app's packages:
   ```
   flutter pub get
   ```
4. Open the `android/app/src/main/AndroidManifest.xml` file, and add this line **inside** the `<manifest>` tag (just below `<uses-permission android:name="android.permission.INTERNET"/>` — add that line too if missing):
   ```
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
5. Plug your phone in with USB (enable "Developer options" → "USB debugging" on your phone), or open an emulator from Android Studio.

## Step 4 — Run the app

```
flutter run
```

The first build takes a few minutes. You should see: **Choose your state** → tap a state → hackathon cards → tap one → **Visit Official Website / WhatsApp / Email / Call** buttons.

---

## How to add your own hackathons (no code)

Two ways:

**Option A (easiest) — paste from CSV:**
1. Open the file `database/hackathons_template.csv` in Excel or Google Sheets.
2. Fill in your real hackathons. One row = one hackathon. (Leave `thumbnail_url` blank if you have no image.)
3. Save as CSV.
4. Supabase Dashboard → **Table Editor** → `hackathons` table → **Import data via CSV** → choose your file.
5. If any row fails, check that the `state` name exactly matches one in the `states` table (e.g. "Karnataka", not "Bangalore").

**Option B — paste data by hand:**
1. Supabase Dashboard → **Table Editor** → `hackathons` → **Insert row**.
2. For `state_id`, first open the `states` table and copy the **id** of the state you want (Karnataka = 11, Tamil Nadu = 23).

---

## How to build a phone install file (APK)

```
flutter build apk --release
```

Your installable file will be at `build/app/outputs/flutter-apk/app-release.apk`. Send it to friends via WhatsApp/Bluetooth — they install it like any app. **No app store fees needed.**

---

## Project file map

```
lib/
  main.dart                      → app start, connects to your Supabase
  core/config.dart               → YOUR Supabase URL + key (already set)
  models/                        → hackathon & state data shapes
  data/hackathon_repo.dart       → queries ("give me hackathons for state X")
  services/app_actions.dart      → website / WhatsApp / email / call / share
  screens/state_list_screen.dart        → Screen 1: choose state
  screens/hackathon_list_screen.dart    → Screen 2: hackathon cards
  screens/hackathon_detail_screen.dart  → Screen 3: details + contact
database/
  setup.sql                      → run once in Supabase SQL Editor
  hackathons_template.csv        → fill with your own data
```

## How the daily auto-update works (YOUR main goal)

The app has a "hunter" script that **checks hackathon platforms + tech/hackathon
news sites + Google News every morning** and auto-sorts them into your app by
state category:

- **Platforms** — Devpost, HackerEarth, Unstop (real events with dates, city,
  thumbnails)
- **Tech & hackathon news sites (RSS)** — YourStory, Inc42, TechCrunch, TOI Tech,
  The Hindu Tech, IndianExpress Tech, Moneycontrol Tech, HackerNoon
- **Hacker News** — story search for "hackathon" (free Algolia API)
- **Google News RSS** (free, no API key) — per-state queries like
  "hackathon in Tamil Nadu"; titles must contain "hackathon" (kills unrelated news)
- Mentions **Chennai/Vellore/Coimbatore/...** → that state's list (Tamil Nadu → Tamil Nadu)
- Mentions **online / virtual / remote** → the **Online** list
- National events (Smart India, "India", etc.) → the **Online** list
- Old "winner/wraps up/concludes/held/kicked off" news → **filtered out**
- Already-seen events → **not added twice**

The script is `auto_finder/fetch_hackathons.py`. It runs on **GitHub Actions
(free)** every day at 3:30 AM UTC (9:00 AM India), even when your PC is off. The
app shows new hackathons automatically.

> **Get real data in the app TODAY:** open `database/add_real_hackathons.sql`,
> copy everything, paste into Supabase **SQL Editor**, click **Run**. That file
> holds ~17 real hackathons (13 online + a few state events) with dates and
> images, found on the day the file was generated. Then the daily job keeps
> adding more.

### To turn on the daily auto-update (10 minutes, one time)

1. Create a free account at https://github.com and create a **New repository**
   (name it `hackathon_india`, choose **Private**).
2. Open Command Prompt in the app folder and upload your code:
   ```
   cd "C:\Users\DELL\Desktop\hackthon search\hackathon_india"
   git init
   git add .
   git commit -m "first upload"
   git branch -M main
   git remote add origin https://github.com/YOURUSERNAME/hackathon_india.git
   git push -u origin main
   ```
   (GitHub will ask for your username and a password/token — use a
   [Personal Access Token](https://github.com/settings/tokens), NOT your password.)
3. On GitHub, go to **Settings → Secrets and variables → Actions → New repository secret**:
   - Name: `SUPABASE_URL`, value: `https://ciarlvcyhieieioxeyth.supabase.co`
   - Name: `SUPABASE_KEY`, value: your **secret** key from
     Supabase Dashboard → **Settings → API** (starts with `sb_secret_`).
     > The secret key is powerful — it lives ONLY in GitHub's secret store, never in the code.
4. Go to the **Actions** tab → you'll see "Daily Hackathon Finder" → click
   **Run workflow** to test it once. Check the green checkmark. From now on it
   runs itself every day.
5. Run `database/update1.sql` in Supabase SQL Editor (needed for online hackathons).

> Not ready for GitHub yet? Python is already on your PC — test the finder now:
> ```
> py auto_finder/fetch_hackathons.py
> ```
> (set the `SUPABASE_URL` and `SUPABASE_KEY` env vars first — your publishable
> key sends results to the `submissions` table for review, the secret key adds
> them straight to the app).

---

## Troubleshooting

- **"Could not load states" in the app** → check that you ran `setup.sql` (Step 1) and that the URL/key in `lib/core/config.dart` match your Supabase project.
- **Image shows grey box** → the image URL is broken or the site blocks direct linking; use a different image URL or leave it blank.
- **Call/WhatsApp button does nothing** → phone must be stored as `91XXXXXXXXXX` (no `+`, no dashes).

> IMPORTANT: Never share your Supabase **secret** key (starts with `sb_secret_`). The key in `config.dart` is the public one and is safe.
