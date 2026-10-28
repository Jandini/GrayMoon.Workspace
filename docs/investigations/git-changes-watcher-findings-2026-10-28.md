# Git Changes watcher - Phase 0 findings (live run on the dev machine)

**Date:** 2026-10-28 (run 01:45 to 02:13 local)
**Build:** Phase 0 diagnostic build, App and Worker both started fresh at 01:45 (logs began empty)
**Setup:** Desktop mode, one Workspace (id 1) with 3 repositories, plus one Feature context (id 224, linked worktrees). The Changes page was open and untouched for the whole run.
**Method:** read the `[GCDiag]` logs, made untracked probe files in the Workspace and Feature checkouts at known times, and watched the App and Worker logs. All probe files were removed afterwards. One plain HTTP request to `/workspaces/1/changes` was made with `curl` at 02:10:57 to emulate a navigation. Nothing was staged, committed or pushed.

## 1. Result in one paragraph

**The Changes page stops receiving updates about 17 minutes after the last navigation, even though the page is still open, and nothing recovers it until the user navigates again plus up to 3 minutes.** The cause is not the Worker watchers themselves: the "this workspace is being viewed" lease is acquired and released within milliseconds on every page load and is never held by an open page. The App therefore treats the workspace as abandoned 8 minutes after the last page load, stops renewing the Worker watchers, and the Worker disposes them 10 minutes later. This was reproduced end to end with timestamps below. It matches the symptom "works for a while, then stops" on any machine, independent of speed.

## 2. Timeline (all times 2026-10-28, IST)

| Time | Event | Source |
|---|---|---|
| 01:45:56 | Worker online, first sweep creates 6 watcher entries (3 Workspace, 3 Feature) | Worker `watcher entry created` |
| 01:46:11 | Last page navigation in the browser: lease gained and released within 6 ms | App `lease gained` / `lease released refCount=0` |
| 01:50:41 | Last page load (the user's last action): lease gained and released within 6 ms, refCount back to 0 | App |
| 01:54:06 | **Probe 1 edit.** Persisted in SQLite 0.7 s later (watcher event, scan, push, write) | App `persisted` |
| 01:54:59, 01:57:59 | Last two sweeps that renew watchers | App `sweep start` |
| 02:00:59 | `workspace left active set (no viewers, activity grace elapsed)`; every later sweep logs `sweep skipped: no active workspaces` | App |
| 02:07:59 | All 6 watchers: `watcher idle-expired and disposed` (10 min after the last renewal), `entries remaining=0` | Worker |
| 02:09:40 | **Probe 2 edit** in both the Workspace and the Feature checkout | probe |
| 02:09:40 to 02:12:59 | **No** Worker activity and **no** `persisted` line. The Changes page and the nav red dot would show stale data for these changes | both logs |
| 02:10:57 | `curl` page request: `activation wasActive=false`, lease gained then released after 4 ms. **No warm-up scan ran** | App |
| 02:12:59 | Next periodic sweep (3 min tick) sees the workspace as active again, recreates all 6 watchers, and persists probe 2 (3 min 19 s after the edit) | both logs |

Between 01:58 and 02:08 the watchers were still alive and would have reported edits (inferred from the entries existing; not directly probed).

## 3. Findings

### F1 - The presence lease is never held by an open page (proven, root cause)
- `WorkspaceGitChangesActivityBinder` is mounted in `MainLayout`, which is rendered statically (no global interactive render mode; pages opt in per page with `InteractiveServerRenderMode(prerender: false)`). Its scope is the HTTP request scope, so `OnInitialized` calls `Activate` and the scope teardown calls `Dispose`, which releases the lease, all within one request.
- Every `gained` is followed by `released refCount=0` within 4 to 20 ms in the logs (about 20 pairs, none held longer). `WorkspaceGitChangesRouteActivity` documents the intent as "holds at most one lease for the workspace in view on this circuit"; that intent is not met.
- Effect: the only thing keeping a workspace active is the 8 minute `WorkspaceActivityGraceMinutes` after the last request. The 8 minute grace, the 10 minute Worker idle grace and the 3 minute renewal were designed assuming a held lease.
- This is mechanism F1 in the design, now proven rather than hypothesized, and it is bigger than the design assumed: it is not a sweep stall or a Worker disconnect, it affects every user on every machine.

### F1b - Recovery depends on the next sweep tick (observed)
- After presence returned (02:10:57) nothing happened until the sweep at 02:12:59 (about 2 min). The warm-up scan that `Activate` is supposed to start when `wasActive=false` did not run for my `curl` request (no `scan done`, no watcher creation, no job log within 8 s). A real browser navigation may behave differently because a circuit exists; **I could not verify this without touching the user's browser**, so treat the warm-up as unverified.
- The warm-up scan only covers the special Workspace context anyway; Feature contexts wait for the sweep either way.

### F6 - Feature worktrees have no metadata watcher (confirmed live, already reproduced in tests)
- Worker log for all three Feature paths: `workTree=true metadata=false metadataSkipReason=.git is a file (linked worktree: index and HEAD live elsewhere and are not watched)`. Workspace checkouts show `metadata=true`. So `git add`, `commit`, `checkout` run in a Feature are invisible to watchers.
- I did not stage anything (the project rule forbids it), so the live effect was not exercised; the baseline test already proves it.

### F-noise - Every snapshot is delivered twice and logged as "rejected stale" (observed)
- Each watcher-driven or scan-driven snapshot appears as `persisted` and then `rejected stale ... version N <= persisted N` with **identical** versions, a few ms later. That is the same snapshot arriving once from the Worker push and once from the scan response, not a stale snapshot. Harmless, but it floods the log at Information level and hides real stale rejections. Action: log equal versions as Debug "duplicate" and keep `<` at Information.

### Not observed in this run (no log evidence either way)
| Id | Mechanism | Status |
|---|---|---|
| F2 | Renewal later than the idle grace | Not seen: sweeps took under 1 s each (3 repos per context) and ran every 180 s. Can only matter with many repos. |
| F3 | Snapshots dropped offline, queue lag | Not seen: no `dropped`, no `write queue lag`, no stale rejections other than the duplicates above. |
| F4 | Lease count underflow | Not seen. |
| F7 | Entry alive without OS watcher | Not seen (no `OS watcher is not running`). Reproduced in tests only. |
| F8 | Failed watcher scan not retried | Not seen (no scan timeout or failure). Reproduced in tests only. |
| F9 | Entry evicted while the workspace is open | **Seen**, but fully explained by F1: the eviction is the consequence of presence loss, not an independent bug. |

The VDI with 39 repositories is where F2, F3 and F8 are most likely to appear; this run cannot speak to them. If the user's VDI shows staleness sooner than about 17 minutes, that points to those mechanisms and the same log lines will show it.

## 4. Impact on the plan

Ranked causes for the symptom "Changes stop updating while the page is open":

1. **F1 presence lost (proven, all machines).** Fix is small and independent of the Worker work.
2. **F6 Feature worktree metadata not watched (proven).** Affects only index/HEAD changes made in Features (stage, commit, branch switch).
3. F8, F2, F7 - plausible on the VDI, unproven here.

Recommended re-ordering (for the user to decide):

- **Move the presence fix to the front as a new Phase 1a:** hold the lease from an interactive component (the same pattern `BackgroundJobOverlay` already uses: an interactive island with `prerender: false` mounted in the layout, so its lifetime is the circuit, and Dispose releases when the tab closes). Keep the 8 minute grace for crashed circuits. Acceptance: with the page open and untouched for 30 minutes, sweeps never stop and watchers never expire, and the probe edit appears within 1 second at 30 minutes.
- Make `Activate` on a cold start also start the warm-up for all contexts, or trigger an immediate sweep, so recovery is not up to 3 minutes.
- Keep Phase 1 (Worker hardening: F6, F7, F8, F4/F5) as designed. The design's "keeper" (Phase 3) matters less once presence is real, but it stays useful as the safety net against F2.
- The Worker-side deadline expiry stays as designed, but note that with presence fixed the App renewal alone keeps watchers alive; the Worker should not expire watchers faster than the App can renew them.

## 5. Open items and limits of this run

- Only one workspace, 3 repositories, fast machine; no Worker restart, sleep/resume or reconnect was tested.
- The browser was not driven, so the red dot and Changes page were not looked at; the conclusions come from the persisted-projection logs (`persisted` is what both read).
- The warm-up scan behaviour in a real navigation is unverified (see F1b).
- Still wanted from the VDI: the same `[GCDiag]` capture (protocol in `git-changes-watcher-lifecycle-2026-10-27.md`), mainly to check F2, F3 and F8 under load.
- Source files for this report: App log `C:\ProgramData\GrayMoon\Logs\graymoon-app-20261028.log`, Worker log `graymoon-worker-20261028.log`.
