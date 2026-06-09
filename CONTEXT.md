# Handoff Context: src/ Folder Organization

## Current status

The repository is already split into Odin sub-packages for the main concerns:

```
src/
  core/     shared game types, constants, and helpers (`package core`, imported as `gcore`)
  engine/   engine managers and backend interfaces (`package engine`)
  audio/    game audio and music (`package audio`)
  io/       logging, save/storage, web assets, karl2d web backend (`package gameio`)
  ui/       UI text, theme constants, message helpers, UI manager (`package ui`)
  ai/       enemy/combat behavior (`package ai`)
  gen/      generation features (`package gen`)
  gameplay/ gameplay orchestration (`package gameplay`)
  input/    input states and action mapping (`package input`)
  render/   rendering, Clay UI rendering, sprites (`package render`)
  *.odin    remaining app wiring in `package main`
```

Odin is directory-based: one folder is one package. Cross-package callers import the package directly (`import gameui "./ui"`, `import gcore "../core"`, etc.).

## Verified package state

- `src/ui/ui_manager.odin`, `src/ui/ui_text.odin`, and `src/ui/ui_theme.odin` already import `gcore "../core"` where needed.
- `src/ui` type-checks as a library package with:
  ```bash
  odin check src/ui -no-entry-point -vet -strict-style -collection:libs=vendor/
  ```
- `just check` passes for `src/`.
- No root-level `src/*_aliases.odin` shims are present in the current tree. Existing root/test access is handled through direct package imports and test import aliases.

## Package naming notes

- Do not import `src/core` as `core`; that conflicts with Odin's core collection. Use `gcore`.
- Do not name the IO package `io`; that conflicts with `core:io`. The package is `gameio`.
- `src/clay/` is not split out. Clay rendering remains in `src/render/`, avoiding the previous render↔clay mutual import cycle.

## Immediate next steps

Use `NEXT_STEPS.md` as the source of truth for remaining work:

1. Shipping validation
   - Manual QA pass for build flags and common combinations.
   - macOS bundle smoke test.
   - WASM/web smoke test.
2. Polish
   - Tune boss camera zoom after playtesting.
   - Title screen polish follow-up.
3. Engine maturity
   - Texture-from-memory backend.
   - Frame allocator lifetime audit.