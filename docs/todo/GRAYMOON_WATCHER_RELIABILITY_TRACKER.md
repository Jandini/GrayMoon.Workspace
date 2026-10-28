# Git Changes watcher reliability - tracker

Living status for [the design](GRAYMOON_WATCHER_RELIABILITY_DESIGN.md) and [the implementation plan](GRAYMOON_WATCHER_RELIABILITY_IMPLEMENTATION_PLAN.md). Update this file at the end of every phase step. Nothing here is committed unless the user asks.

**Last updated:** 2026-10-27

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0 | Evidence: `[GCDiag]` logging, baseline tests, investigation doc, collection script | Dev-machine run done (F1 proven); VDI capture still wanted |
| 1 | Worker hardening (deadline expiry, captured-entry leases, `Touch`, self-heal, worktree metadata watching, scan retry) | Not started |
| 2 | `EnsureGitChangesWatchers` batch command and shared resolver | Not started |
| 3 | Keeper loop and App audit scheduler behind `UseWatcherKeeper` | Not started |
| 4 | Load test, rollout, architecture docs | Not started |

Rule: stop and ask the user before starting each phase.

## Phase 0 checklist

- [x] `[GCDiag]` logging in App (sweep, presence, scan, persist, write queue)
- [x] `[GCDiag]` logging in Worker (watcher, manager, coordinator, publisher, status command)
- [x] Read-only watcher diagnostics (`IsWorkTreeWatching`, `IsMetadataWatching`, `MetadataWatcherSkipReason`)
- [x] Baseline tests pinning F6, F7, F8 (`GitChangesWatcherReliabilityBaselineTests`, trait `WatcherReliabilityBaseline`)
- [x] Full Worker and App test suites green; builds with 0 warnings
- [x] Investigation doc with log-reading guide: `docs/investigations/git-changes-watcher-lifecycle-2026-10-27.md`
- [x] Log collection script: `docs/investigations/Collect-GitChangesDiagnostics.ps1`
- [ ] User captures logs on the fast machine and the VDI (protocol in the investigation doc, section 5)
- [ ] Causes ranked from evidence (investigation doc, section 7)
- [ ] Phase 1 scope confirmed or re-ordered from the ranking

## Hazard status

| Id | Hazard | Evidence so far | Fixed in |
|---|---|---|---|
| F1 | Presence lease never held by an open page (static MainLayout), so sweeps stop 8 min and watchers expire 17 min after the last navigation | **Proven live** 2026-10-28, see investigations/git-changes-watcher-findings-2026-10-28.md | **Phase 1 done (uncommitted, awaiting field check)** || F2 | Renewal arrives after the idle grace | Code reading; `sweep slow` log added | **Phase 1 done (uncommitted, awaiting field check)** || F3 | Snapshot dropped or rejected between Worker and SQLite | Code reading; drop, stale and lag logs added | **Phase 1 done (uncommitted, awaiting field check)** || F4 | Stale lease decrements a recreated entry | Code reading; underflow log added | **Phase 1 done (uncommitted, awaiting field check)** || F5 | Idle timer races `Acquire` | Code reading | **Phase 1 done (uncommitted, awaiting field check)** || F6 | Linked worktrees have no metadata watcher | **Reproduced** by baseline tests | **Phase 1 done (uncommitted, awaiting field check)** || F7 | Entry stays "alive" without an OS watcher | **Reproduced** by baseline test | **Phase 1 done (uncommitted, awaiting field check)** || F8 | Failed watcher scan is never retried | **Reproduced** by baseline test | **Phase 1 done (uncommitted, awaiting field check)** || F9 | Watcher evicted while the workspace is open | Code reading; entry-created and idle-expired logs added | **Phase 1 done (uncommitted, awaiting field check)** || F10 | See the design, section on failure mechanisms | Code reading | See design |

## Decisions

- 2026-10-27: The nav-bar red dot is in scope with no code change; it reads the persisted projection (design acceptance criterion 10).
- 2026-10-27: Phase 0 changes no behavior. Phase 0 is not a product-behavior change, so no Desktop README bullet.
- 2026-10-27: Baseline tests assert today's (wrong) behavior on purpose; Phase 1 flips the marked assertions.

## Open questions

- Which of F1/F2/F9 dominates on the VDI versus the fast machine (answered by the capture).
- Whether the sweep needs per-workspace parallelism or only a keeper (decided in Phase 3 from the sweep durations).

## Notes

- Three files (`WorkspaceGitChangesActivation.cs`, `WorkspaceGitChangesActivityTracker.cs` and `GitRepositoryWatcherManager.cs`) are stored in git with `CR CR LF` endings. Edits must preserve each file's existing endings or the diff becomes whole-file noise; check with `git diff --stat` after every edit.
- 2026-10-28: **Phase 1 implemented, uncommitted.** 1a: `WorkspaceGitChangesActivityBinder` is now an interactive island (F1). Worker: deadline expiry with one sweeper, captured-entry leases (F4, F5), real health plus recovery on renewal (F7), linked-worktree `gitdir` metadata watcher and 64 KB buffers (F6), watcher scan retry with backoff (F8), `Touch` API, removal-reason logs. Equal-version snapshots are logged at Debug as duplicates. The four baseline tests became `GitChangesWatcherReliabilityTests` (flipped assertions plus new ones). Desktop README bullet added.
- 2026-10-28: Not done in Phase 1: the App does not yet call `Touch` (Phase 2), no keeper (Phase 3). Still wanted: confirm in the running app that sweeps never stop with the page open for 30 min. Possible latent bug: `AppActivityTracker.razor` has no `@rendermode` and may have the same static-render problem.
