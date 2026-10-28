# GrayMoon Git Changes - Reliable Watcher Lifecycles and Self-Healing Monitoring

**Status:** Proposed design (revision 2); code re-inspected on branch `change-file-watchers` (HEAD `106b918`), implementation not started
**Date:** 2026-10-27
**Scope:** App <-> Worker Git Changes monitoring; every Workspace and Feature context
**Companions:** [Implementation plan](GRAYMOON_WATCHER_RELIABILITY_IMPLEMENTATION_PLAN.md), [Bootstrap prompt](GRAYMOON_WATCHER_RELIABILITY_BOOTSTRAP.md)

## 1. Executive decision

**Keep the 10-minute idle watcher eviction. Stop using a Git status scan as the watcher keepalive. Replace the sequential "scan everything every 3 minutes" sweep with two independent, individually time-boxed loops: a Git-free keeper and a staggered audit.** Workspace route presence - not mouse or keyboard activity - decides whether watchers are kept. No UI changes.

The symptom was seen on two machines: a fast ~20-repository machine and a ~39-repository enterprise VDI with expensive Git operations. Slow Git is therefore a plausible amplifier, not the established cause; the design must be correct on the fast machine too.

### Non-negotiable user contract

> Leave GrayMoon showing any page of Workspace A while an AI agent edits its repositories for 30, 60 or 120 minutes. Changes appear automatically. Returning to the app reconciles anything missed without pressing **Refresh**.

A workspace that nobody views may still age out and release OS handles after the configured grace. Manual Refresh stays unchanged.

### Three separate contracts

1. **Keeping** a watcher alive (lease/expiry).
2. **Verifying** the watcher is actually functioning (health).
3. **Confirming** the persisted projection is current (reconciliation/audit).

Today all three are collapsed into one operation (a full status scan every 3 minutes). That is why the current sweep is both the keepalive and, implicitly, the only safety net. Removing the scan from the keepalive removes the safety net, so the audit in Plane B is a required replacement, not an extra.

## 2. Verified current behavior (read from code)

| Component | Verified behavior | Consequence |
|---|---|---|
| `GitChangesMonitoringBackgroundService` (replaced by `GitChangesWatcherKeeper` and `GitChangesAuditScheduler`) | Waits 5 s, then loops: for each active workspace, for each non-paused context, `await scanner.ScanWorkspaceAsync(...)` **sequentially**; then waits `WatcherRenewalIntervalMinutes` (3, clamped below idle grace). Wakes early only on Worker `Online`. Returns silently when the Worker is disconnected. No per-context timeout. | Renewal period is `sweep duration + 3 min`. One slow or stalled context delays every later context and workspace. It is also today's only periodic audit: every active repository is rescanned every ~3 min plus sweep time. |
| `GitChangesWorkspaceScanner.ScanCoreAsync` | One DB query and one path-resolution call per context, then one `GetGitChangeStatus` Worker command per repository, bounded by `MaxParallelRepositoryOperations`. Results go to the write queue with fire-and-forget `Enqueue`. | Reusable for target resolution (path + attribution). Each command waits up to `WorkerBridgeOptions.CommandTimeoutSeconds` (240 s). With the Worker read pool saturated, a 39-repo context can take many multiples of that. |
| `WorkerBridge` | Per-command timeout 240 s; a timed-out call returns a failed response. | A lost response does not hang forever, but it can stall the sequential sweep for minutes per batch. |
| `GetGitChangeStatusCommand` | Registers path attribution, `watcherManager.Acquire(repoPath)`, runs `RefreshNowAsync`, releases the lease on completion. | Keepalive is tied to a Git scan and to read-pool scheduling (`ReadOnlyCommands` in `SignalRConnectionHostedService`). |
| `GitRepositoryWatcherManager` | One `Timer` per entry, started on last release, cancelled on `Acquire`. The timer callback checks `LeaseCount <= 0`, then `TryRemove` + `Dispose`, **outside `_createLock`**. `Release` and `Lease` are keyed by path string, and `Release` looks up the *current* entry for that key. | See failure mechanisms F4 and F5. |
| `GitRepositoryWatcher` | `Start()` catches all exceptions and leaves fields null. `OnError` disposes both watchers, raises `Overflowed` (the manager then does `MarkDirty`, so overflow already triggers a rescan), then calls `Start()` again. The `.git` watcher exists only when `Directory.Exists(repo\.git)`. Default `InternalBufferSize` (8 KB). | A failed (re)start leaves a manager entry with no OS watcher and nothing retries it. Linked worktrees (Feature contexts) have a `.git` **file**, so they get no metadata watcher. |
| `GitStatusRefreshCoordinator` | Watcher-driven scans run under `WatcherScanTimeoutSeconds` (120). A failed or timed-out watcher scan is logged and dropped. | A transient failure (slow VDI, locked index) leaves the persisted view stale until the next event or the next sweep. Once the sweep is gone, nothing else would repair it. |
| `GitChangesSnapshotPublisher` | Returns without buffering when the hub connection is not `Connected`. | A disconnect window silently loses pushes. |
| `GitChangesSnapshotPushHandler` | Rejects snapshots whose version is not greater than the persisted one (logged at Debug). Versions are seeded from `DateTime.UtcNow.Ticks`, so a restarted Worker outranks persisted state. | Worker restart ordering is already handled. Rejections are invisible at default log levels. |
| `WorkspaceGitChangesActivation` | Warm-up scan only on **cold** activation (`!wasActive`) and only for the **special Workspace** context. | Re-entry within the 8-minute grace, and every Feature context, get no warm-up. |
| `WorkspaceGitChangesActivityTracker` | `RefCount > 0` or last-active within `WorkspaceActivityGraceMinutes` (8). Independent of UI idle. | Presence is lost only when the lease is disposed, i.e. the circuit is disposed (no `DisconnectedCircuitRetentionPeriod` override found in `Program.cs`, so the Blazor default applies) or the user leaves the workspace. |
| Git hooks | Do not call `MarkDirty`. Hooks drive repository state sync, not Changes. | Index changes in a linked worktree are not seen by the watcher (see F6). |

Default `GitChangesOptions`: `WatcherIdleGraceMinutes = 10`, `WatcherRenewalIntervalMinutes = 3`, `WorkspaceActivityGraceMinutes = 8`, `WatcherDebounceMilliseconds = 400`, `WatcherScanTimeoutSeconds = 120`, `MaxParallelRepositoryOperations = 8`.

**No incident logs exist yet. Everything below is a code-level hazard, ranked by how well the code supports it, not a proven root cause.**

## 3. Failure mechanisms, ranked by evidence

Reasoning anchor: while the sweep runs, every active repository is rescanned every ~3 min plus sweep time. A dead watcher alone therefore causes at most that much lag. A Changes view that stays stale for tens of minutes means the sweep stopped reaching that workspace, or its results were not applied.

| # | Mechanism | Evidence | Applies on fast machine? |
|---|---|---|---|
| F1 | **Sweep not reaching the workspace**: presence lost (circuit disposed, then 8 min grace), Worker `IsWorkerConnected == false` (silent return), sweep stalled behind a slow earlier context/workspace, or exception swallowed. | Code-visible; sequential, untimed, silent returns. | Presence/disconnect: yes. Stall: less likely. |
| F2 | **Late renewal then eviction**: sweep duration + 3 min approaches 10 min when many contexts/repos are slow or the read pool is saturated. After eviction the next scan recreates the watcher, but the delay is already user-visible. | Code-visible arithmetic. | VDI mainly. |
| F3 | **Results dropped**: publisher drops while disconnected; version gate rejects; write queue lag or failure. | Code-visible; rejections logged at Debug only. | Yes. |
| F4 | **Lease-by-key stale release**: after eviction and recreation, an old `Lease` (still holding only the path key) decrements the **new** entry's count, possibly below zero, and can schedule disposal of an entry that is leased. | Code-visible, narrow timing. | Yes, rare. |
| F5 | **Idle-timer vs Acquire race**: callback reads `LeaseCount <= 0`, `Acquire` increments, callback still removes and disposes. `Timer.Dispose()` does not wait for a running callback. | Code-visible, microsecond window. Real but unlikely to be the user-visible cause on its own. | Yes, rare. |
| F6 | **Linked worktree has no metadata watcher**: `git add` / `commit` / `checkout` by an agent in a Feature context change `<main>/.git/worktrees/<name>/index|HEAD`, which no watcher of that context sees. Only working-tree events and the sweep catch it. | Code-visible (`Directory.Exists(repo\.git)` is false for a `.git` file). **Removing the sweep without fixing this regresses Feature contexts.** | Yes, any Feature. |
| F7 | **Dead watcher entry**: `Start()` exception or failed `OnError` restart leaves null OS watchers behind a live manager entry; nothing retries. Heavy churn (build output, `node_modules`) overflows the 8 KB buffer and makes `OnError` more likely. | Code-visible. | Yes. |
| F8 | **Dropped watcher-driven scan**: a timed-out or failed event scan is not retried; the persisted view stays stale until another event. | Code-visible. | VDI mainly. |
| F9 | **Worker restart / reconnect**: watchers and registry are in-memory. Today recovered by a sweep on `Online`. | Code-visible. | Yes. |
| F10 | **Removal races**: `IRepositoryAccess` release-before-delete is intentional; a keepalive must not resurrect a watcher for a claimed folder. | Existing guards in `Acquire`; must be preserved. | Yes. |

Disambiguating F1 from the rest is the purpose of Phase 0 diagnostics.

## 4. Target architecture

```text
Workspace route present (UI may be Idle/Hidden)
  -> WorkspaceGitChangesActivityTracker (unchanged presence source)
  -> App Git Changes monitor (replaces the sweep service, behind a flag)
       Keeper loop (no Git)  --EnsureGitChangesWatchers batch per context-->  Worker
       Audit scheduler       --existing ScanRepositoriesAsync, single-flight-->  Worker GetGitChangeStatus
  Worker: GitRepositoryWatcherManager (deadline-based expiry, health, Touch)
       -> FileSystemWatcher -> existing GitStatusRefreshCoordinator -> existing publisher
       -> App write queue -> SQLite -> Changes page (unchanged)
```

### Plane A - keep: deadline-based lease, no Git

**Worker manager redesign (replaces generation counters and per-entry timers):**

- Each entry has `LeaseCount` and an `ExpiresAt` deadline from an injectable `TimeProvider`. A **single** manager-level sweeper (about every 30 s) removes entries with `LeaseCount == 0 && now >= ExpiresAt`, under the same lock `Acquire`/`Touch` use, and disposes the removed entries **outside** the lock. There is no per-entry `Timer`, so there is nothing to cancel and F5 cannot occur. Tests call `SweepExpired(now)` with a fake clock; no sleeps.
- `Acquire` returns a lease that **captures the entry** (not the key). Releasing a lease whose entry is no longer the current one for that key is a no-op, and underflow is guarded (F4). Last release sets `ExpiresAt = now + grace`.
- New `Touch(repoPath)` extends `ExpiresAt` without any lease, creating the entry if missing and retrying a failed watcher start (subject to cooldown). Keepalive therefore never accumulates lease counts or timers, and repeating it is idempotent.
- Removal precedence is unchanged: `IsUnderRemoval` and `RegisterReleasable` win, and `Touch` returns `UnderRemoval` instead of recreating the watcher.

**`EnsureGitChangesWatchers` Worker command** (batch per context, `Touch` per repository):

- Does only: validate/resolve path with the existing `WorkerRepositoryPaths` helpers, register attribution in `GitChangesRepositoryRegistry`, `Touch`. **No Git process, no status scan, no network.**
- Per-repository result: `Renewed | Created | Recovered | Degraded | Missing | UnderRemoval`, plus a response-level `workerInstanceId` and `effectiveGraceSeconds`. One bad repository never fails the batch. Wire fields are only what the App actually acts on; the App does not track per-repository "coverage generations".
- **Routing:** run it in the read pool alongside `GetGitChangeStatus` (add to `ReadOnlyCommands`). That is where renewal runs today, so the new path is never worse, and the margin is large: renewal is attempted every 3 min against a 10 min grace, i.e. three attempts before expiry, each with a 30 s App-side timeout. Escalate to a dedicated lane only if Phase 0/4 measurements show renewal queue wait approaching the grace. Push Updated lanes are untouched.
- App and Worker are version-locked, so there is no mixed-version fallback and no capability flag.

**App keeper loop:**

- A `PeriodicTimer` tick (fixed cadence; missed ticks are skipped, never queued) every `WatcherRenewalIntervalMinutes`. Per tick: for each active workspace, for each non-paused context, send one batch (chunked to a bounded size), up to a small bounded number of contexts concurrently, each call wrapped in its own timeout (default 30 s). A failure or timeout is logged and retried on the next tick; it never delays another context.
- Targets come from one **shared target resolver** extracted from `ScanCoreAsync` (workspace root, workspace folder, repository names, repository paths, ids). Scan and keeper then share exactly one path/attribution implementation. No separate desired-set cache in the first version: one DB query and one path-resolution call per context per 3 minutes is cheap; add caching only if Phase 4 measurements justify it.
- Idle/Hidden UI state never removes watchers. Workspaces with no viewer and grace expired are simply no longer sent; the Worker evicts them on schedule.
- On Worker `Online`: send Ensure first, then request an audit (see Plane B).

### Plane B - verify: Worker self-healing plus an App audit

**Worker side (zero new protocol):**

- When `Touch` reports `Created`, `Recovered`, or the watcher recorded a discontinuity, the Worker calls `refreshCoordinator.MarkDirty(repoPath)` itself. The existing debounce, scan gate, snapshot cache and publisher then deliver the authoritative snapshot. The App does not need to be told about the gap to cause a rescan.
- `Overflowed` already marks dirty; keep that. Add a bounded, backed-off retry for a **failed or timed-out watcher-driven scan** (for example 5 s, 30 s, 2 min, then stop and rely on the audit) so one transient failure no longer leaves a stale view (F8).
- Raise `FileSystemWatcher.InternalBufferSize` to 64 KB to reduce overflow under agent churn (F7).
- Watch the real index/HEAD location for linked worktrees by resolving the `gitdir:` pointer in the `.git` file (F6). Required **before** the sweep is retired.

**App audit scheduler** (the replacement for the sweep's implicit audit):

- Single-flight and coalesced per `(workspaceId, contextId)`; bounded parallelism; every scan wrapped in a timeout. It uses the existing `IGitChangesWorkspaceScanner.ScanRepositoriesAsync` and the existing write queue. No second scanner, no direct SQLite writes.
- Triggers: (1) periodic, every `WatcherAuditIntervalMinutes` (new option, default 5, always cheaper than today's sweep because it only runs for active contexts and only one at a time per context; tune from Phase 0 data), staggered across contexts; (2) Worker `Online`; (3) **cold activation of a workspace for all its contexts** (today only the special Workspace is warmed); (4) return from a prolonged Idle/Hidden state (existing activity-state signal, cooldown ~2 min) for the contexts of the viewed workspace.
- This is the explicit trade: today a silent miss is repaired within about 3 min plus sweep time by polling; after the change it is repaired within the audit interval. State this in release notes, and do not pick a faster cadence to hide a lifecycle defect.
- **What "persisted" means:** a scan result being enqueued to the write queue is the success signal the App can observe. The design does not require the App to clear per-repository gap flags after confirmed persistence, because gaps are detected and repaired Worker-side and the audit is the backstop. A failed audit is logged and retried at the next trigger.
- The Changes page needs no change; it keeps rendering the persisted projection.

### Plane C - lifecycle cleanup and observability

- 10-minute idle eviction stays for anything not touched. Every removal logs a reason: `IdleExpired`, `ExplicitRemoval`, `WorkerShutdown`, `WatcherError`, `Recreated`.
- Watcher health is derived from the real OS watcher state (`_workTreeWatcher` created and raising events; metadata watcher where a metadata path exists), not from dictionary membership. `ActiveWatcherCount` keeps meaning "entries"; add a separate healthy count.
- Reuse `GitRepositoryWatcherCoverage` (`StartedAt`, `LastDiscontinuityAt`, `EndedAt`) plus a per-process worker instance id for logging; do not invent a new generation counter.
- Log (no secrets, no file contents): keeper tick start/end, entries sent and statuses, skipped/failed/timed-out contexts, planned vs actual tick time; audit trigger reason, duration, outcome; Worker watcher created/touched-recovered/degraded/removed with reason; scan failures and retries; publisher drop-while-offline; version-gate rejections raised from Debug to an anomaly-level (sampled) log.

## 5. State model

```text
Absent --Touch/Acquire + valid path--> Starting --> Healthy (+ MarkDirty once)
Healthy --Touch--> Healthy (ExpiresAt extended, no scan)
Healthy --event--> Healthy (existing debounced scan)
Healthy --OnError--> Discontinuity recorded, MarkDirty, restart
        restart ok --> Healthy        restart fails --> Degraded
Degraded --Touch (after cooldown)--> restart; ok --> Recovered (+ MarkDirty)
Any --folder claimed for removal--> Released (never recreated while claimed)
Any --LeaseCount == 0 and now >= ExpiresAt--> Absent (swept)
```

Idempotence: the same batch twice creates at most one watcher per canonical path and changes no lease counts. Attribution: identical repository names in different contexts are different paths; keep keying by the resolved path from the shared resolver.

## 6. Scheduling and performance policy

| Work | Trigger | Git cost | Requirements |
|---|---|---|---|
| Keeper | every 3 min per active workspace | None | Fixed cadence, per-call timeout, per-context isolation. |
| File event | watcher | Existing per-repo scan | Existing debounce/gate; retry on transient failure. |
| Watcher recreated/recovered | Touch | One coalesced scan | Worker-side `MarkDirty`. |
| Audit | periodic / Online / cold activation / return from idle | Bounded scans | Single-flight per context, timeouts, staggered. |
| Idle cleanup | no touch for grace | None | Unchanged semantics. |

Do not assume any cadence is fast enough: Phase 0 and Phase 4 measure the 20-repo machine, the 39-repo VDI and multi-Feature contexts.

## 7. Reuse and scope control

**Reuse unchanged:** route binder, activity tracker, `GitStatusRefreshCoordinator` state machine, status scan service, snapshot cache/version gate, SQLite projection, SignalR notifications, file-tree UI, manual Refresh, nested-repository rules, `IRepositoryAccess` removal semantics.

**Modify:** watcher manager (deadline expiry, captured-entry leases, health), `GitRepositoryWatcher` (health, restart retry, linked-worktree metadata, buffer size), coordinator (bounded retry of failed watcher scans only), one new Worker command, scanner (extract target resolver), monitoring service (keeper + audit), activation (audit on cold start), options and tests.

**Do not change:** navigation/UX, Git status parsing, stage/unstage/commit semantics, Push Updated lanes, package versioning, general Worker concurrency defaults, repository cleanup guarantees, database schema.

## 8. Acceptance criteria

1. 20-repo and 39-repo Workspaces (main checkout and Feature worktrees) stay monitored through 30-120 minutes without UI interaction during AI editing sessions; persisted Changes matches an independent `git status` without Refresh.
2. A watcher that is recreated, recovered, or re-established after Worker disconnect/restart yields an authoritative snapshot without user action.
3. The keeper issues **zero Git processes** and its cadence is independent of scan duration; one stalled context cannot delay another.
4. A failed or timed-out watcher scan is retried; linked-worktree `git add`/`commit` is observed by a watcher.
5. Idle/unviewed workspaces still evict on schedule, including when a Feature is removed; no handle blocks worktree deletion; no watcher is resurrected for a claimed folder.
6. A stale lease cannot affect a recreated entry; a timer/expiry vs touch race cannot dispose a renewed entry (deterministic tests).
7. No duplicate or unbounded scans, no orphan subscriptions, no snapshot version regressions, no cross-context mix-ups.
8. Logs explain why each watcher was created, touched-recovered, degraded, removed and reconciled, with workspace/context/repository identity and durations.
9. No UX change; manual Refresh, mutation flows and background notifications unchanged.
10. The Changes nav dot (`ChangesNotificationDot`) needs no change but is covered by acceptance: it reads only the persisted projection (`HasAnyChangesAsync`) and refreshes on `IWorkspaceGitChangesNotifier`, so it is exactly as current as the Changes page. With a watcher dead or evicted, the dot must flip within the audit interval after an agent edit (and clear after an external commit), in the main Workspace and in Feature contexts.

## 9. Risks and mitigations

- **Circuit disappears while the window is open:** presence follows the circuit lease; on the new circuit's activation the cold-start audit covers all contexts. Never infer closure from 20-second UI inactivity.
- **Heavy AI churn:** existing coalescing plus the larger buffer; audits are single-flight and bounded.
- **Audit interval is coarser than today's polling:** documented trade; configurable; Phase 4 measures.
- **Ensure queued behind read-pool scans:** three-attempt margin, App timeout, measurement, escalation path.
- **Concurrent removal vs Touch:** `UnderRemoval` wins and is treated as non-error without retry storms.
- **False healthy:** health derives from OS watcher state, not entry existence.

## 10. Rollback

There is no feature flag. The keeper and the audit replace the sweep in one step, so exactly one mechanism ever runs. Worker changes (Phase 1) are behavior-preserving fixes. The new Worker command is inert unless the App calls it. No schema migration. Verify no leaked watchers or duplicate scans across Worker reconnects and circuit reconnects.

## 11. Remaining Phase 0 questions

- Which of F1-F3 explains the field symptom? Correlate keeper/sweep timing, presence, Worker connection state, publisher drops and version-gate rejections during a real AI run on both machines.
- Read-pool queue wait for a tiny command while eight scans run on the VDI.
- Does the Desktop WebView2 shell suspend or throttle the page or circuit while hidden? (Check the Desktop repo before assuming.)
- Linked-worktree layout: `gitdir:` resolution for worktrees of a main checkout and for the special Workspace repository.

**Design principle:** keeping a watcher alive, verifying it is healthy, and confirming the persisted view is current are three separate contracts. Solve and instrument all three.

## 12. Changes from revision 1

- Failure mechanisms re-ranked by what the code proves; the sweep's role as the implicit 3-minute audit is now explicit.
- Expiry redesigned as a deadline plus one sweeper (no generations, no per-entry timers); leases capture the entry; `Touch` replaces acquire/release for keepalive.
- `coverageGeneration` and `needsReconciliation` wire fields removed; the Worker self-heals gaps with `MarkDirty`, and the App audit is the only App-side reconciliation machinery.
- Added: linked-worktree metadata watching, bounded retry of failed watcher scans, buffer size, per-call timeouts, audit on cold activation of all contexts.
- Added decisions instead of open checks: read-pool routing, shared target resolver, no desired-set cache initially.
- Removed mixed-version/legacy-protocol language (App and Worker are version-locked).
