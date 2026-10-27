# Bootstrap prompt — Unify GrayMoon Push Updated safely

**Role:** Senior .NET architect/engineer implementing a tightly scoped correctness and orchestration fix in `Jandini/GrayMoon`.

**Primary specification:** `graymoon-push-updated-unified-implementation-plan.md` (read in full; its findings, phased gates, regression matrix and exclusions are mandatory).

**Verified source baseline:** `main` at `eb320738a999486bfec9aeaab4d31a87c6f4f93e` (verified 2026-10-27). **Do not assume HEAD stays there**: inspect the current branch and working tree before any changes. Never overwrite uncommitted user changes. No automatic commit/push.

## Assignment

Make the combined **Push Updated / Update & Push** workflow have **one application-level mutation entry point**, used for full and Level Only from both:

- `WorkspaceRepositories.Update.cs` (Repos page)
- `WorkspaceActionNotificationPanel.razor` (notifications popup)

Also audit the combined post-branch part of Prepare Workspace and relevant REST paths, then eliminate/restrict any production bypass **without changing the established Prepare branch-success gate**. Update Only and Push Only stay independent operations.

**Keep the existing `UpdateAndPushOrchestrator` as the two-lane engine.** Do not rewrite lanes, handoff channels, Git commands, Worker, package-publishing wait, registry matching, package version rules, level ordering, or CI/provider mechanics.

## Code review FIRST — before writing implementation code

1. Read `CLAUDE.md`, project architecture and the complete implementation plan. Check current main/working tree; identify changes since the reviewed SHA.
2. Trace the actual handlers and their application boundaries: popup full/Level Only, page full/Level Only, `IWorkspaceUpdateOperations`, `IWorkspacePushOperations`, `UpdateAndPushOrchestrator`, `DependencyUpdateOrchestrator`, `PushOrchestrator`, `PrepareWorkspacePhases`, `WorkspaceOperationOutcomeStore`, `BackgroundJobService`, `WorkspaceOperationRunner`, `WorkspaceJobKeys` and existing tests.
3. List all callers of the combined pipeline and any UI code that chains `UpdateAsync` then `PushAsync`. Distinguish legitimate standalone operations.
4. Check if each of F01–F13 in the plan still applies; cite file/line evidence for any that changed. Confirm exact existing defaults and fallback behavior. Do not blindly follow line numbers from an earlier revision.
5. Produce or update **living design notes and a checklist** containing scope, planned files, contracts, test plan and risks. Start with baseline tests and focused regression reproduction before behavior changes.

## Required target

Prefer one small `IWorkspaceUpdateAndPushOperations.ExecuteAsync(...)` interface (or an existing equivalent if more idiomatic), taking an immutable request with `WorkspaceId`, **captured** `WorkspaceFeatureContextId`, optional `MaxLevel`, commit options and **explicit** restore choice. It may use command variants for initial start and explicitly authorized normal-push continuation, but there must be only **one public combined mutation command**. Read-only preflight is allowed.

The coordinator must:

1. Validate context, NeedsRepair/deleted Feature state, pinned tags, default-branch policy and full write targets (not the popup's capped notification subset), without changing any rules casually. Include potential downstream default-branch write targets or pause for renewed approval before a newly discovered target is modified.
2. Call existing pipeline first. `Pipelined=true` is authoritative; preserve two-lane result including already completed lower-level pushes if higher levels fail.
3. On `Pipelined=false` (guaranteed no side effects), perform existing **sequential fallback**, using `UpdateAsync(repoIdsToUpdate:null)` and the *same* max level, Context ID and commit options. **Check returned** `DependencyUpdateRunResult.Success` and refuse any subsequent push if false, even if no exception was thrown.
4. Build a fresh context-scoped push plan, then use synchronized push. **Never silently select normal/parallel push** because the popup has different detection logic. When synchronized push cannot run, return a structured approval-needed result and resume only after a real user explicitly authorizes it; validate continuation state, do not rerun already completed updates.
5. Treat returned `OperationResult.Success=false`, level errors, package publication waits, exceptions and cancellation as real failures. Record **one coherent combined outcome and RunId** outside page lifecycle; a nested Push recording must not overwrite earlier Update failure.
6. Preserve all existing package diagnostics, errors, partial-progress/safe-retry semantics, feature isolation, workspace-role-last logic and per-level DbContext scopes.
7. Reuse the existing workspace job runner/locking, overlays and cancellation semantics; don't introduce a second scheduler. Never capture UI components/DbContexts in a long-lived job callback.
8. Pass options explicitly: Repositories modal restore defaults **off**, popup legacy behavior defaults **on**, Prepare currently defaults **on**. Identical explicit requests must execute identically regardless of origin.

## Implementation phases and gates

**P0 — Characterize:** Capture current SHA/build/tests; create regression tests for `Success=false` ignored by popup, 3-level evolving dependency, Feature context, duplicate job, fallback and error outcome. Existing tests should pass; newly added bug tests may start red.

**P1 — Contract:** Add the small command/result model, DI and unit tests without migrating UI.

**P2 — Coordinator:** Compose current pipeline and sequential fallback; handle returned failure, explicit fallback authorization and unified outcome in tests; keep engine unchanged.

**P3 — Popup:** Migrate only combined Push Updated and Level Only. Remove their stale prefilter and private update→push orchestration. Keep standalone Update Only/Push Only intact. Use fresh, complete branch-warning candidates, capture context once, and propagate errors and outcomes.

**P4 — Repositories:** Migrate both combined actions while retaining modal, confirmations, restore default, page refresh/callouts. Remove duplicate page-local combined logic only after parity tests pass.

**P5 — Other combined callers:** Audit/migrate Prepare Workspace safely and check REST: `/update` and `/push` are standalone; `/prepare-workspace` has separate branch gate and must retain `PushPending`/API semantics. Restrict raw combined pipeline to internal use after every production caller is migrated; add an architecture regression guard.

**P6 — Diagnostics/verification:** Correlated logs, full regression matrix, build/test relevant projects, architecture docs and runbook updates. Report exact commands/results and any skipped smoke tests. No unrequested UX redesign, schema migration, dependency upgrade or unrelated refactoring.

**After each phase:** update the living checklist, run focused tests, inspect diff, and only then proceed. Isolate each phase as a reviewable unit; don't spread simultaneous changes across the Worker, UI, and engine.

## Required acceptance tests (non-negotiable)

- Same explicit full/Level Only request from popup/page selects identical engine/mode and final semantics.
- Lower-level commit can introduce a higher-level dependency update during the run; no frozen upfront ID filter.
- Returned update failure without throw -> **zero new sequential push calls**.
- Pipeline lower levels may already have pushed when a later level fails; outcome stays failed and partial progress intact.
- `NotPipelined` had no effects; sequential fallback updates once, scopes correctly, and never pushes on update failure.
- Synchronized push refusal -> real approval, no unapproved normal push; refusal/replay/stale approval safe.
- Returned push failure and package timeout retain exact level, repo, package ID/version and correlated RunId.
- Tag-pinned/archived repo never mutated; default-branch warning not limited to first 100 popup rows.
- Selected Feature remains bound through update, push, plan, approval and outcome even if UI switches Features. Invalid/NeedsRepair Feature refused.
- Restore on/off and workspace capabilities preserved; package wait unchanged.
- Navigation, two tabs, operation locks, cancellation, partial-progress retry, and Prepare Workspace branch-failure abort work as before.
- Outcome remains available after dismissing a notification or leaving the page; no disposed-component callbacks.
- Static architecture check forbids a UI-owned combined UpdateAsync→PushAsync flow.

## Engineering style

Prefer the **smallest correct production change**: reuse types/services, avoid unnecessary abstractions, keep `.NET` layering, consistent logging patterns and existing test conventions. Conserve risk over cosmetic refactors. If a design assumption is disproved by current code, update the living design and choose the safer implementation; do not silently expand scope.

Do not falsely state that a package timeout proves the current popup bug—the latest incident has not been reproduced from logs. Don't change package wait in this task.

## Final delivery from the coding agent

Return: design decisions and deviations; exact files changed; test cases and commands with pass/fail evidence; before/after call graph confirming the single authoritative combined entry; safety invariants checked; remaining known risks; and any manual VDI/Windows smoke tests still required. **Do not commit, create a PR, or push unless explicitly instructed.**
