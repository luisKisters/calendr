#!/usr/bin/env python3
"""Side-by-side and diff of a snapshot against a reference image: compare.py ref.png snap.png out.png [x0 y0 x1 y1 in ref px]
Writes the triptych (reference | snapshot | difference x4) and prints {"meanDiff": <mean absolute RGB difference, 0-255>} as JSON."""
import json, sys
from PIL import Image, ImageChops, ImageStat
ref = Image.open(sys.argv[1]).convert("RGB")
snap = Image.open(sys.argv[2]).convert("RGB").resize(ref.size, Image.LANCZOS)
box = tuple(int(v) for v in sys.argv[4:8]) if len(sys.argv) >= 8 else (0, 0, ref.width, ref.height)
a, b = ref.crop(box), snap.crop(box)
raw = ImageChops.difference(a, b)
mean = sum(ImageStat.Stat(raw).mean) / 3
diff = raw.point(lambda v: min(255, v * 4))
w, h = a.size
out = Image.new("RGB", (w * 3 + 20, h), (60, 60, 60))
out.paste(a, (0, 0)); out.paste(b, (w + 10, 0)); out.paste(diff, (2 * w + 20, 0))
scale = min(1, 3000 / out.width)
if scale < 1: out = out.resize((int(out.width * scale), int(out.height * scale)), Image.LANCZOS)
out.save(sys.argv[3])
print(json.dumps({"meanDiff": round(mean, 3)}))
