# Backfill thumbnails: for every hackathon row missing an image,
# visit its website and grab the banner (og:image / twitter:image).
# Usage:  py auto_finder/backfill_thumbnails.py
import re
import html
import urllib.request
from urllib.parse import urlparse

SQL_PATH = r"C:\Users\DELL\Desktop\hackthon search\hackathon_india\database\add_real_hackathons.sql"

def find_banner(url):
    if not url or "news.google.com" in url:
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
            m = re.search(r'<img[^>]+src=["\']([^"\']+\.(?:png|jpe?g|webp)[^"\']*)["\']', body, re.I)
        if not m:
            return ""
        img = html.unescape(m.group(1)).strip()
        if img.startswith("//"):
            img = "https:" + img
        elif img.startswith("/"):
            img = urlparse(url).scheme + "://" + urlparse(url).netloc + img
        if not img.startswith("http"):
            return ""
        return img.split("?")[0]
    except Exception:
        return ""

def split_fields(body):
    fields = re.split(r",(?=(?:[^']*'[^']*')*[^']*$)", body)
    return [f.strip() for f in fields]

sql = open(SQL_PATH, encoding="utf-8").read()
lines = sql.splitlines()
changed = 0
no_url = 0
for i, line in enumerate(lines):
    t = line.strip()
    if not (t.startswith("(") or t.startswith("(NULL")):
        continue
    ends_with_comma = t.endswith(",")
    body = t[1:-1].rstrip(",")
    fields = split_fields(body)
    # columns: state_id, city, mode, title, description, website_url, thumbnail_url, start, end, deadline, is_active
    if len(fields) != 11:
        continue
    if fields[6].strip() != "NULL":
        continue  # already has a thumbnail
    url = fields[5].strip().strip("'").replace("''", "'") if fields[5].strip() != "NULL" else ""
    title = fields[3].strip().strip("'").replace("''", "'")
    banner = find_banner(url)
    if banner:
        fields[6] = "'" + banner.replace("'", "''") + "'"
        rebuilt = "(" + ", ".join(fields) + ")"
        if ends_with_comma:
            rebuilt += ","
        else:
            rebuilt += ";"
        lines[i] = rebuilt
        changed += 1
        print("FOUND:", title[:45], "->", banner[:80])
    else:
        no_url += 1
        print("none:", title[:45])

open(SQL_PATH, "w", encoding="utf-8").write("\n".join(lines))
print("\nUpdated %d rows with real banners. (%d still without)" % (changed, no_url))
