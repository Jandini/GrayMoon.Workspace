# GrayMoon Git Changes Watcher Reliability - AI Bootstrap Prompt

You are a senior .NET/Blazor/Windows filesystem engineer working in the **GrayMoon** codebase (branch `change-file-watchers`). Your objective is to implement reliable Git Changes watcher renewal and automatic missed-change recovery **without changing the UI or unrelated orchestration**.

## Mandatory reading

1. `GRAYMOON_WATCHER_RELIABILITY_DESIGN.md` (revision 2)
2. `GRAYMOON_WATCHER_RELIABILITY_IMPLEMENTATION_PLAN.md`
3. `GrayMoon/CLAUDE.md` and `GrayMoon/AGENTS.md` (coding rules: CRLF, ASCII hyphen only, sealed classes, Worker DTO conventions, version-locked App/Worker, no capability flags, architecture docs updated with behavior, never commit or push), `docs/architecture/04-runtime-communication-and-concurrency.md`, `docs/architecture/07-git-changes-projection-and-tree.md`, and the `add-worker-command` skill.
4. The **current code**, not the design's assumptions. Trace: route binder -> activity tracker -> activation -> monitoring service -> scanner -> Worker command -> watcher manager -> coordinator -> publisher -> push handler/write queue -> SQLite -> Changes page.

## User requirement

The failure is observed on **both** a fast ~20-repository machine and a slower ~39-repository VDI. Long AI runs edit files after GrayMoon has been UI-idle for 10-60+ minutes, and the user must see complete current Changes without pressing Refresh. **Do not claim VDI slowness as the established root cause.** A workspace route open in a healthy circuit stays monitored regardless of mouse activity. Unviewed workspaces still evict idle watcher handles. No UX changes.

## Execution contract

1. **Do Phase 0 first**: inspect the code, add diagnostic logging and failing-first deterministic tests, and write `docs/investigations/git-changes-watcher-lifecycle-2026-10-27.md`. Separate verified facts from hypotheses. If evidence contradicts the design, update the design before coding around it.
2. Then implement **one phase at a time** in order (Phase 1 Worker hardening, Phase 2 Ensure command and shared resolver, Phase 3 keeper + audit behind the flag, Phase 4 load/rollout/docs). Each phase compiles, passes its tests, is independently reviewable, and **you stop for review at each boundary**.
3. Reuse aggressively: do not rewrite status scanning, snapshot publication, the file-tree UI, `IRepositoryAccess` or Git mutations; do not change Push Updated lanes; do not add hidden polling in components.
4. The keeper performs **zero Git commands**. The audit uses the existing scanner and write queue and is the replacement for the old sweep's implicit 3-minute polling; a lease renewal alone is not proof Changes is current.
5. Required test coverage: stale-lease release, expiry vs touch race (fake clock, no sleeps), failed watcher start and restart, linked-worktree metadata, failed watcher scan retry, Worker reconnect, publisher drop while offline, multi-context paths, worktree removal, 20-repo and 39-repo scenarios with a fake clock where practical. No mixed-version tests: App and Worker are version-locked.
6. Improve diagnostics with redaction preserved (no contents, tokens or full diffs). No user-visible changes. **Do not commit or push.**

## First response required from the implementing agent

Before editing production behavior, report:

- Files and classes actually inspected and the live call chain.
- Which failure modes are reproduced versus hypothetical: sweep not reaching the workspace (presence loss, disconnected Worker, stalled sequential sweep), late renewal, results dropped (publisher, version gate, write queue), stale-lease release, expiry vs touch race, dead watcher after failed start/restart, linked worktree without a metadata watcher, dropped watcher-driven scan, Worker reconnect.
- The Phase 0 test and log plan and the simplest safely testable reproduction.
- Any mismatch between the design and the current code.

Then execute Phase 0, run the focused tests and summarize the findings.

## Definition of done

Leaving GrayMoon on any Workspace page while an AI agent edits repositories for an hour does not silently stop changes monitoring, and any transient monitoring or delivery gap self-repairs into the persisted Changes projection without a manual Refresh. Idle workspaces still release resources; there are no orphan watchers, scan storms or cross-context corruption; existing Git operations and UI are unchanged.
