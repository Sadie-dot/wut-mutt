#!/usr/bin/env python3
"""Turn the picked candidates into bundled assets and PhotoCredits.swift.

Phase 3 of three. For each pick this re-asks Commons for a ~900px render of
that file — never the multi-megabyte original, which is both rude to the file
host and useless at 218pt — crops it the way the polaroid will, and writes it
into the asset catalog as its own imageset.

The catalog matters: UIImage(named:) resolves extensionless names against the
compiled catalog, so an imageset entry Just Works where a loose .jpg needs the
bundle-path dance. The simulator stand-in learned that the hard way.
"""
import html, json, pathlib, re, sys, time, urllib.parse, urllib.request
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from breeds import BREEDS
from picks import PICKS
import fetch_commons as fc

HERE = pathlib.Path(__file__).parent
REPO = HERE.parent.parent
ASSETS = REPO / "WutMutt" / "Assets.xcassets"
CREDITS = REPO / "WutMutt" / "Models" / "PhotoCredits.swift"
RENDER = 900        # what we ask Commons to render
SIDE = 700          # what we bundle: covers 612x600 (204x200pt at 3x) with room
QUALITY = 82

def slug(name):
    return "breed-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

# Commons' Artist field is a free-text HTML blob, and a good share of it is
# boilerplate wrapped around the actual name. Attribution is the one thing a
# CC BY licence genuinely requires, so unwrap it rather than printing the
# wrapper — and never cut a name off mid-word to fit.
BOILERPLATE = [
    r"No machine-readable author provided\.\s*(.+?)\s+assumed \(based on copyright claims?\)",
    r"Original uploader was (.+?) at \S+",
    r"This (?:photograph|photo|image|file) was taken by (.+?)(?:\.\s|$)",
    r"^\[*User:([^\]|]+)",
    r"^Flickr user (.+?)\.?$",
    r"^Taken by me,?\s*(.+)$",
    r"^Photo by and \(c\)\s*\d{4}\s*(.+)$",
]

# Clauses that trail the name once the wrapper is off.
TRAILERS = (r"(?:\s+(?:and released under|released under|\.?\s*Photo uploaded"
            r"|licen[cs]ed under)\b.*|\s*https?://\S*)$")

def clean_artist(raw):
    s = html.unescape(re.sub(r"<[^>]+>", " ", raw or ""))
    s = re.sub(r"\s+", " ", s).strip()
    for pattern in BOILERPLATE:
        m = re.search(pattern, s, re.IGNORECASE)
        if m:
            s = m.group(1).strip()
            break
    s = re.sub(TRAILERS, "", s, flags=re.IGNORECASE).strip(" .,;")
    if len(s) > 120:                       # cut on a word boundary, not a letter
        s = s[:120].rsplit(" ", 1)[0] + "…"
    return s or "Unknown"

def render_url(title):
    """A ~900px render of one File: page, with its licensing metadata."""
    data = fc.get({"action": "query", "titles": title, "prop": "imageinfo",
                   "iiprop": "url|extmetadata|size", "iiurlwidth": str(RENDER)})
    pages = data.get("query", {}).get("pages", [])
    if not pages:
        return None
    ii = (pages[0].get("imageinfo") or [{}])[0]
    meta = ii.get("extmetadata", {})
    return {
        "url": ii.get("thumburl") or ii.get("url"),
        "descurl": ii.get("descriptionurl"),
        "license": meta.get("LicenseShortName", {}).get("value", ""),
        "artist": clean_artist(meta.get("Artist", {}).get("value", "")),
    }

def crop_square(img):
    """Centre horizontally, anchor top — exactly what the polaroid shows."""
    w, h = img.size
    side = min(w, h)
    img = img.crop(((w - side) // 2, 0, (w - side) // 2 + side, side))
    return img.resize((SIDE, SIDE), Image.LANCZOS)

def write_imageset(name, img):
    d = ASSETS / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    for stale in d.glob("*.jpg"):
        stale.unlink()
    img.save(d / f"{name}.jpg", "JPEG", quality=QUALITY, optimize=True,
             progressive=True)
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.jpg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }, indent=2) + "\n")
    return (d / f"{name}.jpg").stat().st_size

def swift_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def main():
    index = json.loads((fc.OUT / "index.json").read_text())
    order = [name for name, _ in BREEDS]
    rows, total = [], 0

    for name in order:
        if name not in PICKS:
            print(f"  skip {name} — no pick")
            continue
        cands = index.get(name, [])
        i = PICKS[name]
        if i >= len(cands):
            print(f"  SKIP {name} — pick [{i}] out of range")
            continue
        info = render_url(cands[i]["title"])
        if not info or not info["url"]:
            print(f"  SKIP {name} — no render URL")
            continue
        dest = HERE / "full" / f"{slug(name)}.jpg"
        dest.parent.mkdir(exist_ok=True)
        if not dest.exists():
            if not fc.download(info["url"], dest):
                print(f"  SKIP {name} — download failed")
                continue
            time.sleep(1.0)
        size = write_imageset(slug(name), crop_square(Image.open(dest).convert("RGB")))
        total += size
        rows.append((slug(name), name, info["artist"], info["license"], info["descurl"]))
        print(f"  {name:34} {size // 1024:4d} KB  {info['license']}")

    body = "\n".join(
        f'    PhotoCredit(imageName: "{s}", breed: "{swift_escape(b)}", '
        f'author: "{swift_escape(a)}", license: "{swift_escape(l)}", '
        f'sourceURL: "{u}"),'
        for s, b, a, l, u in rows)

    CREDITS.write_text(f'''import Foundation

/// Bundled breed reference photos and their attribution.
///
/// Generated by tools/photo-sourcing/build_assets.py from Wikimedia Commons
/// metadata — edit the pipeline, not this file. Every entry is CC0, public
/// domain, CC BY or CC BY-SA; nothing here is NonCommercial, NoDerivs, or
/// AKC's own photography.
///
/// Author and licence are shown for every photo in Image Credits, including
/// the public-domain ones whose licence compels nothing. Lemon Pig does the
/// same, and the alternative is a screen that quietly credits some
/// photographers and not others.
struct PhotoCredit: Identifiable {{
    let id = UUID()
    let imageName: String
    let breed: String
    let author: String
    let license: String
    let sourceURL: String
}}

let photoCredits: [PhotoCredit] = [
{body}
]
''')
    print(f"\n{len(rows)} photos, {total / 1024 / 1024:.1f} MB total, "
          f"{total // 1024 // max(len(rows), 1)} KB average")

if __name__ == "__main__":
    main()
