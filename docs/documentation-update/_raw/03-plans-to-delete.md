# Planning docs to delete

Checked 2026-11-05. No file was deleted, moved, or edited except this findings file. Nothing was committed or pushed.

Search covered `GrayMoon/docs/` (architecture and `docs/todo/`), `GrayMoon.Desktop/docs/`, the workspace `docs/` folder (empty aside from this documentation-update output), filenames and headings containing plan, todo, proposal, prompt, design, spec, draft, WIP, or future, and agent instruction files under `.cursor`, `.claude/skills`, and `.github/copilot-instructions.md`. `bin`, `obj`, `node_modules`, `.git`, and build artifacts were skipped. `GrayMoon.wiki` is user documentation (Getting Started, Workspace pages, walkthroughs), not draft plans, so its pages are not candidates. Code was checked with the GrayMoon codegraph index and with source reads.

Cited plans that are already gone, so they are not on any list: `GrayMoon/docs/workspace-profiles/Workspace-Profiles-Implementation-Plan.md`, `GrayMoon/docs/worker-install/GrayMoon-Worker-Install-Race-Investigation.md`, and `CODE_REVIEW.md`.

Counts: IMPLEMENTED 0, PARTIAL 2, NOT IMPLEMENTED 5, UNCERTAIN 0. Living architecture references (13 files) are KEEP and are not in those counts.

## TO DELETE

None. No todo, proposal, or prompt document is fully present in the current tree as the behavior or artifact it proposes. The delete list is empty.

## PARTIAL

Update these. Do not delete them. Shipped pieces are already described in `docs/architecture/`; the notes below are what is still open.

### `GrayMoon/docs/todo/pr-description-commit-history.md`

- Proposes subject-first pull-request history: a whole-commit subject rule, oldest-first subjects with shortstat, cross-repo condensing, and an optional later step that reads a few commit bodies.
- Status: PARTIAL (update, do not delete)
- Evidence: Steps 1 to 3 are in the tree. `AiPromptBuilder.CommitSystemPrompt` requires the subject to "summarize the entire commit". `GitEvidenceCommit` and `GitEvidenceLimits.MaxHistoryCommits` (default 200) live in `GrayMoon.Common/Ai/GitEvidenceModels.cs`, whose comment says "Bodies are never read." `CommitHistoryCondenser` folds fixups and drops revert pairs. `GitEvidenceCollector.ReadHistoryAsync` caps history. Current behavior is in `docs/architecture/05-user-capability-reference.md` (CollectGitEvidence oldest-first, no bodies; condenser; 20% history budget). Step 4, reading bodies as a fallback, is still absent, and the note itself says that step is open. Sections 1 and 2 still describe the pre-change pipeline.

### `GrayMoon/docs/todo/push-package-wait-and-circuit-crash.md`

- Proposes fixes for a package wait that shrank its deadline, a Blazor circuit crash on hub start, Open-in buttons that appeared in a browser, and push failures that vanished when the user left the Repositories page.
- Status: PARTIAL (update, do not delete)
- Evidence of what shipped:
  - P1: `WorkspacePushService.cs` extends the deadline only when the new budget is later ("never less time than is already left").
  - P3: `PackageWaitTimeout.FormatMessage` names missing packages and says to run Push Synchronized again, with no CI product name.
  - C1 and C4 for three pages: `WorkspaceSyncHubConnectionHelper.TryStartAsync` is not awaited from `WorkspaceRepositories.Realtime.cs`, `WorkspaceActions.razor.cs`, and `WorkspaceGitChanges.Realtime.cs`. `ResolveHubUri` rewrites `localhost` to `127.0.0.1`.
  - O1, by the user-agent option the note allowed: `MainWindow.xaml.cs` appends `GrayMoonDesktop` to the WebView user agent, and `WorkspaceOpenInRecentTools.DesktopUserAgentToken` paints Open in only for that client.
  - T1 to T3: `WorkspaceOperationOutcomeStore` plus `OperationOutcomeBanner` / `Describe()` and Dismiss on the Repositories page. `docs/architecture/01-product-model-and-user-workflows.md` and `04-runtime-communication-and-concurrency.md` record the store and the non-shrinking wait.
- Evidence of what is still open:
  - `WorkspaceActionNotificationPanel.razor` still `await`s `StartAsync()` inside `OnAfterRenderAsync` (try/catch, not `TryStartAsync`).
  - `TryStartAsync` does not retry, does not take a cancellation token, and does not log circuit id, host, or elapsed time. No test references `WorkspaceSyncHubConnectionHelper`.
  - No "Continue waiting" action.
  - The wiki still says 3 minutes per package and talks about CI (`Workspace-Repositories.md`, `Workspace-Prepare-Workspace.md`). Code default is `PushWaitDependencyTimeoutMinutesPerDependency = 5.0` in `WorkspaceOptions.cs`.

## KEEP

### NOT IMPLEMENTED

#### `GrayMoon/docs/todo/connector-token-failure-handling.md`

- Proposes a shared `ConnectorFailureKind` / `ConnectorFailureClassifier`, a `ConnectorFailureReporter` that marks the connector unhealthy at runtime, `errorKind` on git command responses, and a NuGet result that does not treat 401 as "package absent".
- Status: NOT IMPLEMENTED (keep)
- Evidence: Those types are not in the tree. The only `errorKind` fields are on AI generation responses (`AiResponses.cs`, `WorkspaceAiGenerationOperations.cs`), not connector auth. `NuGetService.PackageExistsAsync` still returns `Task<bool>`. `AuthenticationFailed` exists as a package-lookup kind, which the note already described as diagnostics-only.

#### `GrayMoon/docs/todo/generated-package-context-write.md`

- Proposes stopping a Feature that cannot see a version file from deleting workspace-global generated packages, and stopping one context's resolved version from being written onto every consumer edge.
- Status: NOT IMPLEMENTED (keep)
- Evidence: `WorkspaceFileVersionService.SyncGeneratedPackageDependenciesAsync` still overlays that context's missing-file flags, and when no `.csproj` version files remain it calls `WorkspaceProjectRepository.SyncGeneratedPackageDependenciesAsync(workspaceId, [])`. That repository method still deletes generated `WorkspaceProject` rows whose key is not in the desired set (`RemoveRange(toRemoveGenerated)`) and writes the calling context's version onto matching edges. It does not take a context id for the write.

#### `GrayMoon/docs/todo/git-changes-large-changeset-scale.md`

- Keeps the unbuilt scale follow-ups after Phase 3a: a manual 20K check, persisted folder summaries, snapshot chunking and deltas, and leftover tests. The note says the built path is already in the architecture docs.
- Status: NOT IMPLEMENTED (keep)
- Evidence: No `WorkspaceGitContextFolderSummaries`, `GetGitChangePathsPage`, or `PathsTransferId` in `GrayMoon/src`. `docs/architecture/06-developer-extension-guide.md` still points at this file for the unscheduled follow-ups, and `docs/architecture/07-git-changes-projection-and-tree.md` is the current-behavior reference.

#### `GrayMoon/docs/todo/sqlite-synchronous-per-connection.md`

- Proposes setting `PRAGMA synchronous=NORMAL` on every SQLite connection, not only the startup connection.
- Status: NOT IMPLEMENTED (keep)
- Evidence: `Program.cs` still runs `PRAGMA synchronous=NORMAL` once at startup. `SqliteConnectionPragmasInterceptor.Apply` sets `busy_timeout` and `foreign_keys` only. Its comment still says `synchronous` persists. `docs/architecture/03-data-model-and-persistence.md` still lists that startup PRAGMA with the other startup settings.

#### `GrayMoon/docs/todo/worker-damaged-install-probe.md`

- Proposes one Worker startup probe that reports a damaged install and asks for a single reinstall, instead of failing later repository calls one by one.
- Status: NOT IMPLEMENTED (keep)
- Evidence: No damaged-install probe type or startup check in App or Worker source. Existing "Reinstall the Worker" text is the worker-secret path (`WorkerSecretMiddleware`, `WorkerTokenProvider`, `WorkerStatusText`), which this note already separates from the probe.

### Living architecture (KEEP even where the feature has shipped)

These describe current behavior. They are not delete candidates.

- `GrayMoon/docs/architecture/README.md` - index of the current-state architecture set. It says unbuilt work lives in `docs/todo/`.
- `GrayMoon/docs/architecture/01-product-model-and-user-workflows.md` - product model and user workflows, including the shipped package-wait and operation-outcome behavior.
- `GrayMoon/docs/architecture/02-system-architecture.md` - process boundaries and service layering, including the outcome record on Update and Push.
- `GrayMoon/docs/architecture/03-data-model-and-persistence.md` - SQLite model and migrations. The synchronous-pragma gap above is still described here as current setup.
- `GrayMoon/docs/architecture/04-runtime-communication-and-concurrency.md` - hubs, locking, and the one-outcome-per-run rule.
- `GrayMoon/docs/architecture/05-user-capability-reference.md` - page and operation reference, including shipped AI history generation.
- `GrayMoon/docs/architecture/06-developer-extension-guide.md` - rules for changing the product. Section 24 is an open gap list, still accurate as a living list, not a finished proposal.
- `GrayMoon/docs/architecture/07-git-changes-projection-and-tree.md` - current Git Changes pipeline. Unbuilt scale work stays in the todo note above.
- `GrayMoon.Desktop/docs/architecture/README.md` - Desktop current-state index.
- `GrayMoon.Desktop/docs/architecture/01-product-and-host-behavior.md` - host behavior, including the WebView bridge.
- `GrayMoon.Desktop/docs/architecture/02-runtime-architecture-and-integration.md` - Desktop process, pipe, and hub integration.
- `GrayMoon.Desktop/docs/architecture/03-build-bundle-updates-and-distribution.md` - bundle, updates, and distribution as they work now.
- `GrayMoon.Desktop/docs/architecture/04-developer-extension-guide.md` - Desktop change rules. Section 18 is an open gap list (unused manifest service, bridge commands the App never sends, no installer lock in process).

### Agent instructions (not obsolete feature prompts)

Do not delete. They still govern how agents edit the product. None of them is a finished feature spec.

- `GrayMoon/.cursor/rules/*.mdc` and `GrayMoon/.cursor/README.md` - coding rules (EOL, DbContext, feature context, facades, no commit).
- `GrayMoon/.claude/skills/add-worker-command/SKILL.md` - current recipe for adding a Worker command.
- `GrayMoon/.github/copilot-instructions.md` - short pointer at `CLAUDE.md`, `AGENTS.md`, and `docs/architecture/`.
- Workspace `.cursor/rules/update-desktop-readme.mdc` - still requires the Desktop README bullet after a behavior change.

## UNCERTAIN

None. Every candidate above was matched to a type, method, UI string, or architecture section in the current tree, or confirmed absent.
