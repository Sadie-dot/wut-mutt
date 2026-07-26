#!/usr/bin/env python3
"""Lay the Commons thumbnails out as contact sheets for review.

Phase 2 of three. Each cell is the square, top-anchored crop the polaroid
actually shows — not the whole photograph. That distinction matters: judging
whole frames put a basset in the set whose face was outside the crop, and kept
a hand in frame that the full photo made look incidental.

What to look for, in order: nobody in the frame, dog facing the camera, breed
recognisable, background free of ring numbers and sponsor boards.
"""
import json, pathlib, sys
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).parent
CAND = HERE / "candidates"
OUT = HERE / "sheets"
BREEDS_PER_SHEET = 6
CELL = 210
CELL_H = int(CELL / 0.75)
LABEL_H = 20
ROW_LABEL_W = 160

def font(size):
    for path in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                 "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()

def square_preview(img, size=CELL, focus=0.5):
    """What the polaroid shows: 3:4, anchored top. See build_assets.CROP_W.

    Reviewing squares was a mistake once already — the frame is portrait, so a
    square preview shows margin the app crops away, and a dog whose head sits
    near the edge looks fine here and arrives headless on the device.
    """
    w, h = img.size
    want = 3 / 4
    if w / h > want:
        new_w = int(h * want)
        left = max(0, min(int((w - new_w) * focus), w - new_w))
        box = (left, 0, left + new_w, h)
    else:
        box = (0, 0, w, int(w / want))
    return img.crop(box).resize((size, int(size / want)), Image.LANCZOS)

def main():
    index = json.loads((CAND / "index.json").read_text())
    names = [n for n in index if index[n]]
    OUT.mkdir(exist_ok=True)
    for old in OUT.glob("sheet-*.jpg"):
        old.unlink()

    f_row, f_cell = font(15), font(13)
    sheets = 0
    for start in range(0, len(names), BREEDS_PER_SHEET):
        chunk = names[start:start + BREEDS_PER_SHEET]
        cols = max(len(index[n]) for n in chunk)
        W = ROW_LABEL_W + cols * (CELL + 6)
        H = len(chunk) * (CELL_H + LABEL_H + 8)
        sheet = Image.new("RGB", (W, H), (24, 24, 28))
        draw = ImageDraw.Draw(sheet)

        for r, name in enumerate(chunk):
            y = r * (CELL_H + LABEL_H + 8)
            draw.text((6, y + CELL_H // 2 - 10), name.replace(" ", "\n"),
                      font=f_row, fill=(255, 220, 120))
            for c, cand in enumerate(index[name]):
                x = ROW_LABEL_W + c * (CELL + 6)
                path = CAND / cand["local"]
                draw.text((x + 2, y + CELL_H + 3),
                          f"[{c}] {cand['license'][:14]} {cand['w']}x{cand['h']}",
                          font=f_cell, fill=(200, 200, 210))
                if not path.exists():
                    draw.text((x + 10, y + 40), "MISSING", font=f_row, fill=(255, 90, 90))
                    continue
                sheet.paste(square_preview(Image.open(path).convert("RGB")), (x, y))

        sheets += 1
        dest = OUT / f"sheet-{sheets:02d}.jpg"
        sheet.save(dest, quality=90)
        print(f"{dest.name}  {', '.join(chunk)}")
    print(f"\n{sheets} sheets in {OUT}")

if __name__ == "__main__":
    sys.exit(main())
