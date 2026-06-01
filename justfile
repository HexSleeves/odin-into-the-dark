set dotenv-load

src := "src/"
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

# ─── Quality ───────────────────────────────────────────────────────────────────

# Check and build (CI-style verification)
verify: check build
    @echo "✓ check + build passed"

# Count lines by domain
stats:
    @echo "=== Lines by file ==="
    @wc -l src/*.odin | sort -rn
    @echo ""
    @echo "=== Data files ==="
    @wc -l data/*.json5

# ─── Cleanup ───────────────────────────────────────────────────────────────────

# Remove build artifacts
clean:
    rm -f {{binary}} game
