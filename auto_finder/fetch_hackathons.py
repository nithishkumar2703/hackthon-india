"""
DAILY HACKATHON FINDER
======================
Runs every morning (9:00 AM India via GitHub Actions). Watches hackathon
platforms + tech/hackathon news sites + Google News for India, guesses the
state (or "online"), and adds them to your Supabase database automatically.

SOURCES
-------
  - Platforms (rich data: dates, city, image):
      Devpost, HackerEarth, Unstop
  - Tech & hackathon news sites (RSS + Hacker News):
      Hacker News, YourStory, Inc42, TechCrunch, TOI Tech, The Hindu Tech,
      IndianExpress Tech, Moneycontrol Tech, HackerNoon
  - Google News RSS (per-state queries: "hackathon in Tamil Nadu" etc.)
  - Unstop site: queries on Google News (30-day window)

How it decides where a hackathon goes (the "category"):
  - Finds a city name (Chennai, Vellore, Coimbatore...)  -> that state's list
  - Finds an institute name (IIT Madras, VIT, Anna Univ)  -> that state's list
  - Finds "online / virtual / remote"                     -> the Online list
  - National events (India, Smart India, etc.)            -> the Online list
  - Otherwise                                            -> skipped (needs human review)
  So a hackathon announced for Chennai automatically lands in the
  "Tamil Nadu" category.

HOW TO RUN
----------
  SUPABASE_URL=https://xxxx.supabase.co SUPABASE_KEY=sb_secret_... python fetch_hackathons.py

  - SUPABASE_KEY with your SECRET key (sb_secret_...)  -> adds straight to the
    hackathons table (full auto, appears in the app next day).
  - Any other key                                      -> adds to the
    submissions table for you to review first.

Uses only Python's standard library (no pip install needed).
"""

import html
import json
import os
import re
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")
IS_SECRET_KEY = SUPABASE_KEY.startswith("sb_secret_")

# ---------------------------------------------------------------------------
# City -> State lookup (add more cities here as needed)
# ---------------------------------------------------------------------------
CITY_TO_STATE = {
    "bengaluru": "Karnataka", "bangalore": "Karnataka", "mysuru": "Karnataka",
    "mysore": "Karnataka", "mangalore": "Karnataka", "mangaluru": "Karnataka",
    "hubli": "Karnataka", "hubballi": "Karnataka", "dharwad": "Karnataka",
    "chennai": "Tamil Nadu", "vellore": "Tamil Nadu", "coimbatore": "Tamil Nadu",
    "madurai": "Tamil Nadu", "trichy": "Tamil Nadu", "tiruchirappalli": "Tamil Nadu",
    "salem": "Tamil Nadu", "kanchipuram": "Tamil Nadu", "tirunelveli": "Tamil Nadu",
    "thoothukudi": "Tamil Nadu",
    "mumbai": "Maharashtra", "pune": "Maharashtra", "nagpur": "Maharashtra",
    "nashik": "Maharashtra", "aurangabad": "Maharashtra", "thane": "Maharashtra",
    "delhi": "Delhi", "new delhi": "Delhi",
    "noida": "Uttar Pradesh", "lucknow": "Uttar Pradesh", "kanpur": "Uttar Pradesh",
    "varanasi": "Uttar Pradesh", "agra": "Uttar Pradesh", "prayagraj": "Uttar Pradesh",
    "allahabad": "Uttar Pradesh", "meerut": "Uttar Pradesh", "ghaziabad": "Uttar Pradesh",
    "gurugram": "Haryana", "gurgaon": "Haryana", "kurukshetra": "Haryana",
    "hyderabad": "Telangana", "warangal": "Telangana",
    "kolkata": "West Bengal", "kalyani": "West Bengal", "durgapur": "West Bengal",
    "ahmedabad": "Gujarat", "surat": "Gujarat", "vadodara": "Gujarat",
    "gandhinagar": "Gujarat", "rajkot": "Gujarat",
    "jaipur": "Rajasthan", "jodhpur": "Rajasthan", "udaipur": "Rajasthan",
    "kota": "Rajasthan",
    "indore": "Madhya Pradesh", "bhopal": "Madhya Pradesh",
    "gwalior": "Madhya Pradesh", "jabalpur": "Madhya Pradesh",
    "kochi": "Kerala", "trivandrum": "Kerala", "thiruvananthapuram": "Kerala",
    "kozhikode": "Kerala", "calicut": "Kerala", "ernakulam": "Kerala",
    "palakkad": "Kerala", "kannur": "Kerala",
    "patna": "Bihar", "gaya": "Bihar",
    "bhubaneswar": "Odisha", "cuttack": "Odisha", "rourkela": "Odisha",
    "guwahati": "Assam", "silchar": "Assam",
    "chandigarh": "Chandigarh",
    "goa": "Goa", "panaji": "Goa",
    "ranchi": "Jharkhand", "jamshedpur": "Jharkhand", "dhanbad": "Jharkhand",
    "raipur": "Chhattisgarh", "bilaspur": "Chhattisgarh",
    "dehradun": "Uttarakhand", "roorkee": "Uttarakhand", "nainital": "Uttarakhand",
    "shimla": "Himachal Pradesh", "hamirpur": "Himachal Pradesh",
    "gangtok": "Sikkim",
    "agartala": "Tripura",
    "imphal": "Manipur",
    "shillong": "Meghalaya",
    "aizawl": "Mizoram",
    "kohima": "Nagaland",
    "itanagar": "Arunachal Pradesh",
    "puducherry": "Puducherry", "pondicherry": "Puducherry",
    "visakhapatnam": "Andhra Pradesh", "vijayawada": "Andhra Pradesh",
    "amaravati": "Andhra Pradesh", "guntur": "Andhra Pradesh", "tirupati": "Andhra Pradesh",
    "amritsar": "Punjab", "ludhiana": "Punjab", "jalandhar": "Punjab",
    "patiala": "Punjab",
    "srinagar": "Jammu and Kashmir", "jammu": "Jammu and Kashmir",
    "leh": "Ladakh",
    "port blair": "Andaman and Nicobar",
}

# Institute / university names that don't contain the city name directly
INSTITUTE_TO_STATE = {
    "iit madras": "Tamil Nadu", "iitm": "Tamil Nadu", "anna university": "Tamil Nadu",
    "iit bombay": "Maharashtra", "iit delhi": "Delhi", "iitd": "Delhi",
    "iit kanpur": "Uttar Pradesh", "iit kharagpur": "West Bengal",
    "iit roorkee": "Uttarakhand", "iit bhu": "Uttar Pradesh", "iit varanasi": "Uttar Pradesh",
    "iit ropar": "Punjab", "iit hyderabad": "Telangana",
    "iit gandhinagar": "Gujarat", "iit guwahati": "Assam",
    "iit jodhpur": "Rajasthan", "iit bhopal": "Madhya Pradesh",
    "iiti": "Madhya Pradesh", "iit palakkad": "Kerala", "iit tirupati": "Andhra Pradesh",
    "iit bhubaneswar": "Odisha", "iit mandi": "Himachal Pradesh",
    "iit patna": "Bihar", "iit indore": "Madhya Pradesh",
    "ism dhanbad": "Jharkhand", "iit dhanbad": "Jharkhand",
    "nit trichy": "Tamil Nadu", "nit tiruchirappalli": "Tamil Nadu",
    "nit warangal": "Telangana", "nit surathkal": "Karnataka",
    "nit kurukshetra": "Haryana", "nit delhi": "Delhi", "nit rourkela": "Odisha",
    "nit calicut": "Kerala", "nit patna": "Bihar",
    "vit vellore": "Tamil Nadu", "vit chennai": "Tamil Nadu",
    "srm university": "Tamil Nadu", "srm institute": "Tamil Nadu",
    "iiit hyderabad": "Telangana", "iiit bangalore": "Karnataka",
    "iiit delhi": "Delhi", "iiitd": "Delhi",
    "bmsce": "Karnataka", "pes university": "Karnataka",
    "vit bhopal": "Madhya Pradesh", "vit ap": "Andhra Pradesh",
    "srm": "Tamil Nadu", "anna univ": "Tamil Nadu", "hindustan university": "Tamil Nadu",
    "saveetha": "Tamil Nadu", "velammal": "Tamil Nadu", "kct": "Tamil Nadu",
    "psg": "Tamil Nadu", "cit coimbatore": "Tamil Nadu", "karunya": "Tamil Nadu",
    "manipal": "Karnataka", "jain university": "Karnataka",
    "christ university": "Karnataka", "rv college": "Karnataka",
    "kiit": "Odisha", "vssut": "Odisha", "cvr college": "Odisha",
    "symbiosis": "Maharashtra", "pict": "Maharashtra", "coe pune": "Maharashtra",
    "lpu": "Punjab", "chandigarh university": "Punjab", "thapar": "Punjab",
    "dtu": "Delhi", "nsut": "Delhi", "jmi": "Delhi", "jamia": "Delhi",
    "amity": "Delhi", "bennett": "Delhi", "igdtuw": "Delhi",
    "bharathidasan": "Tamil Nadu", "bharathiar": "Tamil Nadu",
    "great lakes": "Tamil Nadu", "kumaraguru": "Tamil Nadu",
    "nirma": "Gujarat", "daiict": "Gujarat", "pdeu": "Gujarat",
    "sit pune": "Maharashtra", "cummins": "Maharashtra",
    "heritage institute": "West Bengal", "iiest": "West Bengal",
    "nit silchar": "Assam", "tezpur": "Assam",
    "nit hamirpur": "Himachal Pradesh",
    "nit jalandhar": "Punjab", "nit srinagar": "Jammu and Kashmir",
    "nit agartala": "Tripura", "nit manipur": "Manipur",
    "nit meghalaya": "Meghalaya", "nit mizoram": "Mizoram",
    "nit nagaland": "Nagaland", "nit ap": "Andhra Pradesh",
    "nit goa": "Goa", "nit uttarakhand": "Uttarakhand",
    "nit patna": "Bihar", "iit kharagpur": "West Bengal",
    "iisc": "Karnataka", "rgukt": "Andhra Pradesh", "kl university": "Andhra Pradesh",
    "gvp college": "Andhra Pradesh", "sastra": "Tamil Nadu", "shanmugha": "Tamil Nadu",
    "kalasalingam": "Tamil Nadu", "kongu": "Tamil Nadu", "svce": "Tamil Nadu",
    "ssn": "Tamil Nadu", "jeppiaar": "Tamil Nadu", "rajalakshmi": "Tamil Nadu",
    "klu": "Andhra Pradesh", "audisankara": "Andhra Pradesh", "vrsiddhartha": "Andhra Pradesh",
    "vignan": "Andhra Pradesh", "jntu": "Telangana", "cbit": "Telangana",
    "vasavi": "Telangana", "kits": "Telangana", "mlr": "Telangana",
    "muffakham": "Telangana", "davv": "Madhya Pradesh", "rgpv": "Madhya Pradesh",
    "svvv": "Madhya Pradesh", "sgsits": "Madhya Pradesh",
    "gcoen": "Maharashtra", "coep": "Maharashtra", "sveri": "Maharashtra",
    "walchand": "Maharashtra", "vjti": "Maharashtra", "spit": "Maharashtra",
    "cummins college": "Maharashtra", "pict": "Maharashtra",
    "dtu": "Delhi", "nsut": "Delhi", "jmi": "Delhi", "jamia": "Delhi",
    "amity": "Delhi", "bennett": "Delhi", "igdtuw": "Delhi",
    "bharathidasan": "Tamil Nadu", "bharathiar": "Tamil Nadu",
    "great lakes": "Tamil Nadu", "kumaraguru": "Tamil Nadu",
    "nirma": "Gujarat", "daiict": "Gujarat", "pdeu": "Gujarat",
    "ld college": "Gujarat", "mefgi": "Gujarat", "svit": "Gujarat",
    "charusat": "Gujarat", "gujarat technological": "Gujarat",
    "sit pune": "Maharashtra", "cummins": "Maharashtra",
    "heritage institute": "West Bengal", "iiest": "West Bengal",
    "jdavp": "West Bengal", "maulana abul": "West Bengal",
    "nit silchar": "Assam", "tezpur": "Assam", "gauhati": "Assam", "cse assam": "Assam",
    "nit hamirpur": "Himachal Pradesh",
    "nit jalandhar": "Punjab", "nit srinagar": "Jammu and Kashmir",
    "nit agartala": "Tripura", "nit manipur": "Manipur",
    "nit meghalaya": "Meghalaya", "nit mizoram": "Mizoram",
    "nit nagaland": "Nagaland", "nit ap": "Andhra Pradesh",
    "nit goa": "Goa", "nit uttarakhand": "Uttarakhand",
    "nit patna": "Bihar", "iit kharagpur": "West Bengal",
    "iisc": "Karnataka", "rgukt": "Andhra Pradesh", "kl university": "Andhra Pradesh",
    "sastra": "Tamil Nadu", "shanmugha": "Tamil Nadu",
    "ssn": "Tamil Nadu", "jeppiaar": "Tamil Nadu", "rajalakshmi": "Tamil Nadu",
}

STATES = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka",
    "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya",
    "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim",
    "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand",
    "West Bengal", "Andaman and Nicobar", "Chandigarh", "Delhi",
    "Jammu and Kashmir", "Ladakh", "Puducherry",
]

# Titles containing these are NOT upcoming hackathons -> skip
NEGATIVE_WORDS = [
    "wins", "won ", " winner", "winners", "crowns", "felicitat",
    "concludes", "concluded", "wraps up", "top prize", "first prize",
    "recruitment", "hiring", " how ", "transforming", "impact of",
    "winners to be", "emerges", "takes top", "history of",
    " kicked off", "inaugurat", " took place", "was organized",
    "witnessed", "successfully held", "results announced", "announces results",
]

ONLINE_WORDS = ["online", "virtual", "remote", "anywhere", "web-based"]

# Titles that count as a hackathon even when the word differs
KEYWORD = re.compile(r"(hackathon|buildathon|codeathon|hackfest|hack\\s*it|hackcode)", re.I)


# ---------------------------------------------------------------------------
# Platform scrapers: Devpost, HackerEarth, Unstop (best effort, free)
# ---------------------------------------------------------------------------
def fetch_html(url: str) -> str:
    req = urllib.request.Request(
        url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                                    "Chrome/124.0 Safari/537.36"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "ignore")


def _soup(html_text: str):
    try:
        from bs4 import BeautifulSoup
        return BeautifulSoup(html_text, "html.parser")
    except Exception:
        return None


def parse_devpost_dates(s: str):
    """'Aug 21 - Sep 15, 2026' -> (start_iso, end_iso, deadline_iso)."""
    if not s:
        return None, None, None
    m = re.match(r"\s*([A-Za-z]+)\s+(\d{1,2})\s*-\s*([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})\s*$", s)
    try:
        if m:
            year = m.group(5)
            start = datetime.strptime(f"{m.group(1)} {m.group(2)} {year}", "%b %d %Y").date()
            end = datetime.strptime(f"{m.group(3)} {m.group(4)} {year}", "%b %d %Y").date()
            return start.isoformat(), end.isoformat(), end.isoformat()
        m1 = re.match(r"\s*([A-Za-z]+)\s+(\d{1,2})\s*-\s*(\d{1,2}),\s*(\d{4})\s*$", s)
        if m1:
            year = m1.group(4)
            start = datetime.strptime(f"{m1.group(1)} {m1.group(2)} {year}", "%b %d %Y").date()
            end = datetime.strptime(f"{m1.group(1)} {m1.group(3)} {year}", "%b %d %Y").date()
            return start.isoformat(), end.isoformat(), end.isoformat()
        m2 = re.match(r"\s*([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})\s*$", s)
        if m2:
            d = datetime.strptime(f"{m2.group(1)} {m2.group(2)} {m2.group(3)}", "%b %d %Y").date()
            return None, None, d.isoformat()
    except ValueError:
        pass
    return None, None, None


def scrape_devpost() -> list:
    """Upcoming hackathons from Devpost's public JSON feed (reliable)."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
        "Accept": "application/json",
        "Referer": "https://devpost.com/hackathons",
        "Accept-Language": "en-IN,en;q=0.9",
    }
    out, seen = [], set()
    for page in (1, 2):
        url = ("https://devpost.com/api/hackathons?status=upcoming"
               "&sort_by=Submission+Deadline"
               "&challenge_types%5B%5D=online"
               "&challenge_types%5B%5D=in_person&page=" + str(page))
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.loads(r.read().decode("utf-8", "ignore"))
        except Exception as e:
            print("  devpost page", page, "ERROR:", e)
            break
        for h in data.get("hackathons", []):
            title = (h.get("title") or "").strip()
            link = h.get("url") or ""
            if not title or title in seen:
                continue
            seen.add(title)
            loc = ((h.get("displayed_location") or {}).get("location")) or ""
            start, end, deadline = parse_devpost_dates(h.get("submission_period_dates") or "")
            thumb = (h.get("thumbnail_url") or "").lstrip("//")
            if thumb and not thumb.startswith("http"):
                thumb = "https://" + thumb
            out.append({
                "title": title,
                "link": link,
                "desc": (h.get("organization_name") or "") + " - " +
                        (h.get("submission_period_dates") or ""),
                "haystack": f"{title} {loc}",
                "thumbnail_url": thumb,
                "start_date": start,
                "end_date": end,
                "deadline": deadline,
            })
    return out


def scrape_hackerearth() -> list:
    """Hackathons listed on hackerearth.com/challenges/hackathon/."""
    try:
        html_text = fetch_html("https://www.hackerearth.com/challenges/hackathon/")
        soup = _soup(html_text)
        if soup is None:
            return []
        out, seen = [], set()
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if re.search(r"/challenges/hackathon/[\w-]+/?$", href):
                title = a.get_text(" ", strip=True)
                if not title or title in seen:
                    continue
                seen.add(title)
                url = href if href.startswith("http") else "https://www.hackerearth.com" + href
                out.append({"title": title, "link": url, "desc": ""})
        return out
    except Exception as e:
        print("  hackerearth ERROR:", e)
        return []


def _unstop_get(url: str):
    req = urllib.request.Request(
        url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Referer": "https://www.unstop.com/hackathons",
        })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8", "ignore"))


def _iso_date(s):
    if not s:
        return None
    m = re.match(r"(\d{4}-\d{2}-\d{2})", s)
    return m.group(1) if m else None


def scrape_unstop() -> list:
    """Real hackathons from Unstop's public API (title, dates, image, org)."""
    out, seen = [], set()
    for page in range(1, 4):
        url = ("https://unstop.com/api/public/opportunity/search-result"
               "?opportunity=all&page={}&per_page=100&sortBy=&orderBy="
               "&filter_condition=&undefined=true").format(page)
        try:
            data = _unstop_get(url)["data"]["data"]
        except Exception as e:
            print("  unstop search page", page, "ERROR:", e)
            break
        hacks = [h for h in data if h.get("type") == "hackathons"]
        if not hacks:
            continue
        for h in hacks:
            hid = h.get("id")
            if not hid or hid in seen:
                continue
            seen.add(hid)
            try:
                comp = _unstop_get(
                    "https://unstop.com/api/public/competition/{}".format(hid))["data"]["competition"]
            except Exception:
                time.sleep(0.3)
                continue
            if comp.get("regn_open") != 1:
                continue
            title = (comp.get("title") or "").strip()
            if not title:
                continue
            banner = (comp.get("banner") or {}).get("image_url") or ""
            regn = comp.get("regnRequirements") or {}
            org = (comp.get("organisation") or {}).get("name") or ""
            addr = comp.get("address_with_country_logo") or {}
            slug_city = ""
            m = re.search(r"-([a-z]+)-\d+$", comp.get("public_url") or "")
            if m:
                slug_city = m.group(1)
            details = snippet(comp.get("details") or "")
            hay = " ".join(filter(None, [
                title, org, addr.get("city") or "", addr.get("state") or "",
                comp.get("region") or "", slug_city, details[:200]]))
            out.append({
                "title": title,
                "link": comp.get("seo_url")
                        or "https://unstop.com/" + (comp.get("public_url") or ""),
                "desc": details[:300],
                "haystack": hay,
                "thumbnail_url": banner,
                "start_date": _iso_date(comp.get("start_date")),
                "end_date": _iso_date(comp.get("end_date")),
                "deadline": _iso_date(regn.get("end_regn_dt")),
            })
            time.sleep(0.25)
        time.sleep(0.5)
    return out


PLATFORM_SOURCES = [
    ("Devpost", scrape_devpost),
    ("HackerEarth", scrape_hackerearth),
    ("Unstop", scrape_unstop),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def fetch_rss(query: str, days: int = 7):
    q = f"{query} hackathon when:{days}d"
    url = ("https://news.google.com/rss/search?"
           + urllib.parse.urlencode(
               {"q": q, "hl": "en-IN", "gl": "IN", "ceid": "IN:en"}))
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    root = ET.fromstring(data)
    items = []
    for item in root.iter("item"):
        title = html.unescape(item.findtext("title") or "")
        desc = html.unescape(item.findtext("description") or "")
        items.append({
            "title": title,
            "link": item.findtext("link") or "",
            "desc": desc,
            "haystack": f"{title} {snippet(desc)}",
        })
    return items


# ---------------------------------------------------------------------------
# Tech / hackathon news sites (free RSS + Hacker News, no API key)
# ---------------------------------------------------------------------------
def fetch_feed(url: str) -> list:
    """Generic RSS 2.0 / Atom reader -> items with title, link, desc."""
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0",
                                               "Accept-Encoding": "gzip"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read(3000000)
    except urllib.error.URLError:
        import ssl
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
            raw = r.read(3000000)
    if raw[:2] == b"\x1f\x8b":  # gzip -> decompress
        import gzip
        raw = gzip.decompress(raw)
    root = ET.fromstring(raw)
    items = []
    for node in root.iter():
        tag = node.tag.rsplit("}", 1)[-1]
        if tag == "item":
            title = html.unescape(node.findtext("title") or "")
            link = node.findtext("link") or ""
            desc = html.unescape(node.findtext("description") or "")
        elif tag == "entry":
            title = html.unescape(node.findtext("{http://www.w3.org/2005/Atom}title") or "")
            linkel = node.find("{http://www.w3.org/2005/Atom}link")
            link = linkel.get("href") if linkel is not None else ""
            desc = html.unescape(node.findtext("{http://www.w3.org/2005/Atom}summary") or "")
        else:
            continue
        if not title:
            continue
        items.append({
            "title": title,
            "link": link,
            "desc": desc,
            "haystack": f"{title} {snippet(desc)}",
        })
    return items


def fetch_hn() -> list:
    """Hacker News stories mentioning hackathons (Algolia public API)."""
    url = ("https://hn.algolia.com/api/v1/search_by_date?query=hackathon"
           "&tags=story&hitsPerPage=100")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode("utf-8", "ignore"))
    items = []
    for hit in data.get("hits", []):
        title = (hit.get("title") or "").strip()
        if not title:
            continue
        link = hit.get("url") or ""
        if not link:
            link = "https://news.ycombinator.com/item?id=" + str(hit.get("objectID", ""))
        desc = (hit.get("story_text") or hit.get("comment_text") or "")
        items.append({
            "title": title,
            "link": link,
            "desc": desc,
            "haystack": f"{title} {snippet(desc)}",
        })
    return items


# name, url, kind ("rss" or "hn")
NEWS_FEEDS = [
    ("Hacker News", "https://hn.algolia.com/api/v1/search_by_date?query=hackathon&tags=story&hitsPerPage=100", "hn"),
    ("YourStory", "https://yourstory.com/feed", "rss"),
    ("Inc42", "https://inc42.com/feed/", "rss"),
    ("TechCrunch", "https://techcrunch.com/feed/", "rss"),
    ("TOI Tech", "https://timesofindia.indiatimes.com/rssfeeds/66949542.cms", "rss"),
    ("The Hindu Tech", "https://www.thehindu.com/sci-tech/technology/feeder/default.rss", "rss"),
    ("IndianExpress Tech", "https://indianexpress.com/section/technology/feed/", "rss"),
    ("Moneycontrol Tech", "https://www.moneycontrol.com/rss/technology.xml", "rss"),
    ("HackerNoon", "https://hackernoon.com/feed", "rss"),
]


def clean_title(t: str) -> str:
    """Remove the trailing ' - Source Name' Google News adds."""
    t = re.sub(r"\s+-\s+[^-]+$", "", t).strip()
    return t


def norm(t: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", t.lower())


def snippet(desc: str) -> str:
    s = re.sub(r"<[^>]+>", " ", desc)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:400]


def is_bad_title(low: str) -> bool:
    return any(w in low for w in NEGATIVE_WORDS)


UPCOMING_WORDS = [
    "launch", "announc", "registr", " open", "opens", "apply", "from today",
    "scheduled", "coming", "to be held", "invites", "call for", "calling",
    "entries", "deadline", "2025", "2026", "2027", "regs open",
]


def is_upcoming(title: str) -> bool:
    low = title.lower()
    return any(w in low for w in UPCOMING_WORDS)


def decide_home(it: dict):
    """Return (state, city, mode) or (None, None, mode) to skip.

    - Classifiable state/online words in title+desc -> that home.
    - Unclassified Devpost/Unstop or national events  -> Online.
    - News recaps (past tense, winners)                -> skipped.
    """
    state, city, mode = classify(it.get("haystack", it["title"]))
    if state is not None or mode == "online":
        return state, city, mode
    link = it.get("link", "")
    title_low = it["title"].lower()
    if "news.google.com" in link and not is_upcoming(it["title"]):
        return None, None, mode      # recap / past event
    if "devpost.com" in link or "unstop.com" in link:
        return None, "", "online"
    if re.search(r"\bindia\b|national|international|all india", title_low):
        return None, "", "online"
    return None, None, mode          # skip (needs human review)


def find_og_image(url: str) -> str:
    """Best-effort: fetch a page and grab its banner (og:image / twitter:image)."""
    if not url:
        return ""
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                                        "Chrome/124.0 Safari/537.36"})
        with urllib.request.urlopen(req, timeout=6) as r:
            body = r.read(600000).decode("utf-8", "ignore")
        m = re.search(r'property=["\']og:image["\'][^>]*content=["\']([^"\']+)["\']', body, re.I)
        if not m:
            m = re.search(r'content=["\']([^"\']+)["\'][^>]*property=["\']og:image["\']', body, re.I)
        if not m:
            m = re.search(r'name=["\']twitter:image["\'][^>]*content=["\']([^"\']+)["\']', body, re.I)
        if not m:
            m = re.search(r'content=["\']([^"\']+)["\'][^>]*name=["\']twitter:image["\']', body, re.I)
        if not m:
            m = re.search(r'<img[^>]+src=["\']([^"\']+banner[^"\']*)["\']', body, re.I)
        if not m:
            m = re.search(r'<img[^>]+src=["\']([^"\']+\.(?:png|jpe?g|webp)[^"\']*)["\']', body, re.I)
        if not m:
            return ""
        img = html.unescape(m.group(1)).strip()
        if img.startswith("//"):
            img = "https:" + img
        elif img.startswith("/"):
            from urllib.parse import urlparse
            img = urlparse(url).scheme + "://" + urlparse(url).netloc + img
        if not img.startswith("http"):
            return ""
        return img.split("?")[0] if img.startswith("http") else img
    except Exception:
        return ""


def classify(title: str):
    """Return (state, city, mode). mode is 'online' or 'hybrid'."""
    low = title.lower()
    mode = "online" if any(w in low for w in ONLINE_WORDS) else "hybrid"

    for city, state in CITY_TO_STATE.items():
        if re.search(rf"\b{re.escape(city)}\b", low):
            return state, city.title(), mode
    for name, state in INSTITUTE_TO_STATE.items():
        if name in low:
            return state, name.title(), mode
    for state in STATES:
        if state.lower() in low or state.lower().replace(" ", "") in re.sub(r"[^a-z]", "", low):
            return state, state, mode
    return None, None, mode  # unclassified -> skip


def api(path: str, method: str = "GET", body=None):
    url = SUPABASE_URL + path
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": "Bearer " + SUPABASE_KEY,
    }
    req = urllib.request.Request(url, headers=headers, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(body).encode()
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw else []
    except urllib.error.HTTPError as e:
        print(f"  API {method} {path} -> HTTP {e.code}: {e.read().decode()[:300]}")
        raise


def insert_hackathons(items):
    """Full auto: write straight into the hackathons table (needs secret key)."""
    try:
        state_rows = api("/rest/v1/states?select=id,name")
    except Exception as e:
        print("Could not read states table:", e)
        return
    state_ids = {r["name"]: r["id"] for r in state_rows}

    rows, skipped = [], 0
    for it in items:
        low = it["title"].lower()
        if is_bad_title(low):
            continue
        state, city, mode = decide_home(it)
        if state is None and mode != "online":
            skipped += 1
            continue
        thumb = it.get("thumbnail_url") or ""
        if not thumb and "news.google.com" not in (it.get("link") or ""):
            thumb = find_og_image(it.get("link", ""))
        rows.append({
            "title": it["title"],
            "description": snippet(it["desc"]),
            "state_id": state_ids.get(state),   # None for online
            "city": "" if mode == "online" else city,
            "mode": mode,
            "website_url": it["link"],
            "is_active": True,
        })
        if thumb:
            rows[-1]["thumbnail_url"] = thumb
        for field in ("start_date", "end_date", "deadline"):
            if it.get(field):
                rows[-1][field] = it[field]

    print(f"  -> adding {len(rows)} hackathons ({skipped} skipped, unclassified)")
    if not rows:
        return
    try:
        api("/rest/v1/hackathons", "POST", rows)
        print("  DONE")
    except Exception as e:
        print(f"  batch insert failed ({e}); retrying row-by-row to skip bad rows")
        added, failed = 0, []
        for row in rows:
            try:
                api("/rest/v1/hackathons", "POST", row)
                added += 1
            except Exception:
                failed.append(row.get("title", "?"))
        print(f"  -> inserted {added}, skipped {len(failed)} bad rows:")
        for t in failed:
            print("     -", t)


def insert_submissions(items):
    """Safe mode: add to submissions table for you to review."""
    rows, flagged = [], 0
    for it in items:
        low = it["title"].lower()
        if is_bad_title(low):
            continue
        state, city, mode = decide_home(it)
        if state is None and mode != "online":
            flagged += 1
        rows.append({
            "title": it["title"],
            "state": state or "",
            "description": snippet(it["desc"]),
            "url": it["link"],
            "status": "pending",
        })
    print(f"  -> adding {len(rows)} to submissions ({flagged} flagged for review)")
    if rows:
        api("/rest/v1/submissions", "POST", rows)
        print("  DONE")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("ERROR: set SUPABASE_URL and SUPABASE_KEY environment variables.")
        return

    print("Searching Google News for hackathons (last 7 days)...")
    found, seen = [], set()

    def add_items(items, keyword=True):
        for it in items:
            title = clean_title(it["title"])
            if not title:
                continue
            if keyword and not KEYWORD.search(title):
                continue
            key = norm(title)
            if key in seen:
                continue
            seen.add(key)
            found.append({**it, "title": title})

    # Platforms first so their rich data (city, dates, image) wins on dedupe.
    for name, scraper in PLATFORM_SOURCES:
        try:
            items = scraper()
            add_items(items, keyword=False)
            print(f"  {name:<14} {len(items)} hackathons")
        except Exception as e:
            print(f"  {name:<14} ERROR: {e}")
        time.sleep(0.5)

    # Tech / hackathon news sites (RSS + Hacker News) - only hackathon articles.
    print("Checking tech & hackathon news sites...")
    for name, url, kind in NEWS_FEEDS:
        try:
            items = fetch_hn() if kind == "hn" else fetch_feed(url)
            add_items(items)
            print(f"  {name:<18} {len(items)} articles")
        except Exception as e:
            print(f"  {name:<18} ERROR: {e}")
        time.sleep(0.5)

    queries = ["India"] + [f"in {s}" for s in STATES]
    for q in queries:
        try:
            add_items(fetch_rss(q))
            print(f"  news {q:<18} ok")
        except Exception as e:
            print(f"  news {q:<18} ERROR: {e}")
        time.sleep(0.35)

    # Unstop hosts the most Indian hackathons; Google News indexes their pages.
    # site: searches surface each state's live hackathons (30-day window).
    print("Searching Unstop hackathons via Google News (last 30 days)...")
    for q in ["site:unstop.com hackathon when:30d",
              "site:unstop.com buildathon when:30d"] + \
             [f"site:unstop.com hackathon in {s} when:30d" for s in STATES]:
        try:
            add_items(fetch_rss(q))
            print(f"  unstop {q:<44} ok")
        except Exception as e:
            print(f"  unstop {q:<44} ERROR: {e}")
        time.sleep(0.35)

    print(f"\n{len(found)} unique hackathon mentions found.")

    existing = set()
    for table in ("hackathons", "submissions"):
        try:
            for row in api(f"/rest/v1/{table}?select=title"):
                existing.add(norm(row.get("title", "")))
        except Exception as e:
            print(f"  (could not read {table}: {e})")

    new = [it for it in found if norm(it["title"]) not in existing]
    print(f"{len(new)} are NEW (not already in the database).")

    if not new:
        print("Nothing to add today.")
        return

    if IS_SECRET_KEY:
        print("Secret key detected -> adding directly to hackathons table.")
        insert_hackathons(new)
    else:
        print("Publishable key detected -> adding to submissions for review.")
        insert_submissions(new)


if __name__ == "__main__":
    main()
