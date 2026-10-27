# GrayMoon Git Changes — Staged Implementation Plan

**Companion:** [Reliability design](GRAYMOON_WATCHER_RELIABILITY_DESIGN.md)  
**Target repository:** `Jandini/GrayMoon`, `main`  
**Date:** 2026-10-27  
**Mode:** Conservative, test-first, one independently verifiable stage at a time. **No code has been changed by this report.**

## 0. Preconditions, guardrails and work agreement

The failure occurs on both a **fast ~20-repository machine** and a **slower ~39-repository VDI**. Do not implement a VDI-only optimization and declare the issue solved. Detect the real lifecycle failure and add correctness guarantees that make missing watcher events recoverable regardless of root cause.

**Required behavior:** GrayMoon may be idle with an unchanged workspace route while AI writes files for an hour. File changes still appear automatically. If any coverage/delivery gap happens, return/reconnect must reconcile without manual Refresh. Inactive workspaces still release OS resources.

**Do not touch:** Changes UI layout, manual Refresh behavior, Git status parser, commit/stage/unstage semantics, Push Updated orchestrator lanes, Git package orchestration, configuration compatibility, pinned/archived protection, or feature removal safety.

**Preserve:** Current `GitStatusRefreshCoordinator`, `GitChangesWorkspaceScanner`, `GetGitChangeStatusCommand`, snapshot cache/versioning, `WorkspaceGitChangesWriteQueue`, context attribution and existing `IRepositoryAccess` removal claims.

### Global release criteria

- Tests pass after each stage. Unit and integration tests cover Main and Feature contexts, worktree removal, no mouse/keyboard activity, disconnects and re-entry.
- Incremental diffs; no blanket refactor or new polling loop hidden inside a Razor component.
- No generated changes outside scope. No automatic commits/pushes; stop for review at each stage.
- Feature flag / dual-mode rollout is available for App renewal, but never leave duplicate full-sweep and lightweight-keepalive loops active indefinitely.
- Observe under both fast and VDI profiles. Perf improvements are a bonus; correctness is the release gate.

---

## Phase 0 — Establish proof, baseline and deterministic reproduction (no behavior change)

**Objective:** Prove whether the failure is (a) missed App subscription, (b) late lease renewal, (c) timer race, (d) OS watcher failure, (e) Worker restart/reconnect, (f) dropped snapshot, or (g) stale SQLite/UI broadcast.

### 0.1 Trace the chain end to end

```text
Workspace route open
  → ActivityBinder.Sync(workspaceId)
  → WorkspaceGitChangesRouteActivity (lease)
  → WorkspaceGitChangesActivityTracker.GetActiveWorkspaceIds()
  → GitChangesMonitoringBackgroundService sweep
  → GitChangesWorkspaceScanner for each context/repo
  → GetGitChangeStatus Worker command
  → GitRepositoryWatcherManager.Acquire/release/idle disposal
  → FileSystemWatcher event / error
  → GitStatusRefreshCoordinator scan
  → GitChangesSnapshotPublisher (or command result)
  → App WorkspaceGitChangesWriteQueue
  → GitChangesSnapshotPushHandler persist
  → ContextGitChangesUpdated → Changes view
```

Document every place that can suppress, skip, drop, time out or cancel work. Include existing system/worker GitChanges configuration overrides; verify Worker and App default grace/renewal values and Worker command lanes.

### 0.2 Add *diagnostic-only* structured logs and counters

Log at Debug (or sampled Info on anomalies) with `WorkspaceId`, `ContextId`, `RepositoryId`, normalized/path-hash or safe repo identity, Worker instance/generation, watcher instance/generation, command correlation, durations and outcome. Never log contents, credentials, full file diffs, or tokens.

Emit at least:

- App: route lease gained/lost; active set count and scoped contexts; sweep start/end/duration; selection reason; per-context and per-repo attempt/success/failure; planned vs actual renewal time.
- Worker: watcher started/started-with-error/renewed/disposed, disposal reason; lease count/expiry; `OnError`/overflow, restart outcome; `Acquire` during expiry; path-under-removal.
- Data path: `MarkDirty`; status scan success/fail/duration; publisher sent/dropped/offline; App queue enqueued/persisted/failed; snapshot version and resolved context.
- Counters: healthy watcher count vs dictionary entry count, watcher creations, idle expirations, exceptions, late renewals, pending reconciliations, push-drop count, write-queue lag.

Log conditional anomalies at Warning: expected-active workspace not renewed before grace threshold; watcher present but unhealthy; self-repair failed; gap not reconciled.

### 0.3 Deterministic reproduction harness

- Introduce an injectable clock/time provider for activity grace and watcher expiry **only where needed**. Avoid `Task.Delay(10 minutes)` tests.
- Force idle-expiration callback and concurrent `Acquire` interleaving using barriers, not probabilistic sleeps. Verify whether a lease can be disposed while renewed.
- Simulate failing FileSystemWatcher initialization/restart using a watcher factory / injectable abstraction in tests; confirm manager can report a falsely healthy-looking entry.
- Exercise dropped Worker→App notification during disconnect and verify SQLite remains stale until a new scan.
- Simulate App monitoring sweep delayed beyond the default lease grace, then observe watcher recreation and data correctness.
- Simulate a real circuit leaving/disconnecting and re-entering within and beyond 8-minute activity grace.
- For a portable Git-backed integration test: create a temporary local repository, seed status, edit a file after monitoring is established; compare eventually persisted snapshot to an authoritative `git status` result.

### 0.4 Two real-environment scenarios

- **Fast host, ~20 repositories:** UI route remains open, mouse/keyboard idle, AI-style file edits at 1, 9, 12, 30, 60 minutes; check watcher health, source event, Worker→App delivery, SQLite and visible Changes. Test Worker reconnect.
- **VDI, ~39 repositories:** same scenarios plus varying status scan load, several Feature contexts, file churn and periods of command queue saturation.

Record baseline outcomes as **observed / reproduced / not reproduced / inconclusive**. If current instrumentation changes scheduling, note that limitation. If field failure cannot be reproduced, proceed with measured high-confidence vulnerabilities and explicit recovery tests, but never claim an identified root cause.

### Phase 0 deliverable and exit gate

`docs/investigations/git-changes-watcher-lifecycle-2026-10-27.md` with source/code references, timeline, timings, telemetry, reproduction scripts and ranked root causes. Tests added without production behavior change. **Review before Phase 1.**

---

## Phase 1 — Fix watcher lifecycle races and expose real health (Worker only)

**Objective:** Make watcher lifetime transitions linearizable; never treat an unhealthy watcher entry as functioning.

### Work

1. In `GitRepositoryWatcherManager`, synchronize `Acquire`, `Release`, idle timer expiry/removal and access-broker `OnEntryReleased` through a consistent gate or a proven atomic state machine. A pending timer callback must not remove an entry that was just reacquired. Record an expiry generation/epoch and test it on callback. Cancel timers and dispose OS resources outside locks when practical to avoid event-handler reentrancy deadlocks.
2. Guard lease-count underflow, duplicate releases and callbacks after global disposal. Keep `ActiveWatcherCount` semantics explicit: dictionary entries ≠ healthy watcher count.
3. In `GitRepositoryWatcher`, represent explicit state: `Starting`, `Healthy`, `Degraded`, `Disposed` (naming flexible). Expose whether the required worktree OS watcher started. Track `.git` metadata watcher status separately, including linked worktree handling; don't silently classify partial startup as completely healthy.
4. On overflow/Error, record a discontinuity *before* restart. If restart fails, retain retryable degraded state and bounded error details. A future ensure must be able to retry (with cooldown) rather than encountering an immortal dead entry.
5. Preserve `IRepositoryAccess` exclusive removal precedence. Do not recreate watchers under removal claims. Observe ancestor pause/resume handling and refresh after paused events.
6. Produce reasoned structured lifecycle events, no UI changes.

### Targeted tests

- Deterministic concurrent idle timer + `Acquire`; newly renewed lease survives.
- Two simultaneous leases; disposal only after last release and grace.
- Forced watcher start failure, OnError-restart failure, eventual recovery; health statuses correct.
- `IRepositoryAccess` removes a worktree while an App renew request races; no locked folder handles or watcher resurrection.
- Global Worker dispose while timer callback is pending; no exceptions/leaks.
- Existing watcher manager tests and observation/overflow tests continue to pass.

**Exit gate:** A healthy state corresponds to a live initialized watcher; race tests repeat predictably. No change to scheduled App monitoring yet.

---

## Phase 2 — Lightweight batch watcher keepalive contract (Worker + shared wire + App client)

**Objective:** Keepalive does no Git work, returning exact health/coverage status per repository.

### Proposed request / response (illustrative, adapt to existing DTO conventions)

```json
{
  "workspaceRoot": "<existing validated root>",
  "workspaceName": "<context's existing checkout folder name>",
  "workspaceRepositoryName": "<optional special repository name>",
  "workspaceId": 123,
  "contextId": 456,
  "repositories": [
    { "repositoryId": 11, "repositoryName": "Api" },
    { "repositoryId": 12, "repositoryName": "Persistence" }
  ]
}
```

```json
{
  "workerInstanceId": "<ephemeral process-generation identifier>",
  "effectiveGraceSeconds": 600,
  "results": [
    {
      "repositoryId": 11,
      "status": "HealthyExisting",
      "coverageGeneration": 8,
      "needsReconciliation": false
    },
    {
      "repositoryId": 12,
      "status": "RecreatedAfterGap",
      "coverageGeneration": 2,
      "needsReconciliation": true
    }
  ]
}
```

### Work

1. Add a typed Worker request/response and one `EnsureGitChangesWatchers` command handler, routed through existing `CommandJobFactory`, `CommandDispatcher`, `RunCommandHandler` registrations and shared hub constants or existing naming conventions.
2. Reuse `WorkerRepositoryPaths` safety / identity resolution from `GetGitChangeStatusCommand`; **do not pass arbitrary untrusted absolute paths** when a consistent existing resolver is available.
3. Batch per context under explicit request-size limits, deduplicate normalized paths, return partial per-repo failures, and honor cancellation. Make duplicate batches idempotent.
4. Ensure the watcher and register attribution correctly without `GetStatusAsync`. Per-entry action: acquire/touch, sample health/generation, release short-lived lease; avoid accumulating active reference counts.
5. Return `UnderRemoval`, `Missing`, `Unhealthy` distinctly, and include typed reasons for reconciliation. Return effective Worker lease grace so App can schedule independent of potentially different options sections.
6. Extend `IGitChangesWorkerClient` for batch ensure, keep `GetStatusAsync` unchanged. Reuse capabilities-resolution logic if needed; do not run separate capabilities resolution/Worker round-trip **per repository**.
7. Preserve existing command/client path as fallback behind a rollout switch. Check protocol versioning for App/Worker mixed versions and existing mismatch policy.
8. Validate whether Worker command queue saturation can block the keepalive beyond lease expiry. Only if demonstrated, provide a tiny bounded control-path priority; do **not** change Git read/write lanes or Push Updated orchestrator.

### Tests

- 20 and 39 repositories: one bounded batch or small number of batches; **zero Git subprocess/status calls** on repeated ensure.
- Correct context/worktree path and registry attribution, including duplicate repo names in different contexts.
- Repeated ensure near deadline extends life; no leaked leases/timers.
- Mixed healthy/missing/removing repositories report partial results; remaining watchers renew.
- Worker options differing from App options do not accidentally expire watchers.
- Old `GetGitChangeStatus` continues to scan and publish as before.

**Exit gate:** Real elapsed renewal is independent of scan execution; no behavior regression in existing status workflow.

---

## Phase 3 — Replace expensive renewal sweeps with an independent App keeper

**Objective:** Active workspace subscriptions renew reliably even when scans, multiple contexts or background operations stall.

### Work

1. Split `GitChangesMonitoringBackgroundService` responsibilities:
   - **Watcher subscription keeper:** active workspace/context enumeration + Ensure requests only;
   - **Scan/reconciliation scheduling:** event/health-driven, separately bounded (Phase 4).
2. Reuse `IWorkspaceGitChangesActivityTracker` and `WorkspaceGitChangesRouteActivity`; **never** disconnect watchers simply because `AppActivityStateService` reports `Idle` after 20 seconds.
3. Use monotonic fixed-deadline scheduling (TimeProvider/timestamp), rather than `await all scans; await 3 minutes`. Coalesce simultaneous triggers; no concurrent duplicate per-workspace keeper loops.
4. Cache the desired set of context/repo identities across heartbeats, invalidated on workspace membership/Feature lifecycle changes and Worker reconnect. Revalidate paths/context existence; avoid expensive DB enumeration every short heartbeat if baseline demonstrates cost, but do not leave stale paths indefinitely.
5. Use Worker-reported grace to pick renewal deadline with safety margin. Bound number of concurrent contexts and retry failed batches independently; one broken Feature cannot starve the special Workspace or other contexts.
6. Integrate Worker `Online` / reconnect. Ensure lifecycle subscriptions are safely detached on shutdown; app/watcher disposal deterministic. Handle reconnect while route is still active.
7. Retain the existing workspace inactivity grace; after no viewers and grace, stop sending ensure. Let Worker 10-minute idle timers evict automatically. Do not create watchers for closed/deleted contexts.
8. Add a feature flag: `GitChanges:UseLightweightWatcherRenewal` (exact name can be adjusted). When enabled, do not run the old full status scan on each heartbeat; disable the old renewal sweep only after Phase 4 reconciliation is active. In staging, measure both strategies, but never silently run both in production.

### Tests

- A Workspace route with no interaction for 2 hours continues renewing; 20-second UI idle tier has no effect.
- Multiple same-workspace navigation events create only one activity lease and one active keeper per Workspace; external navigation ultimately evicts.
- Duration of a fake 15-minute Git scan never blocks keeper ticks.
- Context A failure does not block context B; cache invalidation handles added/removed Feature repositories.
- Worker reconnection immediately reasserts desired set even if App activity remains `true` across reconnect.
- Repeated route transitions and cancellation leave no orphan tasks/subscriptions.

**Exit gate:** In an active workspace, no watcher expires because scan execution occupies the renewal loop. Current inactive-workspace eviction semantics still pass.

---

## Phase 4 — Automatic reconciliation and missed-event recovery

**Objective:** Watcher presence and health are not mistaken for data correctness. Changes self-heals without manual Refresh.

### Work

1. Introduce an App-side reconciliation scheduler keyed by **workspace + context + repository path/ID**, with single-flight coalescing, bounded parallelism, fair scheduling and clear retry/cooldown states. Use existing `IGitChangesWorkspaceScanner.ScanRepositoriesAsync` (or equivalent) for authoritative status; do not create another parser/scanner.
2. Trigger reconcile for `HealthyCreated`, `RecreatedAfterGap`, coverage generation advance, watcher overflow/error, Worker restart/connection restore, delayed keepalive beyond deadline, known publisher drop, and stale resume audit. Do not repeatedly scan a stable healthy watcher merely because an Ensure arrived.
3. Connect layout-level `AppActivityStateService` `BecameActive` and WebView2 visibility/reconnection signals to a **stale-age-gated** reconciliation request. Use a configurable cooldown, e.g. only after >5 minutes away, subject to Phase 0 measurement; avoid a 39-repo scan every mouse movement. Resumption must not replace always-on watcher monitoring.
4. Add a conservative low-frequency audit for long-open workspaces to catch silently missed FS events. It must use authoritative status even if no watcher warning was seen. If cost is high, prioritize stale/gapped paths and spread audits over time; do not replace correctness with a file-timestamp/mtime heuristic that misses untracked changes.
5. Mark gap reconciled **only after snapshot persistence succeeds** (existing `WorkspaceGitChangesWriteQueue.EnqueueAndWaitAsync`, or a corresponding confirmed outcome); failed scans, dropped messages, queue failure and cancellation leave pending state for retry.
6. Preserve App's per-context snapshot version checks. On Worker restart, new version ordering must still outrank persisted state. Guard against queued out-of-order results and duplicate pushes.
7. On route reentry within the 8-minute App grace, do not skip audit just because `activityTracker.IsActive()` returned `true`. Use actual watcher generation, Worker instance and `lastSuccessfulPersistedAt`/audit freshness.
8. Explicitly classify skipped worktree paths (`UnderRemoval`, `Missing`) as non-errors during removal, and avoid retry storms. Reconcile after valid Feature/worktree recreation only.
9. No change to Changes UI or manual Refresh, beyond receiving the same existing update events from newly scheduled scans.

### Tests

- Simulated AI agent writes after 12, 30 and 60 idle minutes: without a button click, persisted Changes catches up.
- Watcher disposed then recreated: **one** coalesced scan occurs and persists.
- Worker restarted mid-edit: ensure + reconciliation produces correct context projection.
- Publisher intentionally drops offline notification: reconnect audit repairs stale SQLite.
- Watcher start failure then recovery: pending reconciliation clears only on successful persisted snapshot.
- Feature worktrees and special Workspace checkout remain correctly separated, including path reuse and invalidated contexts.
- Idle/Hidden→Active fires no repeated audit when cooldown has not elapsed.
- No outdated snapshot can overwrite a newer post-mutation one.

**Exit gate:** Every introduced gap has a path to eventual authoritative persistence. Long AI editing runs do not require manual Refresh.

---

## Phase 5 — Reliability, load, rollout and documentation

### Fault-injection matrix

| Scenario | Expected result |
|---|---|
| 20 fast repositories, idle 120 min | Watchers alive, events delivered or automatically audited, no manual Refresh. |
| 39 VDI repositories, slow scans | Keeper cadence remains healthy; scans bounded/coalesced; no lease drop from scan duration. |
| 3+ Feature contexts | Independent, correctly attributed watchers and snapshots; failure isolation. |
| Force timer callback / Acquire race | New lease never disposed by stale callback. |
| OS watcher `OnError` / restart failure | Entry degrades, retries bounded, scan after coverage gap. |
| Worker restart or SignalR drop | Watchers reasserted; state reconciled; missed notifications recovered. |
| Blazor circuit disconnect / reconnect | Valid routes recover monitoring; no duplicate leases. |
| Navigating away from Workspace | Monitoring grace then idle eviction; no leaked handles. |
| Delete Feature while keeper runs | `IRepositoryAccess` removal wins; deletion succeeds; no watcher resurrected. |
| Stage/commit/discard and post-sync mutation | Existing snapshot/version semantics and realtime UI updates unaffected. |

### Measurements to collect

- `watcher.healthy_count`, `watcher.entries_count`, `watcher.started_total`, `watcher.disposed_total{reason}`, `watcher.degraded_total`, `watcher.last_renewal_age_ms`.
- `keeper.batch_size`, `keeper.duration_ms`, `keeper.missed_deadline_total`, `keeper.failed_entries`, `keeper.attempts_per_minute`, `keeper.git_commands_total` (**must be 0**).
- `reconcile.trigger_total{reason}`, `reconcile.pending`, `reconcile.status_scan_duration_ms`, `reconcile.persist_latency_ms`, `reconcile.retry_total`, `reconcile.oldest_gap_age_ms`.
- `publisher.dropped_offline_total`, `snapshot.persist_failures_total`, `projection.last_successful_update_age_ms`.
- Disk/CPU/handle impact on 20-fast and 39-VDI runs; compare baseline existing periodic full scans.

### Rollout order

1. Diagnostics and repro evidence review.
2. Worker race/health hardening (existing App behavior unchanged).
3. Batch Ensure protocol, exercised with focused tests and feature-flagged App caller.
4. Independent keeper *and* reconciliation available together behind opt-in staging flag. Do not use keepalive-only production cutover that removes all periodic correctness scans without an audit replacement.
5. Verify fast machine, VDI, Worker restart, disconnect/reconnect and real AI run; compare logs and snapshots to independent `git status`.
6. Make lightweight renewal default only after acceptance; retain legacy rollback switch for one release window and remove when safe.

### Exit artifacts

- Updated architecture docs (`docs/architecture/04-runtime-communication-and-concurrency.md`, `07-git-changes-projection-and-tree.md`, relevant options docs).
- New deterministic tests for manager lifetime, health transitions, keeper cadence, reconciliation and failure injection.
- Baseline vs improved measurements in `docs/investigations/git-changes-watcher-lifecycle-2026-10-27.md`.
- Explicit release note: **Changes remains up to date during long idle AI work, and automatically repairs monitoring gaps; no manual Refresh required.**

---

## Code ownership guide / likely files

| Responsibility | Starting point |
|---|---|
| Activity routes / presence | `src/GrayMoon.App/Components/Shared/WorkspaceGitChangesActivityBinder.razor`; `src/GrayMoon.App/Services/GitChanges/WorkspaceGitChangesRouteActivity.cs`; `WorkspaceGitChangesActivityTracker.cs` |
| App background monitoring | `src/GrayMoon.App/Services/GitChanges/GitChangesMonitoringBackgroundService.cs` |
| Scan and Worker bridge | `src/GrayMoon.App/Services/GitChanges/GitChangesWorkspaceScanner.cs`; `GitChangesWorkerClient.cs` |
| Worker watcher/health/leases | `src/GrayMoon.Worker/Services/GitChanges/GitRepositoryWatcherManager.cs`; `GitRepositoryWatcher.cs`; `GitRepositoryWatcherCoverage.cs` |
| Worker protocol and wiring | `src/GrayMoon.Worker/Jobs/Requests/*`; `Jobs/Response/*`; `Services/CommandJobFactory.cs`; `Services/CommandDispatcher.cs`; `Cli/Handlers/RunCommandHandler.cs`; `GrayMoon.Abstractions/Worker/WorkerHubMethods.cs` |
| Git status + snapshot flow | `src/GrayMoon.Worker/Services/GitChanges/GitStatusRefreshCoordinator.cs`; `GitChangesSnapshotPublisher.cs`; `src/GrayMoon.App/Services/GitChanges/GitChangesSnapshotPushHandler.cs`; `WorkspaceGitChangesWriteQueue.cs` |
| Settings | `src/GrayMoon.Common/Git/GitChangesOptions.cs`; `src/GrayMoon.App/Program.cs`; Worker configuration under `Worker:GitChanges` |
| Unit/integration tests | `src/GrayMoon.Worker.Tests/GitRepositoryWatcherManagerTests.cs`; `GitRepositoryWatcherObservationTests.cs`; `src/GrayMoon.App.Tests/WorkspaceGitChangesRouteActivityTests.cs`; `WorkspaceGitChangesActivityTrackerTests.cs` plus new focused tests |

## Stage-by-stage reviewer checklist

At each stage report: (1) tested baseline, (2) files modified and why, (3) precise lifecycle invariants maintained, (4) reproduction/negative tests, (5) expected timing and process counts, (6) remaining known failure modes, (7) rollback path and behavior toggles, (8) no unexpected UX/operation impact. If evidence contradicts a design assumption, **update the design before coding around it**.
