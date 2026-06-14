set dotenv-load

src := "src/"
test := "test/"
engine_src := "src/engine"
binary := "into_the_depths"
# Dev builds enable the cheat menu (Shift+C) by default. Disable with CHEATS=false.
# Release recipes use release_defines (no cheat_define), so cheats never ship.
cheat_define := if env_var_or_default("CHEATS", "true") == "false" { "" } else { "-define:CHEATS=true" }
sprite_define := if env_var_or_default("SPRITES", "false") == "true" { "-define:SPRITES=true" } else { "" }
no_audio_define := if env_var_or_default("NO_AUDIO", "false") == "true" { "-define:NO_AUDIO=true" } else { "" }
no_sprites_define := if env_var_or_default("NO_SPRITES", "false") == "true" { "-define:NO_SPRITES=true" } else { "" }
skip_title_define := if env_var_or_default("SKIP_TITLE", "false") == "true" { "-define:SKIP_TITLE=true" } else { "" }
fixed_seed_value := env_var_or_default("FIXED_SEED", "")
fixed_seed_define := if fixed_seed_value != "" { "-define:FIXED_SEED=" + fixed_seed_value } else { "" }
vendor_collection := "-collection:libs=vendor/"
build_defines := cheat_define + " " + sprite_define + " " + no_audio_define + " " + no_sprites_define + " " + skip_title_define + " " + fixed_seed_define
compile_defines := build_defines
release_defines := sprite_define + " " + no_audio_define + " " + no_sprites_define + " " + skip_title_define + " -define:PUBLIC_BUILD=true"
copy_assets := if env_var_or_default("NO_SPRITES", "false") == "true" { "false" } else { "true" }

default:
    @just --list

# ─── Development ───────────────────────────────────────────────────────────────

# Type-check without building
check:
    odin check {{ src }} -vet -strict-style {{ vendor_collection }} {{ compile_defines }}

# Build debug binary
build:
    odin build {{ src }} -out:{{ binary }} {{ vendor_collection }} {{ compile_defines }}

# Build and run
run:
    odin run {{ src }} {{ vendor_collection }} {{ compile_defines }}

# Build then run the binary
run-built: build
    ./{{ binary }}

# ─── Release ───────────────────────────────────────────────────────────────────

# Build optimized release binary
release:
    odin build {{ src }} -out:{{ binary }} -o:speed -disable-assert -no-bounds-check {{ vendor_collection }} {{ release_defines }}

# ─── Platform releases ─────────────────────────────────────────────────────────

# Build macOS .app bundle
release-macos:
    odin build {{ src }} -out:build/macos/into_the_depths -o:speed -disable-assert -no-bounds-check {{ vendor_collection }} {{ release_defines }}
    COPY_ASSETS={{ copy_assets }} bash scripts/bundle_macos.sh build/macos/into_the_depths

# Build Linux x86_64 binary (for CI or native Linux)
release-linux:
    odin build {{ src }} -out:build/linux/into_the_depths -o:speed -disable-assert -no-bounds-check {{ vendor_collection }} {{ release_defines }}

# Build web/WASM via karl2d's native WebGL backend (no Emscripten required)
release-web:
    bash scripts/build_karl2d_web.sh

# Bind to 127.0.0.1 (not the [::] wildcard) so the browser treats it as a secure
# context — karl2d's Web Audio worklet requires one.

# Build the web bundle and serve it at http://localhost:8080
run-web port="8080": release-web
    @echo "Serving at http://localhost:{{ port }}  (Ctrl+C to stop)"
    python3 -m http.server -d build/web --bind 127.0.0.1 {{ port }}

# Build with debug info for profiling
profile:
    odin build {{ src }} -out:{{ binary }} -o:speed -debug {{ vendor_collection }}

# ─── Formatting ────────────────────────────────────────────────────────────────

odinfmt := env_var_or_default("ODINFMT", "odinfmt")

# Format all Odin source files
fmt:
    {{ odinfmt }} {{ src }} -w
    {{ odinfmt }} {{ test }} -w

# ─── Quality ───────────────────────────────────────────────────────────────────

# Run all tests staged from test/ into temporary package mirrors.
test:
    python3 scripts/run_odin_tests.py {{ compile_defines }}

# Run compile-flag matrix tests that should stay green regardless of environment.
test-flags:
    python3 scripts/run_odin_tests.py --root-only -define:CHEATS=true
    python3 scripts/run_odin_tests.py --root-only -define:NO_AUDIO=true
    python3 scripts/run_odin_tests.py --root-only -define:SPRITES=true -define:NO_SPRITES=true
    python3 scripts/run_odin_tests.py --root-only -define:SKIP_TITLE=true
    python3 scripts/run_odin_tests.py --root-only -define:FIXED_SEED=12345
    odin check {{ src }} -vet -strict-style {{ vendor_collection }} -define:CHEATS=true -define:NO_AUDIO=true -define:SPRITES=true -define:NO_SPRITES=true -define:SKIP_TITLE=true -define:FIXED_SEED=12345

# Check and build (CI-style verification)
verify: test test-flags check build
    @echo "✓ tests + flag matrix + check + build passed"

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
    rm -f {{ binary }} game
