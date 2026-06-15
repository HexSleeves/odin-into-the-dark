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

# CI may check out karl2d inside the repo (actions/checkout path: karl2d).
# If karl2d isn't at the sibling location, check inside the repo.
if [ ! -f "${KARL2D_DIR}/karl2d.odin" ]; then
    if [ -f "${REPO_DIR}/karl2d/karl2d.odin" ]; then
        KARL2D_DIR="${REPO_DIR}/karl2d"
        # Create sibling symlink so the Odin import path resolves
        ln -sfn "${KARL2D_DIR}" "${REPO_DIR}/../karl2d"
    else
        echo "ERROR: karl2d not found at ${KARL2D_DIR} or ${REPO_DIR}/karl2d" >&2
        echo "Clone it: git clone https://github.com/karl-zylinski/karl2d.git ${KARL2D_DIR}" >&2
        exit 1
    fi
fi

mkdir -p "${OUT_DIR}"

# Step 1: Build WASM
echo "Compiling to WASM (karl2d backend)..."
odin build "${REPO_DIR}/src/" \
    -target:js_wasm32 \
    -define:PUBLIC_BUILD=true \
    -collection:libs="${REPO_DIR}/vendor" \
    -out:"${OUT_DIR}/main.wasm"

# Step 2: Copy Odin JS runtime
cp "${ODIN_ROOT}/core/sys/wasm/js/odin.js" "${OUT_DIR}/"

# Step 3: Copy karl2d audio JS for the WebAudio backend.
cp "${KARL2D_DIR}/audio_backend_web_audio.js" "${OUT_DIR}/"
cp "${KARL2D_DIR}/audio_backend_web_audio_processor.js" "${OUT_DIR}/"

# Step 3b: Copy the localStorage save-backend JS (foreign "itd_storage" module).
cp "${SCRIPT_DIR}/file_system_web.js" "${OUT_DIR}/"

# Step 4: Copy or generate index.html, then wire the storage backend.
if [ ! -f "${OUT_DIR}/index.html" ]; then
    cp "${KARL2D_DIR}/build_web/web_entry_templates/index_template.html" "${OUT_DIR}/index.html"
    # Patch title
    sed -i.bak 's/Karl2D Web Build/Into the Depths/' "${OUT_DIR}/index.html"
    rm -f "${OUT_DIR}/index.html.bak"
fi

# Step 4b: Inject the storage backend wiring (idempotent).
# 1) <script> tag right after the audio backend script.
# 2) merge itdStorageJsImports into the WebAssembly import object.
# 3) hand the WASM memory to the storage JS once exports are known.
INDEX="${OUT_DIR}/index.html"
if ! grep -q "file_system_web.js" "${INDEX}"; then
    python3 - "${INDEX}" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    html = f.read()

# 1) script tag after the audio backend include
audio_tag = '<script type="text/javascript" src="audio_backend_web_audio.js"></script>'
storage_tag = '<script type="text/javascript" src="file_system_web.js"></script>'
if audio_tag in html:
    html = html.replace(audio_tag, audio_tag + "\n\t\t" + storage_tag, 1)
else:
    # Fall back to inserting before odin.js if audio tag layout changed.
    odin_tag = '<script type="text/javascript" src="odin.js"></script>'
    html = html.replace(odin_tag, storage_tag + "\n\t\t" + odin_tag, 1)

# 2) merge imports right after the karl2d audio import merge.
audio_merge = "imports = { ...imports, ...karl2dAudioJsImports };"
storage_merge = "imports = { ...imports, ...itdStorageJsImports };"
if audio_merge in html:
    html = html.replace(audio_merge, audio_merge + "\n\t\t\t\t" + storage_merge, 1)
else:
    raise SystemExit("index template missing karl2d audio import merge; cannot wire storage")

# 3) set storage WASM memory alongside the audio memory hook.
audio_mem = "setKarl2dAudioWasmMemory(exports.memory);"
storage_mem = "setItdStorageWasmMemory(exports.memory);"
if audio_mem in html:
    html = html.replace(audio_mem, audio_mem + "\n\t\t\t\t\t" + storage_mem, 1)
else:
    raise SystemExit("index template missing karl2d audio memory hook; cannot wire storage")

with open(path, "w", encoding="utf-8") as f:
    f.write(html)
print("wired itd_storage localStorage backend into", path)
PY
fi

echo "Web build complete: ${OUT_DIR}/"
echo "Serve with: python3 -m http.server -d ${OUT_DIR} 8080"
