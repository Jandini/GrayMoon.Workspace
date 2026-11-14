# GrayMoon — Branch-Aware Restore and Safe Workspace Repository Setup

**Document:** Detailed staged implementation plan  
**Status:** Ready for engineering  
**Date:** 2026-11-14  
**Depends on:** `GrayMoon-Workspace-Restore-Branching-Design.md`  
**Repository baseline reviewed:** `Jandini/GrayMoon` at approximately `6f65c93af787254aa4417273af1e791dd7a3550f`; inspect the actual implementation branch before editing.

## Delivery strategy

Two independent increments, shared primitives where justified:

- **Increment A (restore):** selectable remote branch, manifest preflight on selection, exact-ref restore, no changes to generated files or commit behavior.
- **Increment B (setup):** branch-safe existing-repository conversion, dedicated setup commit of managed files only, optional push, no PR.

Do not merge Increment B until A's regression suite is green. Keep all new calls within existing Worker, connector and operation-lock architecture. Implement the minimum necessary contract extensions; avoid a broad rewrite of sync, branch management or manifest serialization.

## Phase 0 — Discovery, characterization and baseline safety tests

**Mandatory before production code changes.**

1. Read `AGENTS.md`, `CLAUDE.md`, existing architecture docs, the selected branch's tests and relevant `.cursor/rules`. Verify the user's branch, repo status and targeted version. Do not assume main is the checked-out implementation branch.
2. Trace *every* Restore call from `Workspaces.razor` through `RestoreWorkspaceModal.razor[.cs]`, `RemoteWorkspaceManifestReader`, `IWorkspaceRepositoryOperations`, `WorkspaceRepositoryOperations`, the Worker attach request/command and final manifest import. Record which step currently resolves the default branch, which step uses the manifest content, and whether the attach checks out a branch.
3. Trace Add Workspace / Edit Workspace / Enable Workspace Repository / adopt-existing-folder flows. Distinguish repo conversion from new-repo creation and no-op adoption. Record all paths where `graymoon.json`, managed `.gitignore`, `codegraph.json` or versioning files are written, and whether *any path actually commits or pushes today*. Do not infer that setup always creates a commit.
4. Examine the existing `RepositoryPicker` behavior (search, focus, navigation, dropdown overflow, keyboard accessibility), current GitHub connector request infrastructure and API models, Git branch/checkout APIs, Worker access leases, structural operation locks, and existing `GitChanges` staging/commit commands.
5. Add characterization tests proving the current default-branch restore contract, existing manifest write preservation (`codegraph`, `ai`, tag/revision pins, `versionFiles`, `.gitignore` markers), and unaffected Source-repository branch behavior.
6. Identify tests requiring real temporary Git repositories versus mocked HTTP/Worker interactions; use existing fixtures wherever possible. Write a compact discovery note listing exact methods to modify and any divergence from this document.

**Exit:** baseline tests pass; selected-branch propagation points and file-write side effects are enumerated. No risky production mutations yet.

## Phase 1 — Remote branch discovery (Increment A)

### Required behavior

A repository may be present only in GrayMoon's catalog and not yet cloned. Discover its **remote** branches via the connector, not by reading Workspace-linked local branch rows. Return the provider's authoritative default branch and a complete list of selectable branches.

### Implementation tasks

1. Introduce a small provider-neutral read interface under the appropriate Application/connector abstraction (e.g. `IRemoteRepositoryBranchReader`). Prefer immutable records carrying canonical repository identity, default branch name, branch name and optionally tip SHA.
2. Add the GitHub implementation, likely in a new `GitHubService.Branches.cs` partial or a focused service. Use the *existing* `GitHubService` HTTP transport, connector authentication, status/rate-limit handling, and repository identity parsing. Inspect and reuse existing pagination helpers. The GitHub API is `GET /repos/{owner}/{repo}/branches?per_page=100&page=N` (or equivalent provider capability). Retrieve the authoritative default branch from repository metadata. Account for `main`, `master`, arbitrary default, enterprise hosts and renamed repos.
3. Avoid filtering branches by whether `graymoon.json` exists; no content reads in list calls.
4. Return stable structured errors for `repository not found`, `connector missing`, `403/SSO`, `401`, network/timeout, and API rate limit. Do not collapse all into an empty list.
5. Register the service once in DI; no duplicate HTTP clients or token caches.

### Tests

- Default branch `trunk` (not main/master).
- 0, 1, 99, 101, 250+ branch responses; paging does not silently truncate.
- Nested refs (`feature/a/b`), case-preserving names, special characters valid as refs.
- 404, 403, SSO, rate limits, expired credentials, canceled requests.
- Branch-list operation issues **zero** manifest reads.

**Exit:** branch list and exact default returned for an unattached repo using its existing connector.

## Phase 2 — Searchable selector and selection lifecycle (Increment A)

### Primary code

`RestoreWorkspaceModal.razor`, `RestoreWorkspaceModal.razor.cs`, `RepositoryPicker.razor` (reuse existing styles/behavior; refactor only when genuinely needed), existing restore dialog CSS.

### Tasks

1. Add branch selector immediately beneath the existing repository selector. Hide until a repository is chosen; show loading/failed/empty state appropriately.
2. Mimic repository selector's in-place filter, clear/reset, focus management, keyboard controls, scrolling, selected item, and accessible labels. Do **not** add a second dialog or complex wizard.
3. When repository changes, invalidate and cancel all prior branch list/preflight state. Kick off exactly one branch-list request (plus pagination within service). Ensure provider/canonical identity is used rather than just display text.
4. When list returns, preselect the verified default. Present it at the top with the existing UI's minimal **Default** distinction; sort remaining branches consistently. Do not assume `main` or silently select an arbitrary branch when provider default cannot be resolved.
5. Filter locally (case-insensitive substring); typing does not make API calls or trigger preflight. Preflight starts when a branch is actually selected, *including default auto-selection*.
6. Use independent generation/version counters plus cancellation tokens for list and preflight. On every selection change, clear validated manifest, preview and restore eligibility before awaiting anything.
7. Maintain the existing Fetch Repositories behavior. When the catalog refresh replaces IDs after a rename/merge, reconcile canonical identity and reload branch state; never validate the previous repo by accident.
8. Set Restore enablement to `selected repo && selected branch && validated current preflight && !busy` and enforce again in the handler.
9. Dispose tokens and avoid set-state-after-dispose/circuit disconnect races.

### Tests

- Repository selection reveals branch selector and starts listing.
- Selecting no repository hides branch selector and disables Restore.
- Default branch auto-selection triggers only one preflight.
- Typing to filter branch choices invokes **no** preflight or network request.
- Quick `repo A → B → A` discards stale results.
- Quick `branch A → B` discards stale A validation, even if A request completes last.
- Fetch Repositories while dialog open preserves/clears current selection correctly.
- Keyboard navigation, Escape/Enter behavior, large list and empty states.

**Exit:** UI is fluent and shows branch-specific preflight state without changing restore internals yet.

## Phase 3 — Manifest preflight explicitly reads selected ref (Increment A)

### Primary code

`RemoteWorkspaceManifestReader.cs`, manifest API/service contracts and existing restore preflight tests.

### Tasks

1. Extend the remote manifest read contract with *mandatory branch/ref* for this new call path. Keep a default-branch wrapper only for existing callers, not inside the branch-aware flow.
2. Use provider-correct URL encoding and reference addressing for branch names containing `/`; use the repo's matching connector identity and credentials. Preserve existing manifest validation and error messages where possible.
3. Return structured metadata: repo identity, branch, validation outcome, and branch tip SHA where supported. Detect malformed/unsupported manifest distinctly from missing manifest and auth errors.
4. Ensure the restore dialog consumes preflight only if its result exactly matches current repository/branch/generation. If a branch is absent or `graymoon.json` is absent, disable Restore with a compact actionable message.
5. Do not write any local file or alter the repo in preflight.

### Tests

- Only selected branch is read; never fall back to default.
- Valid manifest on feature branch while default lacks one succeeds.
- Missing manifest disables Restore, then selecting valid branch succeeds.
- Manifest parse/schema failures distinguish from provider errors.
- Rapid branch change cannot promote a stale success to `CanRestore`.

**Exit:** exact-ref read validated; state remains read-only and branch-safe.

## Phase 4 — Propagate chosen branch through full restore (Increment A)

### Primary code

`IWorkspaceRepositoryOperations.cs`, `WorkspaceRepositoryOperations.cs`, Restore dialog request object, Worker `AttachWorkspaceRepositoryRequest.cs`, `AttachWorkspaceRepositoryCommand.cs`, associated Git checkout/clone methods.

### Tasks

1. Capture immutable `WorkspaceManifestSelection(repoId, selectedBranch, validatedSha?)` at Restore click. Do not re-read mutable component state inside async restore steps.
2. Pass branch explicitly through **every** restore/attach/clone layer. Keep existing default-branch overloads for unaffected callers, but the new flow must not use them.
3. Worker must fetch/checkout the requested remote branch in the Workspace-role repo (or clone with that branch). Verify branch name and current commit before it signals success. Keep other Source repos governed by existing manifest semantics.
4. Strongly preferred: use validated tip SHA from preflight and verify before applying. If tip changed, revalidate manifest against the new commit or return a branch-moved error and require a new preflight. Define this behavior in one place and test it.
5. If exact ref cannot be checked out (deleted, inaccessible, ambiguous), fail with a specific error. **Never** silently use default branch.
6. Preserve existing restore sequencing, manifest import, profile/version settings, paths, connector selection, repo synchronization, CodeGraph behavior and partial-failure reporting.
7. Ensure the restored Workspace-role repository is on the requested branch, while its `DefaultBranchName` still accurately reflects the provider default (distinct concepts).
8. Preserve backwards compatibility for existing call sites and serialized Worker contracts; add optional fields/overloads with explicit fallback at legacy boundaries, not implicit fallback inside the new flow.

### Tests

- End-to-end restore from `main`, `release/1.2`, `feature/test`.
- Valid non-default branch + invalid default branch works.
- Selected branch missing after preflight fails; default not used.
- Branch advances between preflight and checkout: revalidate or refuse.
- Correct Git HEAD branch and manifest after restore.
- Existing source repo clones, profiles, CodeGraph, version file imports and rollback scenarios still pass.
- Private connector auth/SSO failure remains actionable.

**Gate A:** Run scoped test suites, app and Worker builds, and a fresh restore against a temporary Git remote. Merge only when selected-ref invariant is proven.

## Phase 5 — Safe existing-repository setup dialog (Increment B)

### Primary code

`Workspaces.razor`, `WorkspaceModal.razor` or a new small setup confirmation modal, `WorkspaceRepositoryOperations.cs` and contracts.

### Tasks

1. Identify exact entry points needing conversion (initial Add Workspace with an existing root repo, changing an existing Workspace to use a repository, and related enable flows). Avoid prompting for no-op attachment where a valid manifest must be preserved.
2. Show the confirmation **before** any conversion-related file write. Suggested new branch `graymoon/workspace-setup`; editable text; **Push branch to origin** checked by default; base shown as provider's actual default branch. Cancel is side-effect-free.
3. Validate via Git (`git check-ref-format --branch` or existing shared validator); make sure base exists and new branch does **not** exist locally or on remote. Handle remote race by verifying again immediately before create and refusing collision rather than resetting a ref.
4. Preflight target cleanliness: reject staged, unstaged, untracked changes in the target repo, plus ignored/untracked conflicts at generated file paths. Never stash or reset user content.
5. Carry a single immutable setup request (workspace/repository identities, base ref and commit, target branch name, push flag) into a repository-scoped operation. Resolve actual Workspace path and context **once**; do not use UI's changing selected context in a job lambda.
6. Prevent the ordinary existing enable flow from writing managed files before branch creation. Be particularly careful with calls to `SyncWorkspaceDefinitionAsync`, CodeGraph activation and import flows.

### Tests

- Dialog only on genuine conversion, proper defaults, cancel no changes.
- Dirty/staged repo blocked before any ref/file mutation.
- Existing local or remote name blocked, no force checkout.
- Branch name validation (`graymoon/workspace-setup`, slashes, bad refs).
- Actual default `trunk` used as base rather than `main`.
- No file write occurs on default before new branch checkout.

**Exit:** safe UI and preflight; no commit/push yet.

## Phase 6 — Setup branch creation, file generation and narrowly scoped commit (Increment B)

### Primary code

`WorkspaceRepositoryOperations.cs`, `WorkspaceManifestService.cs` (reuse, don't duplicate), Worker `CreateBranchCommand.cs` / `GitService.cs`, a small dedicated Worker setup/commit command or safely composed transaction, Git changes infrastructure.

### Tasks

1. Coordinate as one repository-scoped structural operation with existing Workspace locks and Worker process access. Avoid watchers or concurrent background jobs interleaving with setup.
2. Fetch/verify base branch tip, create **new local branch from that specific ref**, checkout, and assert current branch equals requested target. Do not branch accidentally from stale local `main` or an arbitrary current HEAD.
3. Only then call the existing authoritative manifest sync path, which manages `.gitignore`, `graymoon.json`, optional `codegraph.json`; honor `ai`, `codegraph`, tag/reference pins, `versionFiles`, non-managed `.gitignore` content, and unrelated JSON properties. Preserve existing adoption behavior that avoids overwriting a root with an existing valid manifest before its entries are imported.
4. Enumerate exact managed files changed in this operation by comparing worktree/index against the clean pre-operation baseline. A fixed allowlist of paths is preferable to a broad directory scan. If additional generated files (GitVersion config etc.) are part of conversion, whitelist only after Phase 0 establishes ownership.
5. Stage **only** those paths. Avoid `git add .`, `git add -A`, `git commit -a`, and `StageAllFirst=true`. With a clean-index precondition, a path-limited commit is acceptable; prefer a dedicated temporary-index technique when already supported by repo abstractions. Before committing, inspect `git diff --cached --name-only` (and staged content as needed) to verify no foreign path appears.
6. If nothing changed, do not make empty commit. Prefer detecting the no-op before creating a branch; if not possible, report it without a fake success commit.
7. Commit with a stable message such as `chore(graymoon): initialize workspace repository`. Record resulting SHA. The Worker returns success only after commit SHA is verified.
8. Refresh persisted branch/commit state through the usual hooks/Worker response, not optimistic browser-only fields.
9. Do not rewrite or force-update the default branch, ever.

### Tests

- Temporary bare remote + existing checkout. Default remains at identical SHA before/after conversion; setup branch has exactly one intended commit.
- Managed `.gitignore` preserves preexisting user lines, line endings and marker rules.
- CodeGraph true: include `codegraph.json`; false/absent: do not write or stage it unnecessarily.
- Invalid codegraph JSON refuses overwrite.
- Existing `graymoon.json` file-owned data retained; no duplicate entries dropped.
- Repository with preexisting staged/uncommitted/untracked changes is refused without modifying anything.
- No unrelated file in staged commit, even if file watcher updates during operation.
- Generated-file failure, Git checkout failure, commit hook failure and process timeout leave clear recoverable state.

**Exit:** committed setup branch with default branch unchanged and no unrelated changes.

## Phase 7 — Optional push, retry and user-visible outcomes (Increment B)

### Tasks

1. Push only if checkbox was checked. Set upstream to `origin/<setup-branch>` using current authenticated connector/Worker push support. No force and no PR. Fail explicitly if branch naming policy/protection forbids publication.
2. On push success: report branch, commit SHA and `Pushed to origin`; refresh state.
3. On push failure: report **local commit succeeded; remote push failed**. Preserve local branch and commit. Offer a safe Retry Push action or provide actionable guidance; no automatic revert, branch deletion, or re-commit.
4. On unchecked push: report **local setup complete** and provide branch name; do not claim it's available to Restore on another machine until pushed.
5. If retries are supported, resume from stored/verified stage. Never create another branch or duplicate commit on retry; require explicit confirmation if live branch state no longer matches recorded state.
6. Revisit protected-default behavior with a test repository where default rejects direct updates but accepts creating a new branch. Verify conversion succeeds without ever trying to write default.

### Tests

- Default-on push flag and unchecked flag.
- Push success and upstream recorded.
- Rejected push, expired PAT, SSO failure, network timeout; local commit retained.
- Retry after successful commit does not duplicate commit.
- No PR API request and no force push under any path.

**Gate B:** Build, run complete affected test suites, manually test real Git remote and verify commit tree/branch status before merge.

## Phase 8 — Regression, documentation and handoff

1. Run `dotnet build` for affected solution/projects and the applicable `GrayMoon.App.Tests` and `GrayMoon.Worker.Tests` suites (check actual solution layout), including characterization tests from Phase 0.
2. Run focused UI tests / browser automation where available. Manually test 1, 100, and 250+ branch lists, branch ref with slashes, rapid selection, provider default not `main`, missing/invalid manifest, offline Worker, catalog refresh and component disposal.
3. Use a throwaway remote with protected default; record initial default SHA, run conversion with push on and off, confirm default SHA unchanged and setup commit file list contains only managed files.
4. Restore from freshly pushed setup branch on a clean second workspace. Ensure manifest, checked-out ref, metadata and Source repository sync are correct.
5. Verify the old default-branch restore remains equivalent for pre-existing users.
6. Update `docs/architecture/01-product-model-and-user-workflows.md`, `03-data-model-and-persistence.md` and user capability docs only for behavior actually delivered. Add brief usage/help copy near the UI if existing patterns warrant it.
7. Produce PR description: decisions, changed contracts, risk boundaries, tests run, known limitations and screenshots of the two dialogs.

## Stop conditions / escalation

The implementation agent must stop and report (not improvise) when:

- The actual repository branch diverges materially from the review map or an existing call implicitly writes/commits on default before dialog confirmation.
- The selected branch cannot be passed through attach without broader invasive changes.
- Exact managed file ownership cannot be established safely.
- A temporary index or path-limited commit cannot be guaranteed free of unrelated staged files.
- Worktree/Feature state or outstanding structural jobs make conversion unsafe.
- Existing valid workspace definition would be overwritten or imported configuration lost.

Do not “solve” these by resetting the repo, stashing changes, force-pushing, editing manifest schema unnecessarily, or rewriting unrelated subsystems. Document the blocker and propose the minimal safe adjustment.

## Engineering checklist (must pass)

| Check | Expected proof |
|---|---|
| Branch picker appears only after repo selected | UI/component test |
| Typeahead filters locally | No extra HTTP/content calls |
| Default branch correct | Provider metadata test with `trunk` |
| Preflight is branch-specific | Mock API test validates ref |
| Stale preflight impossible | Deterministic async race test |
| Restore checks out selected branch | Temporary Git remote integration test |
| Branch change after preflight protected | Revalidate/refuse test |
| Default branch SHA unchanged on setup | Bare Git integration test |
| Dirty repo not auto-committed | Index/worktree safety test |
| Setup commit contains only expected paths | `git show --name-only` assertion |
| Push failure preserves local commit | Worker integration test |
| No PR and no force push | Call/command assertions |
| No-op and adoption safe | Manifest preservation tests |
| Old restore path works | Regression characterization suite |

## Suggested commit / PR boundaries

- PR A1: provider-neutral remote branch listing + tests.
- PR A2: selector and branch-specific preflight + tests.
- PR A3: exact-ref restore end-to-end + integration tests.
- PR B1: setup confirmation dialog + preflight + tests.
- PR B2: branch-safe manifest generation and limited commit + Git tests.
- PR B3: optional push, retry state and user messaging + regression/docs.

PR splitting can be condensed if appropriate, but keep the two release gates and protect default-branch behavior with automated tests throughout.
