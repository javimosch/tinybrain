#!/usr/bin/env bash
# Build the browser demo into docs/ (GitHub Pages). Needs zig for C->wasm.
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"
[ -f models/driver.json ] || { echo "models/driver.json missing — run examples/race_train.src first" >&2; exit 1; }
mkdir -p docs
"$MACHIN" encode src/tinybrain.src src/evolve.src src/racesim.src web/race_wasm.src > /tmp/race_wasm.mfl
"$MACHIN" build /tmp/race_wasm.mfl --target wasm -o docs/race.wasm
cp web/index.html docs/index.html
cp models/driver.json docs/driver.json
ls -la docs/
echo "built docs/ — serve locally: python3 -m http.server -d docs 8330"
