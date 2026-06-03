#!/usr/bin/env bash
set -euo pipefail

# Build the game for web using karl2d's native WebGL backend.
# No emscripten required — just Odin's js_wasm32 target.
#
# Usage: bash scripts/build_karl2d_web.sh
#
# Output: build/web/ containing index.html, main.wasm, odin.js, and audio JS.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
KARL2D_DIR="${REPO_DIR}/../karl2d"
OUT_DIR="${REPO_DIR}/build/web"
ODIN_ROOT="${ODIN_ROOT:-$(odin root)}"

# Verify karl2d exists
if [ ! -f "${KARL2D_DIR}/karl2d.odin" ]; then
    echo "ERROR: karl2d not found at ${KARL2D_DIR}" >&2
    echo "Clone it: git clone https://github.com/karl-zylinski/karl2d.git ${KARL2D_DIR}" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

# Step 1: Build WASM
echo "Compiling to WASM (karl2d backend)..."
odin build "${REPO_DIR}/src/" \
    -target:js_wasm32 \
    -out:"${OUT_DIR}/main.wasm" \
    -o:size \
    -disable-assert \
    -no-bounds-check

# Step 2: Copy Odin JS runtime
cp "${ODIN_ROOT}/core/sys/wasm/js/odin.js" "${OUT_DIR}/"

# Step 3: Copy karl2d audio JS (web audio backend)
cp "${KARL2D_DIR}/audio_backend_web_audio.js" "${OUT_DIR}/"
cp "${KARL2D_DIR}/audio_backend_web_audio_processor.js" "${OUT_DIR}/"

# Step 4: Copy or generate index.html
if [ ! -f "${OUT_DIR}/index.html" ]; then
    cp "${KARL2D_DIR}/build_web/web_entry_templates/index_template.html" "${OUT_DIR}/index.html"
    # Patch title
    sed -i.bak 's/Karl2D Web Build/Into the Depths/' "${OUT_DIR}/index.html"
    rm -f "${OUT_DIR}/index.html.bak"
fi

echo "Web build complete: ${OUT_DIR}/"
echo "Serve with: python3 -m http.server -d ${OUT_DIR} 8080"
