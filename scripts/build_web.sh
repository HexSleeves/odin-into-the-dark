#!/usr/bin/env bash
set -euo pipefail

# Configurable paths
EMSDK_DIR="${EMSDK_DIR:-/Users/lecoqjacob/Developer/games/emsdk}"
ODIN_ROOT="$(odin root)"
OUT_DIR="build/web"

mkdir -p "${OUT_DIR}"

# Activate Emscripten
EMSDK_QUIET=1 source "${EMSDK_DIR}/emsdk_env.sh"

# Step 1: Compile Odin to WASM object file
echo "Compiling Odin to WASM..."
odin build src/ \
    -target:js_wasm32 \
    -build-mode:obj \
    -define:RAYLIB_WASM_LIB=env.o \
    -o:speed \
    -disable-assert \
    -no-bounds-check \
    -out:"${OUT_DIR}/game.wasm.o"

# Step 2: Copy Odin JS runtime
cp "${ODIN_ROOT}/core/sys/wasm/js/odin.js" "${OUT_DIR}/"

# Step 3: Link with Emscripten
echo "Linking with emcc..."
emcc -o "${OUT_DIR}/index.html" \
    "${OUT_DIR}/game.wasm.o" \
    "${ODIN_ROOT}/vendor/raylib/wasm/libraylib.a" \
    -sUSE_GLFW=3 \
    -sWASM_BIGINT \
    -sWARN_ON_UNDEFINED_SYMBOLS=0 \
    -sASSERTIONS \
    -sALLOW_MEMORY_GROWTH=1 \
    -sTOTAL_MEMORY=67108864 \
    --shell-file src/web/index_template.html \
    --preload-file assets

# Cleanup
rm -f "${OUT_DIR}/game.wasm.o"

echo "Web build created in ${OUT_DIR}/"
echo "Run: python3 -m http.server -d ${OUT_DIR}"
