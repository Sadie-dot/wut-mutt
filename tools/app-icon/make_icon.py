#!/usr/bin/env python3
"""Render the app icon set from its HTML spec.

The icon is direction 11b of the design handoff ("Polaroid, crested
silhouette"). The handoff's APP_ICON.md gives the layer recipe at 256px
design scale — and it also warns that the full composition is too much
ink at home-screen size, prescribing hand-tuned per-size assets. So this
renders three recipes, each a full-bleed square with no rounded corners
and no alpha (iOS applies the squircle mask itself):

- **full** (1024 marketing): polka field, tilted Polaroid, silhouette,
  outlined script. The handoff's "spoiler…" flap whisper is dropped by
  the user's call — the empty flap is what makes the paper a Polaroid,
  and the whisper was one mark too many even at App Store size.
- **medium** (60pt and 40pt slots): the handoff's own 60pt tile — no
  "spoiler…", the script's stroke thinned to ~5% of type size and nudged
  right so the "?" dot separates from the ear. The script runs 20px at
  the 60 scale rather than the handoff's 17 (the user's call, comped at
  17/20/23): 20 reads clearly at arm's length, 23 starts to swallow the
  tile again.
- **small** (29pt and 20pt slots): silhouette + Polaroid only. At that
  size the script is smudge, and the mark carries the tile alone.

The script fill is #FFD3E3 — the designer's 12a revision ("light-pink
script, plum outline"), replacing the original ice. Ice measured 1.0:1
against the photo's own mid-band, so the letter interiors vanished over
the sky and the outline did all the work; the pink keeps every value
pair within ~7% of ice (chest 12.3:1, field spill 4.3:1, outline
12.1:1) and separates from the sky by hue, so the word finally reads
everywhere it lands.

The one deliberate departure from the handoff's reference HTML: the
script layer embeds the app's own bundled GreatVibes-Regular.ttf as a
data URI instead of fetching Google Fonts, so the icon's "Wut?" can
never silently render in a fallback cursive (which is exactly what a
browser without network does to the reference page).

Usage:  python3 make_icon.py
Writes: ../../WutMutt/Assets.xcassets/AppIcon.appiconset/*.png + Contents.json
Needs:  Google Chrome (headless) on the default macOS path.
"""

import base64
import json
import pathlib
import subprocess
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ROOT = pathlib.Path(__file__).resolve().parents[2]
FONT = ROOT / "WutMutt/Fonts/GreatVibes-Regular.ttf"
OUTDIR = ROOT / "WutMutt/Assets.xcassets/AppIcon.appiconset"

# The crested silhouette from APP_ICON.md: flared butterfly ears, dipped
# crown, cheeks tapering to a visible neck, chest to the photo's bottom.
DOG = (
    "M15 6 C10 14 5 23 3 30 C1 36 5 41 10 44 C15 47 18 50 19 54 "
    "C20 58 19 62 16 66 C10 72 8 84 12 98 L88 98 C92 84 90 72 84 66 "
    "C81 62 80 58 81 54 C82 50 85 47 90 44 C95 41 99 36 97 30 "
    "C95 23 90 14 85 6 C78 11 71 19 68 27 C62 21 57 19 50 19 "
    "C43 19 38 21 32 27 C29 19 22 11 15 6 Z"
)

font64 = base64.b64encode(FONT.read_bytes()).decode()

HEAD = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family:'Great Vibes'; src:url(data:font/ttf;base64,{font64}) format('truetype'); }}
html,body {{ margin:0; padding:0; }}
</style></head><body>"""

SILHOUETTE = (
    '<svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMax meet" '
    'style="position:absolute; bottom:0; left:50%; transform:translateX(-50%); '
    'width:{w}px; height:{h}px;"><path fill="#2B1A20" d="' + DOG + '"/></svg>'
)


def full(px: float) -> str:
    """The complete 11b composition, from the 256px recipe scaled by px/256."""
    s = px / 256
    return f"""{HEAD}
<div style="position:relative; width:{px}px; height:{px}px; overflow:hidden;
     background:linear-gradient(160deg,#C22258 0%,#A31C48 55%,#8C1238 100%);
     display:flex; align-items:center; justify-content:center;">
  <div style="position:absolute; inset:0;
       background-image:radial-gradient(rgba(255,244,239,0.14) {2.4*s}px, transparent {2.4*s}px);
       background-size:{30*s}px {30*s}px;"></div>
  <div style="position:relative; background:#FFFDF9; padding:{9*s}px {9*s}px 0;
       box-shadow:0 {8*s}px {18*s}px rgba(67,8,29,0.3);
       transform:rotate(-5deg) translateY({-16*s}px);
       display:flex; flex-direction:column;">
    <div style="position:relative; width:{132*s}px; height:{132*s}px;
         background:linear-gradient(160deg,#DFF9FF,#A9F2FF 50%,#59C2D6); overflow:hidden;">
      <div style="position:absolute; left:0; right:0; bottom:0; height:{34*s}px;
           background:linear-gradient(0deg,rgba(20,6,13,0.30),transparent); z-index:1;"></div>
      {SILHOUETTE.format(w=124*s, h=121*s)}
    </div>
    <div style="position:absolute; bottom:{33*s}px; left:50%;
         transform:translateX(-52%) rotate(-5deg);
         font-family:'Great Vibes',cursive; font-size:{72*s}px; color:#FFD3E3;
         -webkit-text-stroke:{5*s}px #43081D; paint-order:stroke fill;
         text-shadow:0 {4*s}px {8*s}px rgba(67,8,29,0.5); line-height:1; white-space:nowrap;">Wut?</div>
    <div style="position:relative; height:{32*s}px;"></div>
  </div>
</div>
</body></html>"""


def medium(px: float) -> str:
    """The handoff's 60pt tile scaled by px/60: no whisper, thinner stroke,
    script nudged right so the "?" dot clears the ear."""
    s = px / 60
    return f"""{HEAD}
<div style="position:relative; width:{px}px; height:{px}px; overflow:hidden;
     background:linear-gradient(160deg,#C22258 0%,#A31C48 55%,#8C1238 100%);
     display:flex; align-items:center; justify-content:center;">
  <div style="position:absolute; inset:0;
       background-image:radial-gradient(rgba(255,244,239,0.14) {0.6*s}px, transparent {0.6*s + 0.8}px);
       background-size:{7*s}px {7*s}px;"></div>
  <div style="position:relative; background:#FFFDF9; padding:{2*s}px {2*s}px 0;
       box-shadow:0 {2*s}px {4*s}px rgba(67,8,29,0.3);
       transform:rotate(-5deg) translateY({-2*s}px);
       display:flex; flex-direction:column;">
    <div style="position:relative; width:{31*s}px; height:{31*s}px;
         background:linear-gradient(160deg,#DFF9FF,#A9F2FF 50%,#59C2D6); overflow:hidden;">
      <div style="position:absolute; left:0; right:0; bottom:0; height:{8*s}px;
           background:linear-gradient(0deg,rgba(20,6,13,0.30),transparent); z-index:1;"></div>
      {SILHOUETTE.format(w=30*s, h=30*s)}
    </div>
    <div style="position:absolute; bottom:{7*s}px; left:50%;
         transform:translateX(-46%) rotate(-5deg);
         font-family:'Great Vibes',cursive; font-size:{20*s}px; color:#FFD3E3;
         -webkit-text-stroke:{1.06*s}px #43081D; paint-order:stroke fill;
         text-shadow:0 {1*s}px {2*s}px rgba(67,8,29,0.5); line-height:1; white-space:nowrap;">Wut?</div>
    <div style="height:{8*s}px;"></div>
  </div>
</div>
</body></html>"""


def small(px: float) -> str:
    """The handoff's 29pt tile scaled by px/29: silhouette + Polaroid only."""
    s = px / 29
    return f"""{HEAD}
<div style="position:relative; width:{px}px; height:{px}px; overflow:hidden;
     background:linear-gradient(160deg,#C22258,#8C1238);
     display:flex; align-items:center; justify-content:center;">
  <div style="position:relative; background:#FFFDF9;
       padding:{1.5*s}px {1.5*s}px {4*s}px;
       box-shadow:0 {1*s}px {2*s}px rgba(67,8,29,0.3);
       transform:rotate(-5deg) translateY({-1*s}px);">
    <div style="position:relative; width:{16*s}px; height:{16*s}px;
         background:linear-gradient(160deg,#DFF9FF,#59C2D6); overflow:hidden;">
      {SILHOUETTE.format(w=15*s, h=15*s)}
    </div>
  </div>
</div>
</body></html>"""


# (recipe, point size, scales) — the iPhone slots plus App Store marketing.
SLOTS = [
    (full,   1024, [1]),
    (medium,   60, [2, 3]),
    (medium,   40, [2, 3]),
    (small,    29, [2, 3]),
    (small,    20, [2, 3]),
]

images = []
with tempfile.TemporaryDirectory() as tmp:
    for recipe, pt, scales in SLOTS:
        for scale in scales:
            px = pt * scale
            name = f"AppIcon-{pt}@{scale}x.png" if pt != 1024 else "AppIcon.png"
            page = pathlib.Path(tmp) / f"{pt}-{scale}.html"
            page.write_text(recipe(px))
            subprocess.run([
                CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                f"--window-size={px},{px}", "--force-device-scale-factor=1",
                f"--screenshot={OUTDIR / name}", page.as_uri(),
            ], check=True, capture_output=True)
            if pt == 1024:
                images.append({"filename": name, "idiom": "ios-marketing",
                               "scale": "1x", "size": "1024x1024"})
            else:
                images.append({"filename": name, "idiom": "iphone",
                               "scale": f"{scale}x", "size": f"{pt}x{pt}"})
            print(f"wrote {name} ({px}×{px})")

(OUTDIR / "Contents.json").write_text(json.dumps(
    {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
print("wrote Contents.json")
