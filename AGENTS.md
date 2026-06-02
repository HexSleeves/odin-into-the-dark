# Into the Depths — Agent Instructions

## Project

Turn-based 2D roguelike in [Odin](https://odin-lang.org/) + Raylib.
Repo: `HexSleeves/odin-into-the-dark`

## Build & Verify

```bash
just verify    # full CI: test + check + build — run before finishing any task
just test      # odin test src/ && odin test src/engine
just check     # type-check only
just fmt       # format all .odin files with odinfmt
just run       # build + run
```

## Code Rules

- No comments unless WHY is non-obvious (hidden constraint, subtle invariant, workaround)
- No docstrings or multi-line comment blocks
- No error handling for impossible internal cases
- No backwards-compat shims for removed code
- Prefer editing existing files over creating new ones
- Game data (enemies, items, stats) lives in `data/*.json5` — no code change needed
- Engine layer (`src/engine/`) must remain backend-agnostic and window-free testable

## GitHub Project Board — REQUIRED FOR ALL AGENTS

**Board:** https://github.com/users/HexSleeves/projects/4
**Repo:** HexSleeves/odin-into-the-dark

### Project IDs (for GraphQL mutations)

```
PROJECT_ID:         PVT_kwHOAI2S3s4BZire
STATUS_FIELD_ID:    PVTSSF_lAHOAI2S3s4BZirezhUgnCQ
STATUS_TODO:        f75ad846
STATUS_IN_PROGRESS: 47fc9ee4
STATUS_DONE:        98236657
```

### Required Actions

| Situation | Action |
|---|---|
| Starting work on a tracked issue | Set issue to **In Progress** on board |
| Completing tracked work | Close issue + set to **Done** on board |
| Discovering work not yet tracked | Create issue, add to board, set **In Progress** |
| Opening a PR for a feature | Add `Closes #N` to PR body |

### Move Issue to In Progress

```bash
ITEM_ID=$(gh api graphql -f query='{
  repository(owner: "HexSleeves", name: "odin-into-the-dark") {
    issue(number: ISSUE_NUM) { projectItems(first:1) { nodes { id } } }
  }
}' --jq '.data.repository.issue.projectItems.nodes[0].id')

gh api graphql -f query='mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwHOAI2S3s4BZire"
    itemId: "'$ITEM_ID'"
    fieldId: "PVTSSF_lAHOAI2S3s4BZirezhUgnCQ"
    value: { singleSelectOptionId: "47fc9ee4" }
  }) { projectV2Item { id } }
}'
```

### Close Issue + Move to Done

```bash
gh issue close ISSUE_NUM --repo HexSleeves/odin-into-the-dark \
  --comment "Completed: <one-line summary>"

# Then update board status to Done (98236657) using ITEM_ID pattern above
```

### Create Issue + Add to Board

```bash
URL=$(gh issue create --repo HexSleeves/odin-into-the-dark \
  --title "title" --body "body" \
  --label "roadmap,LABEL" --milestone MILESTONE_NUM)

NUM=$(echo $URL | grep -o '[0-9]*$')
NODE=$(gh api repos/HexSleeves/odin-into-the-dark/issues/$NUM --jq '.node_id')

gh api graphql -f query='mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_kwHOAI2S3s4BZire"
    contentId: "'$NODE'"
  }) { item { id } }
}'
```

## Milestones

| Number | Name |
|---|---|
| 1 | v0.2 — Content & Polish |
| 2 | v0.3 — Depth & Progression |
| 3 | v0.4 — Game Modes & Polish |
| 4 | v0.5 — Engine Maturity |

## Labels

`content` · `engine` · `gameplay` · `ui/ux` · `performance` · `good first issue` · `roadmap` · `backlog`

## odinfmt

Binary at: `/Users/lecoqjacob/Developer/games/ols/odinfmt`
Run via: `just fmt`
