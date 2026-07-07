#!/usr/bin/env bash
# Build the tinybrain race game (M2). Vendors static raylib if no system one.
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
MODS="src/tinybrain.src src/evolve.src src/racesim.src game/race_game.src"
if pkg-config --exists raylib 2>/dev/null || [ -f /usr/include/raylib.h ]; then
    "$MACHIN" encode $MODS > race_game.mfl
else
    RL="raylib-5.0_linux_amd64"; D="vendor/$RL"
    if [ ! -f "$D/lib/libraylib.a" ]; then
        mkdir -p vendor
        if [ -d "/tmp/rl/$RL" ]; then cp -r "/tmp/rl/$RL" vendor/
        else curl -fsSL "https://github.com/raysan5/raylib/releases/download/5.0/$RL.tar.gz" | tar xz -C vendor; fi
    fi
    INC="$PWD/$D/include"; LIB="$PWD/$D/lib"
    "$MACHIN" encode $MODS | sed "s#header \"raylib.h\"#cflags \"-I${INC} -L${LIB}\" header \"raylib.h\"#; s#link \"raylib\"#link \":libraylib.a\"#" > race_game.mfl
fi
"$MACHIN" build race_game.mfl -o race_game
rm -f race_game.mfl
echo "built ./race_game — run it from the repo root (loads models/driver.json)"
