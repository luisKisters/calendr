#!/usr/bin/env python3
"""Render audit evidence using a baseline or fixed Calendr executable."""
import argparse
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument('--binary', required=True)
parser.add_argument('--phase', choices=['before', 'after'], required=True)
parser.add_argument('--out', default='artifacts/dmg-audit')
args = parser.parse_args()
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
for state in ['dst', 'midnight-initial', 'midnight-all-day', 'midnight-restored', 'full-day', 'overnight']:
    subprocess.run([args.binary, '--snapshot', 'audit-' + state, '--out', str(out / f'{state}-{args.phase}.png'), '--scale', '1'], check=True)

# A labeled state sequence, not a recording of animation or live pointer delivery.
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 22)
frames = []
for state, label in [('initial', '1. Original: 22:00 to midnight'), ('all-day', '2. Turn All day on'), ('restored', '3. Turn All day off')]:
    with Image.open(out / f'midnight-{state}-{args.phase}.png') as snapshot:
        canvas = Image.new('RGB', (snapshot.width, snapshot.height + 44), '#eeeeee')
        canvas.paste(snapshot, (0, 44))
    ImageDraw.Draw(canvas).text((20, 10), f'{args.phase.upper()}  |  {label}', font=font, fill='#111111')
    frames.append(canvas)
frames[0].save(out / f'midnight-{args.phase}.gif', save_all=True, append_images=frames[1:], duration=[1400, 1000, 2200], loop=0, optimize=True)
