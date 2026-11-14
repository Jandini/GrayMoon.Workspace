# Bootstrap Prompt — Implement Branch-Aware Restore and Safe Workspace Repository Setup

> **Use:** Copy this entire document into the coding agent working in the GrayMoon repository. Give the agent both companion files: `GrayMoon-Workspace-Restore-Branching-Design.md` and `GrayMoon-Workspace-Restore-Branching-Implementation-Plan.md`.
>
> **Status:** Engineering instructions. Treat the user-approved decisions below as fixed; the codebase is the authority for exact implementation details.

---

## Mission

You are implementing two related, narrowly scoped improvements in **GrayMoon**:

**A. Restore from Repository — branch selection.** Preserve the current searchable repository selector. Once a repository is selected, reveal exactly **one additional searchable branch dropdown** using that repository's remote branches. Preselect the provider's actual default branch. Do **not** check every branch for a GrayMoon manifest. Once the user **selects** a branch (including the preselected default), run manifest preflight **only on that selected branch**. A missing/invalid manifest makes Restore unavailable. Clicking Restore must restore from **the same branch** that passed preflight, using the current restore workflow with as little change as possible.

**B. Converting an existing Git repository to a GrayMoon Workspace repository — safe setup branch.** Do not generate/commit configuration directly on the default branch. Before making conversion-related file changes, show a small dialog: user-editable suggested branch `graymoon/workspace-setup`, base shown as actual remote default, and **Push branch to origin** checked by default. After confirmation, validate safety, create/check out the new branch from the correct base, generate the existing managed configuration, **commit only the intended GrayMoon configuration changes**, and optionally push the setup branch. **Never automatically create a PR.** The developer handles merging.

The two features must work together: a newly pushed setup branch is selectable in Restore even before it has been merged into the default branch.

## Mandatory inputs and scope

Read the two companion Markdown documents fully. Inspect and follow `AGENTS.md`, `CLAUDE.md` and relevant repository rules; inspect the **current implementation branch** rather than assuming the source tree is identical to a prior review.

Relevant entry points to trace include:

```text
src/GrayMoon.App/Components/Modals/RestoreWorkspaceModal.razor
src/GrayMoon.App/Components/Modals/RestoreWorkspaceModal.razor.cs
src/GrayMoon.App/Components/Shared/RepositoryPicker.razor
src/GrayMoon.App/Components/Pages/Workspaces.razor
src/GrayMoon.App/Services/WorkspaceManifest/RemoteWorkspaceManifestReader.cs
src/GrayMoon.App/Services/WorkspaceManifest/WorkspaceManifestService.cs
src/GrayMoon.App/Services/Application/WorkspaceRepositoryOperations.cs
src/GrayMoon.Application/Workspaces/IWorkspaceRepositoryOperations.cs
src/GrayMoon.Worker/Commands/AttachWorkspaceRepositoryCommand.cs
src/GrayMoon.Worker/Jobs/Requests/AttachWorkspaceRepositoryRequest.cs
src/GrayMoon.Worker/Commands/CreateBranchCommand.cs
src/GrayMoon.Worker/Commands/CommitGitChangesCommand.cs
src/GrayMoon.Worker/Services/GitService.cs
src/GrayMoon.App/Services/GitHub/GitHubService.cs
```

These are investigation starting points, **not a license to change every file**. Find the real call graph and make a focused modification. Reuse current connector HTTP services, Worker process execution, repository access broker, locking, manifest serializers and progress notifications. Do not introduce an unbounded Git subprocess launcher or a second restore engine.

## Execution discipline

1. **Do Phase 0 first:** map current restore, attach/clone, first-time conversion and file writes. Run baseline tests and add narrow characterization tests. Explicitly identify what today commits or pushes versus merely writing files. Stop if current behavior differs materially from the design.
2. Implement **A first** using small vertical slices: provider-neutral remote branch listing → branch selector → selected-branch preflight → branch propagated into attach/restore → tests. Produce an interim summary and test evidence before moving to B.
3. Implement **B second**: setup-dialog and preconditions → branch-safe generation → narrowly scoped commit → optional push/retry → tests. Never let the original conversion code write the default branch before the dialog runs.
4. Prefer one conceptual change per commit. Keep schema/DB changes out unless genuinely required. Protect the current default-branch restore behavior with tests throughout.
5. At each phase, provide changed files, precise reasoning, tests run, and remaining risks. Avoid placeholder implementations or tests that merely mock away the relevant invariant.
6. Do not auto-commit/push the **implementation work in the GrayMoon code repository**. The new application feature may commit/push only during the simulated/test or user-confirmed *Workspace repository setup* flow, as required by this specification.

## Non-negotiable acceptance rules

### Restore UI

- No new wizard. Add a branch dropdown below the existing repository dropdown.
- Both selectors allow in-place filtering; branch filtering happens locally and does not preflight branch contents.
- Fetch branch names lazily after repository selection; handle server pagination, rate limits and cancellations.
- Default branch comes from provider metadata, never a hardcoded `main` guess.
- Trigger a single selected-branch manifest preflight after branch selection. Missing manifest, invalid manifest, auth failure or deleted branch disables Restore.
- On repo/branch switch, synchronously clear old validity and cancel/ignore stale responses. The user must never be able to restore branch B using branch A's green preflight.
- Keep existing Fetch Repositories and repo selection reconciliation behavior.

### Selected-ref correctness

- Require an explicit branch/ref in the new preflight and restore contracts.
- Preserve opaque branch names containing `/` and use provider-safe encoding/Git argument vectors.
- Preflight and actual Workspace-repository clone/checkout must target the same selected branch, verified by exact identity; preferably detect branch tip movement by SHA and revalidate or refuse.
- A missing ref or auth failure must **never** silently fall back to default.
- Do not change Source-repository checkout behavior defined by the manifest.
- Existing default-branch restorations remain backward-compatible.

### Setup branch and controlled commit

- Show confirmation **before** any setup-related file writes, with editable suggested `graymoon/workspace-setup` and default-on push checkbox.
- Validate name using Git ref rules, reject local/remote collisions, resolve real base/default and verify base tip. Do not reuse/reset/force-create existing branches.
- **Safe v1:** fail preflight if staged/unstaged/untracked developer changes exist in the target repo. Do not auto-stash, reset or include unrelated work. Confirm no output-path collisions.
- Create and check out a *new* branch from the verified base, then write files. The original default branch must remain byte-for-byte at its original Git commit.
- Reuse existing `graymoon.json` authoring and managed `.gitignore` and optional `codegraph.json` logic. Preserve existing data, file-owned properties and migration/adoption safeguards.
- Explicitly allowlist and stage only managed paths that this operation changed. Never `git add .`, `git add -A`, `git commit -a`, or the existing `StageAllFirst=true` blanket commit mode.
- Inspect the staged file list before commit; refuse unexpected paths. Commit with a descriptive message, e.g. `chore(graymoon): initialize workspace repository`.
- If nothing changed, do not manufacture an empty commit. Prefer no-op detection before branch creation.
- Push new branch (with upstream) only if selected. Do not force push and do not create a PR.
- If push fails, keep the successful local commit and branch; report `local commit succeeded; push failed`, with a safe retry path or actionable guidance. Never roll back a successful local commit because a remote push failed.
- Never silently delete/overwrite a branch or lose existing edits on error/cancellation.

### Safety and architecture

- Respect existing structural locks, Workspace vs Feature context identity, Worker repository-access leasing, scoped DB contexts, and file watcher/worker snapshot patterns.
- Repo branch selection API must work before a repository has been cloned/linked; do not rely on persisted `WorkspaceBranchOperations` rows for this dropdown.
- Avoid connector-specific types in UI/application interfaces; use a GitHub adapter now with room for Azure DevOps later.
- No credentials, authorization headers or full private manifest content in logs. Log operation stage, repo ID, branch, commit SHA, timing and classified errors.
- Preserve current CodeGraph behavior and source-repo policies.

## Test plan that must actually be executed

### Focused unit/component tests

- Branch dropdown appears when repo selected, filters in place, and preserves selected item.
- Branch filter events cause **zero manifest reads**; selected branch causes one preflight.
- Provider default `trunk` is selected instead of `main`.
- 101+/250+ paged branches, nested refs, missing branches, connector auth/SSO and transient API errors.
- Rapid repo/branch toggles produce stale responses out of order; only current matching preflight can enable Restore.
- Manifest on non-default branch with no default-branch manifest is accepted.
- Missing/invalid manifest disables Restore with actionable message.
- Catalog refresh changes repository identity; branch and preflight state reconcile safely.

### Temporary Git integration tests

Create disposable local bare remotes and clones for these assertions:

1. Restore branch `release/1.2`: loaded manifest and final Workspace-role `HEAD` point at `release/1.2`, not default.
2. Remove or advance branch after preflight: operation refuses or revalidates; never falls back.
3. Setup against protected/immutable-default simulation: default SHA before == default SHA after; new setup branch commit exists.
4. `git show --name-only <setup-sha>` contains exactly expected managed paths, not unrelated files.
5. Clean/dirty/staged/untracked cases prove safe refusal without automatic cleanup or lost changes.
6. Push-on branch exists on bare remote with correct upstream; push-off branch exists only locally.
7. Push rejection or transport failure preserves local branch and commit; safe retry does not generate a second commit.
8. Existing `graymoon.json`, managed `.gitignore`, optional `codegraph.json` content preservation and no-op cases.
9. Current default-branch restoration and feature/source sync regression.

Run the applicable `dotnet build` and `dotnet test` commands for App, Worker and their tests, following the solution layout. Provide real results with failures and fixes; **never claim tests passed if not run**.

## Failure handling and stop rules

If a safe branch setup or path-only commit requires invasive changes, pause and report the precise code obstacle. Do not patch around a dirty index with a blanket commit or auto-stash. If an existing root manifest would be overwritten, stop and preserve it. If the Worker cannot guarantee selected-ref checkout, do not label the feature complete. If a ref cannot be identified reliably, refuse instead of guessing.

User-facing errors should be short, concrete and state-aware:

- `No GrayMoon workspace manifest was found on branch 'feature/example'. Choose another branch.`
- `The selected branch changed after validation. Select it again to refresh the workspace manifest.`
- `Branch 'graymoon/workspace-setup' already exists. Enter another name.`
- `This repository has uncommitted or staged changes. Finish or set them aside before preparing its Workspace configuration.`
- `Workspace configuration was committed locally on 'graymoon/workspace-setup', but the push to origin failed. Your local commit is safe.`

## Definition of done and final response

Deliver:

1. A brief Phase 0 finding: current behavior, actual paths touched, important differences from reviewed baseline.
2. A clear file-by-file change summary and explanation of interface/Worker contract compatibility.
3. Evidence for the **same-ref** invariant and **no default-branch mutation / managed-files-only commit** invariant.
4. Builds and test results with actual commands, including temporary Git integration tests.
5. Residual limitations (e.g. no branch manifest badges, no automatic PR, any deferred retry UI).
6. Any documentation updates needed to keep the architecture/user-flow docs accurate.

**Primary success criterion:** The existing Restore experience acquires one searchable branch dropdown, validates only the selected branch, and restores from that branch; converting an existing root repo creates and optionally publishes a dedicated, safely scoped configuration commit instead of putting the developer's default branch at risk.
