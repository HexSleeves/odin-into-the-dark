set dotenv-load

src := "src/"
engine_src := "src/engine"
binary := "into_the_depths"

default:
    @just --list

# ─── Development ───────────────────────────────────────────────────────────────

# Type-check without building
check:
    odin check {{src}} -vet -strict-style

# Build debug binary
build:
    odin build {{src}} -out:{{binary}}

# Build and run
run:
    odin run {{src}}

# Build then run the binary
run-built: build
    ./{{binary}}

# ─── Release ───────────────────────────────────────────────────────────────────

# Build optimized release binary
release:
    odin build {{src}} -out:{{binary}} -o:speed -disable-assert -no-bounds-check

# ─── Platform releases ─────────────────────────────────────────────────────────

# Build macOS .app bundle
release-macos:
    odin build {{src}} -out:build/macos/into_the_depths -o:speed -disable-assert -no-bounds-check
    bash scripts/bundle_macos.sh build/macos/into_the_depths

# Build Linux x86_64 binary (for CI or native Linux)
release-linux:
    odin build {{src}} -out:build/linux/into_the_depths -o:speed -disable-assert -no-bounds-check

# Build web/WASM via karl2d's native WebGL backend (no Emscripten required)
release-web:
    bash scripts/build_karl2d_web.sh

# Build with debug info for profiling
profile:
    odin build {{src}} -out:{{binary}} -o:speed -debug

# ─── Formatting ────────────────────────────────────────────────────────────────

odinfmt := "/Users/lecoqjacob/Developer/games/ols/odinfmt"

# Format all Odin source files
fmt:
    {{odinfmt}} {{src}} -w

# ─── Quality ───────────────────────────────────────────────────────────────────

# Run root package and engine package tests
test:
    odin test {{src}}
    odin test {{engine_src}}

# Check and build (CI-style verification)
verify: test check build
    @echo "✓ tests + check + build passed"

# Count lines by domain
stats:
    @echo "=== Lines by file ==="
    @wc -l src/*.odin src/engine/*.odin | sort -rn
    @echo ""
    @echo "=== Data files ==="
    @wc -l data/*.json5

# ─── Cleanup ───────────────────────────────────────────────────────────────────

# Remove build artifacts
clean:
    rm -f {{binary}} game
