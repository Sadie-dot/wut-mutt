#!/usr/bin/env python3
"""Pull candidate breed photos from Wikimedia Commons.

Phase 1 of two. Queries metadata and downloads small review thumbnails only;
the winners get re-fetched at full size by pick_commons.py once a human has
looked at them.

Commons etiquette (learned the hard way on the Lemon Pig catalog):
  - upload.wikimedia.org 429s without a real User-Agent carrying contact info
  - pace image downloads ~1s apart, back off on 429
  - the API endpoint itself is lenient; the file host is not
"""
import json, re, sys, time, urllib.parse, urllib.request, pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from breeds import BREEDS

API = "https://commons.wikimedia.org/w/api.php"
UA = "WutMuttPhotoSourcing/1.0 (https://github.com/Sadie-dot/wut-mutt; sadief@gmail.com)"
OUT = pathlib.Path(__file__).parent / "candidates"
CANDIDATES_PER_BREED = 6
SEARCH_LIMIT = 60

# CC0, public domain and CC BY only — ShareAlike is deliberately excluded.
#
# CC BY-SA is a free licence and costs nothing, but it carries two obligations
# CC BY does not, and neither is worth carrying for decorative photography:
# the square crop this app applies is arguably an adaptation, which would put
# the cropped file under CC BY-SA in turn; and CC BY-SA 4.0 forbids applying
# technological measures that restrict the granted rights, which is an
# unresolved question against App Store DRM. Ruling the whole family out costs
# two breeds of fifty-five and removes the question entirely.
BAD = ("nc", "nd", "noncommercial", "fair", "nonfree", "gfdl-1.2")
def license_ok(short):
    s = (short or "").lower()
    if not s:
        return False
    if "sa" in s.replace(" ", "").replace("-", "").replace("cc0", ""):
        return False
    if any(b in s.replace(" ", "").replace("-", "") for b in ("cc-by-nc", "ccbync", "nd")):
        return False
    if any(b in s.split() or b in s for b in BAD):
        return False
    return any(k in s for k in ("cc0", "public domain", "cc by", "cc-by", "attribution"))

def get(params, tries=4):
    params = {**params, "format": "json", "formatversion": "2"}
    url = API + "?" + urllib.parse.urlencode(params)
    for n in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            if n == tries - 1:
                print(f"    API failed: {e}")
                return {}
            time.sleep(2 ** n)
    return {}

# Commons titles are descriptive, so the ones with people in them usually say
# so. This only skims off the obvious cases — every survivor is still looked at
# on a contact sheet, because "Beagle Bailey" says nothing either way.
PEOPLE = re.compile(r"\b(child|children|kid|kids|girl|boy|woman|women|man|men|"
                    r"family|families|people|person|human|baby|toddler|owner|"
                    r"couple|lady|ladies|gentleman|handler|wedding|selfie|"
                    r"grandma|grandpa|mother|father|daughter|son)s?\b", re.I)

def best_category(term):
    """The Commons category most likely to be this breed's own."""
    data = get({"action": "query", "list": "search", "srsearch": term,
                "srnamespace": "14", "srlimit": "5"})
    hits = [h["title"] for h in data.get("query", {}).get("search", [])]
    want = term.lower().split()
    for title in hits:                      # prefer a category naming the breed
        body = title[9:].lower()
        if all(w in body for w in want):
            return title
    return hits[0] if hits else None

def category_files(cat, limit=200):
    """File: members of a category, with the imageinfo we need."""
    data = get({"action": "query", "list": "categorymembers", "cmtitle": cat,
                "cmlimit": str(limit), "cmtype": "file"})
    titles = [m["title"] for m in data.get("query", {}).get("categorymembers", [])]
    pages = []
    for i in range(0, len(titles), 25):
        batch = get({"action": "query", "titles": "|".join(titles[i:i+25]),
                     "prop": "imageinfo", "iiprop": "url|extmetadata|size",
                     "iiurlwidth": "320"})
        pages += batch.get("query", {}).get("pages", [])
    return pages

def candidates(term):
    """Permissive-licence candidates from the breed's category and from search.

    Search alone is not enough. Commons ranks by relevance, and a category
    where one contributor has uploaded two hundred photos of their own dog
    under CC BY-SA will fill every slot with ShareAlike before a single CC BY
    file appears — the Labradoodle category has forty usable permissive files
    and a search for it returned none of them.
    """
    pages = []
    cat = best_category(term)
    if cat:
        pages += category_files(cat)
    data = get({
        "action": "query", "generator": "search",
        "gsrsearch": f'filetype:bitmap {term}', "gsrnamespace": "6",
        "gsrlimit": str(SEARCH_LIMIT),
        "prop": "imageinfo", "iiprop": "url|extmetadata|size",
        "iiurlwidth": "320",
    })
    pages += data.get("query", {}).get("pages", [])

    out, seen = [], set()
    for page in pages:
        title = page.get("title")
        if not title or title in seen or not title.lower().endswith((".jpg", ".jpeg", ".png")):
            continue
        if PEOPLE.search(title[5:]):
            continue
        ii = (page.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata", {})
        short = meta.get("LicenseShortName", {}).get("value", "")
        if not license_ok(short):
            continue
        # The crop wants 620px on the short side; below that it upscales.
        if min(ii.get("width", 0), ii.get("height", 0)) < 620:
            continue
        seen.add(title)
        artist = re.sub(r"<[^>]+>", "", meta.get("Artist", {}).get("value", "")).strip()
        artist = re.sub(r"\s+", " ", artist)[:80] or "Unknown"
        out.append({
            "title": title,
            "thumb": ii.get("thumburl"),
            "full": ii.get("url"),
            "descurl": ii.get("descriptionurl"),
            "license": short,
            "artist": artist,
            "w": ii.get("width"), "h": ii.get("height"),
        })
    # Files that name the breed first, then biggest short side. A breed
    # category also collects photos where the dog is incidental — a vice
    # president at a Christmas event, a vet's open day — and those are large
    # enough to win on size alone.
    words = [w for w in re.split(r"\W+", term.lower()) if len(w) > 2]
    def rank(c):
        body = c["title"][5:].lower()
        named = sum(w in body for w in words)
        return (-named, -min(c["w"], c["h"]))
    out.sort(key=rank)
    return out[:CANDIDATES_PER_BREED]

def download(url, dest):
    for n in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                dest.write_bytes(r.read())
            return True
        except Exception as e:
            code = getattr(e, "code", None)
            wait = 5 * (n + 1) if code == 429 else 2 ** n
            if n == 3:
                print(f"    download failed: {e}")
                return False
            time.sleep(wait)
    return False

def main():
    OUT.mkdir(exist_ok=True)
    index = {}
    for i, (name, search) in enumerate(BREEDS, 1):
        term = search or name
        print(f"[{i}/{len(BREEDS)}] {name}  <- {term!r}")
        cands = candidates(term)
        if not cands:
            print("    NO USABLE CANDIDATES")
        index[name] = cands
        slug = name.lower().replace(" ", "-")
        for j, c in enumerate(cands):
            dest = OUT / f"{slug}-{j}.jpg"
            if c["thumb"] and not dest.exists():
                download(c["thumb"], dest)
                time.sleep(1.0)          # pace the file host
            c["local"] = dest.name
        time.sleep(0.3)                  # pace the API, lightly
    (OUT / "index.json").write_text(json.dumps(index, indent=1))
    total = sum(len(v) for v in index.values())
    missing = [k for k, v in index.items() if not v]
    print(f"\n{total} candidates for {len(BREEDS)} breeds")
    if missing:
        print("no candidates:", ", ".join(missing))

if __name__ == "__main__":
    main()
