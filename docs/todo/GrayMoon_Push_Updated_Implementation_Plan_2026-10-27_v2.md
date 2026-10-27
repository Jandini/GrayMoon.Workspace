# GrayMoon — Unified Push Updated: Detailed Implementation Plan

**Implementation specification, risk controls, change sequence, and acceptance gates**  
**Date:** 2026-10-27  
**Repository:** [`Jandini/GrayMoon`](https://github.com/Jandini/GrayMoon)  
**Reviewed revision:** [`main` at `eb320738a999486bfec9aeaab4d31a87c6f4f93e`](https://github.com/Jandini/GrayMoon/commit/eb320738a999486bfec9aeaab4d31a87c6f4f93e) (2026-10-25 commit)  
**Status:** Proposal only. No source code changed, no build/tests executed, no reproduction logs from the current incident.

## Executive decision

**One supported application-level *mutation entry point* must own the entire combined Update & Push operation.** All UI entry points—Workspace Repositories, notifications popup (primary and level-only), and future clients—must invoke it with an explicit request and receive a structured outcome. The existing `UpdateAndPushOrchestrator` and `WorkspacePushService.RunPushLaneAsync` remain the two-lane implementation: **do not rewrite their scheduling, dependency-level ordering, channel mechanics, package wait, or worker integration.**

Use a *thin coordinator/facade*, not a second orchestrator implementation. `Update Only` and `Push Only` remain independently supported actions; “one way” means one supported way to initiate a **combined** Update & Push workflow, not abolishing legitimate standalone operations. Read-only preflight/preview is allowed, but must not start mutations.

**Recommended staged design:** introduce `IWorkspaceUpdateAndPushOperations.ExecuteAsync(UpdateAndPushRequest, progress/error callbacks, CancellationToken)` (name illustrative; reuse an existing application boundary if cleaner). It owns pipeline attempt, `NotPipelined` fallback, update-success gate, push plan, push outcome, explicit fallback approval, context/option propagation, and a final cohesive outcome. UI components own only confirmation, input and presentation. The existing internal pipeline service may remain callable by Prepare Workspace *temporarily*; migrate/audit these callers only after parity tests, then make the combined-operation public boundary singular.

## Confirmed execution-path difference

| Aspect | Repositories page | Notification popup |
|---|---|---|
| Combined entry | `WorkspaceRepositories.Update.cs` → `TryRunPipelinedUpdateAndPushAsync` | `WorkspaceActionNotificationPanel.razor` → `StartUpdateAndPushJobAsync` |
| Main engine | `IWorkspaceUpdateOperations.UpdateAndPushAsync` → `UpdateAndPushOrchestrator.RunAsync` | `IWorkspaceUpdateOperations.UpdateAsync` followed by independent `IWorkspacePushOperations.PushAsync` |
| Parallel lanes | Yes: completed update level handed to push lane over channel | No: finish all update work, then plan/push |
| Update scope | Live all-level walk: `repoIdsToUpdate: null` | Up-front ID set from shared link snapshot |
| Update failure result | Checked in sequential fallback (`if (!updateResult.Success) return;`) | Ignored in notification flows |
| Push mode | Pipelined when safe; synchronized sequential fallback; explicit normal-push confirmation on failure | Ad hoc synchronized-vs-parallel decision from dependency notification helper |
| Restore | Repositories modal explicit opt-in; unchecked initially | Omitted `restorePackages` parameter in `PushAsync` defaults to `true` |
| Error UI | Receives repo/level errors and pipeline result | No-op update callbacks, generic push result toast |
| Job lock/key | Current repositories URL/Feature context page key | `/workspaces/{id}` (structural/workspace-wide) |

Primary source: [Repositories combined path, lines 364–555](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Pages/WorkspaceRepositories.Update.cs#L364-L555); [Popup combined path, lines 648–815](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L648-L815).

## Findings, severity, and minimum safe correction

> “Confirmed” means verified code-path difference/bug; “risk” means a plausible outcome not proven for the user's specific stopped run. Do not present static analysis as a reproduced runtime failure.

### F01 — Two competing combined-workflow implementations (HIGH, confirmed)

The popup bypasses `UpdateAndPushOrchestrator` completely. Therefore equal-looking commands do not have equal scheduling and failure behavior. **Correction:** one application-level combined command, called by both UI surfaces. Reuse the existing orchestrator as the engine. Do not copy its lane logic into the popup or build an additional scheduler.

### F02 — Update failure still proceeds to push (CRITICAL, confirmed)

`StartUpdateAndPushJobAsync` and `StartLevelOnlyUpdateAndPushJobAsync` `await updateOps.UpdateAsync(...)` but discard `DependencyUpdateRunResult`. An orchestrator can return `Success=false` without throwing. The code then proceeds to `ExecutePushAsync`. The result model states chained pushes must stop when update fails. **Correction:** mandatory `Success` gate inside the **shared command**, not only the UI. Test update failure by returned result as well as thrown exception; assert *zero* push operations.

Sources: [popup lines 690–729](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L690-L729), [popup level-only lines 774–814](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L774-L814), [result contract](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.Application/OperationModels.cs#L84-L110).

### F03 — Up-front repository filtering misses evolving dependency needs (HIGH, confirmed mechanism)

The popup uses `preloadWs.Repositories` and `UnmatchedDeps/OutOfDateFileRepos` to decide a fixed `repoIdsToUpdate` set before commits happen. In contrast, `DependencyUpdateOrchestrator` intentionally re-reads versions and detects newly outdated files per level, and the Repositories combined path explicitly passes `repoIdsToUpdate: null`. A lower-level producer version bump can make a higher-level consumer require update **during this run**. The popup's scope excludes such a consumer from csproj sync. **Correction:** use the same live level-walk/full scope as Repositories for full and level-only combined operations. Preserve max-level *limit*, not a precomputed repo filter. Do not change the underlying per-level refresh algorithm.

Sources: [popup lines 680–702](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L680-L702); [orchestrator lines 122–175](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Orchestration/DependencyUpdateOrchestrator.cs#L122-L175); [page reasoning lines 377–395](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Pages/WorkspaceRepositories.Update.cs#L377-L395).

### F04 — Shared-link versus Feature-context data (HIGH, correctness risk)

The notification service builds its displayed state from context-scoped link snapshots, yet the popup's prefilter uses `WorkspaceRepositoryLink` counters from `GetByIdAsync`. Feature-specific counters need not equal shared Workspace counters. **Correction:** no prefiltered ID set for combined execution; capture one explicit `WorkspaceFeatureContextId` and pass it through every application call. Apply context-aware preview for any branch or policy warnings.

Sources: [notification refresh lines 51–81](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Ui/WorkspacePendingActionsService.cs#L51-L81); [popup lines 680–702](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L680-L702).

### F05 — Different selection of synchronized vs parallel push (HIGH, confirmed)

Popup `ExecutePushAsync` sets `synchronizedPush` using `ShouldShowSynchronizedPushModal(depInfo, repoIdsThatNeedPush)`, whereas Repositories combined path prefers two-lane or synchronized execution and only presents an explicit *normal push* fallback after a feasibility failure. `DotNetDependencyPushStrategy` runs its non-synchronized path in parallel. This is a **behavioral divergence**; not every parallel push is inherently unsafe, but combined dependency-update operations should not silently choose different semantics by origin. **Correction:** centralize the decision; preserve `CanRunPushLaneAsync` safety and registry-based package waits; no automatic parallel fallback without the user's explicit approval.

Sources: [popup lines 901–947](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L901-L947), [push strategy](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Orchestration/DotNetDependencyPushStrategy.cs), [orchestrator lines 20–45](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Orchestration/UpdateAndPushOrchestrator.cs#L20-L45).

### F06 — Missing failure propagation and stopped-level detail (HIGH, confirmed)

The popup supplies no-op update error callbacks, and `pushResult.ShowRepoErrors(...)` can collapse a failed level into a generic `OperationResult.Error`. `PushOperationResult.Describe` already produces a useful failed-level summary; the result includes `LevelErrors` and `RepoErrors`. **Correction:** the unified command collects structured errors independent of UI lifetime and returns a meaningful result; both UI entry points present it consistently. Preserve per-level package ID/version diagnostic detail; do not replace actionable diagnostics with `Found X of Y`.

Sources: [popup lines 693–702, 938–947](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L693-L947), [description helper](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Orchestration/PushOperationResult.cs).

### F07 — Combined outcome overwritten by successive operations (HIGH, confirmed design gap)

`WorkspaceUpdateOperations.UpdateAsync` begins an `Update` outcome; `WorkspacePushOperations.PushAsync` begins a `Push` outcome for the same Workspace/context. In popup's sequential flow, the latter replaces the earlier record even if the update had already failed. The new shared command must own one coherent combined outcome for its full lifecycle. **Correction:** minimally add aggregate/final outcome handling, or scoped recording by shared run ID, without changing standalone Update or Push behavior. Record failed level and repo errors even when the component is disposed; a *success* must not erase a prior error from the same run incorrectly.

Sources: [update facade lines 20–73](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Application/WorkspaceUpdateOperations.cs#L20-L73); [push facade lines 61–89](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Application/WorkspacePushOperations.cs#L61-L89); [outcome store](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Orchestration/WorkspaceOperationOutcomeStore.cs).

### F08 — Feature context resolved separately for update and push (MEDIUM–HIGH, risk)

The popup independently calls `ResolveOperationContextAsync` in update and push phases. User selection can change during a long wait. Both operations should be bound to the context selected when the user explicitly starts the action; never re-resolve in later phases. **Correction:** capture and validate `ContextId` once; include it in the request, job key, diagnostics and result. Revalidate for stale/deleted/NeedsRepair contexts as appropriate; never silently fall back to Workspace if a selected Feature disappears.

### F09 — Job-key/locking and overlay parity (MEDIUM–HIGH, confirmed divergence)

Popup jobs always use `/workspaces/{id}` and therefore take a structural lock; repositories pages can run at `/workspaces/{id}/ctx/{contextId}`, using hierarchical context locks. `BackgroundJobOverlay` attaches by exact current URL. The popup may therefore over-serialize unrelated Feature contexts, and progress may be invisible while the user remains elsewhere. **Correction:** reuse the existing `IBackgroundJobService`, `WorkspaceOperationRunner`, and `WorkspaceJobKeys` infrastructure. Start with a stable context-aware key appropriate for the originating surface **without changing lock semantics blindly**; test operation attachment, deduplication, navigation, cancellation and other-context concurrency. Ensure the entry-point job key cannot be used to run concurrent mutations on the *same* context.

Sources: [background job service](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Jobs/BackgroundJobService.cs#L107-L155), [job keys](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Jobs/WorkspaceJobKeys.cs), [overlay](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Layout/BackgroundJobOverlay.razor).

### F10 — Commit / restore option mismatch (MEDIUM, confirmed)

Repositories `UpdateDependenciesModal` supports commit subject, dependency details in message, and a **restore packages** checkbox defaulting to *off*. Popup passes `commitMessage: null`, `includeDepsInCommitMessage: true` and omits `restorePackages`, so `IWorkspacePushOperations.PushAsync` defaults to *true*. **Correction:** represent options explicitly in the canonical request. Do not silently change what the popup historically did: document/migrate its defaults consciously; avoid imposing the page's default on popup users without product sign-off. Preserve package wait regardless of local restore selection.

Source: [modal lines 68–108](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Modals/UpdateDependenciesModal.razor#L68-L108).

### F11 — Default branch warning is based on incomplete/stale popup data (MEDIUM–HIGH, risk)

Popup warning filters only `notification.Repos` where `UnmatchedDeps > 0`; the notification deliberately limits displayed entries to 100 and may also show version-file-only work. Thus it may omit a target on the default branch; a lower-level version bump can introduce later work not in the original badge list. **Correction:** preflight from a fresh context-aware operation plan over all candidate repositories, not the notification display model; validate again at the mutation boundary. Preserve existing warning/confirmation behavior, and explicitly guard tag-pinned, detached/archived and NeedsRepair contexts. Do not make tags mutable or create commits on them.

Sources: [notification 100-row cap](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Services/Ui/WorkspacePendingActionsService.cs#L25-L30), [popup warning lines 648–666](https://github.com/Jandini/GrayMoon/blob/eb320738a999486bfec9aeaab4d31a87c6f4f93e/src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor#L648-L666).

### F12 — Notification dismissal masks failure / no central completion summary (MEDIUM, confirmed UI behavior)

Popup dismisses its pending notification as soon as it starts the job, then relies on short-lived toasts to show progress/failure. Job completion and the persistent outcome store must be the authoritative source. **Correction:** preserve dismissal if desired; do not equate dismissal to success. Ensure terminal summary, persisted last-operation errors and refreshed pending-action state when the run ends. Displaying a popup-origin job overlay on unrelated pages is a separate UX enhancement, not required for the correctness fix.

### F13 — Stated behavior of Update Only / Level Only should also be audited (MEDIUM, adjacent risk)

Popup's standalone `RunUpdateAsync` and Level Only branches reuse the same up-front subset logic. Converging *combined* Push Updated must not silently change Update Only or Push Only. Record as follow-up or explicitly include the minimal safe fix for Update Only once tests show the same missed-update mechanism. Ensure `maxLevel` is an upper bound over dependency levels, never a fixed selection inferred from a truncated notification list.


## 1. Scope, boundaries, and exact meaning of “one entry point”

**One application-level command for every combined Update + Push**, whether invoked from the Repositories page, floating notifications, Level Only, or Prepare Workspace's post-branch update/push stage. Legitimate *Update Only*, *Push Only*, and the internal two-lane primitive remain separate capabilities. A read-only preview is allowed; no UI is allowed to reconstruct a combined transaction by calling `UpdateAsync` and then `PushAsync`.

```text
Repositories Push Updated ---------+
Repositories Level N Only ---------+
Popup Push Updated ----------------+----> shared immutable command
Popup Level N Only ---------------+           |
Prepare Workspace (after branch gate) -[adapter]|
                                               v
                   IWorkspaceUpdateAndPushOperations.ExecuteAsync(...)
                    |    1. validate request and context
                    |    2. approval/protection gate
                    |    3. choose pipeline-first
                    |    4. if unavailable, sequential safe fallback
                    |    5. final correlated outcome
                    v
             UpdateAndPushOrchestrator.RunAsync()   (existing engine)
                  | update lane -> channel -> push lane |
                  +------------------------------------+
                    if Pipelined=false BEFORE changes:
                       existing UpdateAsync(live all levels)
                       if success -> fresh push plan
                       existing synchronized PushAsync
                       if normal push needs consent -> stop, ask
```

The orchestrator must not know that a popup exists. An optional `Origin`/`InvokedFrom` property is **diagnostic only** and must not branch the execution behavior. The same request/context/repository state yields the same safety and execution policy.

### Out of scope for this correction

- Replacing, rebalancing or retuning two-lane scheduling, Git/Worker queues, read/write lanes, GitLib, registry lookups, timeouts, CI detection, or NuGet parsing.
- Migrations, new durable queues, new hosted workers, additional third-party dependencies, or Git provider changes.
- A redesign of notification layout, loading overlays, package wait UI, or every standalone action.
- Broad repository selection changes unrelated to combined Update + Push.

## 2. Proposed command contract (precise but adaptable to local naming)

Place a single public combined-operation interface in the existing application boundary (likely `GrayMoon.Application`) with one **mutation method**, and implement it in `GrayMoon.App/Services/Application` or `Services/Orchestration`. Names below are illustrative, not instructions to create overlapping abstractions:

```csharp
public interface IWorkspaceUpdateAndPushOperations
{
    Task<UpdateAndPushExecutionResult> ExecuteAsync(
        UpdateAndPushCommand command,
        Action<string>? reportProgress,
        CancellationToken cancellationToken);
}

public abstract record UpdateAndPushCommand(
    int WorkspaceId,
    WorkspaceFeatureContextId ContextId);

public sealed record StartUpdateAndPush(
    int WorkspaceId,
    WorkspaceFeatureContextId ContextId,
    int? MaxLevel,
    string? CommitMessage,
    bool IncludeDepsInCommitMessage,
    bool RestorePackages,
    string? Origin = null)
    : UpdateAndPushCommand(WorkspaceId, ContextId);

public sealed record ApproveNormalPushContinuation(
    int WorkspaceId,
    WorkspaceFeatureContextId ContextId,
    string PendingApprovalId)
    : UpdateAndPushCommand(WorkspaceId, ContextId);
```

A continuation is a **command variant through the same `ExecuteAsync` entry**. Do not expose a second combined-flow service or let UI call the push service directly to finish the combined flow. If an equivalent existing command/result pattern exists on latest main, reuse it; don't add types solely for architectural aesthetics.

Recommended result fields: `RunId`, `WorkspaceId`, `ContextId`, `Status`, `ModeUsed`, `MaxLevel`, `DependencyUpdateRunResult?`, `OperationResult? Push`, `RepoErrors`, `LevelErrors`, `PushedRepoCount`, `PendingApprovalId?`, and a concise human-readable `Summary`. Useful statuses: `Completed`, `NothingToPush`, `UpdateFailed`, `PushFailed`, `ApprovalRequired`, `Rejected`, and `Cancelled` (or retain cancellation exception contract consistently). A success boolean must be derived from the whole workflow, never from the fact that a background delegate returned normally.

**Request requirements**:

1. `ContextId` is mandatory and captured once from the selected Workspace or Feature **before** starting; do not look it up again between update, plan, push, or continuation.
2. `MaxLevel=null` means the entire dependency graph; a number means all levels **at or below** that level. No caller-supplied initial subset of `repoIdsToUpdate` for combined flows.
3. `CommitMessage`, include-dependency-details, and restore are explicit. Preserve existing UI defaults: Repositories modal currently defaults restore **off**; popup uses default push restore **on**; Prepare Workspace currently requests restore **on**. Identical explicitly supplied options should behave identically irrespective of origin.
4. Run ID is generated or captured once at the **operation boundary** and reused by all nested phases and telemetry. Never accept a different context or branch silently on resume.
5. Scope/context/branch safety is enforced in the service or a shared read-only preflight, not only by disabling a button or trusting the notification's limited rows.

### Read-only preflight and approvals

Two approvals have distinct timing:

- **Before any mutation:** warn for writes to the default/protected branch, validate tag/archived/pinned and NeedsRepair state, and respect full context-aware candidate coverage (not the popup's 100 displayed rows). A read-only `PreviewAsync` query is fine and does **not** violate “one mutation entry point”; re-check it at execution time to close time-of-check/time-of-use gaps. Where a producer update could newly select a downstream consumer, either conservatively include that consumer among *potential* protected-branch write targets before approval, or stop before writing it and request fresh approval; never let dynamic discovery bypass the warning.
- **After an update, only if synchronized push is impossible:** return `ApprovalRequired(NormalPushFallback)` with a human-readable reason and a minimal pending continuation. Ask the user whether to continue with normal push. **No push happens before that approval.** This matches the established page behavior without requiring the job to await a page modal indefinitely.

Use a small in-memory, context-bound pending-approval record only if needed to resume already-updated work through the one command. Bind it to `RunId`, Workspace/Feature Context ID, allowed fallback kind and original options. Do not persist credentials or live services. Expire/consume it, ensure idempotent approval, and **recheck** branch HEADs, pinned status, policy, remaining push plan and context before pushing. If stale, refuse safely with instructions to rerun/replan; **never silently redo the update** or use an old push plan. Avoid a general-purpose workflow/saga framework.

Do not redesign the existing warning modals. Both UI callers should translate `ApprovalRequired` into the existing confirmation surface and invoke only the continuation variant after explicit approval.

## 3. Coordinator control flow and failure boundaries

Implement the following contract with no Git command substitutions:

```text
START
  validate workspace ID, selected Context ID, feature health, job ownership
  read-only preflight: planned write targets, tags, default branches, permissions
  if authorization needed and not obtained -> return ApprovalRequired (no mutations)
  begin one correlated combined-operation outcome
  try UpdateAndPushOrchestrator.RunAsync(existing two-lane engine)
  if Pipelined=true:
      record Update.Success, Push.Success, level/repo failures, count, final status
      never interpret returned Push.Success=false as success
      return final combined result
  else:  // documented guarantee: no mutations have occurred
      call existing dependency UpdateAsync with repoIdsToUpdate:null,
           same ContextId, MaxLevel, commit options, error callbacks
      if !updateResult.Success: stop; do not query/execute push as a continuation
      read fresh push plan with same ContextId and MaxLevel
      if no pending push: complete as NothingToPush
      call existing synchronized PushAsync with explicit restore and RunId
      if operation result unsuccessful: record failure, stop
      if SynchronizedPushNotPossibleException:
          return ApprovalRequired with context-bound continuation
          // never auto-fall back to normal/parallel
      return Completed
```

- Pipeline update and push **already overlap**. If a later update level fails, an earlier level already handed to the push lane may have pushed successfully. Preserve this partial-progress behavior. The safety gate means *no new sequential push started after a failed update* and *no new invalid level handoffs*, **not** magically undoing already completed pipeline pushes.
- Treat `DependencyUpdateRunResult.Success=false`, `OperationResult.Success=false`, exceptions, cancellation, and `NotPipelined` as distinct outcomes. Do not throw simply to express an ordinary returned domain failure if existing application conventions treat it as a result.
- `NotPipelined` must mean **no side effects**; add a regression test for that contract before relying on it.
- Use fresh DI scopes when crossing the pipeline/update/push boundary. Never share a DbContext across concurrently running lanes; never run page methods on a long-lived job after component disposal.
- Capture errors even when no active UI/circuit remains; preserve actionable timeout diagnostics. A package-wait stop is not a stuck orchestrator if it deliberately returns a failure.
- Preserve level ordering, workspace-role-last behavior, pinned tags, registry-only wait, existing timeouts and safe retry. A partial push may remain partially completed; retries must calculate actual remaining work rather than blindly replaying commits.

## 4. Operation identity, outcome store, and background job integration

### One cohesive outcome

Current `WorkspaceUpdateOperations.UpdateAsync` calls `WorkspaceOperationOutcomeStore.Begin(..., "Update")` and `WorkspacePushOperations.PushAsync` calls `Begin(..., "Push")`, replacing the record for the same context. Do not create competing recorders inside the new combined flow. Select the narrowest safe fix:

- Prefer a combined-operation recorder owned by the new boundary, with nested phase errors appended under the **same run identity**; leave standalone Update Only and Push Only recording unchanged.
- If retaining existing facades as nested calls, adjust their recording **explicitly for this invocation** (optional shared recorder/run context), or atomically aggregate returned failures into the combined result and publish the final record. Do not globally stop standalone operations from recording.
- Keep last error visible through navigation/component disposal. Prevent a clean later phase within the **same** run from erasing a prior failure, while a separate legitimate new operation can replace the prior outcome under the existing policy.

The outcome should name operation, run ID, originating Workspace/Feature context, failed level, repo errors and package diagnostics, and distinguish terminal status from the transient notification state. Avoid sensitive connector tokens and URL authorization challenges in logs.

### Existing job/locking semantics

`BackgroundJobService` is circuit-scoped but workspace mutations go through the **process-wide** `WorkspaceOperationRunner`; `/workspaces/{id}` uses a structural lock and `/workspaces/{id}/ctx/{contextId}` can use the hierarchical context lock. Preserve the **runner** as the single mutation ownership mechanism. Do not create new `Task.Run`, semaphores, work queues or cancellation sources in the coordinator to compete with it.

- Resolve context and select the correct job key **before** launching the job. Verify special Workspace context vs named Feature handling; the popup currently always uses `/workspaces/{id}`.
- Ensure one active same-context mutation across tabs; competing starts should attach or receive a busy response without running twice. Preserve existing structural operations blocking context operations.
- A popup launched from a route other than `/workspaces/{id}` may not display an overlay because `BackgroundJobOverlay` matches the current path exactly. Do not infer that the operation stopped from the missing overlay; ensure status is discoverable through the existing operation runner/outcome. Any broader overlay redesign should be separate.
- Make cancellation observable and stop downstream work; preserve any already committed/pushed levels. The job must not capture a component, a `DbContext`, a page-owned semaphore, or a disposed UI scope.
- Do not force a workspace structural lock for all contexts merely to imitate the popup, nor incorrectly use a Feature lock for a Workspace structural action. Validate isolation tests before changing job keys.

## 5. Phased implementation work packages

Each phase produces a small reviewable diff and a green focused test suite; don't delete the old implementation until the replacement is verified. Do not commit/push automatically.

### Phase 0 — Baseline, inventory, and characterization (tests/documentation only)

**Owner:** test/architecture. **Touched:** App test project; living design/plan documents; no runtime behavior changes.

1. Check out current `main`, log its SHA and relevant uncommitted changes. Reopen the exact source files below and reconcile findings that may already be fixed. Reference reviewed baseline: `eb320738a999486bfec9aeaab4d31a87c6f4f93e`.
2. Find *all* combined-flow call sites via `rg "UpdateAndPushAsync|UpdateAndPushOrchestrator|RunUpdateAndPushCoreAsync|StartUpdateAndPushJobAsync|StartLevelOnlyUpdateAndPushJobAsync" src` and identify standalone Update / Push calls separately.
3. Inventory behavior/contract of Repositories full/Level Only, popup full/Level Only, Prepare Workspace, REST `/prepare-workspace`; enumerate current warnings, restore defaults, progress/terminal behavior and fallback semantics.
4. Run baseline existing App tests/build (plus focused Worker/Common suites where relevant). Log environment limitations rather than marking unrun tests as passed.
5. Add characterization tests/fakes for returned update failure, 3-level evolving dependencies, `NotPipelined`, package wait failure, duplicate clicks, pinned tag, selected Feature and restore modes. Mark tests that intentionally reproduce a bug as failing until their phase fixes it.

**Gate:** existing tests green or failures explained; full call graph and baseline behavior matrix documented; repros for F02 and F03 in place.

### Phase 1 — One contract, result model, and tests; no UI migration

**Owner:** application boundary. **Likely files:** `src/GrayMoon.Application/` operation contract/models; `src/GrayMoon.App/Services/Application/` facade/coordinator; DI in `Program.cs`; focused tests.

1. Define immutable start + explicit approval-continuation commands, one `ExecuteAsync` method, strongly typed terminal result, and one run ID. Do not leak UI controls or `WorkspaceRepositoryLink` entities into the request.
2. Add data-independent tests for validation, context binding, error merge, no-work status, restore explicitness, no silent fallback, and approval idempotency.
3. Add DI registration using the existing service lifetime model (scoped application operation, process-wide runner remains unchanged).
4. Keep current caller flows untouched. No source behavior changes on existing UI yet.

**Gate:** contract compiles; fake implementation can be used headlessly; no dependency from Application to Blazor component types.

### Phase 2 — Coordinator composition; preserve engine and fallback

**Owner:** orchestration/application. **Likely files:** new coordinator, `WorkspaceOperationOutcomeStore`, narrow facade changes if needed; tests.

1. Call the existing `UpdateAndPushOrchestrator.RunAsync` / facade first. Do **not** implement level channels, package waiting, or git pushes a second time.
2. On `Pipelined=false`, run only the established sequential fallback: dependency `UpdateAsync` with **null** repo set and same maxLevel; require `Success=true`; fresh push plan; synchronized `PushAsync`; structured result.
3. Preserve existing `SynchronizedPushNotPossibleException` -> explicit normal push approval. Provide a bound pending continuation (or reuse equivalent existing UI continuation flow inside a single command). Do not restart the successful update while confirming.
4. Ensure pipeline returned failures are surfaced and recorded, even if no exception was thrown. Keep one logical combined outcome across nested calls.
5. Test pipeline success, both lanes' returned errors, update thrown/returned failure, zero push after failed sequential update, stop on missing package, cancellation, snapshot updates, and safe retry.

**Gate:** service-level tests prove one decision policy for all callers; two-lane implementation files unchanged (aside from truly necessary small tests/instrumentation).

### Phase 3 — Switch popup's two combined actions only

**Owner:** UI integration. **Primary file:** `src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor`.

1. Replace the bodies of `StartUpdateAndPushJobAsync` and `StartLevelOnlyUpdateAndPushJobAsync` with a request to the new shared command. Both specify the same pinned context and explicit `MaxLevel` (`null` or selected level).
2. Remove the popup **combined-flow-specific** up-front `reposNeedingWork` filter, independent Update -> Push chain and push-mode selection. Do not casually remove `ExecutePushAsync` used by standalone Push Only; isolate/delete code only after a call-site search.
3. Replace no-op error handling with shared structured outcomes and approved `PushOperationResult.Describe`-style messaging. Use existing toast/modal controls; preserve notification dismissal behavior unless users would be falsely told an operation succeeded.
4. Build default-branch policy from full fresh context-aware candidates, not `notification.Repos` (capped at 100). Explicitly preserve pinned-tag and NeedsRepair protection.
5. Pin one ContextId at action start, including when user acknowledges the warning. Preserve the popup's explicit restore=true legacy default and commit-message defaults (or clearly document a deliberate approved change).
6. Test from dashboard/other routes, context switches during operation, warnings, cancellation, and continued visibility of stored failures on Repositories.

**Gate:** popup full/Level Only hit the unified command; they cannot locally initiate a combined two-service chain. Repositories behavior remains untouched.

### Phase 4 — Switch Repositories full and Level Only; delete duplication

**Owner:** UI integration. **Primary files:** `WorkspaceRepositories.Update.cs`, related modal and page state only as necessary.

1. Preserve current modal input/confirmation and `RestorePackages=false` default. Submit one immutable request after approvals; use the same command as popup.
2. Keep the page's current callout and refresh semantics by adapting structured results. Do not call methods on disposed page objects in background completion. Respect `SafeInvoke`/context-generation protections.
3. Remove page-local `TryRunPipelinedUpdateAndPushAsync` / combined sequential fallback once shared flow parity is verified. Do **not** delete reusable Update Only/Push Only helpers or the safe normal-push confirmation.
4. Test identical explicit requests from both surfaces under the same fake data; verify identical mode, level scope, failed-level errors and final result.

**Gate:** exact two entry surfaces, one mutation method; same options -> same engine/safety/result. No Worker, Git, package wait or layout changes.

### Phase 5 — Migrate/audit Prepare Workspace and REST without weakening branch gate

**Owner:** orchestration/API; *separate commit/PR if risk merits.*

1. `PrepareWorkspaceOrchestrator` invokes `PrepareWorkspacePhases.UpdateAndPushAsync` directly after successful branch creation. Preserve **all-repositories-on-target-branch** validation, abort-all on partial creation, `PushPending` behavior, and restore=true default.
2. Route just its combined post-branch action through the canonical command (adapter where necessary), or keep the old lower-level entry **internal and explicitly temporary** until Prepare contract parity is proven. Do not casually change branch or user-confirmation behavior to satisfy an interface purity goal.
3. Inspect REST endpoints: `/update` is Update Only and `/push` is Push Only; neither is a hidden combined flow. `/prepare-workspace` is composite and must preserve HTTP error/result semantics. Don't introduce a new public REST route unnecessarily.
4. After no production caller bypasses the shared command for combined Update + Push, restrict or clearly mark the raw pipeline API internal, add an architecture guard test to prevent UI calls directly to the pipeline or custom Update→Push chains.

**Gate:** Prepare branch failures still cause **zero** update/push calls; no unintended API contract changes; no production dual combined path remains.

### Phase 6 — Diagnostics, full tests, documentation, rollback readiness

**Owner:** cross-cutting QA.

1. For every start/completion, log `RunId`, `WorkspaceId`, `ContextId`, `MaxLevel`, options, (diagnostic) origin, pipeline acceptance/refusal, fallback decision, updated/pushed counts, failed level and summary. Do not log credentials, tokens, or full git diffs.
2. Log explicit markers for refused starts, stale approvals, unchanged/no-work completion, cancellation, returned domain failures and package wait. Do not claim `Completed` for a terminal failure result.
3. Verify operation outcome survives navigation/disposal and a new page shows it; popup dismissal is not the success signal.
4. Update architecture and capability docs and the living implementation checklist; add release notes if project convention requires it.
5. Run relevant test suites, build, lint/static checks, and Windows/VDI smoke where available. Report commands, results and tests not run; review diff for accidental protocol/schema/engine changes.
6. Maintain rollback safety: migration-free application-only change; revert popup/page adapter or the entire shared command together if regression occurs. Do not keep two silently active implementations as a permanent toggle.

**Gate:** all acceptance tests pass; logs contain one correlated trace; completed change is mergeable without modifying two-lane algorithm.

## 6. Regression matrix (mandatory)

| ID | Scenario | Assertions |
|---|---|---|
| T01 | Popup primary vs Repositories full with same explicit options | Same unified command and pipeline/fallback policy, same context and result |
| T02 | Level N Only from both surfaces | MaxLevel inclusive, never touches higher levels |
| T03 | L1 commit updates version needed by L3 consumer | L3 discovered during live walk; no stale prefilter |
| T04 | Update returns `Success=false` but does not throw | Exactly zero sequential push/plan continuation; combined failed result |
| T05 | Update throws or cancels | Stops, records context, no later fallback push |
| T06 | Pipelined mode succeeds | Existing overlap/handoff ordering and progress retained |
| T07 | Pipelined push lane fails at level | Result `Push.Success=false`, failed level/ID/version preserved, previous successful levels retained |
| T08 | Pipeline preflight returns `NotPipelined` | No side effects before fallback; fallback updates once |
| T09 | Sequential synchronized push unavailable | ApprovalRequired, **zero unsynchronized pushes** until actual approval |
| T10 | Approval rejected / expired / repeated | No push on reject/stale/replay; retries replan safely |
| T11 | Fresh plan empty after update | NothingToPush, no push call, still records successful update |
| T12 | Push returns `Success=false` without throwing | Terminal PushFailed, outcome visible after navigation |
| T13 | Feature selection changes mid-run | Original captured ContextId used by update, push, plan, errors, continuation |
| T14 | Feature deleted or NeedsRepair | Safe refusal before mutation; no implicit Workspace fallback |
| T15 | Pinned/tag/detached archived repo | No checkout, commit, update or push of pinned target |
| T16 | Default-branch write beyond popup's first 100 rows | Warning/policy sees full fresh context; cannot bypass |
| T17 | Restore true/false, differing UI defaults | Exact explicit requested behavior; no unwanted restores or skipped registry waits |
| T18 | Basic workspace/no NuGet and alternate CI | Existing capabilities and CI-agnostic registry logic unchanged |
| T19 | Multiple tabs / repeated click in same context | Process-wide lock/dedup; one mutation only |
| T20 | Different Feature contexts + structural mutation | Existing hierarchical lock behavior preserved |
| T21 | User navigates away / page disposed during package wait | Operation survives appropriately; no disposed UI exceptions; final outcome available |
| T22 | Partial push / retry after package delay | Already pushed repos not blindly recommitted/pushed; remaining work recoverable |
| T23 | Prepare Workspace branch failure or incomplete result | Stops before Update/Push; original branch gate unchanged |
| T24 | Prepare pipeline refused | Existing `PushPending`/approval semantics preserved or deliberately translated equivalently |
| T25 | Operation outcome Begin/merge | Nested Update and Push cannot overwrite earlier failure of same combined run |
| T26 | Runtime log and no secrets | One RunId with stage-level error and context; no PAT/connector secret leakage |
| T27 | Static architecture guard | No UI component contains combined UpdateAsync + PushAsync chain after migration |

**Test discipline:** Start with small fakes and deterministic callbacks. Add a thin integration test with a temporary SQLite/context and simulated worker behavior for dynamic levels and outcome propagation. Don't require live GitHub Actions or an actual private NuGet feed for unit tests. Run project-specific tests suggested by `CLAUDE.md` and actual solution/project files; don't invent solution targets or assert CI validation you haven't run.

## 7. Living tracking checklist for coding agent

- [ ] Baseline SHA, existing build/test status and source inventory recorded.
- [ ] Broken popup behavior characterized with tests (returned failure and stale scope).
- [ ] Single combined application contract and result added without UI dependency.
- [ ] Service implements pipeline-first and existing safe sequential fallback.
- [ ] No push when sequential update returns failure, even without an exception.
- [ ] Explicit approval path for normal push after synchronized mode refused.
- [ ] Context pinning, tag/default-branch/Feature policy checks validated.
- [ ] Operation store reports one coherent outcome and correlation ID.
- [ ] Popup full + Level Only migrated and tested.
- [ ] Repositories full + Level Only migrated and tested.
- [ ] Prepare Workspace audited/migrated and branch gate preserved.
- [ ] REST callers audited; standalone operations untouched.
- [ ] Direct combined execution paths removed/restricted; architecture guard added.
- [ ] Restore defaults explicitly preserved/documented.
- [ ] Diagnostics, docs, release notes updated.
- [ ] All focused tests and available suite builds pass; unrun checks listed.
- [ ] Diff reviewed for Worker, Git, registry, schema and UI churn; no unrequested commit/push.

## 8. Source map and review order

| Concern | Source path |
|---|---|
| Popup full / Level Only and push-mode selection | `src/GrayMoon.App/Components/Shared/WorkspaceActionNotificationPanel.razor` |
| Repositories combined and fallback | `src/GrayMoon.App/Components/Pages/WorkspaceRepositories.Update.cs` |
| Shared Repositories push helper | `src/GrayMoon.App/Components/Pages/WorkspaceRepositories.Push.cs` |
| Combined pipeline engine | `src/GrayMoon.App/Services/Orchestration/UpdateAndPushOrchestrator.cs` |
| Per-level update and handoff | `src/GrayMoon.App/Services/Orchestration/DependencyUpdateOrchestrator.cs` |
| Per-level push and registry wait | `src/GrayMoon.App/Services/Workspaces/WorkspacePushService.cs`, `WorkspacePushService.PackageWait.cs` |
| Application facades | `src/GrayMoon.App/Services/Application/WorkspaceUpdateOperations.cs`, `WorkspacePushOperations.cs` |
| Result contract | `src/GrayMoon.Application/OperationModels.cs` |
| Existing durable-per-process failure record | `src/GrayMoon.App/Services/Orchestration/WorkspaceOperationOutcomeStore.cs` |
| Job locks/key routing | `src/GrayMoon.App/Services/Jobs/BackgroundJobService.cs`, `WorkspaceJobKeys.cs`, `WorkspaceOperationRunner.cs` |
| Context-aware notification computation | `src/GrayMoon.App/Services/Ui/WorkspacePendingActionsService.cs` |
| Repositories modal restore default | `src/GrayMoon.App/Components/Modals/UpdateDependenciesModal.razor` |
| Prepare combined caller | `src/GrayMoon.App/Services/Orchestration/PrepareWorkspaceOrchestrator.cs`, `PrepareWorkspacePhases.cs` |
| API orchestration | `src/GrayMoon.App/Api/Endpoints/WorkspaceOperationsEndpoints.cs` |
| Tests | `src/GrayMoon.App.Tests/WorkspacePushStrategyTests.cs`, `DependencyUpdateRunResultTests.cs`, `WorkspaceOperationOutcomeStoreTests.cs`, `FeatureContextIsolationTests.cs`, `WorkspaceOperationRunnerTests.cs` |

This review examined source at commit [`eb320738a999486bfec9aeaab4d31a87c6f4f93e`](https://github.com/Jandini/GrayMoon/commit/eb320738a999486bfec9aeaab4d31a87c6f4f93e). It did **not** reproduce the latest runtime stop with fresh logs; package wait timeouts and the popup's sequencing errors are distinguishable possibilities, not one proven root cause. Re-read the current branch on execution day.
