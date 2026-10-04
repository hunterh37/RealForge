"""Bottom brand strip for showcase images: wordmark and platforms left, URL right."""
from PIL import Image, ImageDraw, ImageFont
SF = "/System/Library/Fonts/SFNS.ttf"
URL = "github.com/hunterh37/RealityHD"
PLATFORMS = "RealityKit  ·  Apple Vision Pro  ·  iPhone  ·  Mac"

def font(size, weight):
    f = ImageFont.truetype(SF, size); f.set_variation_by_name(weight); return f

OUT_W = 2560   # every image is resampled to this width so text is drawn at full resolution

def brand(path, out=None):
    im = Image.open(path).convert("RGB")
    if im.width != OUT_W:
        im = im.resize((OUT_W, round(im.height * OUT_W / im.width)), Image.LANCZOS)
    W, H = im.size
    u = W / 1280                                 # 2.0 at 2560 px wide
    pad = round(28 * u)
    word, sub = font(round(22 * u), "Semibold"), font(round(13 * u), "Regular")
    # Scrim: transparent to 62% black over the bottom band.
    band = round(96 * u)
    scrim = Image.new("L", (1, band))
    for y in range(band): scrim.putpixel((0, y), round(158 * (y / (band - 1)) ** 1.6))
    black = Image.new("RGB", (W, band), (0, 0, 0))
    im.paste(black, (0, H - band), scrim.resize((W, band)))
    d = ImageDraw.Draw(im)
    base = H - pad
    # Wordmark: "Reality" semibold + "HD" in a thin rounded box.
    wx = pad
    sub_h = sub.getbbox("Ag")[3]
    wy = base - sub_h - round(8 * u) - word.getbbox("R")[3]
    d.text((wx, wy), "Reality", font=word, fill=(255, 255, 255))
    rw = d.textlength("Reality", font=word) + round(5 * u)
    hd = font(round(13 * u), "Bold")
    cap = word.getbbox("R")
    bx0, by0 = wx + rw, wy + cap[1] - round(1 * u)
    bw = d.textlength("HD", font=hd) + round(10 * u)
    bh = cap[3] - cap[1] + round(2 * u)
    d.rounded_rectangle((bx0, by0, bx0 + bw, by0 + bh), radius=round(4 * u), outline=(255, 255, 255), width=max(1, round(1.5 * u)))
    hb = hd.getbbox("HD")
    d.text((bx0 + (bw - (hb[2] - hb[0])) / 2 - hb[0], by0 + (bh - (hb[3] - hb[1])) / 2 - hb[1]), "HD", font=hd, fill=(255, 255, 255))
    # Platforms line under the wordmark, URL right-aligned on the same baseline.
    d.text((wx, base), PLATFORMS, font=sub, fill=(225, 225, 225), anchor="ls")
    d.text((W - pad, base), URL, font=sub, fill=(235, 235, 235), anchor="rs")
    im.save(out or path, quality=93, subsampling=0, optimize=True)

if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]: brand(p, p.rsplit(".", 1)[0] + ".jpg")
