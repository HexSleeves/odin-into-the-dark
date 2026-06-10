---
name: create-work-item
description: Create a GitHub Issue and add it to the Project board with proper labels and milestone.
---

# Create Work Item

## Use When

- User says "create an issue", "file a bug", "add a task"
- Discovering untracked work during implementation
- Converting an idea or bug report into a tracked work item

## Inputs

| Input       | Required | Notes                                                                                |
| ----------- | -------- | ------------------------------------------------------------------------------------ |
| Title       | yes      | Issue title                                                                          |
| Description | yes      | What to do, acceptance criteria                                                      |
| Label       | no       | `content`, `engine`, `gameplay`, `ui/ux`, `performance`, `bug`, `roadmap`, `backlog` |
| Milestone   | no       | `1` (v0.2), `2` (v0.3), `3` (v0.4), `4` (v0.5)                                       |

## Workflow

1. **Create issue**:
   ```bash
   gh issue create --repo HexSleeves/odin-into-the-dark \
     --title "title" --body "body" \
     --label "roadmap,LABEL" --milestone MILESTONE_NUM
   ```
2. **Add to board**:

   ```bash
   NUM=$(echo $URL | grep -o '[0-9]*$')
   NODE=$(gh api repos/HexSleeves/odin-into-the-dark/issues/$NUM --jq '.node_id')

   gh api graphql -f query='mutation {
     addProjectV2ItemById(input: {
       projectId: "PVT_kwHOAI2S3s4BZire"
       contentId: "'$NODE'"
     }) { item { id } }
   }'
   ```

3. **Set status to Todo** (if needed):

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
       value: { singleSelectOptionId: "f75ad846" }
     }) { projectV2Item { id } }
   }'
   ```

## Safety

- Do not create duplicate issues — search existing first
- Do not assign without user approval
- Use appropriate labels and milestones
- Include clear acceptance criteria in description

## Proof

Work item created when:

- Issue exists on GitHub
- Issue is on the Project board
- Status is set to Todo
- URL is returned to user

## Final Response

Report:
s is set to Todo

- URL is returned to user

## Final Response

Report:

- Issue number and URL
- Label and milestone applied
- Board status set
- Suggested next step (e.g., "Run execute-work-item skill to start implementation")
