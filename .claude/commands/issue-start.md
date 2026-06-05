# Issue Start — Begin Work on a GitHub Issue

Move a GitHub issue to **In Progress** on the project board and set up context for the work.

$ARGUMENTS

Provide the issue number after the command: `/issue-start 42`

## Steps

### 1. View the Issue

```bash
gh issue view $ARGUMENTS --repo HexSleeves/odin-into-the-dark
```

### 2. Move to In Progress on the Project Board

```bash
ITEM_ID=$(gh api graphql -f query='{
  repository(owner: "HexSleeves", name: "odin-into-the-dark") {
    issue(number: '$ARGUMENTS') {
      projectItems(first: 1) { nodes { id } }
    }
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

### 3. Understand the Work

Read the issue body, labels, and milestone carefully. Then:

- Check `NEXT_STEPS.md` for related pending work
- Search the codebase for relevant files:

  ```bash
  rg "keyword" src/ --type odin -l
  ```

- Check existing tests to understand expected behaviour

### 4. Plan Before Coding

For non-trivial work, outline:

1. Which files need to change
2. What new files are needed
3. What tests are required
4. Whether it's engine-layer (no Raylib) or game-layer

### 5. Run Baseline Verify

Before touching any code, confirm the repo is green:

```bash
just verify
```

If it's already red, note what's broken before starting.

## Board Constants

```
PROJECT_ID:         PVT_kwHOAI2S3s4BZire
STATUS_FIELD_ID:    PVTSSF_lAHOAI2S3s4BZirezhUgnCQ
STATUS_IN_PROGRESS: 47fc9ee4
REPO:               HexSleeves/odin-into-the-dark
```
