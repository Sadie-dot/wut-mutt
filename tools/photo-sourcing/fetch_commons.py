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
import json, sys, time, urllib.parse, urllib.request, pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from breeds import BREEDS

API = "https://commons.wikimedia.org/w/api.php"
UA = "WutMuttPhotoSourcing/1.0 (https://github.com/Sadie-dot/wut-mutt; sadief@gmail.com)"
OUT = pathlib.Path(__file__).parent / "candidates"
CANDIDATES_PER_BREED = 4

# CC0 / public domain / CC BY / CC BY-SA only. No NC, no ND, no "fair use".
BAD = ("nc", "nd", "noncommercial", "fair", "nonfree", "gfdl-1.2")
def license_ok(short):
    s = (short or "").lower()
    if not s:
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

def candidates(term):
    """Search File: namespace, return entries with an acceptable licence."""
    data = get({
        "action": "query", "generator": "search",
        "gsrsearch": f'filetype:bitmap {term}', "gsrnamespace": "6",
        "gsrlimit": "30",
        "prop": "imageinfo", "iiprop": "url|extmetadata|size",
        "iiurlwidth": "320",
    })
    out = []
    for page in data.get("query", {}).get("pages", []):
        ii = (page.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata", {})
        short = meta.get("LicenseShortName", {}).get("value", "")
        if not license_ok(short):
            continue
        if ii.get("width", 0) < 500 or ii.get("height", 0) < 500:
            continue
        artist = meta.get("Artist", {}).get("value", "")
        # Artist arrives as HTML; strip tags crudely, it is reviewed by hand.
        import re
        artist = re.sub(r"<[^>]+>", "", artist).strip() or "Unknown"
        artist = re.sub(r"\s+", " ", artist)[:80]
        out.append({
            "title": page["title"],
            "thumb": ii.get("thumburl"),
            "full": ii.get("url"),
            "descurl": ii.get("descriptionurl"),
            "license": short,
            "artist": artist,
            "w": ii.get("width"), "h": ii.get("height"),
        })
        if len(out) >= CANDIDATES_PER_BREED:
            break
    return out

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
