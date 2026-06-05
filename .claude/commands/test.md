# Test — Run Test Suite

Run the Odin test suite for the game package, the engine package, or both.

$ARGUMENTS

## Usage

- `/test` — Run both packages (default)
- `/test engine` — Engine package only
- `/test game` — Game/main package only
- `/test flags` — Compile-flag matrix only

## Commands

### Both packages (default)

```bash
just test
# equivalent to:
odin test src/
odin test src/engine/
```

### Engine package only

```bash
odin test src/engine/
```

### Game package only

```bash
odin test src/
```

### Compile-flag matrix

```bash
just test-flags
```

## Test Conventions

All tests in this project follow these rules:

- **Test names are full sentences** describing the behaviour: `storage_manager_delegates_file_operations_to_configured_file_system`
- **Inject fake backends** for I/O — construct `Engine_File_System` / other backends with test functions; never depend on real files
- **Window-free** — engine tests must never import Raylib; game tests may use engine but not open a window
- **No mocking framework** — use state-tracking structs with `read_count int`, `last_path string`, etc.

## Finding Test Files

```bash
find src/ -name "*_test.odin" | sort
```

## Writing a New Test

```odin
@(test)
my_manager_does_the_right_thing :: proc(t: ^testing.T) {
    // Arrange
    state := My_Fake_State{}
    backend := My_Backend{ctx = &state, fn = my_test_fn}

    // Act
    result := my_manager_do_thing(&backend)

    // Assert
    testing.expect_value(t, result, expected_value)
    testing.expect_value(t, state.call_count, 1)
}
```
