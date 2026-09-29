#!/bin/bash
# For every state that has a mockup shot: writes artifacts/compare/<name>.png = mockup | snapshot | amplified diff.
cd "$(dirname "$0")/.."
mkdir -p artifacts/compare
python3 - <<'PY'
import json, subprocess, os
d = json.load(open("design/states.json"))
for name, s in d["states"].items():
    m = s.get("mockup")
    if not m: continue
    ref = f"design/mockup-v2/shots/{m}.png"
    snap = f"artifacts/snapshots/{name}.png"
    if os.path.exists(ref) and os.path.exists(snap):
        subprocess.run(["python3", "scripts/compare.py", ref, snap, f"artifacts/compare/{name}.png"], check=True)
print("wrote artifacts/compare/*.png")
PY
