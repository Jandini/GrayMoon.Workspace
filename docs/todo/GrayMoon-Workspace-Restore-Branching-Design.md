# GrayMoon - Workspace Repository Branching and Restore-from-Branch

**Document:** Technical design  
**Status:** Increment A (restore from a chosen branch) implemented 2026-11-14. Increment B (setup branch) is not built; section 6 has been corrected against the code and awaits a go-ahead.  
**Date:** 2026-11-14  
**Scope:** Restore from repository; conversion of an existing repository into the Workspace repository  

## 1. Executive decision

Make two focused changes without redesigning the rest of GrayMoon:

1. **Restore from repository:** After choosing a repository, show **one additional searchable branch dropdown**, populated with that repository's existing remote branches. Select its real default branch initially. **Do not inspect manifests while populating/filtering branches.** Only after a branch is selected, preflight the `graymoon.json` manifest in that branch. Restore uses the **same selected branch**, never silently the default branch.
2. **Convert an existing repository to the Workspace repository:** Before creating or rewriting GrayMoon-owned configuration, prompt for an editable new setup branch name (suggest `graymoon/workspace-setup`) and an optional **Push branch to origin** checkbox, checked by default. Create/check out the setup branch, generate configuration, commit **only the precise files generated/modified by this operation**, and optionally push it. **No automatic PR. No direct commit/push to the default branch.**

These workflows complement each other: a user can push the setup branch, then restore that workspace from the setup branch on another computer before the change is merged.

## 2. Goals and non-goals

### Goals

- One extra branch selector in the existing Restore dialog; repo filtering and fetch remain unchanged.
- Responsive branch filtering without one network request per keystroke or manifest checks per branch.
- Manifest preflight that is bound to the exact repository and selected ref, including on rapid selection changes.
- Backward-compatible default-branch restoration.
- Branch-safe, auditable first-time Workspace repository setup; no mixed commits with existing developer changes.
- Explicit, actionable handling of missing manifests, inaccessible branches, protected branches, existing names, and failed pushes.
- Reuse existing manifest writer, Worker/Git infrastructure, authentication, locking and progress UI.
- Keep the feature compatible with future connector types (for example Azure DevOps), not hardwire UI contracts to GitHub-specific DTOs.

### Non-goals

- No manifest pre-scan of every branch, manifest-aware branch search, branch badges for manifest presence, or background branch validation.
- No PR generation, merge automation, remote branch deletion, or auto-switch to the default branch after setup.
- No changes to source-repository branch policy, feature-worktree orchestration, or workspace dependency restore behavior beyond passing through the chosen Workspace-repository branch.
- No manifest schema change just to record the branch selected during restore.
- No implicit pushing of unrelated changes or automatic force pushes.

## 3. Existing implementation surfaces (code-review map)

Reviewed against the `GrayMoon` repository at `6f65c93a` (all paths below are under `GrayMoon/`; verified 2026-11-14). The companion Implementation-Plan and Agent-Prompt documents this file used to cite were never written and are not needed.

| Area | Existing entry points | Design consequence |
|---|---|---|
| Restore dialog | `src/GrayMoon.App/Components/Modals/RestoreWorkspaceModal.razor` and `.razor.cs` | Keep the existing repository picker and preflight UI; add branch state and selector. |
| Repository picker | `src/GrayMoon.App/Components/Shared/RepositoryPicker.razor` | Match its searchable/filter-in-place interaction, without abusing repo-specific logic. |
| Remote manifest preflight | `src/GrayMoon.App/Services/WorkspaceManifest/RemoteWorkspaceManifestReader.cs` | Extend the read contract with an explicit branch/ref, keeping a default-branch overload where needed. |
| Repository restore orchestration | `src/GrayMoon.App/Services/Application/WorkspaceRepositoryOperations.cs` and `src/GrayMoon.Application/Workspaces/IWorkspaceRepositoryOperations.cs` | Propagate the chosen branch into restore/attach instead of resolving default branch later. |
| Worker attach | `src/GrayMoon.Worker/Commands/AttachWorkspaceRepositoryCommand.cs`, `src/GrayMoon.Worker/Jobs/Requests/AttachWorkspaceRepositoryRequest.cs` | Update checkout/clone contract and ensure selected ref survives throughout the operation. |
| Workspaces page | `src/GrayMoon.App/Components/Pages/Workspaces.razor` | Owns Add Workspace, choosing Workspace repository and the dialog lifecycle. |
| Workspace-repository enable flow | `src/GrayMoon.App/Services/Application/WorkspaceRepositoryOperations.cs` | Introduce a setup-branch operation before managed files are written in existing-repository conversion paths. |
| Workspace definition | `src/GrayMoon.App/Services/WorkspaceManifest/WorkspaceManifestService.cs` | Reuse `SyncDefinitionToDiskAsync` and respect file-owned fields and managed sections. |
| Managed files | `graymoon.json`, managed block of `.gitignore`, and optionally `codegraph.json` | Stage only actual paths changed by this conversion. Preserve other sections/properties. |
| Branch operations | `WorkspaceBranchOperations.cs`, Worker `CreateBranchCommand.cs`, `GitService.cs` | Reuse Git abstractions where appropriate, but do not rely on an existing linked-repository branch API for a repo not yet attached. |
| Git changes commit | Worker `CommitGitChangesCommand.cs`, `StageAndCommitRequest` | `StageAllFirst` (the Changes page "commit all" mode) is unsuitable for the setup commit. `StageAndCommitRequest.PathsToStage` already stages an explicit path list and is the starting point; it still needs the clean-index precondition and a check of the staged diff. |
| Connector API | `GitHubService` partials, connector/repository services | Add narrowly scoped, paginated remote-branch listing and branch content reads via connector credentials. |

**Phase 0 result (verified in code):** `EnableWorkspaceRepositoryAsync` attaches the repository, then writes the managed `.gitignore` section and `graymoon.json` (through `WorkspaceManifestService`) and rescans Git Changes. It never branches, commits or pushes: the files are left uncommitted for the user to commit from the Changes page. When the folder already is that repository (`AdoptedExisting`) it writes nothing. `CodeGraph` config is written only when the definition has `"codegraph": true`. Add Workspace and Edit Workspace reach this one method; Restore does not write files except an optional definition rewrite. So section 6 describes a new behavior of Enable, not a change to an existing commit.

## 4. UX specification - Restore from repository

### 4.1 Intended layout

```text
Restore from repository

Repository
[ Search repositories...              v ]    [ Fetch ]

Branch                       (appears once a repository is selected)
[ main                             v ]
   Search branches...
   main                         Default
   develop
   feature/workspace-setup
   graymoon/workspace-setup

[Workspace manifest status / existing restore preview]

                                         [Cancel] [Restore]
```

Do not add a new page or wizard. Use the existing styling, type-ahead mechanics, focus and keyboard patterns of the repository selector. The branch selector is **hidden until a valid repo has been selected**. A pending branch list shows a small in-field spinner or placeholder; it does not block search/filter in other fields. Restore Workspace offers GitHub repositories only today (`ReloadChoicesAsync`), so the GitHub adapter is the only implementation; the interfaces stay provider-neutral.

### 4.2 Interaction contract

1. User opens **Restore from repository**; existing repository search/fetch behavior works unchanged.
2. User selects repository `R`. Clear any old repo/branch preflight. Asynchronously list remote branches for `R`, with cancellation or a generation token.
3. Resolve `R`'s actual provider default branch; when available in the returned branches, preselect it. Never hardcode `main` or choose `master` by guesswork. If the default is not available/verified, do not silently pick an arbitrary branch; show a recoverable branch-list error or require explicit selection.
4. Branch dropdown filters **locally as the user types**, case-insensitive substring matching, with sensible ordering (default first, others sorted). Branch names are case-preserved. Support large branch lists via paging and, if needed, list virtualization; provider pagination must not truncate silently. **As built:** the branch field is a native text input with a `datalist` (browser substring filtering, default shown first and labelled "Default"), not a copy of `RepositoryPicker`, because the picker is keyed by integer repository id and its scoped CSS would have to be duplicated. A choice is committed on change/selection (not per keystroke) and must be a listed name. Provider paging is capped at 20 pages of 100; a longer list sets `Truncated`, the dialog says so, and an exact typed name is then accepted and left to the preflight and the Worker. A name that is not listed stays in the field with a message under it and Restore stays off. Keys pressed in the branch field do not reach the dialog (Escape still closes it), so Enter there commits the branch and cannot start a restore from the branch validated before; focusing the field selects its text so typing replaces the preselected default.
5. **Only after a branch becomes selected** (including the initial default selection), preflight `graymoon.json` at exactly that branch. Branch menu opening, filtering, arrow navigation/highlighting, or list fetch does not trigger manifest checks.
6. If manifest missing, invalid, inaccessible, unsupported, or the branch was deleted, show the existing/friendly preflight error and disable **Restore**. The user can choose a different branch immediately.
7. If preflight passes, show the current restore preview/actions unchanged. **Restore** is enabled only when the validated repository/branch matches the current selection.
8. On Restore, capture an immutable selection and pass that branch to the existing restore orchestration. Continue existing repository synchronization, profile setup, import and error behavior, except ensure the Workspace repository is attached/checked out from that branch.

**Preflight is one branch at a time, not a scan of all branches.** Opening a branch list for a repository with 1,000 branches must not issue 1,000 manifest requests.

### 4.3 Interaction and concurrency safeguards

- On repository change: clear branch, branch list, manifest validation, summary, and restore readiness immediately. Cancel in-flight requests and increment request generation.
- On branch change: clear previous validation/readiness immediately; cancel obsolete preflight and increment validation generation.
- Ignore stale branch list or validation completions even if the underlying provider call cannot cancel.
- Preflight state key: `(connector identity, provider repository identity, selected full branch name)`; optionally pin a resolved commit SHA for stronger consistency.
- Disable Restore during incomplete/failed preflight, changing selection, or in-progress restore; server-side validation must repeat the branch/repo match and existence checks.
- Distinguish `missing manifest` from `permission/SSO`, `rate limit`, `network`, `invalid manifest`, and `branch removed` in error handling.
- On catalog Fetch while dialog is open, preserve the selection if the canonical repo identity still exists, then refresh branch list and invalidate stale preflight; clear selection if it disappears. **Not done in increment A:** a catalog Fetch that keeps the same repository does not re-list its branches or re-run the preflight; reselecting the repository does.
- Track auth per connector; no hardcoded GitHub tokens in browser state or logs.

### 4.4 Branch name handling

Treat branch names as opaque values (valid provider refs), not filenames. URL-encode each API path segment according to the provider, or use safe Git ref argument handling. A branch may contain `/`, periods and hyphens. Do not strip `origin/` from an actual provider branch name by blindly string replacement: keep display name and canonical ref separate.

## 5. Architecture - list, preflight, restore

### 5.1 Contracts (illustrative, not prescribed class names)

```csharp
// Implemented: names only, ordered default first then ordinal-ignore-case; no per-branch flag is needed.
public sealed record RemoteBranchList(
    string? DefaultBranchName, IReadOnlyList<string> Branches, bool Truncated, string? Error);

public interface IRemoteRepositoryBranchReader
{
    Task<RemoteBranchList> ListAsync(int repositoryId, CancellationToken cancellationToken = default);
}

// The selection is just (repositoryId, branchName), passed to
// PreflightRestoreAsync(..., branchName) and RestoreFromRepositoryAsync(..., branchName);
// null or blank means the default branch.
```

Implement a provider-neutral application abstraction and a GitHub adapter. Remote branch discovery is for **unattached** repositories and should therefore use connector APIs, not `WorkspaceBranchOperations.GetBranchesAsync`, which expects a workspace-linked local repository. GitHub's branch-list API must be paginated, observe API limits/ETags where available, and use the existing connector HTTP pipeline. A future Azure DevOps adapter can implement the same app-level interface.

### 5.2 Branch-scoped manifest read

Modify the existing `RemoteWorkspaceManifestReader` path to accept explicit `BranchName` and, ideally, retrieve a content SHA/commit SHA alongside the manifest. The read must be from the **selected ref**; not a default-branch URL that only changes the UI label. Preserve existing manifest schema and parser. Keep a backward-compatible overload for callers needing the default branch, but make the new Restore path always provide an explicit branch.

**Corrected:** a `ManifestPreflightResult` and a content/commit SHA are not added. The existing `RestoreWorkspacePreflight` is reused. A late answer is dropped by the token in `RestorePreflightGate` (every repository or branch change begins a new token) plus a check that the branch still matches. `IRemoteWorkspaceManifestReader.ReadAsync(repositoryId, branchName, ct)` reads `?ref=<branch>`; the old two-argument form remains as a default interface method (default branch).

### 5.3 Same-ref invariant during restore

The central invariant is:

> **The branch whose manifest GrayMoon validated is the branch from which it restores the Workspace repository.**

Propagate explicit `BranchName` through the Restore dialog → application operation → Worker attach/sync command. For a fresh clone, check out (or clone directly into) the named branch and verify `HEAD` matches the expected branch before proceeding. Do **not** check out the named branch for unrelated Source repositories: their existing manifest-defined rules remain in force.

**Corrected:** pinning and comparing a tip SHA is not needed. Restore already validates twice: the connector read at preflight, then the definition read again from the cloned local copy (`RestoreIntoWorkspaceAsync`, step D14-3) against the same checked-out branch. A branch tip that moved in between is therefore validated again, not trusted, and a failure there rolls the Workspace back. A branch removed before Restore fails the Worker attach with "Branch ... was not found on the remote"; there is no fallback to the default branch.

**Avoid a second implementation of restore:** branch selection changes only the source ref of the Workspace repository. Existing restore import, cloning, manifest parsing, dependency settings, profile, CodeGraph behavior and safe retries should be reused.

## 6. UX specification - convert existing repository

### 6.1 When the dialog appears

Show a compact **Prepare Workspace repository** dialog only when the action will convert an existing Git repository into the Workspace-role repository **and** needs to generate or modify its GrayMoon configuration. Do not display it for a no-op reattachment of a repository already holding a valid intended setup, and do not silently change established behavior of separate creation paths. Phase 0 must map Add Workspace, Edit Workspace, repository import, and Enable Workspace Repository entry points.

```text
Prepare Workspace repository

Repository: org/workspace-root
Create setup branch from: main (default)

New branch
[ graymoon/workspace-setup              ]

[x] Push branch to origin

GrayMoon will generate its configuration and commit only
those configuration changes on this branch. No pull request
will be created and the default branch will not be modified.

                                   [Cancel] [Create and commit]
```

The **new** branch name is editable; resolve base from the actual remote default branch. A separate base-branch picker is not needed for this first iteration unless an existing workflow requires it; do not add unnecessary UX. Validate the candidate using Git ref checks, not only a regex. Branch name collision must block the operation and prompt for a different name; **never silently reuse, reset, overwrite, or force-create** a matching local or remote branch.

### 6.2 Operation sequence

```text
Confirm → preflight repo identity, clean worktree/index, remote default/base,
           destination branch absence, and branch policy
        → create/check out new local branch from verified base commit
        → write GrayMoon configuration using existing manifest services
        → identify and validate the exact changed managed files
        → commit only those file changes
        → optionally push the new branch with upstream tracking
        → persist/refresh Workspace state and show outcome
```

A setup operation must not create or commit changes on a protected default branch. Protection might not be knowable in advance; branch isolation is the guarantee. Push refusal on the **setup** branch is a recoverable post-commit failure.

### 6.3 Managed changes and unrelated work

- Candidate managed files: `graymoon.json`, `.gitignore` (its managed section only when editing content), `codegraph.json` if enabled; any additional generated files must be discovered from the *real* conversion code and explicitly allowlisted. The **file contents remain owned by their existing services**.
- Because a Git commit captures **all staged changes**, do not use blanket `git add .`, `git add -A`, or `CommitGitChangesCommand` with `StageAllFirst=true`.
- **Recommended v1:** require the target repository to have a clean index and worktree before creating the setup branch (including ignored/untracked collisions at managed output paths). This is a deliberate safety rule, not a hidden stash. User changes remain untouched when blocked.
- Still stage only the allowlisted paths, and verify the staged diff exactly matches the expected generated changes. A path-specific commit is safe after requiring a clean index; use an isolated temporary Git index or equivalent when feasible so unrelated staged entries cannot leak into the commit.
- Preserve hand-authored `.gitignore` sections, arbitrary `codegraph.json` properties, existing valid `graymoon.json` file-owned data, and any repo adoption rules; refuse overwrite on conflicts rather than destroy data.
- If no actual file changes result, do not create an empty commit/push. Report “already configured” and leave a created branch only if explicitly desired; ideally detect no-op before branch creation.

### 6.4 Result and failure behavior

| Failure point | Required result |
|---|---|
| Bad branch name / existing branch | No writes, no checkout; keep dialog open. |
| Dirty worktree or staged changes | Refuse with clear paths; never auto-stash, reset, or commit them. |
| Branch create/checkout failure | No generated files; keep original branch checked out. |
| Manifest/CodeGraph file write failure | No automatic commit; report setup branch and failed step. Safely remove the newly created branch only if its state is provably unchanged/clean; otherwise preserve it. |
| Commit failure | Preserve generated files and new branch for manual inspection/retry. |
| Push failure | **Local setup commit is successful**. Preserve it; report that remote publication failed, with a Retry Push action or clear command guidance. |
| Cancellation | Cancel only at safe boundaries; do not delete a successful commit, rewrite the default branch or discard changes. |

The UI should distinguish `Prepared locally`, `Pushed to origin`, `Already configured`, and `Failed before commit`. **No automatic PR** or forced remote operation.

## 7. Branch lifetime and source-of-truth semantics

The setup branch is a **temporary publication mechanism**, not a new forever-authoritative Workspace setting. Restoring from it selects that ref for the *initial restore*. The provider default branch continues to be what the provider defines. Do not save `graymoon/workspace-setup` in the manifest as a permanent source branch; doing so would break after the developer merges and deletes it.

After merge, a new restore can simply choose the default branch, now containing `graymoon.json`. If users restore before merge, the dialog lists the setup branch and its manifest passes preflight. GrayMoon's normal branch operations remain available afterward; no automatic switch on merge/deletion is required in this feature.

## 8. Concurrency, security, robustness

- Run setup as one repository-scoped structural operation in the current Workspace context; do not race with background Sync, Git watchers, branch checkout, CodeGraph file writes, or settings updates. Reuse existing operation locks/worker process brokers.
- On a shared worktree, take the appropriate Worker access/lease, and avoid direct unbounded `Process.Start` or unmediated LibGit2Sharp access.
- Use connector-scoped credentials for API reads and authenticated pushes; never emit PATs or authorization URLs containing secrets in logs.
- Audit events with workspace ID, repo ID, provider, base ref/SHA, selected/setup branch, manifest ref/SHA, stage, commit SHA, push state, elapsed time, and error codes; avoid dumping file contents.
- Git ref validation prevents argument injection; use argument vectors rather than shell string concatenation.
- Ref retrieval should be bounded, cancellable, respect rate limits, and handle private/enterprise/SSO GitHub repositories using current connector error normalization.
- Make recovery idempotent: after a partially successful setup, retry the failed stage (particularly push) rather than creating duplicate branches or duplicate commits.

## 9. Acceptance criteria

- [ ] Existing default-branch restores behave as before, with the real default selected automatically.
- [ ] Selecting a repository reveals a searchable branch selector; branch filtering never calls manifest preflight.
- [ ] Every selected branch triggers one fresh branch-specific manifest preflight; missing/invalid manifest disables Restore.
- [ ] Rapid repo/branch changes cannot enable Restore based on an outdated response.
- [ ] A successful restore checks out/loads the **same branch** that was preflighted, or safely revalidates if its tip changed.
- [ ] A branch containing the manifest works even when default branch does not contain one.
- [ ] Conversion of an existing repo creates a user-named setup branch **before** writing files, and never commits on default.
- [ ] The setup commit contains only intended managed changes, not unrelated staged or working changes.
- [ ] Push is offered and default-on; no PR is created; a failed push preserves the local commit.
- [ ] No automatic branch overwrite, reset, force push, or silent fallback to default.
- [ ] Relevant unit/integration/Worker tests, documentation, and backwards-compatibility tests pass.

## 10. Suggested delivery boundary

Deliver this as two increments with shared ref-contract tests: **A - Restore selection and end-to-end selected-branch propagation** (primarily read/attach, lower risk) and **B - Existing-repository setup branch and controlled commit/push** (write-sensitive, independently gated). Do not combine with a broad Git service rewrite or unrelated UX redesign.

## 11. Implementation status and corrections (2026-11-14)

Increment A is implemented. Changes against this design:

- **Contracts:** `IRemoteRepositoryBranchReader` and `RemoteBranchList` live in `GrayMoon.Application/Workspaces`; `IRemoteWorkspaceManifestReader.ReadAsync` gained `branchName`; `PreflightRestoreAsync` and `RestoreFromRepositoryAsync` gained an optional `branchName`; `AttachWorkspaceRepositoryRequest` gained `branchName`. No `ValidatedCommitSha` or `ManifestPreflightResult` (see 5.2 and 5.3).
- **Worker:** after the clone (or the init path for a non-empty root) the Worker checks out `origin/<branch>` and verifies HEAD. A missing branch fails with a message; a name that is not a plain ref name (leading `-`, spaces, quotes, `..`, `@{`, `refs/`) is refused before it reaches a git argument string. `CheckoutTrackingAsync` still builds an interpolated command string, so the validation is what keeps it safe; converting it to `ArgumentList` is a separate cleanup.
- **Tests:** `AttachWorkspaceRepositoryCommandTests` (checkout, missing branch, init path, unsafe names), `WorkspaceRepositoryOperationsTests` (branch reaches the reader and the Worker, null keeps the default, ordering).
- **Docs:** `05-user-capability-reference.md` and `01-product-model-and-user-workflows.md` describe the new Restore behavior.
- **Open for increment B:** section 6 is unchanged apart from the Phase 0 note above. Decisions needed before building it: where the setup-branch dialog hooks in (Enable on a folder that is not yet the repository, or also the adopt path), and whether the commit/push run as a new Worker command or compose `CreateBranch`, `StageAndCommit` and `PushRepository`.
