# GrayMoon code review - 2026-11-10

Fix plan: [2026-11-10-fix-plan.md](2026-11-10-fix-plan.md).

**Baseline:** GrayMoon `ae1b748c`, GrayMoon.Desktop `c9c9c105` (both tagged `0.2.0`).
**Method:** eight parallel read-only reviews (Features, orchestration, data/security, Blazor pages, modals/shared UI/JS, GitChanges/Common, Worker, Desktop/build) checked against the invariants in `GrayMoon/CLAUDE.md` and `AGENTS.md`. Findings marked CONFIRMED were re-read in the current source; PLAUSIBLE ones were traced but not executed.
**Build and tests:** both solutions build with 0 warnings. Tests: Common 390, Worker 882 (+1 skipped), App 1851, Desktop 221, all passing.

Paths are relative to `C:\Workspace\GrayMoon`; App paths are under `GrayMoon/src/GrayMoon.App/`. Severity: High = data loss, security, or circuit crash on a normal path; Med = wrong result or stuck state on a realistic path; Low = hardening, leak, or narrow race.

## 1. What is GOOD

- **Process and argument hygiene.** `BoundedProcessRunner`, `CommandLineService`, `GitEvidenceCollector`, `AiCliRunner` and the Desktop open-in launchers use `ArgumentList`, `--` plus `:(literal)` pathspecs, timeout and idle watchdogs, process-tree kill, and never place paths in a command string. Tricky-path tests exist on both sides.
- **Secrets.** AES-GCM v2 tokens with key ids and legacy decrypt-only keys, startup re-encryption, DPAPI or mode-600 key file, `GIT_CONFIG_*` transport with `LogSafe` redaction on the `http.extraHeader` fallback, and the Worker secret validated as a plain token before copy.
- **Migrations.** Strict steps run in their own transaction with a `user_version` bump, a rollback test, and a golden 0.1.0 upgrade fixture.
- **Scoping discipline where it was designed in.** Fan-out services (`PathResolver`, `ContextResolver`, `PullRequestService`, query services, manifest service) use `IDbContextFactory`, tag-pinned repos are excluded in every mutating path traced, and Feature state is correlated by context id.
- **Destructive Worker paths** always take an exclusive `IRepositoryAccess` claim first; `FeatureFolderCleaner` and worktree residue removal validate markers and never recurse into reparse points.
- **Two-lane Update and Push orchestrator** uses a fresh DI scope per level, an ordered progress stream, a sync barrier, and treats unknown outcomes as failures.
- **UI race guards.** Generation counters plus disposed flags in `FilterSearchInput`, `DebouncedQueryLoader`, `ChangesNotificationDot`, and the diff viewers' per-instance JS maps with `JSDisconnectedException` handling.
- **Release pipeline.** Channel derived only from the ref, duplicate-version refusal, deterministic Setup.exe discovery, double Authenticode verification, draft-then-publish.

## 2. What is BAD (patterns, not single bugs)

- **Shared-link writes from Feature contexts.** The scoping rule (Feature contexts write `WorkspaceRepositoryContextState` only) is enforced by the state writer, but several services bypass it and write `WorkspaceRepositories` columns directly (`WorkspacePushService`, `WorkspaceCommitSyncHandler`, Actions panel). Each is a correctness bug waiting for a Feature user.
- **Job bodies mutate page state off the dispatcher.** The Blazor pages are careful with `SafeInvoke` in most places, but reload helpers and status setters still write page collections from thread-pool jobs.
- **Context id read lazily inside job lambdas.** `RequireSelectedContextId()` is called inside many `svc =>` bodies instead of using the id captured when the job was queued, so a context switch mid-job retargets the job.
- **Singletons that hold per-circuit state or handlers.** `IToastService` is a singleton with mutable message state; `WorkerConnectionTracker` handlers are added per circuit and never removed.
- **Error swallowing on "best effort" steps.** `dotnet restore` failures, package-wait transport errors, and push-lane faults are either reported as success or surfaced late with no boundary information.
- **LAN-reachable surfaces default to open.** Worker secret optional until first pairing, hook listener trusts any loopback POST with an unbounded body, Docker `AllowedHosts "*"` plus a same-host Origin rule.
- **Unvalidated App-supplied relative paths** in three Worker commands, while the file read/write commands do validate.

## 3. Hidden bugs, prioritized

### P1 - fix before the next release

| # | Where | Defect | Failure scenario | Status |
|---|---|---|---|---|
| 1 | `Services/GitHub/GitHubRepositoryService.cs:84` + `Repositories/RepositoryRepository.cs:130,314` | Merge deletes every existing repository not in `allFetched`, but a connector whose fetch failed contributes nothing and the merge still runs. | Two connectors; A returns 401 or rate-limit, B succeeds. All of A's repositories, links, projects, branches and PR rows are deleted (only Feature-used repos survive). The existing fan-out test uses `repoCount: 0` and misses it. | Fixed (code-review-fixes) |
| 2 | `Services/Workspaces/WorkspacePushService.cs:1478-1521` | Post-push upstream and remote-branch bookkeeping reads `BranchName`/`CheckedOutTag` from the shared link and writes `BranchHasUpstream` to it for any context. | Push from a Feature on `feature/x` while the Workspace is on `main` without upstream: Workspace gets `BranchHasUpstream=true` and a bogus `origin/main` row; a tag pinned only in the Workspace skips the Feature's commit-count refresh. | Fixed (code-review-fixes) |
| 3 | `Components/Shared/WorkerStatusBadge.razor:51`, `Components/Layout/MainLayout.razor:87` | `WorkerConnectionTracker.OnStateChanged` on a singleton, never `RemoveStateChanged`. | Every circuit and every prerender pass leaks a delegate holding the dead component; the list grows for the process lifetime and fires `InvokeAsync` on disposed components. | Fixed (code-review-fixes) |
| 4 | `Components/Pages/WorkspaceRepositories.Update.cs:384` (also `Sync.cs:98,186`, `PrepareWorkspace.cs:83`, `Dependencies.cs:295`, `RepositoriesModal.cs:89`) | `ReloadWorkspaceDataFromFreshScopeAsync` is awaited inside job bodies and swaps `_slots`, `_linkByRepoId`, `prByRepositoryId`, `repoSyncStatus` on the thread pool. | Dispatcher renders the virtual-scroll table while the job swaps collections: `InvalidOperationException` and a broken circuit. | Fixed (code-review-fixes) |
| 5 | `Components/Pages/WorkspaceActions.razor.cs:63-71` | Hub creation and background refresh gated on `firstRender && workspace != null && !isLoading`, but first render happens at the first await in `OnInitializedAsync`. | On a normal visit the sync hub never attaches and the initial refresh never starts. Same pattern in `WorkspaceRepositories.Realtime.cs:18`. | Fixed (code-review-fixes); confirmed by code trace, manual check owed |
| 6 | `GrayMoon.Desktop/src/GrayMoon.Desktop/MainWindow.xaml.cs:344-361` | `IsPrivilegedWebMessage` reads `"command"` case-sensitively while the bridge deserializes case-insensitively. | `{"Command":"InstallWorker"}` from a non-App origin skips the origin gate and still reaches the elevated handlers. | Fixed (code-review-fixes) |
| 7 | `Services/Security/RequestSecurityMiddleware.cs` (`IsAllowedOriginHost`) with `appsettings.json` `AllowedHosts "*"` | Origin host equal to request Host is accepted; Docker mode has no host allowlist. | DNS rebinding from a hostile page reaches `/api/...` and, before a Worker has paired, `GET /repos/{id}/connector` returns a plaintext PAT. Desktop mode is protected by `GRAYMOON_AllowedHosts`. | Fixed (code-review-fixes); `X-Forwarded-Host` equality dropped too |

### P2 - fix in the next sprint

| # | Where | Defect | Failure scenario | Status |
|---|---|---|---|---|
| 8 | `GrayMoon.Worker/Commands/DotnetRestoreCommand.cs:43-54`; `WorkspacePushService.cs:1219,1286`; `WorkspaceGitService.Restore.cs:902` | Worker returns `Success=true` on non-zero `dotnet restore`; App discards the response. | Registry outage: Update and Push report completed, user builds against stale packages. | App side Fixed (code-review-fixes), reported as a failed run because `OperationResult` has no warning channel; Worker side open (stream F1) |
| 9 | `Services/Worker/WorkerResponseDelivery.cs:204-218` | `cancellationToken.Register` runs before `Pending.TryAdd`. | Already-cancelled token (timeout CTS, disposed page): callback fires before the entry exists, entry is never removed, `WaitAsync` completes only on Worker disconnect. | Fixed (code-review-fixes) |
| 10 | `WorkspacePushService.cs:512-528,578-584` | Package wait rethrows NuGet transport errors out of `Task.WhenAll`. | One DNS or TLS blip during a multi-minute wait aborts the synchronized push level. | Fixed (code-review-fixes) |
| 11 | `Services/Orchestration/UpdateAndPushOrchestrator.cs:53-117` | Push-lane fault observed only after the update lane finishes all levels. | Update keeps committing version bumps whose lower levels never pushed; final message does not name the boundary. | Fixed (code-review-fixes) |
| 12 | `Services/Jobs/BackgroundJobService.cs:107-155` | When `TryStartContext`/`TryStart` fails the caller's work is dropped and a handle for the other operation is returned. | Callers without an `IsRunning` guard show "running" then "completed" with nothing done. | Fixed (code-review-fixes) |
| 13 | `Components/Pages/WorkspaceGitChanges.MultiRepo.cs:362` and most `WorkspaceRepositories.*` job lambdas | `RequireSelectedContextId()` read inside the job body instead of the captured id. | User changes `?context=` while a commit job runs; push targets the other context's branches. | Fixed (code-review-fixes) |
| 14 | `Components/Pages/WorkspaceRepositories.Sync.cs:174-178` | `repoSyncStatus[repoId]` written from the job thread without `SafeInvoke`. | Concurrent dictionary write during render throws or corrupts. | Fixed (code-review-fixes) |
| 15 | `Program.cs:132` + `Services/Ui/ToastService.cs` | `IToastService` singleton with mutable state. | An error toast from one circuit appears in every open tab; concurrent toasts overwrite each other. | Fixed (code-review-fixes) |
| 16 | `Repositories/WorkspaceRepositoryLinkCleanup.cs:14-78` | Repository unlink never deletes `WorkspaceFiles`, `WorkspaceFileVersionConfigs`, `WorkspaceFileLineStatuses`. | Files page keeps showing the unlinked repo's files; line statuses orphaned. | Fixed (code-review-fixes) |
| 17 | `Migrations.cs:153-189` | No try/catch around `VACUUM INTO`; failed integrity check only logs. | Disk full: raw `SqliteException` surfaces as "Application terminated unexpectedly"; migration can proceed on a corrupt backup. | Fixed (code-review-fixes); failed-integrity-check path has no test |
| 18 | `Services/Features/WorkspaceFeatureOperations.cs:758-1139` | Remove sends `force = AllowDiscardUncommitted` to every repo at execution time. | Repo clean at analysis, dirty before the queued removal runs: force-removed without warning. | CONFIRMED shape, Med |
| 19 | `WorkspaceFeatureOperations.cs:2134-2207` (Rollback) | Rollback relies on the Worker's empty-root delete and never marks the folder pending-delete. | Non-worktree file (`codegraph.json`, `.codegraph`) leaves the root behind; a later Create with the same name fails `FeatureFolderExists` with no self-healing. | PLAUSIBLE, Med |
| 20 | `GrayMoon.Worker/Commands/UpdateBranchFromDefaultCommand.cs:31` | `Path.Combine(repo, ".git", "MERGE_HEAD")` assumes `.git` is a directory. | In a Feature worktree (`.git` is a file) a half-finished merge passes the guard and a second merge starts on an unmerged index. | CONFIRMED, Med |
| 21 | `GrayMoon.Worker/Commands/UpdateFileVersionsCommand.cs:20`, `CheckFileVersionsCommand.cs:28`, `DotnetRestoreCommand.cs:35` | App-supplied relative paths never go through `GitRepositoryPathValidator`; restore interpolates the path into a string. | Rooted or `..` path writes outside the repository; a quote breaks tokenization. | CONFIRMED, Med (input is App-controlled) |
| 22 | `GrayMoon.Worker/Hosted/HookListenerHostedService.cs:117` | Body read with no size cap; `repositoryPath` from the payload is used directly. | Any local process or a browser simple-POST to 127.0.0.1:9191 can exhaust memory or point git/GitVersion scans at an arbitrary local path. | CONFIRMED, Med |
| 23 | `GrayMoon.Worker/Hosted/SignalRConnectionHostedService.cs:113` | `RequestCommand` awaits the bounded `EnqueueAsync` inside the SignalR handler. | Main pool full: handler blocks and `CancelCommand` dispatch waits behind it, so the cancel that would free the pool is delayed. | PLAUSIBLE, Med |
| 24 | `GrayMoon.Desktop/src/GrayMoon.Desktop/Services/AppProcessManager.cs:104-108` | Handshake timeout throws without killing the child; a new Job Object handle per `StartAsync`. | Slow first start leaves a live App on port 8384; Retry launches a second App that exits 62 until Desktop exits. | CONFIRMED, Med |
| 25 | `GrayMoon.Desktop/src/GrayMoon.Desktop/Services/VelopackUpdateService.cs:143-178` | App child stopped before `ApplyUpdatesAndRestart`; nothing restarts it on failure. | Locked file or disk full: MessageBox, then WebView on a dead App with no Retry overlay. | CONFIRMED, Med |
| 26 | `GrayMoon.Desktop/src/GrayMoon.Desktop/Services/SingleInstanceService.cs:20,97` | `ActivationRequested` raised but never subscribed. | Second launch exits silently; the running window is not activated. Docs 01 section 3 and `CLAUDE.md` describe the intended behavior. | CONFIRMED, Med |
| 27 | `GrayMoon.Desktop/src/GrayMoon.Desktop/Services/HostPrerequisiteInstaller.cs:322-324` | `Success` requires `RestartError is null`, but restarting a not-yet-installed Worker sets it. | First-run Install All completes every step and reports failure. | Fixed (code-review-fixes) |
| 28 | `Components/Modals/GhaLogsModal.razor:216-236` | Reopen clears `_jobs` without cancelling or generation-guarding the previous load. | Open run A, close, open run B while A is in flight: A's jobs appended into B's list. | CONFIRMED, Med |
| 29 | `Components/Shared/WorkspaceActionNotificationPanel.razor` | Warnings computed from the 100-capped `n.Repos`; repo sets taken from special-Workspace link columns even for a Feature context. | Repos beyond the cap or Feature-only state are skipped without warning. | PLAUSIBLE, Med |
| 30 | `Services/GitChanges/WorkspaceGitChangesWriteQueue.cs` (`ExecuteAsync`) | Reader rethrows every `OperationCanceledException`, not only the stopping token's. | A non-shutdown OCE ends the reader; later snapshots are silently lost and `EnqueueAndWaitAsync` callers hang; with `StopHost` behavior the App stops. | Fixed (code-review-fixes); confirmed by failing test |
| 31 | `GrayMoon/src/GrayMoon.Common/CommandLineService.cs:94,200` | stdin write outside any `IOException` catch. | `--pathspec-from-file=-` with a large list when git exits early: exception instead of the exit-code result the Worker fallback expects. | CONFIRMED path, Med |
| 32 | `Services/Worker/WorkerConnectionTracker.cs:611-615` + `Hubs/WorkerHub.cs:861-876` | `GetWorkerConnectionId` returns `FirstOrDefault`; `OnDisconnectedAsync` calls `FailAll` for any connection. | Worker restart with a brief overlap fails every in-flight command on the new connection. | Fixed (code-review-fixes); real cause: new commands were routed to the old connection during the overlap |
| 33 | `GrayMoon.Desktop/.github/workflows/release.yml:22-27,110-125,185` | Signing secrets described as repository secrets while `production` applies only to stable; stable tags resolve GrayMoon to `releases/latest` at run time. | A `workflow_dispatch` from a feature branch can read signing credentials; re-running a Desktop tag bundles different App code. | App pin Fixed (code-review-fixes), workflow not run; signing secrets: workflow side fixed, owner action pending (move `ESIGNER_*` to the `production` environment, delete the repository secrets) |

### P3 - hardening and small leaks

- `Services/Security/WorkerSecretMiddleware` + `Api/Endpoints/ConnectorEndpoints.cs:198-209`: secret optional until first pairing; flip the default to required. (Med by design, documented.) **Fixed (code-review-fixes).**
- `Migrations.Features.cs:16-39`: tolerant catch leaves Added entities in the shared startup context, flushed by step 16; `MigrateWorkspaceRepositoryRoleAsync` / `MigrateForkSupportAsync` have no catch. **Fixed (code-review-fixes).**
- `Migrations.cs:53-77`: a brand-new database also gets a `.bak` of an empty file. **Fixed (code-review-fixes).**
- `Services/GitHub/GitHubService.Http.cs:134-204`: `TaskCanceledException` retried 3x with backoff on every GET, so a hung endpoint stretches refresh by minutes. **Fixed (code-review-fixes).**
- `Components/Shared/GhaWorkflowLiveTerminal.razor:103,122-132,342-344`: poll loop catches only OCE; `RunId` change never restarts polling; fault rethrown from `DisposeAsync`.
- `Components/Shared/LoadingOverlay.razor:197-216`: `matrixOverlay.*` interop every render without `JSDisconnectedException` handling.
- `Components/Shared/Toast.razor:37-44` (**Fixed (code-review-fixes)**), `ConnectorModal.razor` (Enter in Delete mode has no submit guard), `AddFilesModal.razor` (`SearchAsync` dropped while in flight), `Workspaces.razor:786` (focus stolen every render), `SwitchBranchModal.razor:1045-1065` (Remotes tab bypasses the client occupancy check).
- `GrayMoon/src/GrayMoon.Common/Ai/AiPromptBuilder.cs:81`: recent commit subjects skip `Sanitize` and `EvidenceRedactor`.
- `Services/GitChanges/GitChangesSnapshotPushHandler.cs:186-192`: legacy-table version gate returns before context tables are written (flag default off).
- `Services/Ai/AiTextGenerationRuns.cs:118-124` (Cancel vs Finish dispose race), `Services/Ai/WorkspaceAiGenerationOperations.cs:50,185` (`First` on provider id), `Services/GitChanges/GitChangesLineStatsRefresh.cs` (non-atomic CTS swap), `Services/GitChanges/MarkdownImageEmbedder.cs` (HTML-escaped URL used for download; App fetches arbitrary http(s) images, 2 MB cap).
- `Services/Features/WorkspaceFeatureReconciler.cs:147` (does not consult `IFeatureRemovalQueue.IsPending`), `Services/Features/FeatureRemovalQueue.cs:86-93` (shutdown leaves `Removing` until the next Worker Online), `GrayMoon.Worker/Services/FeatureFolderCleaner.cs:101-109` (narrow sweep-vs-add window), `GrayMoon.Worker/Services/CodeGraphCli.cs:177` (`_finishedInits` never pruned).
- Worker: `Hosted/SignalRConnectionHostedService.cs:170-175` (reconnect loop during shutdown), `Commands/PushRepositoryCommand.cs:106` / `Commands/UndoPushCommand.cs:53` (fire-and-forget scans outside pool accounting), `Services/GitCliRepositoryReader.cs:566` and `GitWorktreeService.InspectWorktreeAsync` (interpolated ref names without `--`), `Services/CommandJobCancellationRegistry.cs:37` (pre-cancelled CTS leak), `Services/WorkerTokenProvider.cs:20-86` (dead token cache).
- Desktop: `DesktopNotificationService` / `TrayIconService.SetTopBarVisible` cross-thread menu updates, `NavigationPolicyService.IsValidRelativePath` accepts `//host/path`, `HostPrerequisiteInstaller.TryParseHelperArgs` does not require a rooted result path, `EnsureVisibleConsoleToken` rejects `&`/`^` in profile paths, `build/Test-GrayMoonTestGate.ps1` and `build/Test-VelopackReleaseBoundary.ps1` are not invoked by any workflow. **Fixed (code-review-fixes)** for `NavigationPolicyService`, `TryParseHelperArgs` (file-name check, folder not compared), `EnsureVisibleConsoleToken` and the test-gate scripts (now called by `release.yml`); the cross-thread menu updates are open (stream G1).

## 4. Fix order and risk

1. **#1 connector-refresh deletion.** Pass the set of successfully fetched connector ids into the merge and restrict `candidateDeleteIds` to repositories owned by those connectors. Risk: low, one query filter plus a test with `repoCount > 0` for the failing connector. Highest payoff: this is silent data loss on a routine refresh.
2. **#2 and the other Feature-context shared-link writes** (`WorkspacePushService`, `WorkspaceCommitSyncHandler.SetSyncStatusErrorAsync`, Actions panel). Route through `_stateWriter` (`UpstreamProbed`) and read branch/tag from `WorkspaceRepositoryContextState`. Risk: medium, touches the push path; cover with a Feature-context push test.
3. **#3 handler leak and #15 toast singleton.** Add `RemoveStateChanged` in `Dispose` for badge and layout; make `IToastService` scoped. Risk: low.
4. **#4, #14, #13 page-state and context-id discipline.** Wrap reload helpers in `SafeInvoke` or return data and apply on the dispatcher; capture the context id at queue time. Risk: medium, mechanical but wide (grep `RequireSelectedContextId()` inside `svc =>` lambdas).
5. **#5 Actions hub gating.** Confirm with a breakpoint; if real, move hub creation to after the load completes. Risk: low.
6. **#6, #7, #22, #21 LAN and WebView surfaces.** Case-insensitive command check in `IsPrivilegedWebMessage`; require the Worker secret by default; cap the hook body and validate `repositoryPath`; validate the three Worker command paths. Risk: low to medium; the secret default change needs a first-pairing path and a wiki note.
7. **#8, #10, #11, #12 orchestration error reporting.** Restore failures as level warnings, package-wait throws as "not yet", push-lane fault cancels the update lane and names the boundary, `StartWorkspaceJob` returns a refused state. Risk: medium, user-visible behavior changes; add a README bullet per the Desktop README rule.
8. **Desktop #24-#27.** Kill the child on handshake timeout and close the old Job handle; restart the App on apply failure; subscribe `ActivationRequested` in `App.xaml.cs`; treat "service not installed" as not-an-error in `Success`. Risk: low.
9. **Remaining P2 and P3** as time allows; #16, #17, #20 first because they affect data on disk.

## 5. Documentation status

Fixed in this pass (uncommitted):

- `GrayMoon/docs/architecture/07`: change-count cap is `MaxChangesPerSnapshot` (15,000), not "none".
- `GrayMoon/docs/architecture/04`: `ContextGitChangesUpdated` carries a fourth `contentDigest` argument; Remove marks `Removing` before `UninitCodeGraph`.
- `GrayMoon/docs/architecture/03`: `synchronous=NORMAL` is startup-only; the interceptor re-applies only `busy_timeout` and `foreign_keys`.
- `GrayMoon.Desktop/docs/architecture/02`: origin gate also covers `RestartWorker`.
- `GrayMoon.Desktop/docs/architecture/04`: About-dialog hyperlink exception; test list adds `LatestReleaseGithubSourceTests` and `WorkspaceContextTests`.
- Baseline hashes in both architecture `README.md` files moved to the current HEADs.
- Earlier in this pass: `GrayMoon/CLAUDE.md` deployment modes and DB paths, `.cursor/README.md` rule row, the push-package-wait defect note, and the `docs/documentation-update` status section.

Left as documented intent, because the code is the thing to fix: Desktop single-instance activation (#26), Switch Branch occupancy on the Remotes tab, hook-listener trust boundary (#22), cancel latency under a full pool (#23), toast scoping (#15), and the Actions idle-tier polling description in doc 04 section 14 (the tracker is mounted in the static layout, so idle polling cannot run; decide whether to fix the mount or the doc).

Still open from the documentation plan: screenshots (phase 1), changelog location (phase 2 decision), the `Shared-Chrome.md` sample tag, and the root README.
