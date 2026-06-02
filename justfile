set dotenv-load

src := "src/"
engine_src := "src/engine"
binary := "into_the_depths"

default:
    @just --list

# ─── Development ───────────────────────────────────────────────────────────────

# Type-check without building
check:
    odin check {{src}}

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
