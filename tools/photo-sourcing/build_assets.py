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
import hashlib, html, json, pathlib, re, shutil, sys, time, urllib.parse, urllib.request
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

# The polaroid is NOT square. Its photo area is a fixed 218pt wide by
# max(200, railHeight - 41) tall — about 218x256 at default type, and taller
# still as Dynamic Type grows the trait rail beside it. scaledToFill against a
# square source therefore scales to fill the height and crops the sides, which
# is how a Plott Hound lost its nose off the right edge.
#
# Bundling 3:4 means the source is always narrower than the frame, so the app
# only ever trims the bottom — and the top, where the head is, is anchored and
# safe. Judge candidates at this aspect, not as squares.
CROP_W, CROP_H = 700, 933
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
    # Flickr display names sometimes carry licensing boilerplate as a trailing
    # parenthetical — "Olgierd (Creative Commons licensed only)". That's a
    # statement about the account, not part of anyone's name.
    s = re.sub(r"\s*\([^()]*(?:licen[cs]e|creative commons)[^()]*\)$", "", s,
               flags=re.IGNORECASE).strip()
    # Commons templates sometimes render twice: "Unknown author Unknown author".
    s = re.sub(r"^(.+?)(?:\s+\1)+$", r"\1", s).strip()
    if s.lower() in ("unknown author", "author unknown", "not provided"):
        s = "Unknown"
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

def crop_frame(img, focus=0.5):
    """Anchor top, take the widest 3:4 that fits, positioned by `focus`.

    `focus` is where the dog is across the frame, 0 left to 1 right. Centre is
    right for most photographs and wrong for the ones where the subject sits
    off to one side — a dog lying with its head at the edge loses the head.
    """
    w, h = img.size
    want = CROP_W / CROP_H
    if w / h > want:                       # too wide: trim the sides
        new_w = int(h * want)
        left = int((w - new_w) * focus)
        left = max(0, min(left, w - new_w))
        box = (left, 0, left + new_w, h)
    else:                                  # too tall: trim the bottom
        box = (0, 0, w, int(w / want))
    return img.crop(box).resize((CROP_W, CROP_H), Image.LANCZOS)

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

# Hand-curated attributions where the Commons artist field can't be unwrapped
# by rule. The Black Mouth Cur's field fuses the uploader's username with the
# photographer's name ("Jwschulze Steve Howard"); the human name is the
# attribution.
ARTIST_OVERRIDES = {
    "File:Howard Line Southern Black Mouth Cur (Male).jpg": "Steve Howard",
}

def main():
    index = json.loads((fc.OUT / "index.json").read_text())
    order = [name for name, _ in BREEDS]
    rows, total = [], 0

    for name in order:
        if name not in PICKS:
            print(f"  skip {name} — no pick")
            continue
        cands = index.get(name, [])
        # A pick is an index, or (index, focus) when the dog is off-centre.
        pick = PICKS[name]
        i, focus = pick if isinstance(pick, tuple) else (pick, 0.5)
        if i >= len(cands):
            print(f"  SKIP {name} — pick [{i}] out of range")
            continue
        info = render_url(cands[i]["title"])
        if not info or not info["url"]:
            print(f"  SKIP {name} — no render URL")
            continue
        # Cache keyed by the picked file, not just the breed: a slug-only key
        # survives a pick CHANGE and silently re-crops the stale photo while
        # the credits row moves to the new one — a misattribution factory.
        # (Caught live: the Poodle recast cropped the old show portrait under
        # the new photographer's name.) Old slug-only files just orphan.
        tag = hashlib.md5(cands[i]["title"].encode()).hexdigest()[:8]
        dest = HERE / "full" / f"{slug(name)}-{tag}.jpg"
        dest.parent.mkdir(exist_ok=True)
        if not dest.exists():
            if not fc.download(info["url"], dest):
                print(f"  SKIP {name} — download failed")
                continue
            time.sleep(1.0)
        size = write_imageset(slug(name),
                              crop_frame(Image.open(dest).convert("RGB"), focus))
        total += size
        artist = ARTIST_OVERRIDES.get(cands[i]["title"], info["artist"])
        rows.append((slug(name), name, artist, info["license"], info["descurl"]))
        print(f"  {name:34} {size // 1024:4d} KB  {info['license']}")

    # Drop imagesets for breeds that are no longer picked, so a breed removed
    # from the set leaves nothing behind in the app bundle.
    keep = {s for s, *_ in rows}
    for stale in ASSETS.glob("breed-*.imageset"):
        if stale.stem not in keep:
            shutil.rmtree(stale)
            print(f"  removed {stale.stem} — no longer in the set")

    body = "\n".join(
        f'    PhotoCredit(imageName: "{s}", breed: "{swift_escape(b)}", '
        f'author: "{swift_escape(a)}", license: "{swift_escape(l)}", '
        f'sourceURL: "{u}"),'
        for s, b, a, l, u in rows)

    CREDITS.write_text(f'''import Foundation

/// Bundled breed reference photos and their attribution.
///
/// Generated by tools/photo-sourcing/build_assets.py from Wikimedia Commons
/// metadata — edit the pipeline, not this file.
///
/// Every entry is CC0, public domain, or CC BY. ShareAlike is excluded on
/// purpose: the square crop the detail screen applies is arguably an
/// adaptation, and CC BY-SA 4.0's bar on technological measures is unsettled
/// against App Store DRM. Neither question is worth carrying for decorative
/// photography, and ruling the family out cost exactly one breed.
///
/// Author and licence are shown for every photo in Image Credits, including
/// the CC0 and public-domain ones whose licence compels nothing. Lemon Pig
/// does the same, and the alternative is a screen that quietly credits some
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
