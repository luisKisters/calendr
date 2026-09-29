#!/usr/bin/env python3
"""Prints mean absolute difference per cell of a coarse grid between a mockup shot and a snapshot: diffgrid.py ref.png snap.png [cols rows]"""
import sys
from PIL import Image, ImageChops
ref = Image.open(sys.argv[1]).convert("L"); snap = Image.open(sys.argv[2]).convert("L").resize(ref.size)
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 8; rows = int(sys.argv[4]) if len(sys.argv) > 4 else 5
diff = ImageChops.difference(ref, snap)
w, h = ref.size
tot = sum(diff.getdata()) / (w * h) if False else None
print("mean abs diff per cell (0-255):")
for r in range(rows):
    line = []
    for c in range(cols):
        cell = diff.crop((c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows))
        px = list(cell.getdata())
        line.append(f"{sum(px) / len(px):5.1f}")
    print(" ".join(line))
