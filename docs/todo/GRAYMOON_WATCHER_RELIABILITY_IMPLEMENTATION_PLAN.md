# GrayMoon Git Changes - Staged Implementation Plan

**Companion:** [Reliability design](GRAYMOON_WATCHER_RELIABILITY_DESIGN.md) (revision 2)
**Target:** branch `change-file-watchers` of the `GrayMoon` repository (HEAD `106b918` when written)
**Date:** 2026-10-27
**Mode:** Conservative, test-first, one independently verifiable phase at a time. **No code has been changed by this plan.** Stop for review at every phase boundary; never commit or push without an explicit request.

## 0. Guardrails

The failure occurs on a fast ~20-repository machine and on a ~39-repository VDI. Do not ship a VDI-only optimization and call it solved; do not claim slow Git is the proven root cause.

**Required behavior:** GrayMoon can sit idle on a Workspace route while AI edits files for an hour, and Changes keeps up. Any monitoring or delivery gap repairs itself. Unviewed workspaces still release OS handles.

**Do not touch:** Changes UI, manual Refresh, Git status parser, stage/unstage/commit semantics, Push Updated lanes, package orchestration, pinned/archived protection, feature removal safety, database schema.

**Preserve:** `GitStatusRefreshCoordinator` state machine, `GetGitChangeStatusCommand`, snapshot cache and version gate, `WorkspaceGitChangesWriteQueue`, context attribution, `IRepositoryAccess` removal claims.

**Repository rules that apply here (see `GrayMoon/CLAUDE.md`):** CRLF line endings; ASCII hyphen only (no em or en dash anywhere, including comments, logs and Markdown); sealed classes and primary constructors; Worker DTOs are sealed classes with `[JsonPropertyName]`; new Worker commands follow the `add-worker-command` recipe; App and Worker are version-locked, so **no mixed-version fallback and no per-feature capability flags**; update the matching `docs/architecture/` file in the same change as any behavior change; add a bullet to `## Recent GrayMoon changes` in `../GrayMoon.Desktop/README.md` for product-behavior changes (not for tests, refactors or docs only).

### Global release criteria

- Tests pass after each phase; Main and Feature contexts, worktree removal, no UI activity, disconnect and re-entry are covered.
- Incremental diffs; no blanket refactor and no polling loop hidden in a Razor component.
- The App-side flag selects the new keeper + audit **or** the old sweep, never both.
- Correctness is the release gate; performance gains are a bonus. Observe both the fast and the VDI profile.

---

## Phase 0 - Evidence and baseline (no behavior change)

**Objective:** discriminate F1 (sweep not reaching the workspace), F2 (late renewal), F3 (results dropped) and the Worker-side hazards F4-F9 from the design.

### 0.1 Confirm the live chain

```text
Workspace route -> WorkspaceGitChangesActivityBinder -> WorkspaceGitChangesRouteActivity
  -> WorkspaceGitChangesActivation.Activate (cold-start warm-up, special Workspace only)
  -> WorkspaceGitChangesActivityTracker.GetActiveWorkspaceIds
  -> GitChangesMonitoringBackgroundService sweep (sequential, untimed)
  -> GitChangesWorkspaceScanner.ScanCoreAsync (per-repo GetGitChangeStatus)
  -> Worker read pool -> GetGitChangeStatusCommand -> GitRepositoryWatcherManager.Acquire
  -> GitStatusRefreshCoordinator -> GitChangesSnapshotPublisher
  -> GitChangesSnapshotPushHandler (version gate) -> WriteQueue -> SQLite -> ContextGitChangesUpdated
```

List every place work can be skipped, dropped, timed out or cancelled (already known: silent return when the Worker is disconnected, 240 s `WorkerBridge` timeout, 120 s watcher scan timeout, publisher drop while offline, Debug-level version-gate rejection, Feature contexts not warmed). Check the Desktop repo for WebView2 suspend/throttle behavior while hidden.

### 0.2 Diagnostic-only logging

Debug, or sampled Warning on anomalies; carry workspace/context/repository ids, safe path identity, durations, outcome; never contents, tokens or full diffs.

- App: route lease gained/lost; active set size; sweep start/end/duration and per-context duration; planned vs actual next-sweep time; skipped because Worker disconnected; per-scan failures.
- Worker: watcher created/disposed with reason; `OnError` and restart outcome; `Start()` failures; acquire during expiry; watcher scan failure/timeout; publisher dropped-while-offline.
- App persistence: write queue enqueue/persist/failure and lag; version-gate rejections at Warning (sampled).
- Counters or periodic summary: entries vs healthy watchers, creations, idle expirations, late renewals, drops.

### 0.3 Deterministic tests (written first, expected to expose defects)

Use an injectable `TimeProvider` only where needed; no multi-minute delays.

- Stale-lease: acquire, evict, recreate, then dispose the old lease; assert the new entry's count and expiry are unaffected (expected to fail today).
- Expiry vs touch: force the timer callback and an `Acquire` to interleave with barriers (expected to be racy today).
- Start failure and failed `OnError` restart via a watcher factory seam; confirm today's entry stays "present" but dead.
- Linked worktree: `git add` in a worktree changes no event on that context's watcher (expected to fail today).
- Failed watcher-driven scan is not retried (expected to fail today).
- Publisher drop while disconnected leaves SQLite stale until a new scan.
- A sweep delayed past 10 minutes causes eviction.
- Portable Git-backed integration test: temp repository, edit after monitoring starts, compare persisted snapshot to `git status`.

### 0.4 Real scenarios

Fast host (~20 repos) and VDI (~39 repos, several Features): route open, no input, AI-style edits at 1, 9, 12, 30, 60 minutes; Worker reconnect; circuit reconnect. Record each failure mode as observed / reproduced / not reproduced / inconclusive. If the field failure cannot be reproduced, proceed on the verified defects and never claim an identified root cause.

### Exit gate

`docs/investigations/git-changes-watcher-lifecycle-2026-10-27.md` (create the folder; it does not exist yet) with code references, timeline, timings, logs, reproduction steps and ranked causes. Tests added, production behavior unchanged. **Review before Phase 1.**

---

## Phase 1 - Harden the Worker watcher lifecycle (Worker only, behavior-preserving)

**Objective:** make lifetime transitions linearizable and health real. Ships unflagged; the App is unchanged.

### Work

1. `GitRepositoryWatcherManager`: replace per-entry `Timer` with `ExpiresAt` (from `TimeProvider`) plus one manager-level sweeper and an internal `SweepExpired(now)`. `Acquire`, `Touch`, `Release` and the sweeper share one lock; entries are disposed outside it. Leases capture the entry; release of a non-current entry is a no-op; guard underflow and use-after-dispose; global `Dispose` stops the sweeper first.
2. Add `Touch(repoPath)` returning a small result (`Renewed | Created | Recovered | Degraded | UnderRemoval`) and extending `ExpiresAt` without a lease. Reuse `IsUnderRemoval` and the registerable-release path from `Acquire`. When it reports `Created` or `Recovered`, the manager calls `MarkDirty` for that path. `Acquire` keeps its current contract for `GetGitChangeStatus`.
3. `GitRepositoryWatcher`: expose health from the real watcher state; record a discontinuity before restart; if restart fails, stay `Degraded` and allow `Touch`-driven retry after a cooldown. Keep `ActiveWatcherCount` as entries and add a healthy count.
4. Linked worktrees: when `.git` is a file, resolve `gitdir:` and watch that directory with the existing relevant-name filter. Test with a worktree of a main checkout.
5. Set `InternalBufferSize` to 64 KB on both watchers.
6. `GitStatusRefreshCoordinator`: bounded, backed-off retry of a failed or timed-out **watcher-driven** scan only (suggested 5 s, 30 s, 2 min, then stop). No change to manual `RefreshNowAsync` semantics or to suppression behavior.
7. Removal reasons in logs: `IdleExpired`, `ExplicitRemoval`, `WorkerShutdown`, `WatcherError`, `Recreated`.

### Tests

- All Phase 0.3 Worker tests now pass: stale lease, expiry vs touch, start/restart failure and recovery, linked worktree, scan retry.
- Existing watcher manager, observation, overflow, `WorktreeRemovalReleasesHandlesTests` and `NestedFeatureRemovalTests` still pass.
- `IRepositoryAccess` removal racing `Touch`: no resurrected watcher, no locked handle.
- Global dispose with the sweeper pending: no exceptions or leaks.

**Exit gate:** healthy means a live OS watcher; race tests are deterministic; App behavior unchanged. Update `docs/architecture/04-runtime-communication-and-concurrency.md` and `07-git-changes-projection-and-tree.md` for the changed lifecycle.

---

## Phase 2 - Git-free `EnsureGitChangesWatchers` command and shared target resolver

**Objective:** a keepalive that does no Git work and returns what happened per repository.

### Wire shape (illustrative; follow existing DTO conventions)

```json
{
  "workspaceRoot": "<validated root>",
  "workspaceName": "<context checkout folder name>",
  "workspaceRepositoryName": "<optional special repository name>",
  "workspaceId": 123,
  "contextId": 456,
  "repositories": [ { "repositoryId": 11, "repositoryName": "Api" } ]
}
```

```json
{
  "workerInstanceId": "<per-process id>",
  "effectiveGraceSeconds": 600,
  "results": [ { "repositoryId": 11, "status": "Renewed" } ]
}
```

### Work

1. Follow the `add-worker-command` recipe: request/response DTOs under `Jobs/Requests` and `Jobs/Response`, handler under `Commands`, `CommandJobFactory`, `CommandDispatcher`, `RunCommandHandler` wiring, hub constant in `WorkerHubMethods`. Add the command to `ReadOnlyCommands` so it uses the read pool (see the design for why).
2. Handler: reuse `WorkerRepositoryPaths.GetWorkspacePath` / `Resolve` exactly as `GetGitChangeStatusCommand` does; never accept raw absolute paths. Per repository: skip missing folders (`Missing`), register attribution, `watcherManager.Touch`. Deduplicate normalized paths, cap batch size, honor cancellation, return partial results.
3. `IGitChangesWorkerClient`: add the batch call; keep `GetStatusAsync` unchanged. Resolve capabilities once per batch, not per repository.
4. App: extract the target-resolution portion of `GitChangesWorkspaceScanner.ScanCoreAsync` into a shared resolver used by both the scanner and the future keeper. Pure refactor first, covered by the existing scanner tests.
5. Add options: `WatcherAuditIntervalMinutes` (default 5), `UseWatcherKeeper` (default false), keeper call timeout (default 30 s), keeper concurrency. Document them in the options XML docs.

### Tests

- 20 and 39 repository contexts: one bounded batch (or a small number), zero Git subprocess invocations on repeated ensure.
- Correct path and registry attribution across contexts that contain the same repository names.
- Repeat ensure near the deadline extends life; no leaked counts or timers.
- Mixed healthy/missing/under-removal repositories give partial results and the rest renew.
- `GetGitChangeStatus` still scans and publishes exactly as before.

**Exit gate:** renewal cost and time are independent of scan execution; existing status workflow unchanged.

---

## Phase 3 - App keeper and audit scheduler (behind the flag)

**Objective:** replace the sequential sweep. The keeper and the audit ship together so correctness never depends on a keepalive alone.

### Work

1. Rework `GitChangesMonitoringBackgroundService` (or split into a keeper service and an audit scheduler service) selected by `UseWatcherKeeper`; the old sweep remains reachable only when the flag is off.
2. **Keeper:** `PeriodicTimer` at `WatcherRenewalIntervalMinutes`; per tick, active workspaces then non-paused contexts (`monitoringPause` still honored), one batch per context chunk, bounded context concurrency, each call under its own timeout, per-context error isolation, logs with planned vs actual tick time. Use the Worker-reported grace only for logging and for a sanity warning if the cadence would not leave at least two attempts before expiry.
3. **Audit scheduler:** single-flight, coalesced per `(workspaceId, contextId)`; bounded parallelism; every run wrapped in a timeout; uses the existing `ScanRepositoriesAsync` and write queue; remembers last audit time per context.
4. **Triggers:** periodic (`WatcherAuditIntervalMinutes`, staggered), Worker `Online` (Ensure first, then audit), cold activation of a workspace (all contexts, not only the special Workspace; coordinate with `WorkspaceGitChangesActivation` so the page's own line-stats warm-up is not duplicated), and return from a prolonged Idle/Hidden state through the existing activity-state signal with a cooldown of about 2 minutes. Mouse movement itself never triggers a scan.
5. Presence rules unchanged: `GetActiveWorkspaceIds` decides what is sent; after the grace, nothing is sent and the Worker evicts. Skip `UnderRemoval` and `Missing` quietly; no retry storms.
6. Subscribe to Worker connection state with deterministic detach on shutdown.

### Tests

- A workspace route with no interaction for hours (fake clock) keeps renewing; the 20-second UI idle tier has no effect.
- A fake 15-minute scan or a hung Worker call never blocks keeper ticks.
- Context A failing or timing out does not delay context B or the special Workspace.
- Worker reconnect while the route stays active: Ensure then audit, no reliance on the activity grace.
- Cold activation audits all contexts once; repeated route transitions create no duplicate loops, subscriptions or scans.
- Cooldown: Idle/Hidden to Active within the cooldown does not rescan.
- Flag off: old sweep behavior unchanged; flag flip at runtime leaves no duplicate loops.
- No outdated snapshot overwrites a newer one (existing version-gate tests plus an out-of-order case).

**Exit gate:** in an active workspace no watcher expires because a scan occupies the renewal path; unviewed workspaces still evict; every watcher gap has a path to an authoritative snapshot.

---

## Phase 4 - Reliability, load, rollout and documentation

### Fault-injection matrix

| Scenario | Expected result |
|---|---|
| 20 fast repos, idle 120 min, AI edits | Watchers alive; events delivered or caught by audit; no Refresh needed. |
| 39 VDI repos, slow scans | Keeper cadence holds; audits bounded and coalesced; no eviction caused by scan time. |
| 3+ Feature contexts, including `git add`/`commit` inside a worktree | Independent attribution; metadata changes observed; failure isolation. |
| Expiry vs touch race | A renewed entry is never disposed by a stale callback. |
| Watcher start or restart failure | Entry degrades; `Touch` retries after cooldown; one coalesced scan on recovery. |
| Worker restart or SignalR drop | Ensure then audit restores watchers and the projection. |
| Blazor circuit disconnect/reconnect | Valid routes recover; cold activation audits all contexts. |
| Navigate away from the Workspace | Grace, then idle eviction; no leaked handles. |
| Delete a Feature while the keeper runs | Removal wins; deletion succeeds; no resurrected watcher. |
| Stage/commit/discard and post-sync mutation | Existing realtime behavior unaffected. |

### Measurements

Collect before/after on both machines, compared with today's sweep: keeper tick duration and missed ticks; Ensure queue wait in the read pool; audit duration and frequency; scans per hour; healthy watchers vs entries; creations, evictions with reason; publisher drops; version-gate rejections; oldest unreconciled age if observable; CPU, disk and handle impact. The keeper's Git process count must be zero.

### Rollout order

1. Phase 0 evidence review.
2. Phase 1 Worker hardening (App unchanged).
3. Phase 2 command and resolver (inert until called).
4. Phase 3 keeper + audit behind `UseWatcherKeeper`, opt-in on both machines.
5. Verify with real AI runs, Worker restart and circuit reconnect; compare persisted snapshots with independent `git status`.
6. Make the keeper the default after acceptance; keep the flag for one release window, then delete the old sweep.

### Exit artifacts

- Updated `docs/architecture/04-runtime-communication-and-concurrency.md`, `07-git-changes-projection-and-tree.md` and the options documentation, describing the current state only; delete or shrink these todo documents once shipped.
- Deterministic tests for manager lifetime, health, keeper cadence, audit triggers and failure injection.
- Baseline vs improved measurements in the investigation document.
- Desktop README bullet and release note: Changes stays current during long idle AI work and repairs monitoring gaps automatically; silent-miss repair interval is now the audit interval.

---

## Likely files

| Responsibility | Starting point (relative to `GrayMoon/src`) |
|---|---|
| Presence | `GrayMoon.App/Components/Shared/WorkspaceGitChangesActivityBinder.razor`; `GrayMoon.App/Services/GitChanges/WorkspaceGitChangesRouteActivity.cs`, `WorkspaceGitChangesActivityTracker.cs`, `WorkspaceGitChangesActivation.cs` |
| Monitoring | `GrayMoon.App/Services/GitChanges/GitChangesMonitoringBackgroundService.cs`, `GitChangesWorkspaceScanner.cs`, `GitChangesWorkerClient.cs` |
| Worker watchers | `GrayMoon.Worker/Services/GitChanges/GitRepositoryWatcherManager.cs`, `GitRepositoryWatcher.cs`, `GitRepositoryWatcherCoverage.cs` |
| Refresh and publish | `GrayMoon.Worker/Services/GitChanges/GitStatusRefreshCoordinator.cs`, `GitChangesSnapshotPublisher.cs`; `GrayMoon.App/Services/GitChanges/GitChangesSnapshotPushHandler.cs`, `WorkspaceGitChangesWriteQueue.cs` |
| Worker protocol | `GrayMoon.Worker/Jobs/Requests/*`, `Jobs/Response/*`, `Commands/*`, `Services/CommandJobFactory.cs`, `Services/CommandDispatcher.cs`, `Cli/Handlers/RunCommandHandler.cs`, `Hosted/SignalRConnectionHostedService.cs` (`ReadOnlyCommands`), `GrayMoon.Abstractions/Worker/WorkerHubMethods.cs` |
| Options | `GrayMoon.Common/Git/GitChangesOptions.cs`, `GrayMoon.App/Program.cs` |
| Tests | `GrayMoon.Worker.Tests/GitRepositoryWatcherManagerTests.cs`, `GitRepositoryWatcherObservationTests.cs`, `WorktreeRemovalReleasesHandlesTests.cs`, `NestedFeatureRemovalTests.cs`; `GrayMoon.App.Tests/WorkspaceGitChangesRouteActivityTests.cs`, `WorkspaceGitChangesActivityTrackerTests.cs` |

## Per-phase reviewer checklist

Report: (1) tested baseline, (2) files changed and why, (3) lifecycle invariants maintained, (4) negative and reproduction tests, (5) expected timing and process counts, (6) remaining known failure modes, (7) rollback and flags, (8) confirmation of no UX or operation impact. If evidence contradicts a design assumption, update the design before coding around it.
