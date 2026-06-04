set dotenv-load

src := "src/"
engine_src := "src/engine"
binary := "into_the_depths"
cheat_define := if env_var_or_default("CHEATS", "false") == "true" { "-define:CHEATS=true" } else { "" }
sprite_define := if env_var_or_default("SPRITES", "false") == "true" { "-define:SPRITES=true" } else { "" }
build_defines := cheat_define + " " + sprite_define


default:
    @just --list

# ─── Development ───────────────────────────────────────────────────────────────

# Type-check without building
check:
    odin check {{src}} -vet -strict-style {{build_defines}}

# Build debug binary
build:
    odin build {{src}} -out:{{binary}} {{build_defines}}

# Build and run
run:
    odin run {{src}} {{build_defines}}

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

# Bind to 127.0.0.1 (not the [::] wildcard) so the browser treats it as a secure
# context — karl2d's Web Audio worklet requires one.

# Build the web bundle and serve it at http://localhost:8080
run-web port="8080": release-web
    @echo "Serving at http://localhost:{{port}}  (Ctrl+C to stop)"
    python3 -m http.server -d build/web --bind 127.0.0.1 {{port}}

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
