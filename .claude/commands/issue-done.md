# Issue Done — Close a GitHub Issue and Mark Complete

Close a GitHub issue with a summary comment and move it to **Done** on the project board.

$ARGUMENTS

Provide the issue number after the command: `/issue-done 42`

## Steps

### 1. Run Final Verification

Never close an issue without passing the full CI gate:

```bash
just verify
```

Fix any failures before proceeding.

### 2. Close the Issue with a Summary Comment

```bash
gh issue close $ARGUMENTS --repo HexSleeves/odin-into-the-dark \
  --comment "Completed: <one-line summary of what was done and how>"
```

Write a concrete summary — e.g. "Added `crystal_golem` enemy with freeze ability, spawns on depths 5–10" not just "Done".

### 3. Move to Done on the Project Board

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
    value: { singleSelectOptionId: "98236657" }
  }) { projectV2Item { id } }
}'
```

### 4. Update `NEXT_STEPS.md` (if applicable)

If the completed work is listed in `NEXT_STEPS.md` under "Remaining work", move it to "Recently shipped" with a brief description. Keep the recently-shipped list to the last ~10 items.

### 5. Commit (if not already done)

```bash
git add -A
git commit -m "feat: <imperative description closes #$ARGUMENTS>"
git push
```

## Board Constants

```
PROJECT_ID:         PVT_kwHOAI2S3s4BZire
STATUS_FIELD_ID:    PVTSSF_lAHOAI2S3s4BZirezhUgnCQ
STATUS_DONE:        98236657
REPO:               HexSleeves/odin-into-the-dark
```
