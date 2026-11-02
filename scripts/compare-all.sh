#!/bin/bash
# For every state with a mockup shot: writes artifacts/compare/<name>.png = mockup | snapshot | amplified diff, and
# artifacts/compare/report.json with the mean difference of each pair (0 = identical, 255 = inverted). A report, not a gate.
# The shots are <mockupDir>/shots/<mockup>.png from design/states.json (render them with `swift scripts/render-mockup.swift`);
# the snapshots come from scripts/snapshots.sh.
cd "$(dirname "$0")/.."
mkdir -p artifacts/compare
python3 - <<'PY'
import json, subprocess, os
d = json.load(open("design/states.json"))
shots = os.path.join(d["mockupDir"], "shots")
report, missing = {}, []
for name, s in d["states"].items():
    m = s.get("mockup")
    if not m: continue
    shot = s.get("shot") or m.replace("&", "-").replace("=", "-")
    ref, snap = os.path.join(shots, f"{shot}.png"), f"artifacts/snapshots/{name}.png"
    if not (os.path.exists(ref) and os.path.exists(snap)):
        missing.append(name); continue
    out = subprocess.run(["python3", "scripts/compare.py", ref, snap, f"artifacts/compare/{name}.png"], check=True, capture_output=True, text=True).stdout
    report[name] = {"mockup": ref, "snapshot": snap, "meanDiff": json.loads(out)["meanDiff"]}
json.dump({"mockupDir": d["mockupDir"], "states": report, "missing": missing}, open("artifacts/compare/report.json", "w"), indent=2)
for k, v in sorted(report.items(), key=lambda kv: -kv[1]["meanDiff"]): print(f"  {k:24s} mean diff {v['meanDiff']:6.2f}")
if missing: print("missing shot or snapshot:", ", ".join(missing))
print(f"wrote {len(report)} triptychs and artifacts/compare/report.json")
PY
