---
name: update-board
description: Update the Into the Depths GitHub project board. Move issues between Todo/In Progress/Done, create new issues for discovered work, close completed issues. Use whenever starting, finishing, or discovering work.
---

# Update Project Board

Keeps the Into the Depths roadmap board in sync with actual work.

## Project Constants

```
REPO:        HexSleeves/odin-into-the-dark
PROJECT_ID:  PVT_kwHOAI2S3s4BZire
PROJECT_URL: https://github.com/users/HexSleeves/projects/4

# Status field
STATUS_FIELD_ID:    PVTSSF_lAHOAI2S3s4BZirezhUgnCQ
STATUS_TODO:        f75ad846
STATUS_IN_PROGRESS: 47fc9ee4
STATUS_DONE:        98236657

# Milestones
MILESTONE_V02: 1   # v0.2 — Content & Polish
MILESTONE_V03: 2   # v0.3 — Depth & Progression
MILESTONE_V04: 3   # v0.4 — Game Modes & Polish
MILESTONE_V05: 4   # v0.5 — Engine Maturity
```

## When to Use

| Trigger                         | Action                      |
| ------------------------------- | --------------------------- |
| Starting work on a roadmap item | Move issue → In Progress    |
| Completing a roadmap item       | Close issue + move → Done   |
| Discovering untracked work      | Create issue + add to board |
| Opening a PR for a roadmap item | Link PR to issue            |
| Finishing a milestone           | Verify all issues closed    |

## Workflows

### Move Issue to In Progress

```bash
# 1. Get the project item ID for the issue
ITEM_ID=$(gh api graphql -f query='
{
  repository(owner: "HexSleeves", name: "odin-into-the-dark") {
    issue(number: <ISSUE_NUMBER>) {
      projectItems(first: 5) {
        nodes { id }
      }
    }
  }
}' --jq '.data.repository.issue.projectItems.nodes[0].id')

# 2. Set status to In Progress
gh api graphql -f query='
mutation {
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
# Close the issue
gh issue close <NUMBER> --repo HexSleeves/odin-into-the-dark \
  --comment "Completed. <brief summary of what was done>"

# Move to Done on board (get ITEM_ID first as above, then:)
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwHOAI2S3s4BZire"
    itemId: "'$ITEM_ID'"
    fieldId: "PVTSSF_lAHOAI2S3s4BZirezhUgnCQ"
    value: { singleSelectOptionId: "98236657" }
  }) { projectV2Item { id } }
}'
```

### Create New Issue + Add to Board

```bash
# 1. Create issue (pick milestone number from constants above)
ISSUE_URL=$(gh issue create \
  --repo HexSleeves/odin-into-the-dark \
  --title "<title>" \
  --body "<body with acceptance criteria>" \
  --label "roadmap,<type-label>" \
  --milestone <milestone-number>)

# 2. Get issue node ID
ISSUE_NUMBER=$(echo $ISSUE_URL | grep -o '[0-9]*$')
ISSUE_NODE_ID=$(gh api repos/HexSleeves/odin-into-the-dark/issues/$ISSUE_NUMBER --jq '.node_id')

# 3. Add to project board
gh api graphql -f query='
mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_kwHOAI2S3s4BZire"
    contentId: "'$ISSUE_NODE_ID'"
  }) { item { id } }
}'
```

### Check Board Status

```bash
# View open issues by milestone
gh issue list --repo HexSleeves/odin-into-the-dark \
  --milestone "v0.2 — Content & Polish" --state open

# View all project items
gh project item-list 4 --owner HexSleeves --format json | \
  jq -r '.items[] | "\(.status // "No Status") | \(.title)"'
```

## Labels Reference

| Label              | Use for                                 |
| ------------------ | --------------------------------------- |
| `content`          | New game content (enemies, items, maps) |
| `engine`           | Engine internals                        |
| `gameplay`         | Game mechanics and balance              |
| `ui/ux`            | UI and experience                       |
| `performance`      | Optimization                            |
| `good first issue` | Newcomer-friendly                       |
| `roadmap`          | Tracked on roadmap board                |
| `backlog`          | Future consideration                    |

## Rules

- Always set status to **In Progress** when starting any roadmap issue
- Always set status to **Done** and close issue when work is complete
- New issues for discovered work go on the board immediately
- Backlog items get `backlog` label, no milestone
- Every issue needs at least one label + `roadmap` label
