#!/usr/bin/env python3
"""Frame simulator captures for the README: rounded corners, hairline border, soft shadow,
caption pill, transparent margin (reads on GitHub light and dark themes).
usage: Scripts/frame.py <in.png> <out.png> <caption> [width]"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

src, dst, caption = sys.argv[1], sys.argv[2], sys.argv[3]
width = int(sys.argv[4]) if len(sys.argv) > 4 else 1600
s = width / 1600
im = Image.open(src).convert("RGB")
im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
w, h = im.size
r, pad = round(36 * s), round(56 * s)

mask = Image.new("L", (w, h), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
card = Image.new("RGBA", (w, h))
card.paste(im, (0, 0), mask)
d = ImageDraw.Draw(card)
d.rounded_rectangle((0, 0, w - 1, h - 1), r, outline=(255, 255, 255, 70), width=max(1, round(2 * s)))

def font(size):
    for f in ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try: return ImageFont.truetype(f, size)
        except OSError: pass
    return ImageFont.load_default()

f = font(round(26 * s))
tb = d.textbbox((0, 0), caption, font=f)
tw, th = tb[2] - tb[0], tb[3] - tb[1]
px, py, m = round(20 * s), round(12 * s), round(28 * s)
box = (m, h - m - th - 2 * py, m + tw + 2 * px, h - m)
pill = Image.new("RGBA", (w, h))
ImageDraw.Draw(pill).rounded_rectangle(box, (box[3] - box[1]) // 2, fill=(0, 0, 0, 140))
card = Image.alpha_composite(card, pill)
ImageDraw.Draw(card).text((box[0] + px - tb[0], box[1] + py - tb[1]), caption, font=f, fill=(255, 255, 255, 235))

out = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + round(14 * s), pad + w, pad + h + round(14 * s)), r, fill=(0, 0, 0, 110))
out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(round(22 * s))))
out.alpha_composite(card, (pad, pad))
out.save(dst, optimize=True)
