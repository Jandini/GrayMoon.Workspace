# Plans to delete

Checked 2026-11-05 against `GrayMoon/docs/`, `GrayMoon.Desktop/docs/`, the workspace `docs/` folder, and the agent instruction files. Counts from that pass: IMPLEMENTED 0, PARTIAL 2, NOT IMPLEMENTED 5, UNCERTAIN 0. The 13 architecture files are a separate KEEP and are outside those counts.

Wiki pages are the user guide. Update them from [wiki-0.2.0.md](wiki-0.2.0.md). Leave every wiki page in place.

## TO DELETE

None. No todo, proposal, or prompt document is fully present in the current tree.

## PARTIAL (update, do not delete)

Shipped pieces are already described in `docs/architecture/`. Update the note so the open remainder is what a reader sees.

### `GrayMoon/docs/todo/pr-description-commit-history.md`

Proposes subject-first pull-request history: a whole-commit subject rule, oldest-first subjects with shortstat, cross-repo condensing, and an optional later step that reads a few commit bodies.

**Shipped.** Steps 1 to 3 are in the tree.

- `AiPromptBuilder.CommitSystemPrompt` requires the subject to "summarize the entire commit".
- `GitEvidenceCommit` and `GitEvidenceLimits.MaxHistoryCommits` (default 200) live in `GrayMoon.Common/Ai/GitEvidenceModels.cs`. The comment says "Bodies are never read."
- `CommitHistoryCondenser` folds fixups and drops revert pairs.
- `GitEvidenceCollector.ReadHistoryAsync` caps history.
- Current behavior is in `docs/architecture/05-user-capability-reference.md` (CollectGitEvidence oldest-first, no bodies; condenser; 20% history budget).

**Still open.** Step 4, reading bodies as a fallback, is absent. The note says that step is open. Sections 1 and 2 of the note still describe the pre-change pipeline. Rewrite those two sections so they match architecture `05`, and leave step 4 as the open work.

### `GrayMoon/docs/todo/push-package-wait-and-circuit-crash.md`

Proposes fixes for a package wait that shrank its deadline, a Blazor circuit crash on hub start, Open-in buttons that appeared in a browser, and push failures that vanished when the user left the Repositories page.

**Shipped.**

- P1: `WorkspacePushService.cs` extends the deadline only when the new budget is later ("never less time than is already left").
- P3: `PackageWaitTimeout.FormatMessage` names missing packages and says to run Push Synchronized again, with no CI product name.
- C1 and C4 on three pages: `WorkspaceSyncHubConnectionHelper.TryStartAsync` is not awaited from `WorkspaceRepositories.Realtime.cs`, `WorkspaceActions.razor.cs`, and `WorkspaceGitChanges.Realtime.cs`. `ResolveHubUri` rewrites `localhost` to `127.0.0.1`.
- O1, by the user-agent option the note allowed: `MainWindow.xaml.cs` appends `GrayMoonDesktop` to the WebView user agent, and `WorkspaceOpenInRecentTools.DesktopUserAgentToken` paints Open in only for that client.
- T1 to T3: `WorkspaceOperationOutcomeStore` plus `OperationOutcomeBanner` / `Describe()` and Dismiss on the Repositories page. Architecture `01` and `04` record the store and the non-shrinking wait.

**Still open.**

- `WorkspaceActionNotificationPanel.razor` still awaits `StartAsync()` inside `OnAfterRenderAsync` (try/catch, and it does not call `TryStartAsync`).
- `TryStartAsync` has no retry, no cancellation token, and no log of circuit id, host, or elapsed time. No test references `WorkspaceSyncHubConnectionHelper`.
- No **Continue waiting** action.
- The wiki still says 3 minutes per package and talks about CI (`Workspace-Repositories.md`, `Workspace-Prepare-Workspace.md`). The code default is 5.0 minutes. That wiki fix is in [wiki-0.2.0.md](wiki-0.2.0.md). Leave it in this note until the wiki matches, so the note stays the open-work list.

## KEEP

### Open todo notes

- `GrayMoon/docs/todo/connector-token-failure-handling.md` - `ConnectorFailureKind`, `ConnectorFailureClassifier`, and `ConnectorFailureReporter` are absent. `NuGetService.PackageExistsAsync` still returns `Task<bool>`.
- `GrayMoon/docs/todo/generated-package-context-write.md` - A Feature that cannot see a version file can still delete workspace-global generated package rows, and one context's version is still written onto every matching consumer edge.
- `GrayMoon/docs/todo/git-changes-large-changeset-scale.md` - The manual 20K check, persisted folder summaries, and snapshot chunking are still absent. Architecture `07` is the current pipeline. Architecture `06` still points here for the unscheduled follow-ups.
- `GrayMoon/docs/todo/sqlite-synchronous-per-connection.md` - `PRAGMA synchronous=NORMAL` still runs once at startup in `Program.cs`. `SqliteConnectionPragmasInterceptor.Apply` sets `busy_timeout` and `foreign_keys` only.
- `GrayMoon/docs/todo/worker-damaged-install-probe.md` - No startup probe reports a damaged install and asks for one reinstall. Existing "Reinstall the Worker" text is the worker-secret path.

The 13 architecture files under `GrayMoon/docs/architecture/` and `GrayMoon.Desktop/docs/architecture/` stay, because they are the living reference for current behavior.

Agent rule files stay, because they still govern edits: `GrayMoon/.cursor/rules/*.mdc`, `GrayMoon/.cursor/README.md`, `GrayMoon/.claude/skills/add-worker-command/SKILL.md`, `GrayMoon/.github/copilot-instructions.md`, and the workspace rule `update-desktop-readme.mdc`.

## Already gone

These paths were cited and are already absent. There is nothing to delete:

- `GrayMoon/docs/workspace-profiles/Workspace-Profiles-Implementation-Plan.md`
- `GrayMoon/docs/worker-install/GrayMoon-Worker-Install-Race-Investigation.md`
- `CODE_REVIEW.md`

## UNCERTAIN

None. Every candidate was matched to a type, method, UI string, or architecture section in the current tree, or confirmed absent.
