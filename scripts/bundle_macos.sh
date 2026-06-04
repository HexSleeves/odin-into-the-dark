#!/usr/bin/env bash
set -euo pipefail

BINARY="${1:?Usage: bundle_macos.sh <binary_path>}"
APP_NAME="Into the Depths"
BUNDLE_DIR="build/macos/${APP_NAME}.app"

rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# Copy binary
cp "${BINARY}" "${BUNDLE_DIR}/Contents/MacOS/into_the_depths"
chmod +x "${BUNDLE_DIR}/Contents/MacOS/into_the_depths"

# Copy Info.plist
cp scripts/Info.plist "${BUNDLE_DIR}/Contents/"

# Copy runtime assets (sprites loaded by Raylib at runtime).
# Data files (enemies/items/player json5) are #load'd at compile time — not needed here.
cp -r assets "${BUNDLE_DIR}/Contents/Resources/"


# Ad-hoc sign so macOS Gatekeeper doesn't flag it as "damaged"
codesign --force --deep --sign - "${BUNDLE_DIR}"
echo "Created ${BUNDLE_DIR}"
