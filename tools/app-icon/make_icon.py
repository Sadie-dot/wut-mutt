#!/usr/bin/env python3
"""Render the app icon master from its HTML spec.

The icon is direction 11b of the design handoff ("Polaroid, crested
silhouette"): the handoff's APP_ICON.md gives the layer recipe at 256px
design scale, and this script is that recipe multiplied by 4 into a
1024×1024 full-bleed square — no rounded corners and no alpha, because
iOS applies the squircle mask itself.

The one deliberate departure from the handoff's reference HTML: the
script layer embeds the app's own bundled GreatVibes-Regular.ttf as a
data URI instead of fetching Google Fonts, so the icon's "Wut?" can
never silently render in a fallback cursive (which is exactly what a
browser without network does to the reference page).

Usage:  python3 make_icon.py
Writes: ../../WutMutt/Assets.xcassets/AppIcon.appiconset/AppIcon.png
Needs:  Google Chrome (headless) on the default macOS path.
"""

import base64
import pathlib
import subprocess
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ROOT = pathlib.Path(__file__).resolve().parents[2]
FONT = ROOT / "WutMutt/Fonts/GreatVibes-Regular.ttf"
OUT = ROOT / "WutMutt/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

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

HTML = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family:'Great Vibes'; src:url(data:font/ttf;base64,{font64}) format('truetype'); }}
html,body {{ margin:0; padding:0; }}
</style></head><body>
<div style="position:relative; width:1024px; height:1024px; overflow:hidden;
     background:linear-gradient(160deg,#C22258 0%,#A31C48 55%,#8C1238 100%);
     display:flex; align-items:center; justify-content:center;">
  <div style="position:absolute; inset:0;
       background-image:radial-gradient(rgba(255,244,239,0.14) 9.6px, transparent 9.6px);
       background-size:120px 120px;"></div>
  <div style="position:relative; background:#FFFDF9; padding:36px 36px 0;
       box-shadow:0 32px 72px rgba(67,8,29,0.3);
       transform:rotate(-5deg) translateY(-64px);
       display:flex; flex-direction:column;">
    <div style="position:relative; width:528px; height:528px;
         background:linear-gradient(160deg,#DFF9FF,#A9F2FF 50%,#59C2D6); overflow:hidden;">
      <div style="position:absolute; left:0; right:0; bottom:0; height:136px;
           background:linear-gradient(0deg,rgba(20,6,13,0.30),transparent); z-index:1;"></div>
      <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMax meet"
           style="position:absolute; bottom:0; left:50%; transform:translateX(-50%); width:496px; height:484px;">
        <path fill="#2B1A20" d="{DOG}"/>
      </svg>
    </div>
    <div style="position:absolute; bottom:132px; left:50%;
         transform:translateX(-52%) rotate(-5deg);
         font-family:'Great Vibes',cursive; font-size:288px; color:#A9F2FF;
         -webkit-text-stroke:20px #43081D; paint-order:stroke fill;
         text-shadow:0 16px 32px rgba(67,8,29,0.5); line-height:1; white-space:nowrap;">Wut?</div>
    <div style="position:relative; height:128px;">
      <div style="position:absolute; right:64px; bottom:20px;
           font-family:'Great Vibes',cursive; font-size:72px;
           color:rgba(140,53,87,0.55); transform:rotate(-3deg);">spoiler…</div>
    </div>
  </div>
</div>
</body></html>"""

with tempfile.TemporaryDirectory() as tmp:
    page = pathlib.Path(tmp) / "icon.html"
    page.write_text(HTML)
    subprocess.run([
        CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
        "--window-size=1024,1024", "--force-device-scale-factor=1",
        f"--screenshot={OUT}", page.as_uri(),
    ], check=True, capture_output=True)

print(f"wrote {OUT}")
