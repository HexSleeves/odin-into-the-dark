# New Manager — Scaffold an Engine Manager

Create a new backend-agnostic engine manager in `src/engine/` following the project's established pattern.

$ARGUMENTS

## When to Create an Engine Manager

Use engine managers for reusable, backend-agnostic systems. If it needs Raylib, put it in `src/` instead.

Good candidates: resource caches, event queues, spatial grids, cooldown trackers, state machines.

## Scaffold

Replace `Foo` / `foo` with your manager name throughout.

### 1. Manager file — `src/engine/foo_manager.odin`

```odin
package engine

Foo_Manager :: struct {
    // fields
}

// Constructor — allocate nothing unless necessary
foo_manager_make :: proc() -> Foo_Manager {
    return Foo_Manager{}
}

// Destructor — free anything allocated in make
foo_manager_destroy :: proc(fm: ^Foo_Manager) {
    // cleanup
}

// Primary operations — snake_case, manager-verb pattern
foo_manager_do_thing :: proc(fm: ^Foo_Manager, arg: int) -> bool {
    // implementation
    return true
}
```

### 2. Test file — `src/engine/foo_manager_test.odin`

```odin
package engine

import "core:testing"

@(test)
foo_manager_does_thing_when_condition :: proc(t: ^testing.T) {
    fm := foo_manager_make()
    defer foo_manager_destroy(&fm)

    result := foo_manager_do_thing(&fm, 42)

    testing.expect(t, result, "expected do_thing to succeed")
}

@(test)
foo_manager_handles_edge_case :: proc(t: ^testing.T) {
    fm := foo_manager_make()
    defer foo_manager_destroy(&fm)

    // edge case
    result := foo_manager_do_thing(&fm, 0)
    testing.expect(t, !result, "expected do_thing to fail on zero")
}
```

### 3. If the manager needs a backend (injectable dependency)

```odin
// In src/engine/foo_backend.odin
Foo_Backend :: struct {
    ctx:        rawptr,
    do_io:      proc(ctx: rawptr, data: []byte) -> bool,
}

// In the manager
Foo_Manager :: struct {
    backend: Foo_Backend,
}

foo_manager_make :: proc(backend: Foo_Backend) -> Foo_Manager {
    return Foo_Manager{backend = backend}
}
```

Inject a fake backend in tests:

```odin
@(test)
foo_manager_delegates_to_backend :: proc(t: ^testing.T) {
    call_count := 0
    fake_do_io :: proc(ctx: rawptr, data: []byte) -> bool {
        (cast(^int)ctx)^ += 1
        return true
    }
    backend := Foo_Backend{ctx = &call_count, do_io = fake_do_io}
    fm := foo_manager_make(backend)
    defer foo_manager_destroy(&fm)

    foo_manager_do_thing(&fm, []byte{1, 2, 3})

    testing.expect_value(t, call_count, 1)
}
```

### 4. Register as a service (if game layer needs it)

In `src/engine/engine_services.odin`, add a constant:

```odin
FOO_SERVICE_ID :: Engine_Service_Id(N)  // next available int
```

In `src/game_app.odin`, register at init:

```odin
foo_mgr := foo_manager_make(...)
eng.engine_services_register(engine.services, FOO_SERVICE_ID, &foo_mgr)
```

Retrieve anywhere:

```odin
foo := cast(^engine.Foo_Manager)eng.engine_services_get(engine.services, engine.FOO_SERVICE_ID)
```

### 5. Run tests

```bash
odin test src/engine/
```

Naming conventions:

- Manager type: `Foo_Manager`
- Constructor: `foo_manager_make`
- Destructor: `foo_manager_destroy`
- Operations: `foo_manager_verb_noun`
- Constants: `FOO_SCREAMING_SNAKE`
