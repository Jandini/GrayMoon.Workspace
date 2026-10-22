# GrayMoon — Project Identity & Dependency Graph Engine Redesign

**Status:** Proposed design, implementation-ready after code audit  
**Scope:** GrayMoon engine, Worker discovery, App persistence and dependency projections only  
**Baseline reviewed:** `Jandini/GrayMoon`, `main`, indexed commit `8e284e4` (2026-10-22)  
**Companion documents:** [Implementation Plan](02-implementation-plan.md) · [Bootstrap AI Prompt](03-bootstrap-agent-prompt.md)

## 1. Executive decision

Replace `ProjectName` as the identity of a physical .NET project with a **stable, normalized repository-relative project path scoped by workspace feature context and repository**. Keep names as non-unique metadata and `PackageId` as the NuGet producer-matching key. Preserve database `ProjectId` as the primary key and preserve generated-package semantics with a **separate logical identity**. Build dependent edges from physical project identity and referenced package edges from unambiguous package identities. Never resolve dependency edges using project names.

This is an engine correction, **not** a packable-first collision workaround. No user-facing changes, repository edits, `.csproj` rewriting changes, Git operations, or commit/push automation are included.

## 2. Verified baseline and important findings

These facts were inspected in `main`:

| Code | Existing behavior | Consequence |
|---|---|---|
| `src/GrayMoon.App/Data/AppDbContext.cs` | Unique `IX_WorkspaceProjects_Context_Repo_Name` on `(WorkspaceFeatureContextId, RepositoryId, ProjectName)` | Physically distinct projects with identical names cannot coexist. |
| `src/GrayMoon.App/Repositories/WorkspaceProjectRepository.Merge.cs` | `GroupBy(ProjectName.Trim(), OrdinalIgnoreCase).First()` | Drops all but the first collision candidate. |
| Same file, dependency merge | Maps incoming dependent projects by `ProjectName`; targets indexed by `PackageId` | Dependent identity is ambiguous; producer matching by `PackageId` is conceptually correct. |
| `src/GrayMoon.Worker/Services/CsProjFileParser.cs` | Name is local `<PackageId>` then `<AssemblyName>` then filename; `ProjectType` determines whether `PackageId` is surfaced | Duplicate names are legitimate; current classification may hide packaging of Test/Service/Executable types. |
| `src/GrayMoon.Worker/Services/CsProjFileService.cs` | Discovers and parses `.csproj` files concurrently; returns `ProjectPath` relative to repo | Existing discovery already supplies the identity candidate, without requiring new Git or disk work. |
| `src/GrayMoon.App/Repositories/WorkspaceProjectRepository.GeneratedPackages.cs` | Generated rows have `IsGenerated=true`, empty `ProjectFilePath`, and are owned by the special Workspace context | A plain unique path index would collide for all generated rows in a repo. They need a separate key. |
| Same generated-package repository | Already normalizes relative paths for consumer lookups (`trim`, `/`, lower-case) | Reuse/consolidate, do not introduce another incompatible normalizer. |
| `src/GrayMoon.App/Services/Git/WorkspaceGitService.Projects.cs` | Batch and single-repo refresh persist project rows and then dependency edges separately; empty successful scans are not merged (`Count > 0`) | Partial graph update failures are possible; successful empty scans may leave stale physical rows. |
| `src/GrayMoon.App/Services/Workspaces/WorkspaceRepositoryStateWriter.cs` | Writes other snapshot/projection paths | Migration must cover all writers, not only manual refresh. |
| `ProjectDependency` | Unique `(DependentProjectId, ReferencedProjectId)` | Keep existing physical edges/PKs; rebuild only affected graph projections. |

**Repository links:**
- https://github.com/Jandini/GrayMoon/blob/main/src/GrayMoon.App/Repositories/WorkspaceProjectRepository.Merge.cs
- https://github.com/Jandini/GrayMoon/blob/main/src/GrayMoon.App/Data/AppDbContext.cs
- https://github.com/Jandini/GrayMoon/blob/main/src/GrayMoon.Worker/Services/CsProjFileService.cs
- https://github.com/Jandini/GrayMoon/blob/main/src/GrayMoon.Worker/Services/CsProjFileParser.cs
- https://github.com/Jandini/GrayMoon/blob/main/src/GrayMoon.App/Repositories/WorkspaceProjectRepository.GeneratedPackages.cs
- https://github.com/Jandini/GrayMoon/blob/main/src/GrayMoon.App/Services/Git/WorkspaceGitService.Projects.cs

**Validation boundary:** This is a targeted source review, not an executed build or full caller audit. Before implementation, inspect current HEAD and amend this document for any drift.

## 3. Invariants (non-negotiable)

1. A physical `.csproj` in a specific `(WorkspaceFeatureContextId, RepositoryId)` is represented by at most one row per **normalized relative path**. Different physical projects can have identical `ProjectName` and identical `PackageId` values; the second case is an **ambiguity**, not a reason to throw away a row.
2. Existing `ProjectId` values survive where the same physical project can be identified safely. Foreign keys, connector metadata, dependency edges, and generated-package bindings must not silently shift to unrelated projects.
3. No matching by `ProjectName` for either a physical dependent or NuGet producer. Names remain metadata/search labels only.
4. Package references match only a meaningful `PackageId` from a valid package-producing project; no `ProjectName` fallback.
5. An ambiguous producer match never uses `First()` or discovery order. It results in a diagnostic and **no new ambiguous edge**; retain unaffected graph state, while ensuring stale affected edges cannot masquerade as valid.
6. Generated/inferred package rows remain workspace-owned and distinct from physical rows; they are not deleted by a physical repo scan and are not accidentally copied into feature contexts.
7. Snapshot writes are context-isolated, cancellation-aware and atomic at the graph projection boundary. Failure must not record success or erase last-known-good graph state.
8. No changes to checked-out refs, tags, branches, worktrees, product repositories, `PackageReference` version editing, or Git commands.
9. Ordinary non-colliding repos preserve observable behavior and performance; avoid an N+1 DB query or extra per-project file IO.
10. A repeated unchanged scan is idempotent: no duplicate rows, no needless edge churn, no dependency-level oscillation.

## 4. Identity and model

### 4.1 Physical identity

```
PhysicalProjectKey = (
    WorkspaceFeatureContextId,
    RepositoryId,
    NormalizedProjectFilePath
)
```

`NormalizedProjectFilePath` is the stable database lookup/index key, derived from the worker-supplied repository-relative path, not the absolute path. Keep `ProjectFilePath` as the original relative path for display and file operations. Explicitly normalize `.`, repeated separators, relative path segments and separator convention, reject empty/absolute/root-escaping paths for physical projects. Do **not** use `ToLowerInvariant()` as the stored display path. Choose a consistent case policy (the existing app targets Windows; ordinal-ignore-case for key resolution), encoded either via canonical indexed key or configured SQLite collation. Verify the persistence provider before choosing migration SQL. Avoid changing filename casing for file operations.

This path key is intentionally a **physical location identity**. A move/rename may produce a remove + add; do not infer a move by `ProjectName` or `PackageId`. Stable identity across renames would require an explicit future mechanism.

### 4.2 Generated identity

```
GeneratedPackageKey = (
    WorkspaceFeatureContextId = SpecialWorkspaceContextId,
    RepositoryId,
    NormalizedPackageId
)
```

Generated projects have no physical file. Use a **filtered unique index** on physical rows (`IsGenerated = false`) for the path key, plus a filtered unique index on generated rows (`IsGenerated = true`) for normalized package identity. If the SQLite/EF version or migration conventions make filtered indexes unworkable, use an explicit `ProjectIdentityKind` + `ProjectIdentityKey` column and a unique composite index `(WorkspaceFeatureContextId, RepositoryId, ProjectIdentityKind, ProjectIdentityKey)`. Prefer the smallest reliable design after inspecting provider constraints. Never use empty project paths to distinguish generated rows. Null `WorkspaceFeatureContextId` legacy data must be normalized/backfilled or explicitly gated before uniqueness is enforced.

**Caution:** In existing code, generated identities are workspace-global, whereas physical feature projects are context-specific; some graph operations also query generated rows by `WorkspaceId`. Preserve those intentional cross-context links and verify feature projection behavior rather than forcing all generated rows into each feature.

### 4.3 Project vs package producer

Treat `ProjectType` as a **project role**, not the authoritative packaging capability. `ProjectPackagingResolver` already determines `IsPackable` and effective package properties. During implementation, check its semantics against the parser and existing tests. Prefer a separate packaging result (`ProducesPackage` / effective `PackageId`) **only if needed to accurately model an executable/service/test that emits a package**. Do not add redundant persisted fields without demonstrable need. An explicit `IsPackable=false` must defeat an incidental `<PackageId>`. Package IDs used in the graph must be effective and valid, not simply text pulled from the XML.

### 4.4 Graph structure

`ProjectDependency.DependentProjectId` and `ReferencedProjectId` remain foreign keys to `WorkspaceProject.ProjectId`.

1. Build a per-snapshot `PhysicalProjectKey -> ProjectId` index.
2. Build a normalized `PackageId -> candidate physical producer ProjectIds` index, under the existing workspace/context/feature semantics; include generated-package resolution through existing dedicated rules.
3. Resolve each incoming consumer by its physical path. Missing consumer path = diagnostic / skip; **never** map to another same-named project.
4. Resolve package reference to exactly one eligible producer. Zero = external/unmatched (existing semantics); >1 = ambiguous (diagnostic, no arbitrary edge).
5. Distinguish packages within a repository from packages in other repositories where applicable; do not silently resolve two producers that publish the same ID to one winner.
6. Deduplicate edges by `(dependent ProjectId, referenced ProjectId)` after deterministic conflict analysis. If versions disagree for an otherwise identical edge, use an explicit checked rule and log the conflict, never `First()` blindly.
7. Recompute repository-level dependencies/levels from the committed graph, after the graph projection is successfully persisted.

### 4.5 Required ambiguity policy

A collision in `ProjectName` is **not** a problem after this change: warn only if the diagnostic is useful. A collision in effective package producer identity **is** a data integrity issue. For ambiguous producer keys, log structured repository IDs, context, candidate relative paths, package ID, reason, and affected consumer count. Do not call the overall operation successful while representing a guessed edge as authoritative. Preserve the current external failure/warning surface; no UX scope expansion. Distinguish unresolved external packages from ambiguous workspace producers in logs.

Decide and document whether ambiguous producer references invalidate the repository-level `IsInSync` computation, based on the current badge and state model. Do not silently mark a graph complete if resolution is known ambiguous. Avoid changing UI, but improve engine correctness and log diagnostic status.

## 5. Persistence and migration

### 5.1 Schema proposal

- Add `NormalizedProjectFilePath` (or unified `ProjectIdentityKey`) to persisted `WorkspaceProjects`; ensure its derivation is deterministic and validated.
- Replace unique `IX_WorkspaceProjects_Context_Repo_Name` with a physical-project unique key and a generated-package unique key (or kind-qualified key).
- Retain useful **nonunique** name indexes for queries/search.
- Keep `ProjectId` primary key; keep `ProjectDependency` FK constraints and unique `(DependentProjectId, ReferencedProjectId)`.
- Add lookup indexes based on query plans, not speculative indexes; `PackageId` lookup may benefit from a nonunique normalized key/index.

### 5.2 Existing data reconciliation

The initial database may already contain the *wrong* physical winner selected by name. The migration must not assume that `ProjectName` identifies its file:

1. Enumerate persisted project rows with context, repo, path, generation flag, package ID and `ProjectId`.
2. Backfill and validate normalized physical paths; quarantine/report invalid/missing physical paths without destructive repair.
3. Keep each persisted physical row's ID attached to its current path when unambiguous. **Do not repurpose a shell row into migrations based solely on package ID.**
4. If an already-hotfixed row points to migrations, keep it bound to migrations. Subsequent scans add a separate shell row.
5. Deduplicate exact same-kind identity only after inspecting incoming/outgoing edges, metadata and dependent consumers; never remove FKs silently. Prefer migration blocking with actionable logs when conflicting IDs cannot be safely reconciled.
6. Generated rows: backfill separate package key, enforce ownership in special Workspace context, preserve deduplication semantics and graph.
7. Backfill legacy nullable context IDs using existing feature-context migration conventions before enforcing new uniqueness.
8. Next valid full scan inserts physical projects previously lost to collisions, refreshes references and recomputes levels. Maintain clear upgrade-and-rescan marker if mandatory.
9. Confirm upgrade/downgrade policy for SQLite, including existing indexes and unique-index creation on real user DB fixtures; provide backup/rollback guidance. No destructive `EnsureCreated`/rebuild shortcuts.

### 5.3 Atomic projection boundary

The current `WorkspaceGitService.Projects.cs` calls batch project merge, `SaveChanges`, then dependency merge; other writer paths exist. Introduce a **single bounded reconciliation entry point** accepting a validated per-repository snapshot, so project rows, graph edges, and dependency-level/repository state changes are committed consistently. Preserve the existing projection gate and avoid nested incompatible transactions. Snapshot parsing/worker calls remain **outside** the DB transaction; DB mutations are batched within it.

Use these snapshot outcomes:

| Worker scan outcome | Engine action |
|---|---|
| Successful nonempty | Reconcile physical rows and the affected graph. |
| Successful empty | Remove stale physical rows and their edges for that repo **only when success is authoritative**; preserve generated rows. |
| Failed / disconnected / invalid response | Do **not** interpret as empty. Preserve prior physical rows and edges; record failure. |
| Cancelled | Roll back in-flight projection; no success marker. |
| Partial multi-repo results | Reconcile only successful repo snapshots; ensure graph recomputation uses the complete stored graph, not a partial list as global truth. |

Investigate all current writers and readers of project graph state, including `WorkspaceRepositoryStateWriter`, `WorkspaceGitService.Sync.cs`, `WorkspaceGitService.Projects.cs`, generated packages, feature seed/finalization, project search/filter queries, version updates and push-plan dependency leveling. Reuse existing repository/projection infrastructure rather than adding an independent synchronization engine.

### 5.4 Edge replacement across partial snapshots

For each successful repository snapshot, only replace edges whose **dependent** is one of its physical projects, plus delete edges referencing physical producer rows actually removed. An upstream producer change can affect consumers in repos not in the current scan: ensure their resolution is re-evaluated from persisted source reference facts or schedule a safe targeted rescan; do not silently retain now-invalid edges. If reference facts are not persisted, explicitly choose a consistent policy (e.g., mark unresolved/needs rescan) rather than claiming that partial refresh is globally complete. This is a mandatory design decision before implementation.

## 6. Performance budget

- Worker uses the existing parallel `FindAsync`, no new `dotnet` evaluation or `git` processes.
- Normalize project paths O(N) once per scan; build O(N) dictionaries for project keys/package IDs.
- Batch SQL reads/writes per workspace/context, not per `.csproj`; preserve the projection lock and avoid contention with Worker discovery.
- Only update changed entity fields and edge deltas. No delete/recreate-all graph on repeated scans.
- Preserve existing max parallel worker/discovery behavior and cancellation.
- Add log metrics: scanned projects, duplicate names, duplicate package IDs, newly discovered rows, changed rows, removed rows, graph edges created/removed, ambiguity count, resolution/reconciliation duration.
- Establish baseline on real multi-repo/VDI cases (including ~39 repos) and require no meaningful regression in typical non-colliding sync.

## 7. Failure-mode matrix

| Scenario | Expected behavior |
|---|---|
| Shell `Project.csproj` and migrations package share name `Project` | Two persisted physical rows, correct consumer dependency to migrations package. |
| Two libraries share `ProjectName` | Both persisted; their PackageReferences mapped independently by path. |
| Two package projects share `PackageId` | Both persisted; ambiguous consumers never arbitrarily connect; structured warning. |
| Existing package turns `IsPackable=false` | Same project/path/ID, package producer eligibility removed, affected edges cleared/re-resolved and levels updated. |
| Same path, updated `AssemblyName` or `PackageId` | Same `ProjectId`; metadata updated; graph re-resolved. |
| Renamed/moved `.csproj` | Remove old physical row, add new; no guessing by name. |
| Successful empty repo | Physical rows deleted, generated rows untouched, affected graph updated. |
| Failed scan | No project/edge deletion. |
| Duplicate filename with different directories/case | Paths disambiguate; normalization policy handles case consistently. |
| Same package generated + real producer | Explicit precedence/ambiguity rule validated against existing inferred-package behavior; no duplicate arbitrary targets. |
| Workspace vs Feature contexts | Physical projects isolated; special generated-package ownership retained. |
| Snapshot cancellation mid-commit | Atomic rollback, no fake green success. |

## 8. Out of scope

No UX/badge/layout changes; no modifications to consumer or producer `.csproj` files; no generalized MSBuild evaluation redesign; no changes to Git clone/push/merge/branch/worktree behavior; no new storage engine; no speculative project GUID identity; no provider-wide package resolution redesign unless directly necessary to remove ambiguity.

## 9. Acceptance definition

The design is complete only when: both shell and migrations are persisted; a real consumer resolves the correct package and stale versions become eligible for current update logic; duplicate named consumers have distinct edges; duplicate producer IDs never yield a guessed edge; clean second scan is idempotent; successful empty/failed scans are distinguished; special generated-package semantics survive; existing DB upgrades without unsafe FK remapping; all sync entry points use the same identity rules; integration tests and existing regressions pass.
