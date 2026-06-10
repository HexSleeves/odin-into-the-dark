# Repository Guidelines

Turn-based 2D roguelike written in [Odin](https://odin-lang.org/) + Raylib.
**Repo:** `HexSleeves/odin-into-the-dark`

---

## Project Overview

_Into the Depths_ is a procedurally generated mine-descending roguelike. The player descends floors, fights data-driven enemies, collects/equips items, and is scored on depth, kills, and turns survived.

---

## Repository Layout

| Path                | Contents                                           |
| ------------------- | -------------------------------------------------- |
| `src/`              | Game package (`package main`) + sub-packages       |
| `src/core/`         | Shared types, constants, content/save managers     |
| `src/gameplay/`     | Actions, items, mining, FOV, generation            |
| `src/input/`        | Input manager, key bindings, state handlers        |
| `src/render/`       | Clay UI, world rendering, sprites                  |
| `src/engine/`       | Backend-agnostic engine managers                   |
| `data/`             | json5 data files — enemies, items, player, sprites |
| `assets/`           | PNG spritesheets                                   |
| `test/`             | Test files mirroring src structure                 |
| `internal-docs/ai/` | Long-form AI reference docs                        |
| `.agents/skills/`   | Repeatable AI workflows                            |

---

## Architecture

Two-layer split: `engine` (backend-agnostic) and `game` (logic + rendering). Read `internal-docs/ai/architecture.md` before changing boundaries between packages, services, or backends.

---

## Commands

```bash
just verify          # required pre-completion gate: test + flags + check + build
just test            # run all tests
just check           # type-check only
just build           # debug binary
just run             # build and run
just fmt             # format with odinfmt
just release         # optimized build
```

Read `internal-docs/ai/quality-gates.md` for full command reference and CI gate details.

---

## Coding Rules

Read `internal-docs/ai/coding-style.md` before broad code changes.

Key rules:

1. Engine layer (`src/engine/`) must have **zero Raylib imports** — tests run headlessly.
2. Engine layer must have **zero Clay imports** — Clay stays in game layer.
3. Use `snake_case` for procedures, `PascalCase` for types, `SCREAMING_SNAKE_CASE` for constants.
4. No panics — use `logger_fatalf` + cleanup + return false.
5. Data lives in `data/*.json5` — no code change needed for content updates.

---

## Testing Rules

Read `internal-docs/ai/quality-gates.md` for test framework and coverage expectations.

- `just verify` must pass before any task is complete.
- Test files in `test/` using `package main`.
- Test names are full sentences: `storage_manager_delegates_file_operations_to_configured_file_system`.
- Inject fake backends by constructing structs directly — no mocking framework.

---

## Work Tracking

Work tracking system: **GitHub Issues + GitHub Projects v4**.

Use `.agents/skills/create-work-item/SKILL.md` when creating work.
Use `.agents/skills/execute-work-item/SKILL.md` when implementing work.

**Board:** <https://github.com/users/HexSleeves/projects/4>

**Status model:**

- Todo → In Progress → Done

**Required actions:**

- Starting work: set issue to **In Progress**
- Completing work: close issue + set to **Done**
- PR body: include `Closes #N`

Read `docs/ai-operating-model.md` for the full delivery loop.

---

## Runtime Feedback

- Errors and logs: `into_the_depths.log`
- CI failures: GitHub Actions
- Player bugs: GitHub Issues
- Treat runtime errors as signals to investigate and convert to work when appropriate.

---

## Safety Rules

Read `internal-docs/ai/safety.md` before touching secrets, production data, infrastructure, or releases.

Agents must not:

- Commit secrets, tokens, or local environment files.
- Mutate production systems (releases, tags) without explicit approval.
- Run `just release` without approval.
- Modify `vendor/` or `src/vendor/` without approval.
- Corrupt or delete save files (`savegame.dat`).
- Print sensitive paths or save data in final answers.

---

## Before Finishing

1. Run `just verify`.
2. Run `just fmt`.
3. Re-read the diff.
4. Confirm docs were updated when behavior changed.
5. Confirm no secrets or local artifacts were added.
6. Summarize changes, tests, risks, and remaining unknowns.

---

## References

| Doc                                 | When to read                                             |
| ----------------------------------- | -------------------------------------------------------- |
| `internal-docs/ai/architecture.md`  | App/service boundaries, module ownership, data ownership |
| `internal-docs/ai/coding-style.md`  | Framework and language rules                             |
| `internal-docs/ai/domain-model.md`  | Product concepts and user-facing language                |
| `internal-docs/ai/quality-gates.md` | Install, lint, test, build, release checks               |
| `internal-docs/ai/safety.md`        | Secrets, production, data, infra, approvals              |
| `docs/ai-operating-model.md`        | How work flows through tools and skills                  |
| `docs/ai-decisions.md`              | Setup choices, tradeoffs, assumptions                    |
| `CLAUDE.md`                         | Claude-specific instructions and learned patterns        |
| `CONTEXT.md`                        | Handoff context for src/ reorganization                  |

---

## graphify

This project has a knowledge graph at `graphify-out/`.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
roject has a knowledge graph at `graphify-out/`.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:

- For codebase questions, first run `graphify query "<question>"` when `graphify-out/graph.json` exists.
- Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review.
- After modifying code, run `graphify update .` to keep the graph current.
