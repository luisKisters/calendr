#!/bin/bash
# Renders every state in design/states.json into artifacts/snapshots/<name>.png (offscreen, no screen access needed).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG" >/dev/null
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Calendr"
OUT=artifacts/snapshots
mkdir -p "$OUT"
fail=0
while IFS=$'\t' read -r name state size; do
  if ! "$BIN" --snapshot "$state" --out "$OUT/$name.png" --size "$size" >/dev/null; then echo "FAILED: $name"; fail=1; fi
done < <(python3 - <<'PY'
import json
d = json.load(open("design/states.json"))
for name, s in d["states"].items():
    print(f"{name}\t{s.get('state', name)}\t{s.get('size', d['size'])}")
PY
)
[ $fail -eq 0 ] && echo "rendered $(ls "$OUT"/*.png | wc -l | tr -d ' ') snapshots into $OUT"
exit $fail
