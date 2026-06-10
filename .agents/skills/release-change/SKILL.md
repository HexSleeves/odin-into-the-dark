---
name: release-change
description: Cut a release version — bump version, tag, trigger CI builds, and verify artifacts.
---

# Release Change

## Use When

- User says "release", "cut a version", "ship vX.Y.Z"
- Milestone is complete and ready for release
- After QA passes and PRs are merged

## Inputs

| Input | Required | Notes |
|---|---|---|
| Version | yes | Semantic version (e.g., `v0.2.0`) |
| Milestone | no | Which milestone this release closes |

## Workflow

1. **Verify readiness**:
   - `main` branch is green (CI passing)
   - All milestone issues are closed
   - `just verify` passes locally
   - `just fmt` passes
2. **Update version** — if version is tracked anywhere (e.g., in code or docs)
3. **Update changelog** — summarize changes since last tag
4. **Create tag**:
   ```bash
   git tag -a v0.2.0 -m "v0.2.0 — Content & Polish"
   git push origin v0.2.0
   ```
5. **Verify CI** — GitHub Actions `release.yml` triggers automatically:
   - Linux x86_64 build
   - macOS ARM64 build + .app bundle
   - Web/WASM build
6. **Verify artifacts** — GitHub Release page has all three artifacts
7. **Close milestone** — mark milestone as closed in GitHub

## Safety

- **Requires explicit approval** — never release without user confirmation
- Verify `main` is green before tagging
- Do not force-push tags
- Do not delete existing tags
- Do not modify release artifacts after upload

## Proof

Release is complete when:

- Tag pushed to origin
- GitHub Actions release workflow triggered
- All three artifacts built (Linux, macOS, Web)
- GitHub Release page created with artifacts
- Milestone closed

## Final Response

Report:
- Version tagged
- Milestone closed
- Artifacts verified
- Release URL
- Any issues or warnings
