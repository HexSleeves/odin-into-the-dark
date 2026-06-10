# AI Operating Model

> How work flows through tools and skills for Into the Depths.

## Delivery Loop

```
Idea / Bug / Feature request
  -> GitHub Issue (with label + milestone)
  -> GitHub Project board (auto-added)
  -> Set status: In Progress
  -> AI executes: create-work-item + execute-work-item
    -> Branch: feat/<issue-num>-description
    -> Implementation + tests
    -> just verify
    -> just fmt
  -> PR with "Closes #N"
  -> review-change skill
  -> qa-pass skill (manual QA for game builds)
  -> Merge to main
  -> CI runs (check + build + test)
  -> release-change skill (when cutting a version)
    -> Tag vX.Y.Z
    -> GitHub Actions builds Linux/macOS/Web artifacts
    -> GitHub Release with artifacts
  -> Runtime feedback
    -> CI failures → new issue
    -> Player bugs → GitHub Issues
    -> Game logs → local diagnostics
```

## Tool Adapters

### Work Tracking: GitHub Issues + GitHub Projects v4

| Generic | GitHub |
|---|---|
| Work item | Issue |
| Board | Project v4 |
| Status | Project status field |
| PR link | `Closes #N` in PR body |
| QA note | Issue comment |

**Board IDs (from AGENTS.md):**
- Project: `PVT_kwHOAI2S3s4BZire`
- Status field: `PVTSSF_lAHOAI2S3s4BZirezhUgnCQ`
- Todo: `f75ad846`
- In Progress: `47fc9ee4`
- Done: `98236657`

### Code: GitHub

- Branch naming: `feat/<issue-num>-description`, `fix/<issue-num>-description`
- Default branch: `main`
- PR required before merge
- Reviewers: owner

### CI/CD: GitHub Actions

- **CI:** `ci.yml` — test + check + build on macOS + Linux
- **Release:** `release.yml` — triggered on `v*` tags, builds Linux/macOS/Web artifacts

### Runtime Feedback

| Signal | Location | Action |
|---|---|---|
| CI failure | GitHub Actions logs | Create issue, fix, retry |
| Player bug | GitHub Issues | Triage, assign milestone |
| Game crash | `into_the_depths.log` | Manual investigation |
| Build failure | Local terminal | Run `just verify`, fix |

## When to Use Each Skill

| Situation | Skill |
|---|---|
| New issue appears | create-work-item |
| Starting implementation | execute-work-item |
| PR opened | review-change |
| Before merge | qa-pass |
| Cutting a version | release-change |

## Non-Code Work

- Data changes (new enemies, items): edit `data/*.json5`, verify with `just check`, PR
- Asset changes (sprites): add to `assets/`, verify game renders, PR
- Docs changes: edit `README.md`, `AGENTS.md`, or `internal-docs/ai/`, PR

## Safety Gates

- No direct push to `main`
- `just verify` must pass before PR
- `just fmt` must pass before commit
- No production build mutations without tag
- No save format changes without migration plan

## Feedback Loop

1. Player reports bug → GitHub Issue
2. Issue added to board → status: In Progress
3. AI executes work → PR → review → QA → merge
4. CI passes → release on next tag
5. Players test new version → repeat
