# Summary of the 2026-11-10 code review fixes

This is the only document kept from the 2026-11-10 code review. The review, its fix plan and its follow-up were deleted on 2026-11-11 when the work was closed. Everything was done on the `code-review-fixes` branch of `GrayMoon` and `GrayMoon.Desktop`.

Keep this file while manual testing is going on. When testing shows a problem, use section 1 to find the fix that most likely caused it, then the numbered tables for the files and tests. Delete the file when manual testing is signed off (section 8 says what to clean up with it).

Finding numbers (#1 to #33, N1 to N9) are kept because code comments, test comments and the bracketed numbers in `GrayMoon/AGENTS.md` and `GrayMoon.Desktop/CLAUDE.md` refer to them ("review 2026-11-10, finding 18", `[13]`).

App paths are under `GrayMoon/src/GrayMoon.App/`, Worker paths under `GrayMoon/src/GrayMoon.Worker/`, Desktop paths under `GrayMoon.Desktop/src/GrayMoon.Desktop/`. The "Fix" columns give the planned fix, corrected where the review recorded a different outcome. Test names are given where a test file cites the finding; a dash means none was recorded here.

## 1. If manual testing shows a problem

Behavior that a user can notice changed in these places. Start with the row that matches the symptom.

| Symptom | Most likely fix | Look at |
|---|---|---|
| Browser shows "GrayMoon does not accept requests for this host name..." (403) | N1 request host check. The name typed in the browser, or the name a reverse proxy sends as `Host`, is not loopback and not in `GRAYMOON_AllowedHosts`. | `Services/Security/RequestSecurityMiddleware.cs` (`IsRequestHostAllowed`), `GrayMoon/docs/architecture/05-user-capability-reference.md` section 33 |
| Page loads but buttons or live updates do nothing from another machine (403 on `/_blazor`, hubs or non-GET `/api`) | #7 Origin rule: the Origin host must be loopback or listed. Equality with `Host` or `X-Forwarded-Host` is no longer enough. | same file (`IsAllowedHost`) |
| Worker cannot connect, or the connector token request is refused | #7 and P3: the Worker secret is required from the first start; `GET /repos/{id}/connector` always needs it. Pair the Worker again from the Worker page. | `Services/Security/WorkerSecretMiddleware.cs`, `Api/Endpoints/ConnectorEndpoints.cs` |
| Amber toast "Another operation is still running, so this one was not started. Try again when it finishes." appears when nothing seems to run | #12 and N2. A job for the page key is still `Running`, or the Workspace or context lock is held (another tab, a background job). | `Services/Jobs/BackgroundJobService.cs` (`StartRefusedMessage`), `WorkspaceOperationRunner` |
| An action does nothing and shows no toast | Same area: the caller has its own `IsJobRunning` guard and returned early before `StartJob`. | the page's `Start...Job` helper |
| Toast appears in one tab only | #15, intended: `IToastService` is per circuit. A toast raised from a fresh DI scope reaches no one. | `Services/Ui/ToastService.cs`, `Components/Shared/Toast.razor` |
| Repositories grid does not refresh after a job, or shows the previous Feature's rows | #4, #13, #14, N4: reloads are load-then-apply and are dropped when the page is disposed or the context changed. | `Components/Pages/WorkspaceRepositories.Loading.cs` (`LoadWorkspaceReloadSnapshotAsync`, `ApplyWorkspaceReloadSnapshotAsync`), `PageStateApplyGuard` |
| Dependency tooltip stays empty after switching Feature while it loads | N4, intended: the result of the old context is dropped; hover again. | `WorkspaceRepositories.Loading.cs` (`EnsureTooltipDataForRepoAsync`) |
| Actions or Repositories page does not refresh live after a Sync in another tab | #5: the hub is attached at the end of the load, no longer only on first render. This was fixed by reading the code and never checked by hand. | `Components/Pages/WorkspaceActions.razor.cs`, `WorkspaceRepositories.Realtime.cs` |
| Connector refresh reports "Skipped: ... left unchanged" and repositories are not removed | #1, intended: a connector whose fetch failed deletes nothing. | `Services/GitHub/GitHubRepositoryService.cs`, `Repositories/RepositoryRepository.cs` |
| Push or Update finishes with a warning "Package restore failed for ..." | #8, intended: a failed `dotnet restore` is now reported; the level still completes. | `Commands/DotnetRestoreCommand.cs` (Worker), `Services/Workspaces/WorkspacePushService.cs` |
| Update and Push stops updating higher levels after a push failure | #11, intended: a push-lane fault cancels the update lane at the next level boundary and the message names the level. | `Services/Orchestration/UpdateAndPushOrchestrator.cs` |
| Synchronized push waits longer on a flaky network instead of failing | #10, intended: a transport error during the package wait counts as "not yet"; the deadline still applies. | `WorkspacePushService.cs` (package wait) |
| Remove Feature skips a repository with "changed since the check, run Remove again" | #18, intended: repositories not shown dirty in the dialog are probed again when the removal runs. | `Services/Features/WorkspaceFeatureOperations.cs` |
| Feature folder remains after Roll back with a `GRAYMOON-PENDING-DELETE.md` marker | #19, intended: the folder is marked and swept later; Create with the same name finishes it first. | same file, `FeatureFolderCleaner` (Worker) |
| App stops at startup with a message that names a backup path | #17, intended: a backup that cannot be written or fails the integrity check stops the migration. | `Migrations.cs` |
| Files page lost rows after a repository was unlinked | #16, intended: unlink also deletes the repository's file, config and line-status rows. | `Repositories/WorkspaceRepositoryLinkCleanup.cs` |
| A git hook POST is answered 400, 413 or 415 | #22: 64 KB body cap, `application/json` required, `repositoryPath` must be under a known workspace root or carry a matching GrayMoon hook. | `Hosted/HookListenerHostedService.cs` (Worker) |
| A Worker command fails with a path validation error | #21: every App-supplied relative path and repository name is validated. | `GitRepositoryPathValidator`, `RepositoryPathContainment` (Worker) |
| "Update branch from default" refuses in a Feature because a merge is in progress | #20, intended: `MERGE_HEAD` is now found in a worktree too. | `Commands/UpdateBranchFromDefaultCommand.cs` (Worker) |
| Commands fail right after a Worker restart | #32: commands are routed to the newest Worker connection and only that connection's commands fail on its disconnect. | `Services/Worker/WorkerConnectionTracker.cs`, `Hubs/WorkerHub.cs` |
| Abort does not stop a queued Worker command | #23: the `RequestCommand` handler no longer waits for queue room, so `CancelCommand` is delivered at once. | `Hosted/SignalRConnectionHostedService.cs` (`CommandRequestIntake`) |
| Worker logs connect retries but hooks work while the App is down | N6 (b), intended: Worker start no longer waits for the App. | same file (`StartAsync`, `ConnectTask`) |
| Actions page polls slowly while the tab or window is in the background | Idle tier, intended: `AppActivityTracker` now has a render mode, so the idle tier runs. | `Components/Layout/MainLayout.razor`, doc 04 section 14 |
| Desktop: second launch does not bring the window forward | #26 | `App.xaml.cs`, `Services/SingleInstanceService.cs` |
| Desktop: Retry after a slow first start fails with exit code 62 | #24: a failed start must kill the App child. | `Services/AppProcessManager.cs` |
| Desktop: failed update leaves a blank window | #25: the App is restarted or the Retry overlay is shown. | `Services/VelopackUpdateService.cs` |
| Desktop: Install All reports failure although every step ran | #27 | `Services/HostPrerequisiteInstaller.cs` |
| Desktop: Install or Restart Worker button does nothing | #6: privileged commands are accepted only from the App's loopback origin, checked on the parsed message. | `MainWindow.xaml.cs`, `Services/WebViewMessageSourceValidator.cs` |
| Desktop release workflow fails on "environment" or on an unknown App tag | #33: signing jobs require the `production` environment; the bundled App is pinned in `build/graymoon-app-version.txt`. The workflow has never been run. | `GrayMoon.Desktop/.github/workflows/release.yml` |

## 2. P1 findings

| # | What was wrong | Fix | Tests |
|---|---|---|---|
| 1 | Connector refresh deleted the repositories of a connector whose fetch failed. | Only connectors that answered contribute deletions; a failed one is reported as skipped. | `GitHubFanOutTests` |
| 2 | Post-push bookkeeping read branch and tag from the shared link and wrote `BranchHasUpstream` to it for any context. | Branch and tag come from the context state; writes go through `WorkspaceRepositoryStateWriter`. `WorkspaceCommitSyncHandler` sync errors follow the same rule. | `ServiceConventionTests` (guardrail 5) |
| 3 | `WorkerConnectionTracker` handlers were never removed by the badge and the layout. | Removed in `Dispose`; no subscription during prerender. | `ServiceLifetimeAndConnectionPlumbingTests`, `ComponentConventionTests` (guardrail 1) |
| 4 | Job bodies swapped page collections on the thread pool. | Reload is a load step into `WorkspaceReloadSnapshot` and an apply step inside `InvokeAsync` behind `PageStateApplyGuard`. | `WorkspacePageJobDisciplineTests`, `ComponentConventionTests` (guardrails 2 and 3) |
| 5 | Hub creation and the background refresh were gated on the first render, which happens before the load ends. | Attached at the end of the load on the Actions and Repositories pages. Confirmed by reading only. | - (manual check owed, section 6) |
| 6 | Desktop origin gate read `"command"` case-sensitively while the bridge is case-insensitive. | One parse with the bridge's options; the gate checks the parsed command. | `PrivilegedWebMessageGateTests` |
| 7 | An Origin equal to the request Host was accepted and Docker had no host allowlist. | Origin must be loopback or listed in `GRAYMOON_AllowedHosts`; `X-Forwarded-Host` equality dropped; empty list means loopback only with one startup warning; the connector endpoint always requires the Worker secret. | `RequestSecurityMiddlewareTests`, `WorkerSecretTests` |

## 3. P2 findings

| # | What was wrong | Fix | Tests |
|---|---|---|---|
| 8 | Failed `dotnet restore` returned success and the App ignored the response. | Worker returns `Success=false` with the error tail; the App adds a level warning. | `WorkerInputValidationTests` |
| 9 | Cancellation was registered before the pending entry existed. | Entry added first; an already-cancelled token removes it at once. | `ServiceLifetimeAndConnectionPlumbingTests` |
| 10 | Package wait rethrew NuGet transport errors. | Transport errors count as "not yet"; the last one is named in the timeout message. | - |
| 11 | A push-lane fault was seen only after the update lane finished. | The fault cancels the update lane at the next level boundary; the message names the boundary. | - |
| 12 | A refused job start returned the other operation's handle and looked like it ran. | `BackgroundJobHandle.WasStarted`; the refusal is logged and (N2) shown as a warning toast. | `ServiceLifetimeAndConnectionPlumbingTests` |
| 13 | `RequireSelectedContextId()` was read inside job bodies. | Captured into a local before the job is queued, on the Repositories and Git Changes pages. | `WorkspacePageJobDisciplineTests` |
| 14 | `repoSyncStatus` was written from the job thread. | Written through `SafeInvoke`. | `WorkspacePageJobDisciplineTests` |
| 15 | `IToastService` was a singleton with mutable state. | Scoped (one per circuit); scope validation is on in Development. | `ServiceLifetimeAndConnectionPlumbingTests`, `ServiceConventionTests` (guardrail 4) |
| 16 | Unlink left Files page rows behind. | Unlink deletes `WorkspaceFiles`, `WorkspaceFileVersionConfigs` and `WorkspaceFileLineStatuses` for the link. | `WorkspaceRepositoryLinkCleanupTests` |
| 17 | `VACUUM INTO` failure surfaced raw; a failed integrity check only logged. | Both stop the migration with `DatabaseMigrationException` naming the backup path. | `MigrationsRunnerTests` (failed backup; the failed integrity check has no test) |
| 18 | Remove Feature forced every repository with the choice made at analysis time. | Repositories shown dirty in the dialog are still forced; every other repository is probed again and skipped when it became dirty. | `RemoveFeatureReportTests` |
| 19 | Roll back left the Feature folder when it held a non-worktree file. | The folder is marked pending-delete. Confirmed by reading. | `WorkspaceFeatureRepairTests` |
| 20 | `MERGE_HEAD` was looked up under `.git` as a directory. | Resolved with `git rev-parse --git-path`. | - |
| 21 | Three Worker commands used App-supplied paths without validation; restore interpolated the path. | `GitRepositoryPathValidator` on every path, `ArgumentList` for restore, repository names validated, writes through a link that leaves the repository refused. Reads through such a link are still open (doc 06 known gaps). | `WorkerInputValidationTests`, `WorkerRepositoryNameAndLinkValidationTests`, `RequestPathValidationConventionTests` (guardrail 6) |
| 22 | Hook listener had no body cap and trusted `repositoryPath`. | 64 KB cap, JSON content type, path accepted under a known workspace root or with a matching GrayMoon hook. | `WorkerInputValidationTests` |
| 23 | `RequestCommand` awaited queue room inside the SignalR handler, delaying `CancelCommand`. | The handler registers the request, starts the queue write and returns; nothing is rejected. | `CommandRequestIntakeTests` (intake level; serial handler dispatch not tested) |
| 24 | Desktop handshake timeout left the App child alive. | Every failure path after start kills the process tree; one Job Object per manager. | `ProcessLifecycleTests` |
| 25 | Desktop update failure left the WebView on a stopped App. | The failure path restarts the App or shows the Retry overlay. | `ProcessLifecycleTests` |
| 26 | `ActivationRequested` had no subscriber. | `App.xaml.cs` subscribes and activates the main window on the UI thread. | `ProcessLifecycleTests` |
| 27 | Install All reported failure when the Worker service was not installed yet. | "Service not installed" from the restart step is not an error. | `HostPrerequisiteInstallerHardeningTests` |
| 28 | Reopening the logs modal mixed jobs of two runs. | Generation guard and cancellation per open. | `ModalAndSharedUiGuardTests` |
| 29 | Notification panel computed warnings from a 100-capped list and from special-Workspace columns. | Full repository set; Feature values from the context state. Confirmed by reading. | - |
| 30 | Git Changes write queue reader ended on any `OperationCanceledException`. | Only the stopping token ends the reader. | `ServiceLifetimeAndConnectionPlumbingTests` |
| 31 | stdin write was outside the `IOException` catch. | An early process exit returns the exit-code result. | - |
| 32 | Commands were routed to the old Worker connection during a restart overlap, then failed with it. | The newest connection is the active one; a disconnect fails only that connection's commands. | `ServiceLifetimeAndConnectionPlumbingTests` |
| 33 | Signing secrets readable from a branch dispatch; stable tags bundled `releases/latest`. | App pinned by `build/graymoon-app-version.txt`; signing jobs require the `production` environment. **Open:** the secrets are still repository secrets and the workflow has not been run (section 7). | - |

## 4. P3 hardening (all fixed)

- **App startup and data:** Worker secret required by default; tolerant migration catch clears the change tracker and covers the role and fork steps; an empty database gets no `.bak`; a GitHub GET that hits the per-request timeout is retried once, not three times (`GitHubGetRetryTests`).
- **Components:** `GhaWorkflowLiveTerminal` poll loop survives errors and restarts on a `RunId` change; `LoadingOverlay` interop tolerates a disconnected circuit; `ConnectorModal` Enter in Delete mode is guarded; `AddFilesModal` search is not dropped in flight; `Workspaces.razor` focuses once; `SwitchBranchModal` checks occupancy on the Remotes tab (`ModalAndSharedUiGuardTests`).
- **AI and Git Changes:** recent commit subjects go through `Sanitize` and `EvidenceRedactor`; the snapshot version gate no longer skips the context tables; Cancel and Finish share one dispose path; provider lookup hardened; line-stats CTS swap is atomic; the image embedder downloads the raw URL (any http(s) host, 2 MB cap, a documented choice) (`AiAndGitChangesSweepTests`).
- **Features:** the reconciler asks `IFeatureRemovalQueue.IsPending`; a removal interrupted by shutdown is picked up again; the sweep-versus-add window is closed on the add side (`PathUnderRemoval`); `_finishedInits` is pruned (`WorkspaceFeatureReconcilerTests`).
- **Worker:** the reconnect loop observes shutdown; post-push and undo-push scans are awaited inside the job; ref names are passed after `--`; the pre-cancelled CTS leak and the dead token cache are gone.
- **Desktop:** tray and notification updates go through the UI dispatcher; `IsValidRelativePath` rejects `//host/path`; helper result paths must be rooted and carry the expected file name; profile paths with `&` or `^` are quoted; the test-gate scripts are called by `release.yml` (`HostPrerequisiteInstallerHardeningTests`, `ProcessLifecycleTests`).

## 5. Follow-up fixes (2026-11-11)

A second read of the branch found gaps in the fixes above. Four were fixed; the rest are open notes (section 7).

| # | What was wrong | Fix | Tests |
|---|---|---|---|
| N1 | The #7 fix checked `Origin` only. With an empty allowlist (Docker default) a DNS-rebinding page, which is same-origin and sends no `Origin` on GET, could read pages and `GET /api/...` data. | `RequestSecurityMiddleware` rejects (403, plain text naming `GRAYMOON_AllowedHosts`) any request whose `Host` is neither loopback nor listed, on every path and method. `/health` and the Worker paths are exempt. A proxy that replaces `Host` with its upstream name must have that name listed. | `RequestSecurityMiddlewareTests` ("Host rule") |
| N2 | Nothing read `WasStarted`, so a refused start still looked like it ran. | `BackgroundJobService` shows a warning toast in the tab that asked. | `ServiceLifetimeAndConnectionPlumbingTests` |
| N4 | Three Repositories page handlers read the context after an `await`. | The tooltip load, the custom-dependency save and the push badge lookup capture the context first; the tooltip load drops a stale result. Confirmed by reading and by the source scan, not by a behavioral test. | `WorkspacePageJobDisciplineTests` (allowlist shrunk) |
| N6 (b) | Worker `StartAsync` awaited the connect loop, so the hook listener and job pools did not start while the App was down. | `StartAsync` returns; the loop runs in the background and ends on shutdown. | `CommandRequestIntakeTests` (`Start_returns_while_the_App_is_down_and_stop_ends_the_connect_loop`) |

## 6. Verification state and manual checks

- GrayMoon solution: builds with 0 warnings; Common 393, Worker 996 (1 skipped) and App 2017 tests pass with every fix above (2026-11-11).
- Desktop solution: not rebuilt or retested after the follow-up fixes; only its `README.md` changed then.
- The four follow-up tests were not run against the old code.
- No fix was exercised in a browser or in Desktop. Manual checks that no test covers:
  - #5: open Actions, run a Sync from another tab, the grid refreshes.
  - #15: two browser tabs, a toast shows only in the tab that raised it.
  - #24: slow first start, then Retry works.
  - #26: a second launch activates the running window.
  - #22: a 1 MB body posted to `127.0.0.1:9191` gets 413.
  - N1: Docker container without `GRAYMOON_AllowedHosts` opens from `http://localhost:8384` and refuses another host name; with the variable set, the listed name works; a Worker on another machine still connects.
  - N2: click an action twice quickly, the second click shows the amber toast.

## 7. Still open

| Item | Where it is tracked |
|---|---|
| #33 / N9: move `ESIGNER_*` to the `production` environment, delete the repository secrets, run the release workflow from a branch and from a stable tag | `GrayMoon/docs/todo/defects/release-signing-secrets-and-workflow-run.md` |
| #17 failed-integrity-check test, #23 serial-dispatch test, N4 behavioral test, follow-up tests against the old code | `GrayMoon/docs/todo/defects/review-fix-test-gaps.md` |
| N5: a connector that answers with zero repositories | `GrayMoon/docs/todo/defects/connector-refresh-empty-answer.md` |
| N6 (a): Worker response dropped while reconnecting | Fixed 2026-11-11 on `outstanding-bugs` (logged; see `GrayMoon/docs/architecture/04-runtime-communication-and-concurrency.md`) |
| N7: silent catch blocks | Fixed 2026-11-11 on `outstanding-bugs`; the scan widening is in `GrayMoon/docs/todo/defects/convention-test-coverage.md` |
| N3: convention tests cover less than the rules | `GrayMoon/docs/todo/defects/convention-test-coverage.md` |
| #21 remainder: reads through a link that leaves the repository | `GrayMoon/docs/architecture/06-developer-extension-guide.md`, "Known gaps" |

## 8. When this file is deleted

- Reword the comments that cite the review ("review 2026-11-10", "finding N", "Guardrail N") in about 35 source and test files of both repositories as plain statements of the rule.
- Remove the pointers to this file and the bracketed finding numbers from the workspace root `CLAUDE.md` and `AGENTS.md`, `GrayMoon/AGENTS.md` ("Rules from the 2026-11-10 code review"), `GrayMoon/CLAUDE.md`, `GrayMoon/.cursor/rules/*.mdc`, `GrayMoon/.github/copilot-instructions.md`, `GrayMoon.Desktop/CLAUDE.md` and `GrayMoon.Desktop/AGENTS.md`.
- Delete the `docs/code-review` folder and check with a search for `code-review` and `2026-11-10`.
