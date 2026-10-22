# Bootstrap AI Prompt — GrayMoon Project Identity Engine

> Copy this prompt into the coding agent with both companion documents accessible in the authorized GrayMoon checkout. Do not execute it in any producer/consumer workspace repository.

## Your role

You are the lead .NET/EF Core engineer and implementation coordinator working on **GrayMoon's project identity and dependency graph engine**. Deliver a production-quality, narrowly scoped architectural correction rather than a `ProjectName` collision workaround.

Your authoritative inputs are:

1. `01-engine-design.md` — architectural decisions, invariants and edge cases.
2. `02-implementation-plan.md` — staged deliverables, acceptance gates and file ownership.
3. The **current** `GrayMoon` source tree, `AGENTS.md`, and the repository's `verify-changes` instructions; current code prevails when a prior observation is stale. Record deviations transparently.

## Desired outcome

Physical `.csproj` rows must be identified by `(WorkspaceFeatureContextId, RepositoryId, normalized repo-relative project path)` rather than by `ProjectName`. Preserve all physical projects even with duplicate names. Resolve each dependent via physical identity and each NuGet producer via unambiguous effective `PackageId`. Preserve generated-package ownership and distinct identity. Safely migrate existing DBs and ensure snapshot reconciliation is atomic, idempotent and partial-failure-safe. Keep existing sync/dependency version rewriting behavior and performance.

## Hard safety rules

- **Only work inside the explicitly authorized GrayMoon development repository.** Do not modify any archived, pinned/tagged, detached, read-only, producer, consumer or unrelated workspace repository. Do not create branches in such repos. If repo identity or current branch is uncertain, inspect read-only and stop writes until resolved.
- Do not commit, push, create a PR, reset, rebase, checkout, clean, discard or force anything unless explicitly requested. Do not invoke GrayMoon's "commit all" action.
- Do not modify UX, UI badges, layouts, Git orchestration, package reference text rewriting, user/product `.csproj` files, or unrelated features.
- Protect user data and `ProjectId`/foreign-key integrity; no `DropAndRecreate` shortcuts, destructive one-off scripts, or blind `First()` selection for ambiguous package identities.
- Respect `AGENTS.md`, verify-changes and existing conventions. Avoid overengineering, unrelated refactoring and unnecessary packages.

## Start in audit mode (mandatory)

Before editing any code:

1. Verify current branch, working tree and repository permissions; identify source HEAD. Read `AGENTS.md`/verify-changes. If an unrelated user change is present, preserve it.
2. Trace the complete Worker discovery → wire mapping → App persistence → dependency graph → levels → package update/push-plan data path. Inspect `CsProjFileService`, `CsProjFileParser`, `ProjectPackagingResolver`, `SyncProjectInfo`, `WorkspaceProject`, `AppDbContext`, `WorkspaceProjectRepository.Merge.cs`, `WorkspaceProjectRepository.GeneratedPackages.cs`, `WorkspaceGitService.Projects.cs`, `WorkspaceGitService.Sync.cs`, `WorkspaceRepositoryStateWriter`, feature context/projection writers and all relevant tests.
3. Search all source/tests for name-based identity, `GroupBy(ProjectName)`, `ProjectName` dictionaries, `IndexPackageTargets`, generated-package rows, empty-scan handling and separate `SaveChanges` boundaries.
4. Audit actual SQLite/EF migration provider features. Determine how to enforce distinct physical and generated identity keys, preserve legacy nullable contexts and existing FK references.
5. Inspect current behavior of producer ambiguity, partial refresh, cross-context generated references, test/service packages, and changed PackageId across repos. Do not guess.
6. Run a minimal baseline test/build per repo guidance and record results.

Create a **living** progress document at `docs/implementation/project-identity-engine.md` containing the design decisions, per-phase checklist, owners, changed files, validation evidence, risks and any revisions required by current code.

## Implementation execution

Follow phases P0–P6 in `02-implementation-plan.md`, with an explicit test gate after each. Assign separate agents only to non-overlapping files/tasks. Coordinate API/schema contracts before parallel edits. Prefer existing projection gate and repository services; do not build a second orchestration framework.

Special attention:

- Use an explicit normalized path key for physical projects; preserve relative display/file path separately.
- Generated package rows currently have empty paths and are special-context-owned. Give them a distinct package identity, not an empty-path physical identity.
- Do not allow two same-named `.csproj` files to overwrite one another or accidentally merge their PackageReferences.
- Package producers with the same effective `PackageId` are ambiguous; never choose arbitrarily. Validate generated-vs-real precedence against existing semantics.
- Package role (`ProjectType`) might not equal packability. Check resolver semantics and handle `IsPackable=false` correctly.
- A successful **empty** scan differs from a failed/missing scan; only authoritative success permits stale physical-row deletion.
- A producer losing `PackageId` can invalidate edges in other repos even when their consumer scan is absent. Formulate and test a safe policy before committing graph state.
- Fix all write paths (manual refresh, normal sync, state writer, generated package dependencies, feature projections), not merely one `MergeProjectsForRepository` call.
- Preserve in-place reclassification, original ProjectIds, unrelated FKs, and unchanged-repo idempotence.
- Ensure project and edge projection commits are atomic or prove an equivalently safe transaction/recovery scheme.

## Required tests

At minimum reproduce shell `Project.csproj` (`IsPackable=false`) + `packages/migrations/migrations.csproj` (`PackageId=Project`) + `packages/dbcontext/dbcontext.csproj` (`PackageId=Persistence.Project`), with a stale consumer reference. Confirm all three producer projects are persisted and the consumer maps to migrations. Add same-name nonpackable projects, duplicate-name consumers, duplicate package IDs, packable→nonpackable reclassification, package rename, moved project, generated package, context isolation, SQLite legacy upgrade, authoritative empty scan, failed/partial scan, cancellation rollback, and unchanged second scan. Run existing `WorkspaceProjectRepositoryPackableSyncTests`, `WorkspaceProjectRepositoryGeneratedPackageTests`, relevant Worker tests and verify-changes.

## Output format during execution

For each phase, update the living tracker with:

- **Changed:** exact files and observable behavior changes.
- **Validated:** tests/commands and their real pass/fail outcome.
- **Compatibility:** migration and feature/generated-package impact.
- **Risks:** unresolved issues, decisions and next gated phase.

On completion, produce a concise engineering report: architecture diff, migration safety and rollback notes, all tests run, performance findings, remaining limitations, and confirmation of **no UX change, no Git worktree/ref manipulation and no commits/pushes**.

Do not stop after making a plan: proceed through implementation and tests if the repository is writable and all safety gates pass. If an unsafe migration or unresolvable graph ambiguity appears, stop only the affected stage, document concrete evidence and a safe alternative; never substitute the packable-first `First()` workaround without explicit approval.
