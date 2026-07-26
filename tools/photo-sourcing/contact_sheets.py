#!/usr/bin/env python3
"""Lay the Commons thumbnails out as contact sheets for review.

Phase 1.5 of three. The detail screen crops its photo square and anchors the
top, so what matters per candidate is: is the dog head-forward, is the head in
the upper middle, and does the frame survive a centre-square crop. That is a
looking-at-it judgement, so the thumbnails get arranged into sheets rather than
inspected one file at a time.

Each cell is drawn twice: the whole thumbnail, and beside it the square the app
would actually show.
"""
import json, pathlib, sys
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).parent
CAND = HERE / "candidates"
OUT = HERE / "sheets"
BREEDS_PER_SHEET = 6
CELL_W, CELL_H = 300, 225        # full thumbnail cell
CROP = 150                       # the square-crop preview beside it
LABEL_H = 22
ROW_LABEL_W = 150

def font(size):
    for path in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                 "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()

def square_preview(img):
    """What the polaroid shows: fill to square, anchored top."""
    w, h = img.size
    side = min(w, h)
    box = ((w - side) // 2, 0, (w - side) // 2 + side, side)
    return img.crop(box).resize((CROP, CROP), Image.LANCZOS)

def main():
    index = json.loads((CAND / "index.json").read_text())
    names = list(index)
    OUT.mkdir(exist_ok=True)
    for old in OUT.glob("sheet-*.jpg"):
        old.unlink()

    f_row, f_cell = font(15), font(13)
    sheets = 0
    for start in range(0, len(names), BREEDS_PER_SHEET):
        chunk = names[start:start + BREEDS_PER_SHEET]
        cols = max((len(index[n]) for n in chunk), default=0)
        if not cols:
            continue
        cell_total_w = CELL_W + CROP + 8
        W = ROW_LABEL_W + cols * (cell_total_w + 10)
        H = len(chunk) * (CELL_H + LABEL_H + 10)
        sheet = Image.new("RGB", (W, H), (24, 24, 28))
        draw = ImageDraw.Draw(sheet)

        for r, name in enumerate(chunk):
            y = r * (CELL_H + LABEL_H + 10)
            draw.text((8, y + CELL_H // 2), name.replace(" ", "\n"),
                      font=f_row, fill=(255, 220, 120))
            for c, cand in enumerate(index[name]):
                x = ROW_LABEL_W + c * (cell_total_w + 10)
                path = CAND / cand["local"]
                label = f"[{c}] {cand['license'][:18]}  {cand['w']}x{cand['h']}"
                draw.text((x, y + CELL_H + 4), label, font=f_cell,
                          fill=(200, 200, 210))
                if not path.exists():
                    draw.text((x + 10, y + 40), "MISSING", font=f_row,
                              fill=(255, 90, 90))
                    continue
                img = Image.open(path).convert("RGB")
                thumb = img.copy()
                thumb.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
                sheet.paste(thumb, (x, y + (CELL_H - thumb.height) // 2))
                sheet.paste(square_preview(img), (x + CELL_W + 8, y))
                draw.rectangle([x + CELL_W + 8, y, x + CELL_W + 8 + CROP,
                                y + CROP], outline=(255, 220, 120), width=2)

        sheets += 1
        dest = OUT / f"sheet-{sheets:02d}.jpg"
        sheet.save(dest, quality=88)
        print(f"{dest.name}  {', '.join(chunk)}")
    print(f"\n{sheets} sheets in {OUT}")

if __name__ == "__main__":
    sys.exit(main())
