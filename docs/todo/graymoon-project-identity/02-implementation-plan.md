# GrayMoon — Project Identity Engine Implementation Plan

**Status:** Ready for agent-led implementation after mandatory audit  
**Source baseline:** `Jandini/GrayMoon` `main` (reviewed indexed commit `8e284e4`)  
**Design authority:** [01-engine-design.md](01-engine-design.md)  
**Agent entry:** [03-bootstrap-agent-prompt.md](03-bootstrap-agent-prompt.md)

## 1. Outcome and constraints

Replace name-keyed physical project reconciliation with path-keyed reconciliation, store all projects, resolve graph consumers by path and producers by unambiguous effective package ID, retain generated-package invariants, and establish transactional/partial-scan-safe engine projections. No UX or Git workflow changes. No commits or pushes without explicit request. Respect `AGENTS.md` and repository `verify-changes` instructions. Any repository that is archived, tagged/pinned, or detached is read-only; never create branches or alter it. All work only in the authorized `GrayMoon` development checkout/branch.

### Delivery standards

- Small, independently testable changes; avoid speculative abstractions.
- Maintain a **living** implementation tracker in repo (e.g., `docs/implementation/project-identity-engine.md`) with decision log, file ownership, stage status, evidence, command/results and risks.
- Update existing architecture documentation when changed behavior is landed.
- Every phase has a pass/fail gate. Do not start dependent changes before the gate passes.
- Preserve compatibility of current worker wire structures where possible; if extending shapes, update serializers/protocol versions and all call sites together.
- Keep feature-context scoping explicit in every query.

## 2. Phase 0 — Mandatory discovery and threat model

**Owner:** Lead/architecture agent (read-only).  
**Deliverables:** concise code map, actual schema/provider details, decisions and executable baseline tests.

### Audit targets

1. Physical project producers: `CsProjFileParser`, `ProjectPackagingResolver`, `CsProjFileService`, wire models (`CsProjFileInfo`, `SyncProjectInfo`), `GetProjectsDetail` mapping.
2. All writers: `WorkspaceProjectRepository.Merge.cs`, `WorkspaceProjectRepository.GeneratedPackages.cs`, `WorkspaceGitService.Projects.cs`, `WorkspaceGitService.Sync.cs`, `WorkspaceRepositoryStateWriter.cs`, Feature seed/finalization and snapshot/recompute services.
3. All readers: dependency queries, levels, push/update package maps, project grids/queries (do **not** modify UI), package matching, version update persistence, restore and export.
4. EF Core indexes/migrations: `AppDbContext`, migrations structure including feature backfill, SQLite collation/filter/index support, potential live legacy null contexts.
5. Semantic behavior on a scan that returns zero files, worker failure, worker disconnect, tag-pinned repo, repository not selected, partial workspace refresh, and mixed generated/physical package identity.
6. Duplicate producer resolution scope: package IDs across workspace/feature, generated physical precedence, connector/registry effects and behavior of existing `IndexPackageTargets`.
7. Transaction/projection gate: inspect current coordinator and DbContext lifetime before proposing a transaction wrapper.
8. Existing test harness and fixture migrations, including `WorkspaceProjectRepositoryPackableSyncTests`, `WorkspaceProjectRepositoryGeneratedPackageTests`, Worker parser/packaging tests.

### Required decisions before coding

| Decision | Proposal | Confirm against code |
|---|---|---|
| Physical key | Context + repo + canonical relative path | Provider collation, path input guarantees |
| Generated key | Special context + repo + normalized package ID, filtered index | Existing generated write/dedup logic |
| Empty scan | Authoritative success removes physical rows | Existing UI/worker response semantics |
| Package ambiguity | No arbitrary producer selected | Current downstream error/sync semantics |
| Partial refresh and upstream producer changes | Invalidate/rebuild affected external consumers or mark refresh needed | Available persisted reference facts |
| Transaction boundary | Merge projects + edges + level stats + success marker | Current coordinator, EF patterns |
| Project role vs packability | Separate only when parser evidence requires | Packaging tests and existing role assumptions |

**Gate P0:** Code map and decisions documented; baseline targeted tests have run; scope changes explicitly recorded.

## 3. Phase 1 — Identity primitive and model/schema

**Owner:** Persistence agent. **Dependencies:** P0.

### Tasks

- Introduce exactly one reusable `NormalizeRepositoryRelativeProjectPath` helper in the correct shared layer; use it consistently at Worker/App boundary and persisted-key comparisons. Reject empty, rooted, escaping, invalid physical paths; ensure Windows path-casing behavior matches existing expectations.
- Introduce persisted canonical identity column(s), selecting either filtered physical/generated keys or `IdentityKind` + `IdentityKey` as specified in design. Keep original `ProjectFilePath` unchanged for IO/UI.
- Retain `ProjectId` PK and existing foreign keys. Replace unique name index. Keep/adjust nonunique indexes with measured query demand.
- Write an EF migration that backfills physical and generated identities, accounts for legacy null context, validates duplicate keys, and preserves IDs/edges. No silent `First()` dedup of conflicting legacy rows.
- Add migration diagnostics for unsafe rows, and a documented rollback/backup approach. Prefer fail-safe migration failure to corrupting data.
- Validate provider-specific partial indices/collation and upgrade from a copy of an existing DB fixture.

### Tests

- Canonical path: mixed separators, `.` and `..`, repo escape, absolute paths, case variants, whitespace, same filename under different directories.
- Unique constraint: duplicate names with distinct physical paths succeed; duplicate canonical path in same context/repo fails; same path in different contexts/repos succeeds.
- Generated rows with empty file path and distinct package IDs succeed; duplicate generated identity fails; generated rows never steal physical keys.
- Legacy upgrade keeps project IDs and dependency FKs; already-hotfixed migrations row remains tied to migrations path.

**Gate P1:** Schema and upgrade tests pass against a real SQLite-backed test database; no known destructive migration behavior.

## 4. Phase 2 — Physical project merge reconciliation

**Owner:** App project-repository agent. **Dependencies:** P1.

### Tasks

- Remove `.GroupBy(ProjectName).First()` for physical projects in `MergeProjectsForRepository`.
- Use normalized path to match persisted vs incoming physical projects and update in place; allow repeated display names.
- Validate/diagnose duplicate paths in one Worker response. Exact duplicates should not produce silently divergent metadata; dedup identical entries if safe, reject/log conflicting ones.
- For successful snapshot, remove physical rows no longer present (including zero-project scan); never touch `IsGenerated` rows or different feature contexts.
- Handle `ProjectName`, `ProjectType`, `PackageId`, `TargetFramework`, path case changes as metadata updates; no spurious new `ProjectId` when same canonical path.
- Batch load/reconcile, respect projection gate; do not introduce per-project DB work.

### Tests

- Root shell plus migrations package same name both persisted after a scan.
- Duplicate nonpackable project names coexist.
- Same path reclassified `Package -> Library` preserves `ProjectId` and clears package identity.
- Name/PackageId changes at same path preserve `ProjectId`.
- Successful empty repo removes only physical projects in that repo/context; failed scan preserves rows; feature isolation.
- Idempotence across two identical scans.

**Gate P2:** All merge regression tests pass including existing packable sync tests; no unrelated row updates.

## 5. Phase 3 — Dependency graph identity and ambiguity

**Owner:** Graph agent. **Dependencies:** P2.

### Tasks

- Replace dependent `ProjectName -> ProjectId` lookup with `(context, repo, normalized project path) -> ProjectId` in `MergeWorkspaceProjectDependenciesAsync` and all other edge-building call sites.
- Audit `UpdateProjectDependencyVersionsAsync` (already path-based in one direction) and generated consumer lookups; migrate to the shared normalizer.
- Build package target candidate groups by effective `PackageId`, using the proper applicable context and generated-package resolution rules; do not use `TryAdd`/`First` to mask collisions.
- Explicitly handle no target (external), unique target, and multiple target (ambiguous); log structured candidate identities, count, and affected refs. No arbitrary ambiguous edge. Preserve intended precedence of generated/physical producer **only if confirmed by existing architecture**.
- Ensure each consumer's references come from its own scan record even when consumers have identical names.
- Incrementally maintain graph edges and dependency levels. Verify cross-repository consumer invalidation when producer eligibility changes in a partial snapshot.
- Confirm downstream push dependency levels/plan, missing package detection, matched/unmatched counters, package version persistence and generated-package graph remain correct.

### Tests

- Reported `Project` collision: consumer gets edge to migrations package; `Persistence.Project` remains independent.
- Two same-named consumers in separate physical paths resolve different package refs correctly.
- Two producers of same `PackageId` yield no guessed new edge and a diagnostic.
- Package becomes nonpackable; affected edges removed, levels recomputed.
- Package ID changes; stale old-ID edges invalidated, new-ID edges resolved appropriately.
- Producer repo refreshed alone, consumer repo not refreshed: expected invalidation/rescan contract enforced.
- Generated package references, feature-context graphs, package-version update paths and existing generated tests.

**Gate P3:** No graph edge creation by project name remains; ambiguous producers are observable and never silently chosen.

## 6. Phase 4 — Transactional reconciliation + all entry points

**Owner:** Orchestration agent. **Dependencies:** P3.

### Tasks

- Introduce/reuse a narrow `ReconcileProjectSnapshotAsync` operation accepting validated, explicit `Success`/`EmptySuccess`/`Failure` scan outcomes with repo/context ID; retain current public facades where practical.
- Keep Worker discovery outside transactions, batch/merge successful snapshots inside an appropriate EF transaction/projection gate. Commit project metadata, affected graph, dependency levels, and success state together wherever feasible.
- Ensure failure/cancellation does not remove projects or edges, compute fake zero projects, or mark the repo synced.
- Support mixed successful/failed repos in batch and avoid a global graph rewrite based only on partial successful scans.
- Route current entry points via shared reconciliation: manual refresh (batch/single), ordinary sync, `WorkspaceRepositoryStateWriter` snapshots, feature projections, and generated-package integration as appropriate.
- Preserve tag-pinned/archived repository read-only protections, sync concurrency bounds, and no process changes.
- Beware of savepoint/deadlock behavior with existing `AcquireProjectionGateAsync` and DbContext lifetime; no nested incompatible transaction.

### Tests

- Transaction fault injection after project merge but before edge commit: entire affected projection rolled back.
- Worker disconnect, parse failure, cancellation and invalid response preserve old state.
- Mixed success/failure batch touches only successful repos while maintaining coherent full-graph levels.
- Successful empty authoritative scan clears real projects without deleting generated package rows.
- Single refresh, batch refresh and background sync produce identical final graph for same inputs.
- Feature finalization and workspace state writer continue to pass existing tests.

**Gate P4:** Failure atomicity and all critical entry points verified; no success status on partial failure.

## 7. Phase 5 — Engine instrumentation and performance

**Owner:** Worker/diagnostics agent. **Dependencies:** P2–P4.

- Keep Worker discovery parallel. No new disk traversal for collision analysis; group already parsed in-memory results.
- Structured Warning for duplicate project **names** as diagnostic (not necessarily an error); Warning/Error-class diagnostic for ambiguous effective package producer ID. Include repository, context as available, paths, type, package IDs, category, count, resolution status; avoid dumping huge lists unbounded (bounded samples + count if large).
- Log project merge and graph deltas and elapsed duration. Avoid PII/credentials and absolute user paths where unnecessary.
- Add performance regression coverage for several thousand `.csproj` records, high-repo-count (e.g., 39) workspace, partial scan, and repeated unchanged scans; compare with baseline.
- No UX changes, no new logging warnings on every clean unchanged scan beyond collision diagnostics.

**Gate P5:** Diagnostics tested via logger fake/collector; performance non-regression documented.

## 8. Phase 6 — Integration, migration hardening, docs

**Owner:** Lead/test agent. **Dependencies:** P1–P5.

### Full scenarios

1. **Bug reproduction:** shell (`IsPackable=false`) + migrations (`PackageId=Project`) + dbcontext (`PackageId=Persistence.Project`) in same producer repo; consumer references `Project` at stale version. After refresh all physical rows persisted and expected dependency edge exists; current dependency-sync logic updates stale version, with no `.csproj` edits outside explicitly invoked sync.
2. Same structure in `Central` twin repo and central package management (`Directory.Packages.props`).
3. Duplicate names among consumer projects with distinct references and paths.
4. Multiple genuine package producers sharing exact ID (same or different repos): ambiguity surfaced and never guessed.
5. Package reclassification and producer `PackageId` rename; consumers re-evaluated.
6. Project rename/move; generated-package collision case; context isolation; restarts and persistence reload.
7. Legacy DB upgrade from both shell-won and package-won states; project IDs/FKs preserved.
8. Empty/failure partial-snapshot equivalence; transaction rollback; multi-repo performance and idempotence.

### Repository checks

- Follow `AGENTS.md` and `verify-changes`; run targeted tests continuously and whole relevant solution tests at final gate.
- Apply formatting/analyzers per repo conventions.
- Validate schema against SQLite and inspect final EF migration SQL.
- Search for remaining name-based identity assumptions in all source and tests; list intentional name-based queries (display/search) separately.
- Update `docs/architecture/03-data-model-and-persistence.md`, runtime orchestration docs and developer guide only where semantics changed.
- Produce a final change report: before/after invariants, migration instructions, test commands/results, performance numbers, unresolved risk and rollback.
- **Do not commit or push.**

**Release gate P6:** All mandatory integration scenarios and existing related tests green; verified migration, clear known limitations, no extraneous code/UX/Git changes.

## 9. Work allocation (parallel agents)

| Role | Ownership | Parallel timing | Restricted writes |
|---|---|---|---|
| Architecture lead | Audit, design decisions, integration map, living tracker | Starts P0; owns final review | Avoid code churn; final coordination |
| Persistence | `WorkspaceProject`, DbContext/migration, key helper | P1 | Own schema migration exclusively |
| Merge | App physical project reconciliation + tests | Begins after key API stable | No migration edits |
| Graph | Dependency indexes, generated-package integration, graph tests | Begins after merge contract stable | No migration edits |
| Orchestration | Batch/single/snapshot entry points, transactions | After graph APIs stable | No graph semantics changes without coordination |
| Worker/test | Parser packaging audit, diagnostic logs, Worker tests | Can start read-only at P0; code P5 | No schema writes |

**Integration rule:** One agent owns each file. Parallel agents may research/read the same files but must not concurrently edit shared infrastructure. Dependency order is P0 → P1 → P2 → P3 → P4 → P5/P6; independent tests/docs may overlap. All branch/worktree operations must comply with pinned-repository safeguards.

## 10. Stop conditions / mandatory escalation

Stop affected implementation and document the blocker if: migration cannot preserve project/FK identity safely; selected SQLite provider cannot enforce chosen indexes; a proposed package producer policy would change Git/push behavior; existing generated graph makes context ownership ambiguous; a partial scan cannot maintain graph consistency with available persisted facts; or the only solution requires destructive repository edits. Do not paper over any of these with a package-first `First()` fallback. Propose a narrowly bounded alternative and regression tests before proceeding.

## 11. Definition of done (checkbox tracker)

- [ ] P0 audit and decisions approved by evidence
- [ ] P1 identity/index/migration safe and tested
- [ ] P2 all physical projects retained; in-place updates by path
- [ ] P3 dependent and producer matching correct; ambiguities explicit
- [ ] P4 transactional, partial-scan-safe reconciliation across entry points
- [ ] P5 diagnostics and non-regression benchmark
- [ ] P6 full integration tests, docs, final verification report
- [ ] No UX or Git workflow changes
- [ ] No commits/pushes performed
