set dotenv-load

src := "src/"
engine_src := "src/engine"
binary := "into_the_depths"
cheat_define := if env_var_or_default("CHEATS", "false") == "true" { "-define:CHEATS=true" } else { "" }
sprite_define := if env_var_or_default("SPRITES", "false") == "true" { "-define:SPRITES=true" } else { "" }
no_audio_define := if env_var_or_default("NO_AUDIO", "false") == "true" { "-define:NO_AUDIO=true" } else { "" }
no_sprites_define := if env_var_or_default("NO_SPRITES", "false") == "true" { "-define:NO_SPRITES=true" } else { "" }
skip_title_define := if env_var_or_default("SKIP_TITLE", "false") == "true" { "-define:SKIP_TITLE=true" } else { "" }
use_clay_define := if env_var_or_default("USE_CLAY", "false") == "true" { "-define:USE_CLAY=true" } else { "" }
fixed_seed_value := env_var_or_default("FIXED_SEED", "")
fixed_seed_define := if fixed_seed_value != "" { "-define:FIXED_SEED=" + fixed_seed_value } else { "" }
build_defines := cheat_define + " " + sprite_define + " " + no_audio_define + " " + no_sprites_define + " " + skip_title_define + " " + use_clay_define + " " + fixed_seed_define
release_defines := sprite_define + " " + no_audio_define + " " + no_sprites_define + " " + skip_title_define + " " + use_clay_define + " " + fixed_seed_define + " -define:PUBLIC_BUILD=true"
copy_assets := if env_var_or_default("NO_SPRITES", "false") == "true" { "false" } else { "true" }

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
    odin build {{src}} -out:{{binary}} -o:speed -disable-assert -no-bounds-check {{release_defines}}

# ─── Platform releases ─────────────────────────────────────────────────────────

# Build macOS .app bundle
release-macos:
    odin build {{src}} -out:build/macos/into_the_depths -o:speed -disable-assert -no-bounds-check {{release_defines}}
    COPY_ASSETS={{copy_assets}} bash scripts/bundle_macos.sh build/macos/into_the_depths

# Build Linux x86_64 binary (for CI or native Linux)
release-linux:
    odin build {{src}} -out:build/linux/into_the_depths -o:speed -disable-assert -no-bounds-check {{release_defines}}

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
    odin test {{src}} {{build_defines}}
    odin test {{engine_src}}

# Run compile-flag matrix tests that should stay green regardless of environment.
test-flags:
    odin test {{src}} -define:CHEATS=true
    odin test {{src}} -define:NO_AUDIO=true
    odin test {{src}} -define:SPRITES=true -define:NO_SPRITES=true
    odin test {{src}} -define:SKIP_TITLE=true
    odin test {{src}} -define:FIXED_SEED=12345
    odin check {{src}} -vet -strict-style -define:CHEATS=true -define:NO_AUDIO=true -define:SPRITES=true -define:NO_SPRITES=true -define:SKIP_TITLE=true -define:FIXED_SEED=12345

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
    rm -f {{binary}} game
