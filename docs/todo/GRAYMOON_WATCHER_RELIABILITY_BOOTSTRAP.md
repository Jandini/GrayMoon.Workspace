# GrayMoon Git Changes Watcher Reliability — AI Bootstrap Prompt

You are a senior .NET/Blazor/Windows filesystem engineer working in the **GrayMoon** `main` codebase. Your objective is to implement reliable Git Changes watcher renewal and automatic missed-change recovery **without changing the UI or unrelated orchestration**.

## Mandatory reading

1. `GRAYMOON_WATCHER_RELIABILITY_DESIGN.md`
2. `GRAYMOON_WATCHER_RELIABILITY_IMPLEMENTATION_PLAN.md`
3. Relevant repo docs: `CLAUDE.md`, `docs/architecture/04-runtime-communication-and-concurrency.md`, `docs/architecture/07-git-changes-projection-and-tree.md`.
4. Read **current local main code**, not old design assumptions; trace App route binder → activity tracker → monitoring service → scanner → Worker command → watcher manager → publisher → SQLite projection.

## User requirement / critical correction

The failure is observed **both on a fast 20-repository machine and on a slower 39-repository VDI**. Long AI runs can edit files after GrayMoon has been UI-idle for 10–60+ minutes. The user must see complete current Changes automatically without pressing Refresh. **Do not claim VDI slowness as established root cause.** A workspace route open in a healthy circuit should stay monitored independent of mouse activity. Unviewed workspaces should still evict idle watcher handles. No UX changes.

## Execution contract

1. **Do Phase 0 first.** Inspect real code and write the investigation report with diagnostics + deterministic reproductions. Do not start the refactor before reporting what is verified and what remains a hypothesis. If evidence shows a different root cause, adjust the design/plan and explain it.
2. After Phase 0 review, implement **one phase at a time** in dependency order. Each phase must compile, pass relevant tests, be independently reviewable, and not leave broken intermediate behavior. Stop at phase boundaries for review.
3. Focus on minimal-risk reuse; do not rewrite status scanning, snapshot publication, file-tree UI, `IRepositoryAccess` or Git mutations. Do not change Push Updated's two lanes. Do not silently introduce costly periodic polling.
4. Test lease-expiration/acquisition race, failed OS-watcher startup, Worker reconnect, dropped publisher notifications, multi-context paths, worktree removal, 20-fast and 39-VDI scenarios; simulate long idle with a fake clock where practical.
5. The keeper must use lightweight batched renewals and perform **zero Git commands**. Reconciliation and low-frequency audits use the existing authoritative status/SQLite pipeline. A lease renewal alone is not proof Changes is current.
6. Improve diagnostic logging; preserve redaction. No user-visible changes. **Do not commit or push automatically.**

## First response required from implementing agent

Before editing production behavior, report:

- Files/classes actually inspected and their live call chain.
- Measured/reproduced versus hypothetical failure modes. Include watcher timer race, failed restart, late sweep, circuit/presence, Worker reconnect and missing SignalR snapshots.
- The **Phase 0** test/log plan and the simplest safely testable reproduction.
- Any mismatch between the supplied design and current `main`.

Then execute Phase 0, produce `docs/investigations/git-changes-watcher-lifecycle-2026-10-27.md`, run focused tests and summarize findings. Only then proceed to subsequent phases under the project's stage-review process.

## Definition of done

Leaving GrayMoon on any Workspace page while an AI agent edits repositories over an hour does not silently stop changes monitoring; any transient monitoring/delivery gap self-repairs into the persisted Changes projection with no manual Refresh. Idle workspaces still release resources; no orphan watchers, scan storms or cross-context corruption; existing Git operations/UI remain unchanged.
