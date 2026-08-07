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

The script fill is the share card's spoiler-gold (#FFD400) over the
original sky photo — the 2026-08-04 revision, the user's own inversion
of a gold-photo/ice-script comp that read as unintentional (all-warm
icon, lone cool word, two one-off colours). This arrangement wins on
structure and on grammar: the cool sky in the warm raspberry field is
the window architecture the icon was designed around, and gold type in
a plum outline is exactly how the share card bills its headline, so
icon and card speak one system. It is also the most legible fill this
script has worn — hue-opposed to the sky above it, value-opposed to
the silhouette below it, where the 12a pink separated by value alone
and the original ice by neither (1.0:1 on the sky's mid-band, the
hollow-letters failure that got ice retired). Distinct from the
2026-08-03 rejection: that was gold as an *outline*, which dissolved
against fill and sky; gold as a *fill inside* the plum stroke is the
card's own measured-and-shipped arrangement.

The set also carries iOS 18 dark and tinted appearances, selected by
palette rather than post-processing so each stays a design:

- **any**: the shipped light icon, byte-identical to the pre-variant
  renders (the palette strings reproduce the original CSS exactly).
- **dark**: the field drops ~two stops so the tile recedes with a dark
  home screen; the cream Polaroid, sky window, and gold script stay —
  they are the foreground accents the HIG asks to keep. The paper's
  plum shadow goes black (a plum shadow reads as mud on the deep field)
  and the polka dots ease to 0.11 so they don't sparkle.
- **tinted**: a deliberate grayscale design, not an auto-desaturation —
  iOS multiplies the user's tint over the grayscale, so *value* is the
  whole design. The value ladder keeps the icon's hierarchy: paper
  brightest (strongest tint), script just under it, sky mid, field
  near-black, silhouette darkest. Auto-graying the light icon instead
  would land field and sky a muddy half-step apart and cost the window
  its pop.

**Why dark/tinted are single 1024s while light stays per-size**: actool
does not accept appearance variants on per-size app-icon slots — 18
per-size dark/tinted entries compile to "unassigned children" and are
silently dropped (verified against Xcode 26 actool; Apple's docs only
describe appearances for Single Size). The supported maximum is this
hybrid: hand-tuned per-size slots for the light icon plus one universal
1024 per appearance. Because iOS derives every dark/tinted size by
scaling that lone 1024, it is rendered from the **medium** recipe, not
the full composition — the home screen is what dark/tinted modes exist
for, and the full recipe at 60pt is exactly the too-much-ink failure
the per-size system was built to avoid. The trade: Settings/Spotlight
derive their small dark/tinted tiles from the same image, where the
script softens toward smudge — accepted, since the scriptless small
recipe can't be expressed in this scheme at all.

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

# One palette per appearance. The "any" strings reproduce the original CSS
# byte-for-byte — regenerating must leave the shipped light PNGs unchanged
# (headless Chrome renders deterministically, so identical HTML is the proof
# of no collateral damage).
PALETTES = {
    "any": {
        "field":       "linear-gradient(160deg,#C22258 0%,#A31C48 55%,#8C1238 100%)",
        "field_small": "linear-gradient(160deg,#C22258,#8C1238)",
        "dot":         "rgba(255,244,239,0.14)",
        "paper":       "#FFFDF9",
        "shadow":      "rgba(67,8,29,0.3)",
        "sky":         "linear-gradient(160deg,#DFF9FF,#A9F2FF 50%,#59C2D6)",
        "sky_small":   "linear-gradient(160deg,#DFF9FF,#59C2D6)",
        "scrim":       "rgba(20,6,13,0.30)",
        "dog":         "#2B1A20",
        "script":      "#FFD400",
        "stroke":      "#43081D",
        "text_shadow": "rgba(67,8,29,0.5)",
    },
    "dark": {
        "field":       "linear-gradient(160deg,#7E1038 0%,#5C0A28 55%,#42061C 100%)",
        "field_small": "linear-gradient(160deg,#7E1038,#42061C)",
        "dot":         "rgba(255,244,239,0.11)",
        "paper":       "#FFFDF9",
        "shadow":      "rgba(0,0,0,0.45)",
        "sky":         "linear-gradient(160deg,#DFF9FF,#A9F2FF 50%,#59C2D6)",
        "sky_small":   "linear-gradient(160deg,#DFF9FF,#59C2D6)",
        "scrim":       "rgba(20,6,13,0.30)",
        "dog":         "#2B1A20",
        "script":      "#FFD400",
        "stroke":      "#43081D",
        "text_shadow": "rgba(0,0,0,0.5)",
    },
    "tinted": {
        "field":       "linear-gradient(160deg,#1C1C1C 0%,#111111 55%,#0A0A0A 100%)",
        "field_small": "linear-gradient(160deg,#1C1C1C,#0A0A0A)",
        "dot":         "rgba(255,255,255,0.06)",
        "paper":       "#E9E9E9",
        "shadow":      "rgba(0,0,0,0.6)",
        "sky":         "linear-gradient(160deg,#CFCFCF,#ABABAB 50%,#6F6F6F)",
        "sky_small":   "linear-gradient(160deg,#CFCFCF,#6F6F6F)",
        "scrim":       "rgba(0,0,0,0.30)",
        "dog":         "#101010",
        "script":      "#F4F4F4",
        "stroke":      "#111111",
        "text_shadow": "rgba(0,0,0,0.5)",
    },
}

font64 = base64.b64encode(FONT.read_bytes()).decode()

HEAD = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family:'Great Vibes'; src:url(data:font/ttf;base64,{font64}) format('truetype'); }}
html,body {{ margin:0; padding:0; }}
</style></head><body>"""

SILHOUETTE = (
    '<svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMax meet" '
    'style="position:absolute; bottom:0; left:50%; transform:translateX(-50%); '
    'width:{w}px; height:{h}px;"><path fill="{fill}" d="' + DOG + '"/></svg>'
)


def full(px: float, p: dict) -> str:
    """The complete 11b composition, from the 256px recipe scaled by px/256."""
    s = px / 256
    return f"""{HEAD}
<div style="position:relative; width:{px}px; height:{px}px; overflow:hidden;
     background:{p['field']};
     display:flex; align-items:center; justify-content:center;">
  <div style="position:absolute; inset:0;
       background-image:radial-gradient({p['dot']} {2.4*s}px, transparent {2.4*s}px);
       background-size:{30*s}px {30*s}px;"></div>
  <div style="position:relative; background:{p['paper']}; padding:{9*s}px {9*s}px 0;
       box-shadow:0 {8*s}px {18*s}px {p['shadow']};
       transform:rotate(-5deg) translateY({-16*s}px);
       display:flex; flex-direction:column;">
    <div style="position:relative; width:{132*s}px; height:{132*s}px;
         background:{p['sky']}; overflow:hidden;">
      <div style="position:absolute; left:0; right:0; bottom:0; height:{34*s}px;
           background:linear-gradient(0deg,{p['scrim']},transparent); z-index:1;"></div>
      {SILHOUETTE.format(w=124*s, h=121*s, fill=p['dog'])}
    </div>
    <div style="position:absolute; bottom:{33*s}px; left:50%;
         transform:translateX(-52%) rotate(-5deg);
         font-family:'Great Vibes',cursive; font-size:{72*s}px; color:{p['script']};
         -webkit-text-stroke:{5*s}px {p['stroke']}; paint-order:stroke fill;
         text-shadow:0 {4*s}px {8*s}px {p['text_shadow']}; line-height:1; white-space:nowrap;">Wut?</div>
    <div style="position:relative; height:{32*s}px;"></div>
  </div>
</div>
</body></html>"""


def medium(px: float, p: dict) -> str:
    """The handoff's 60pt tile scaled by px/60: no whisper, thinner stroke,
    script nudged right so the "?" dot clears the ear."""
    s = px / 60
    return f"""{HEAD}
<div style="position:relative; width:{px}px; height:{px}px; overflow:hidden;
     background:{p['field']};
     display:flex; align-items:center; justify-content:center;">
  <div style="position:absolute; inset:0;
       background-image:radial-gradient({p['dot']} {0.6*s}px, transparent {0.6*s + 0.8}px);
       background-size:{7*s}px {7*s}px;"></div>
  <div style="position:relative; background:{p['paper']}; padding:{2*s}px {2*s}px 0;
       box-shadow:0 {2*s}px {4*s}px {p['shadow']};
       transform:rotate(-5deg) translateY({-2*s}px);
       display:flex; flex-direction:column;">
    <div style="position:relative; width:{31*s}px; height:{31*s}px;
         background:{p['sky']}; overflow:hidden;">
      <div style="position:absolute; left:0; right:0; bottom:0; height:{8*s}px;
           background:linear-gradient(0deg,{p['scrim']},transparent); z-index:1;"></div>
      {SILHOUETTE.format(w=30*s, h=30*s, fill=p['dog'])}
    </div>
    <!-- Two stacked copies fake a heavier weight Great Vibes doesn't have:
         the top copy strokes itself in its own fill, fattening the glyph
         core by ~0.22px per side at the 60 scale, and the bottom copy
         widens its plum stroke by the same amount so the visible rim stays
         constant. 0.45 is the ceiling before the W's loops clog. -->
    <div style="position:absolute; bottom:{7*s}px; left:50%;
         transform:translateX(-46%) rotate(-5deg);
         font-family:'Great Vibes',cursive; font-size:{20*s}px; color:{p['script']};
         -webkit-text-stroke:{1.51*s}px {p['stroke']}; paint-order:stroke fill;
         text-shadow:0 {1*s}px {2*s}px {p['text_shadow']}; line-height:1; white-space:nowrap;">Wut?</div>
    <div style="position:absolute; bottom:{7*s}px; left:50%;
         transform:translateX(-46%) rotate(-5deg);
         font-family:'Great Vibes',cursive; font-size:{20*s}px; color:{p['script']};
         -webkit-text-stroke:{0.45*s}px {p['script']}; paint-order:stroke fill;
         line-height:1; white-space:nowrap;">Wut?</div>
    <div style="height:{8*s}px;"></div>
  </div>
</div>
</body></html>"""


def small(px: float, p: dict) -> str:
    """The handoff's 29pt tile scaled by px/29: silhouette + Polaroid only."""
    s = px / 29
    return f"""{HEAD}
<div style="position:relative; width:{px}px; height:{px}px; overflow:hidden;
     background:{p['field_small']};
     display:flex; align-items:center; justify-content:center;">
  <div style="position:relative; background:{p['paper']};
       padding:{1.5*s}px {1.5*s}px {4*s}px;
       box-shadow:0 {1*s}px {2*s}px {p['shadow']};
       transform:rotate(-5deg) translateY({-1*s}px);">
    <div style="position:relative; width:{16*s}px; height:{16*s}px;
         background:{p['sky_small']}; overflow:hidden;">
      {SILHOUETTE.format(w=15*s, h=15*s, fill=p['dog'])}
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

# The appearance variants: one universal 1024 each (see the docstring for
# why they can't be per-size), rendered from the medium recipe because the
# home screen is their destination.
VARIANTS = [
    ("dark",   "AppIcon-dark.png"),
    ("tinted", "AppIcon-tinted.png"),
]


def render(html: str, px: float, name: str, tmp: str) -> None:
    page = pathlib.Path(tmp) / f"{name}.html"
    page.write_text(html)
    subprocess.run([
        CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
        f"--window-size={px},{px}", "--force-device-scale-factor=1",
        f"--screenshot={OUTDIR / name}", page.as_uri(),
    ], check=True, capture_output=True)
    print(f"wrote {name} ({px}×{px})")


images = []
with tempfile.TemporaryDirectory() as tmp:
    for recipe, pt, scales in SLOTS:
        for scale in scales:
            px = pt * scale
            name = f"AppIcon-{pt}@{scale}x.png" if pt != 1024 else "AppIcon.png"
            render(recipe(px, PALETTES["any"]), px, name, tmp)
            if pt == 1024:
                images.append({"filename": name, "idiom": "ios-marketing",
                               "scale": "1x", "size": "1024x1024"})
            else:
                images.append({"filename": name, "idiom": "iphone",
                               "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    for mode, name in VARIANTS:
        render(medium(1024, PALETTES[mode]), 1024, name, tmp)
        images.append({
            "appearances": [{"appearance": "luminosity", "value": mode}],
            "filename": name, "idiom": "universal",
            "platform": "ios", "size": "1024x1024",
        })

(OUTDIR / "Contents.json").write_text(json.dumps(
    {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
print("wrote Contents.json")
