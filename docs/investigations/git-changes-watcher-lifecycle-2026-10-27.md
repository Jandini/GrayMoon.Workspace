# Git Changes watcher lifecycle - Phase 0 investigation

**Status:** Phase 0 code, logging and baseline tests done; **field evidence not collected yet** (needs the capture runs in section 5)
**Date:** 2026-10-27
**Design:** [../todo/GRAYMOON_WATCHER_RELIABILITY_DESIGN.md](../todo/GRAYMOON_WATCHER_RELIABILITY_DESIGN.md)
**Tracker:** [../todo/GRAYMOON_WATCHER_RELIABILITY_TRACKER.md](../todo/GRAYMOON_WATCHER_RELIABILITY_TRACKER.md)

## 1. What Phase 0 changed (no behavior change)

Only log statements, three read-only diagnostic properties on `GitRepositoryWatcher` (`IsWorkTreeWatching`, `IsMetadataWatching`, `MetadataWatcherSkipReason`) and one new test class. Every new message is tagged **`[GCDiag]`**. Some existing messages gained the tag or a higher level where a silent failure was previously hidden at Debug. No new setting, protocol, schema or UI.

| Area | File (under `GrayMoon/src`) | What is now logged |
|---|---|---|
| App sweep | `GrayMoon.App/Services/GitChanges/GitChangesMonitoringBackgroundService.cs` | sweep start (active workspaces, seconds since the previous sweep start), per-context duration, sweep end or slow (Warning when sweep + renewal reaches watcher idle grace), skipped because Worker not connected, Worker connection state changes |
| App presence | `.../WorkspaceGitChangesActivityTracker.cs`, `.../WorkspaceGitChangesActivation.cs` | activity lease gained/released with ref count, workspace leaving the active set, activation with `wasActive` |
| App scan | `.../GitChangesWorkspaceScanner.cs` | per-scan summary (repos, failed/empty, elapsed), failed scan raised from Debug to Warning (Information for expected removal outcomes) |
| App persist | `.../GitChangesSnapshotPushHandler.cs`, `.../WorkspaceGitChangesWriteQueue.cs` | stale-version rejections raised from Debug to Information with workspace/repo/path; persisted (Debug); write queue lag over 5 s (Warning) |
| Worker watcher | `GrayMoon.Worker/Services/GitChanges/GitRepositoryWatcher.cs` | start result (work-tree / metadata watching and why metadata is skipped), start failure, overflow/error, restart result |
| Worker manager | `.../GitRepositoryWatcherManager.cs` | entry created, entry exists but OS watcher not running, lease count underflow, idle-expired disposal, released for removal |
| Worker scan | `.../GitStatusRefreshCoordinator.cs` | watcher-driven scan timeout/failure raised from Debug to Warning and stated "no retry"; scan failure tagged |
| Worker publish | `.../GitChangesSnapshotPublisher.cs` | snapshot dropped while the App connection is down (first, then every 25th, with running total); path not registered |
| Worker command | `GrayMoon.Worker/Commands/GetGitChangeStatusCommand.cs` | done line with elapsed ms and watcher entry count (Debug) |

## 2. Hazards reproduced by the baseline tests (not field evidence)

`GrayMoon.Worker.Tests/GitChangesWatcherReliabilityBaselineTests.cs` pins today's behavior. All 4 tests pass on current code, which **reproduces** these hazards deterministically:

| Id | Reproduced fact |
|---|---|
| F7 | A folder the OS watcher cannot watch still yields a live `GitRepositoryWatcherManager` entry (`ActiveWatcherCount == 1`) while `IsWorkTreeWatching == false`. Renewal would keep that dead entry alive. |
| F6 | A linked worktree (every Feature checkout) has no metadata watcher (`.git` is a file). `git add` in a worktree raises no watcher event; the same `git add` in a normal checkout does (positive control). |
| F8 | A failed watcher-driven scan is attempted exactly once and never retried. |

Phase 1 inverts the assertions marked "Phase 1 flips this".

## 3. Hazards confirmed by code reading only (no deterministic test yet)

F4 (stale lease keyed by path decrements the current entry) and F5 (idle timer versus `Acquire`) need a time/entry seam that does not exist today, so their tests arrive in Phase 1 together with the fix. The `lease count underflow` log line is the runtime evidence for F4. F1/F2 (sweep not reaching the workspace, late renewal) are App scheduling problems; the sweep logs are their evidence, and a deterministic test arrives with the Phase 3 keeper.

Regression run after the logging changes: Worker tests 839 passed / 1 skipped, App tests 1763 passed, both projects build with 0 warnings.

## 4. Where the logs are

| Process | File | Notes |
|---|---|---|
| App | `C:\ProgramData\GrayMoon\Logs\graymoon-app-YYYYMMDD.log` | Debug is included. In Docker the same folder is inside the container. |
| Worker | `C:\ProgramData\GrayMoon\Logs\graymoon-worker-YYYYMMDD.log` | Debug is included. |
| Desktop | `%LOCALAPPDATA%\GrayMoon\Logs\desktop-YYYYMMDD.log` | Only needed if the window or WebView2 misbehaved. |

If the App and the Worker run on different machines (Worker on a VDI, App in Docker elsewhere), collect each file from its own machine and tell me which is which.

**Easiest way to collect:** run the script with the time window of the test. It reads running logs safely and sorts App and Worker lines together:

```powershell
.\docs\investigations\Collect-GitChangesDiagnostics.ps1 -Since "2026-10-27 09:00" -Until "2026-10-27 11:30"
```

It writes `gcdiag-<time>.txt` with every `[GCDiag]` line plus every warning and error in that window. Send me that file (and the Desktop log only if asked). It contains repository paths and workspace/repository ids, but no file contents or tokens.

## 5. What to do while capturing

Run the **same plan on the fast ~20-repo machine and on the ~39-repo VDI**, once each, with the build containing these logs on both App and Worker. Use one Workspace that also has at least one Feature (worktree) context.

1. Start GrayMoon, open a Workspace page (any page under `/workspaces/{id}`), wait for the first sweep (up to about 3 minutes), then **do not touch the window**. Write down the clock time `T0`.
2. At about `T0+1`, `+9`, `+12`, `+30` and `+60` minutes, from a terminal (not from GrayMoon), edit one file in a main-Workspace repository, then edit another file in a Feature worktree repository. Once, at the first step, also run `git add <that file>` in the Feature worktree. Write down the exact time of each action.
3. About one minute after each step, look at the Changes page and the red dot in the nav bar **without pressing Refresh**. Write down what you see: updated within 1 minute / updated later (when) / not updated. Press Refresh once only after writing the observation, and note whether the missing change then appears.
4. Optional extras, each as its own timed note: restart the Worker service while the page is open; let the machine sleep or the VDI session disconnect and reconnect; close and reopen the GrayMoon window.
5. Run the collection script for the whole window and send me the file together with your notes (a table of time / action / what you saw is perfect), the machine type (fast or VDI), the number of repositories and Features, whether this is Desktop or Docker, and the GrayMoon version.

## 6. What to look for (and what it means)

You do not need to interpret these; this is the decoder I will use, and you can grep for the quoted text yourself.

| Look for | Meaning |
|---|---|
| `sweep start ... sinceLastSweepStartSec=` | The App sweep cadence. About 180 s plus the previous sweep duration is normal. Anything approaching 600 means watchers can expire between renewals (F2). |
| `sweep slow` (Warning) | Sweep plus renewal delay already reaches the Worker's idle grace. Direct F2 evidence. |
| A `sweep start` with no later `sweep end` / `sweep slow` for a long time | The sequential sweep is stuck on one context (F1). The last `sweep context done` shows which one was slow. |
| `sweep skipped: Worker is not connected` | The sweep did nothing because the Worker connection was down (F1). Check the `Worker connection state changed` lines in the window. |
| `workspace activity lease released ... refCount=0`, followed 8 minutes later by `left active set`, while the window was still open | The browser circuit was disposed and presence was lost, so sweeps stopped for that workspace (F1 presence). The Desktop log may explain why. |
| `workspace activation: ... wasActive=false` | A cold start. The warm-up scan covers only the special Workspace context, not Features. |
| `watcher entry created` for a path already created earlier in the run | That watcher was evicted (`idle-expired`) or the Worker restarted. If the workspace was open, this is the F2/F9 smoking gun; compare with the sweep lines just before. |
| `watcher idle-expired and disposed` while the workspace should be active | Same as above: renewal did not arrive within the idle grace. |
| `git watcher started ... workTree=True metadata=False metadataSkipReason=.git is a file` | Expected for every Feature worktree: its `git add` / `commit` is not seen by a watcher (F6, already reproduced). |
| `watcher entry exists but its OS watcher is not running` | A renewed entry that is dead (F7). |
| Watcher overflow or failure lines, and `restart after error finished ... workTreeWatching=False` | The OS watcher overflowed or failed and did not come back (F7). |
| `Watcher-driven git status scan ... timed out ... no retry` | A change event was seen but its scan failed; the view stays stale until the next event or sweep (F8). Likely on the VDI. |
| `snapshot dropped` (offline) | The Worker produced a snapshot while the App link was down; nothing was buffered (F3). |
| `rejected stale` snapshot version | The App ignored a snapshot as older than the persisted one (F3). |
| `write queue lag` | SQLite writes are backed up; the view lags behind (F3). |
| `lease count underflow` | A stale or duplicate lease release hit a recreated entry (F4). |
| `scan done ... failedOrEmpty=N` and `scan failed ... ErrorCode` | Whether the App-driven scans themselves succeed, and why not. |
| `GetGitChangeStatus done ... elapsedMs=` (Debug) | How long one repository status takes on that machine (compare fast and VDI). |
| `snapshot persisted` (Debug) | The last time each repository's data reached SQLite. If your observation says "stale" but these lines continue, the problem is in the UI/notifier, not the pipeline. |

## 7. Ranked causes (fill in after the capture)

| Rank | Mechanism | Fast machine | VDI | Evidence |
|---|---|---|---|---|
| 1 | _pending field evidence_ | | | |

Record each candidate (F1 to F10) as **observed / reproduced / not reproduced / inconclusive**, with the log lines and times that support it.

## 8. Known limitation of this instrumentation

Debug lines are included in the files by the existing logging configuration. If you changed the log levels, restore the defaults before capturing, or the `persisted` and `GetGitChangeStatus done` lines will be missing.
