#!/usr/bin/env python3
"""Burns small caption chips into a rendered video (ffmpeg here has no drawtext, so chips are PNGs overlaid in time).

  scripts/caption-video.py <in.mp4> <captions.json> <out.mp4> [--speed 1] [--offset 0]

captions.json: [{"start": s, "end": s, "text": "Drag to create", "keys": ["⌘", "K"]}, ...] in source seconds.
--speed divides the times (match `glide render --speed`), --offset shifts them (match `--start`).
Chips sit bottom-centre in the padding under the window, so Glide's zoom never crops them.
"""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

FONT = os.path.join(os.path.dirname(__file__), "..", "Sources", "Calendr", "Resources", "Fonts", "InstrumentSans.ttf")


SYMBOLS = "/System/Library/Fonts/SFNS.ttf"   # keycaps: Instrument Sans has no ⌘ ⌥ ⇧ ↩ glyphs


def keyfont(size):
    try:
        f = ImageFont.truetype(SYMBOLS, size)
        try: f.set_variation_by_name("Semibold")
        except Exception: pass
        return f
    except OSError:
        return font(size, 600)


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([100, weight])
    return f


def probe(path):
    out = subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height:format=duration", "-of", "default=nw=1", path]).decode()
    v = dict(line.split("=", 1) for line in out.strip().splitlines())
    return int(v["width"]), int(v["height"]), float(v["duration"])


def chip(text, keys, H):
    """One pill: optional keycaps, then the text. Sized relative to the video height."""
    s = H / 1080
    ft, fk = font(round(25 * s), 500), keyfont(round(20 * s))
    pad_x, pad_y, gap, kpad = round(20 * s), round(12 * s), round(10 * s), round(8 * s)
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    tw = d.textlength(text, font=ft)
    kws = [max(d.textlength(k, font=fk) + 2 * kpad, round(30 * s)) for k in keys]
    kh = round(30 * s)
    th = round(25 * s * 1.25)
    w = round(pad_x * 2 + tw + (sum(kws) + gap * len(kws) + (gap if keys else 0) * 0) + (gap * (len(keys) - 1) if keys else 0) + (gap if keys else 0))
    h = max(th, kh) + pad_y * 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g = ImageDraw.Draw(img)
    g.rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 2, fill=(17, 17, 21, 232), outline=(255, 255, 255, 40), width=max(1, round(s)))
    x = pad_x
    for k, kw in zip(keys, kws):
        y0 = (h - kh) // 2
        g.rounded_rectangle([x, y0, x + kw, y0 + kh], radius=round(7 * s), fill=(255, 255, 255, 30), outline=(255, 255, 255, 46), width=max(1, round(s)))
        g.text((x + kw / 2, h / 2), k, font=fk, fill=(237, 236, 241, 255), anchor="mm")
        x += kw + gap
    g.text((x, h / 2), text, font=ft, fill=(237, 236, 241, 255), anchor="lm")
    return img


def main():
    a = sys.argv[1:]
    src, caps_path, out = a[0], a[1], a[2]
    speed = float(a[a.index("--speed") + 1]) if "--speed" in a else 1.0
    offset = float(a[a.index("--offset") + 1]) if "--offset" in a else 0.0
    caps = json.load(open(caps_path))
    W, H, dur = probe(src)
    tmp = tempfile.mkdtemp(prefix="captions-")
    inputs, filters, last = [], [], "0:v"
    margin = round(H * 0.032)
    for i, c in enumerate(caps):
        img = chip(c["text"], c.get("keys", []), H)
        p = os.path.join(tmp, f"c{i}.png"); img.save(p)
        inputs += ["-i", p]
        t0 = max(0.0, (c["start"] - offset) / speed); t1 = (c["end"] - offset) / speed
        if t1 <= 0: continue
        x = (W - img.width) // 2; y = H - margin - img.height
        lab = f"v{i}"
        # short fade in and out so chips don't pop
        filters.append(f"[{i + 1}:v]format=rgba,fade=t=in:st={t0:.3f}:d=0.12:alpha=1,fade=t=out:st={max(t0, t1 - 0.12):.3f}:d=0.12:alpha=1[f{i}]")
        filters.append(f"[{last}][f{i}]overlay={x}:{y}:eof_action=pass:enable='between(t,{t0:.3f},{t1:.3f})'[{lab}]")
        last = lab
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", src]
    for p in inputs[1::2]:
        cmd += ["-loop", "1", "-t", f"{dur:.3f}", "-i", p]   # bounded, or the graph never ends
    cmd += ["-filter_complex", ";".join(filters), "-map", f"[{last}]", "-map", "0:a?", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-shortest", out]
    subprocess.check_call(cmd)
    print(out)


if __name__ == "__main__":
    main()
