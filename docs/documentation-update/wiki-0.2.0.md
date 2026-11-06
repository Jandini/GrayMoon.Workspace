# Wiki plan for 0.2.0

The local wiki (`GrayMoon.wiki`, `master` at `59df2e4`) describes the 0.1.0 product. There is no wiki page titled as a 0.2.0 release. `0.1.0` and `0.2.0` inside walkthroughs are MezzoRecovery package or tag names (TapeDrive `0.2.0`, TapeImage `0.1.0`, GitVersion strings such as `0.1.0-tape-density.40`). Leave those numbers. Product-version samples that are locked to 0.1.0 are listed below.

39 content pages: 13 OK, 21 partial, 5 stale. `_Sidebar.md` is navigation only and has no version.

OK means the procedure still matches the code that was checked. Partial means the page is still right about an older control, and silent on a 0.2.0 control on that same screen. Stale means a stated fact is now false.

Screenshot capture is in [screenshots.md](screenshots.md). File-level work is in [what-needs-update.md](what-needs-update.md).

## Stale pages

| Page | False statement in the wiki | Code |
| --- | --- | --- |
| `Workspace-Repositories.md` | Menu **Create PRs...**. Package wait "default 3" minutes. **Push Updated** is Update Only, then Push Only. | Menu **Create PR**. `PushWaitDependencyTimeoutMinutesPerDependency = 5.0` in `Models/WorkspaceOptions.cs`. Desktop changelog: "Push Updated waits up to 5 minutes per package". Two lanes in `UpdateAndPushOrchestrator`: level N is pushed while level N+1 is still updating. Sequential Update Only then Push Only remains when the push lane cannot run ("Continue with normal push?"). |
| `Workspace-Prepare-Workspace.md` | "3 packages x 3 minutes". Menu **Create PRs...**. | Same 5.0 minute default and **Create PR**. If any branch cannot be created, the job stops: "Prepare Workspace stopped: branches could not be created in all selected repositories..." Update and push then uses the two-lane operation. |
| `Workspace-Packages.md` | Columns are Package Id, Framework, Registry. | Those three remain. `WorkspacePackages.razor` adds **Used by** (repositories that restore the package, transitive ones "via &lt;package&gt;") and **Needs**. Package Id and a GitHub package name open GitHub package settings. **Sync registries** stays. `Directory.Packages.props` is honored by Update and Push (`#479`). |
| `Feature-Walkthrough-Library-Update.md` | 3-minute default. Step text **Create PRs...**. "GrayMoon does not merge for you." | 5.0 minutes. Menu **Create PR**. **Merge PRs...** merges and can return to the default branch. TapeImage `0.1.0` to `0.2.0` still matches. |
| `Feature-Walkthrough-Tape-Density.md` | Same three, and "GrayMoon does not merge for you" twice. | Same corrections. Prepare Workspace, Changes, and level-by-level update stay. The dependency filter `agent` is the MezzoRecovery package name. |

The three false statements are shared where that row says so. `Workspace-Packages.md` has its own column error. It does not state the 3-minute wait, **Create PRs...**, or "GrayMoon does not merge for you."

**Merge PRs...** opens `BulkMergePullRequestsModal`. Checkbox **Return to default branch**. Scope radios **Merged** (default) and **All repositories**. A single PR dialog has the same checkbox (`MergePullRequestModal.razor`). Hidden in a Feature. Tag checkouts are never returned.

A phase name "Create PRs" inside a walkthrough can stay. The menu item the user clicks is **Create PR**. The primary button is also **Create PR** when a yellow create badge exists. Correct these pages. Leave the titles.

Also on `Workspace-Repositories.md`: repository names linking to GitHub (`#491`), row heading **GitHub SSO authorization required** / **Authorize SSO**, the **Workspace** group, and the yellow **Push Updated** menu versus **Update & Push...**.

## New pages and sections

Heading outlines only. Evidence paths are the ones already in `_raw/02-wiki-vs-code.md`.

### New page: AI commit and pull-request text

Evidence: architecture `05` section 34, `Components/Ai/AiProviderControl.razor`, `WorkspaceGitChanges.razor`.

- Where it is
- Commit control (`[Commit Staged or Commit All][AI provider][chevron]`)
- On Commit (**Generate commit message** starts ticked, **Push committed** starts unticked)
- New Pull Request (one title and one Markdown description for every PR in the dialog; text uses the branch's commit subjects)
- Providers: Claude (`claude`), Codex (`codex`), Cursor Agent (`agent`, then `cursor-agent`). A provider that is not installed is omitted. The pinned provider is a gray pin, remembered per workspace on this machine.
- What you see when it fails (failures stay in the AI control; Cursor text can be kept with an amber warning when the CLI exits nonzero after a valid result)
- What is stored

### Section on `Workspace-Features.md`: CodeGraph on New Feature

Evidence: `CreateFeatureModal.razor`, `FeatureCodeGraphService.cs`, `Worker.razor`.

- Checkbox **Create CodeGraph index** ("Indexes this Feature's code for CodeGraph. The build starts from scratch in this Feature.")
- When it starts ticked (CLI installed, and `graymoon.json` does not set `"codegraph": false`)
- Overlay **Starting CodeGraph index...** and **Background** (this overlay offers **Background**; other overlays still offer Abort)
- Remove Feature stops CodeGraph first
- Host tab CodeGraph version

### Section on `App-Workspaces.md` and `Workspace-Overview.md`: Basic vs .NET Dependency

Evidence: `WorkspaceModal.razor`, architecture `05` section 1, `WorkspacePageAccess.cs`, `NavMenu.razor`.

- **.NET Dependency**
- **Basic**
- **Calculate versions with GitVersion**
- **GitHub Actions**
- What Basic hides: Version column, level groups, dependency badges, Update / Push Updated, and Restore
- **Update Files** only while a version file is out of date
- **Merge PRs...** on the header Branch menu, because Basic has no level menus
- `WorkspacePageGate`: "Projects are only available for .NET Dependency workspaces." or "CI is not enabled for this workspace." Button **Back to Repositories**

### Section on `App-Workspaces.md` and `Restore-Workspace.md`: Workspace repository and `graymoon.json`

Evidence: architecture `05` section 1, `#388`, `#437`, `#448`, `#490`, `#503`. The wiki already uses the name `graymoon.json` (`#435`).

- Optional repository whose working tree is the workspace folder
- Grid group header **Workspace**
- Name stays on this computer (a different name alone does not rewrite `graymoon.json`)
- Drift banner **Write Workspace definition to disk** or **Dismiss** (`WorkspaceRepositories.razor`)
- Adopting an existing folder keeps `graymoon.json` and imports `versionFiles`
- **Restore** stays disabled until the definition read finishes
- Preflight: missing file, invalid JSON, a newer schema, an unknown profile
- App and Worker versions must match
- Result panel appears only when something needs action. Success with nothing to fix opens the workspace.

Remove, when Features exist, says "Removing this workspace loses track of its Features..." and stays disabled until the acknowledgement is ticked (architecture `05` section 1). Put that on `App-Workspaces.md` with the type radios.

### New page: Desktop shell

Evidence: `Win32WindowInterop.cs`, `TrayIconService.cs`, `AboutDialog.xaml`, `WorkerUpgradeDialog.xaml`, `UpdateAvailableDialog.xaml`, Desktop architecture `01` sections 8, 9, and 15. `Install-the-App.md` keeps the Docker commands. This page takes the shell.

- Window, tray, and system menu
- Check for updates ("Checking for updates...", "No updates available.", "The update server did not respond. Try again later.", then **Update now** / **Not now**, "Stopping GrayMoon...", "Applying update...")
- About ("All repos moving together.", "Free for personal use.", "Commercial use requires a license.") and first-run About
- Worker update prompt ("The GrayMoon Worker needs an update.", **Not now**, **Update now**, "Always update the Worker automatically")
- Open in (toast `Starting {Label}...`, button disabled until the toast closes, hidden in a browser tab, pin on the bar beside the selector; using a tool does not pin it)
- Install All and Restart (Install All installs .NET SDK, Git, GitVersion, Claude, Codex, and Cursor Agent, then restarts the Worker. Host-tab **Restart**: "Restarts the Worker so it can find an AI agent that was just installed.")
- What stays in the browser App

### Section on `Workspace-Repositories.md`: Merge PRs...

Evidence: `BulkMergePullRequestsModal`, `MergePullRequestModal.razor`. The walkthroughs say "GrayMoon does not merge for you." Replace that sentence with this section. `Workspace-Return-to-Default.md` should name the checkbox, because this action can return repositories itself.

- Where it sits (header Branch menu; on Basic, that menu is the one that has it)
- **Return to default branch**
- **Merged** (default) and **All repositories**
- Single PR dialog, same checkbox
- Hidden in a Feature
- Tag checkouts are never returned

### Section on the failed-clone row: GitHub SSO

Evidence: `GitHubSsoAuthorization.Heading`, `RepositorySyncAlert.cs`, `#451`. Put it on `Workspace-Repositories.md` where the row is.

- Heading **GitHub SSO authorization required**
- Link **Authorize SSO**
- GrayMoon does not open the browser or poll. The user opens **Authorize SSO**.
- The sentence lasts for the page session
- A failed clone stays **not cloned** or **error**

### Expand `Workspace-Features.md`

Evidence: `CreateFeatureModal.razor`, `WorkspaceFeatureSelector.razor`, architecture `05` section 32, `FeatureOpenInTools.cs`. CodeGraph and Open in headings above are the detail. This is the page edit.

- Selector states (**Setting up...**, **Removing...**, **Needs attention** / **Removal incomplete**)
- New Feature (**Based on** = **Current Workspace**)
- Create CodeGraph index
- Repair (banner "This Feature needs attention. Use Repair to continue." **Feature Status**: **Retry**, **Roll back**, **Remove**, **Continue removal**)
- Remove Feature (checkboxes: delete local branches, delete remote branches, discard uncommitted changes; removal runs in the background and the workspace opens at once)
- Pending delete marker (`GRAYMOON-PENDING-DELETE.md`, folder deleted later; CodeGraph's own processes are stopped; `#405` / Desktop `#123`)
- Open in
- Feature menu primary **Feature** / **Create PR** / **Remove**
- What a Feature will not do (architecture `05` section 31): based only on the current Workspace; every repository gets a worktree; no adopting an existing branch; REST has no Feature endpoints; no MCP server

Do not document a user-facing "versions from default" label inside a Feature. Architecture `05` section 31 says GitVersion at the default tip is ignored for a local repository and the known-gap test is skipped.

### Replace the column section on `Workspace-Packages.md`

- Package Id
- Framework
- Registry
- Used by
- Needs (includes sibling packages, `#495`)
- Sync registries
- Central package versions (`Directory.Packages.props`, `#479`)

## Partial pages

Each page keeps its current procedure and gains this behavior.

| Page | Add this |
| --- | --- |
| `What-is-GrayMoon.md` | Basic Git workspaces, worktree Features, and Desktop. The page is still right for .NET package rollouts. Evidence: architecture `01` section 1. |
| `Getting-Started.md` | **Show pairing code**. Worker text: "The script asks for a one-time pairing code... GrayMoon Desktop does this for you." The install command `irm {app}/api/worker/install \| iex` stays. |
| `Install-the-App.md` | Pointer to the new Desktop page (**Check for updates...**, About, tray). Docker commands stay. |
| `Layout.md` | Desktop past Hide title: system menu **Check for updates...**, **Show title** / **Hide title**, **About**, **Exit**. |
| `Shared-Chrome.md` | The loading overlay is clipped to the page, sits under the top bar, and covers open dialogs (`#504`, Desktop `#211`). Abort and the terminal stay. |
| `Restore-Workspace.md` | **Restore** stays disabled until the definition read finishes (`#503`). |
| `App-Workspaces.md` | Type radios **.NET Dependency** and **Basic**. The name is local. |
| `App-Worker.md` | Host tab rows **Claude**, **Codex**, **Cursor Agent**, and **CodeGraph**, plus **Install All**, **Restart**, and **Always update the Worker automatically**. |
| `Workspace-Overview.md` | Projects, Packages, and Dependencies are hidden for **Basic**. Actions is hidden when **GitHub Actions** is off. Direct URL hits `WorkspacePageGate`. |
| `Workspace-Features.md` | Banner "This Feature needs attention. Use Repair to continue." and **Repair**. The rest of the headings are in the expand list above. |
| `Workspace-Changes.md` | **On Commit**: **Generate commit message** (starts ticked) and **Push committed** (starts unticked), on `[Commit Staged or Commit All][AI provider][chevron]`. |
| `Workspace-Files.md` | Configurations live in `graymoon.json` as `versionFiles` and return on Sync, adopt, and Restore (`#438`, `#448`). `{@Repo}` requires GitVersion. `{@Repo:branch}` and `{@Repo:commit}` always resolve. |
| `Workspace-Dependencies.md` | The Workspace repository is the top level. Hover shows the repository type at the bottom-left. |
| `Workspace-Actions.md` | **Last Run** shows elapsed time (`FormatRunElapsed`, title "Elapsed ..."). Rows stay after a transient empty response (`#484`). |
| `Workspace-Projects.md` | Same-named projects are kept by path (`#483`). "mra / Agent" on the shots is the MezzoRecovery tool. |
| `Workspace-Switch-Branch.md` | Occupancy labels **Current**, **Feature**, **Workspace**, **Worktree**. Checkout only if unoccupied or current. Menu label **Create PR**. |
| `Workspace-Repository-Branch-Management.md` | Deleting a Feature branch opens Remove Feature. An external worktree delete asks twice when the tree is dirty. |
| `Workspace-Restore-Packages.md` | Manual **Restore** on the Sync menu stays for .NET Dependency. The notification-popup Update and Push path skips restore (`#501`). `DependencyUpdateOrchestrator` never restores. A Basic workspace has no Restore item. |
| `Workspace-New-Branch.md` | Menu label **Create PR**. The New Branch dialog stays. |
| `Workspace-Protected-Branch-and-Push-Failure.md` | Menu label **Create PR**. Name **Merge PRs...**. The push-rejection scenario still holds. |
| `Workspace-Return-to-Default.md` | Tag checkouts are left untouched (`#487`). A single repository shows the loading overlay while it is checked (`#474`). Overlay progress is counts only. |

Confirm before rewriting `App-Worker.md` "Live git tracking". The install path still writes the shared sync hooks (`post-commit`, `post-checkout`, `post-merge`, `pre-push`). Add `reference-transaction`: a branch created or deleted outside GrayMoon shows up without Sync (`#446`). Listen port default is still `9191` (`WorkerOptions.cs`). The Desktop changelog says GrayMoon no longer overwrites a repository's own Git hooks. Check that claim against the installer before changing the sentence.

### Mention on the existing page

These are real since `0.1.0`. Add them where a page already describes that moment. They do not need their own page.

- Failed push is a toast and a level error (`#488`). `Workspace-Repositories.md`.
- Push Updated from the notification card matches the Repositories page, and that popup path skips package restore (`#498`, `#501`). `Workspace-Restore-Packages.md`.
- Pending syncs run before Update and Push (`#478`). `Workspace-Repositories.md`.
- Git Changes keeps refreshing while the page stays open (`#499`). Large inventories (about 1,500 paths) open collapsed. `Workspace-Changes.md`.
- Ctrl+F includes Mermaid labels in markdown Preview. Added files offer only After. `{STAGE_NUMBER}`-style braces are kept in Preview (`3731b5c1`). `Workspace-Changes.md`.
- Workspace search boxes are focused when the page opens (`#457`).
- Binary files no longer crash the diff (`#439`). Add a Changes sentence only if the page promised a diff for every file.
- Startup Worker dialog on `App-Worker.md`: "The GrayMoon Worker needs an update." The red **update** badge and the red **Upgrade Worker** tile stay.
- Button **Show pairing code** and notice **Reinstall the Worker to finish securing GrayMoon.** on `App-Worker.md`.

Internal refactors (LibGit2Sharp for status and gitignore, SQLite writer lock, SignalR bump, test-only commits) are not user-facing. Leave them off the wiki.

Product-version samples to refresh when those pages are edited: `Getting-Started.md` worker `0.1.0-fix-sync-to-default.263` versus App `0.1.0-main.262`, `Layout.md` top bar `0.1.0-main.262`, `Shared-Chrome.md` `0.1.0-upstream-fix.261`. Walkthrough tag numbers stay.

## Renamed labels

**Create PRs...** to **Create PR**. The menu item the user clicks, on:

- `Workspace-Repositories.md`
- `Workspace-Prepare-Workspace.md`
- `Workspace-New-Branch.md`
- `Workspace-Switch-Branch.md`
- `Workspace-Return-to-Default.md`
- `Workspace-Protected-Branch-and-Push-Failure.md`
- `Feature-Walkthrough-Library-Update.md`
- `Feature-Walkthrough-Tape-Density.md`

**Agent install shots.** Files `agent-install.png`, `agent-install.gif`, `agent.png`, `home-install-agent.png`, `home-upgrade-agent.png`, and similar. The service and the page title are **Worker**. Route `/agent` still works as an alias (`Worker.razor` `@page "/worker"` and `@page "/agent"`). The rename is after the 0.1.0 tag (`#383` / Desktop `#106`). Pages: `App-Worker.md`, `App-Home.md`, `Getting-Started.md`. Recapture names are in [screenshots.md](screenshots.md). The public README embed `worker-install.gif` points at a file that is not on disk. The file that exists is `agent-install.gif`.

**Host tab tools.** Wiki rows are Worker, Dotnet, Git, and GitVersion, and "All prerequisites are installed" when those three exist. Those rows remain. Claude, Codex, Cursor Agent, and CodeGraph are also on the Host tab. "All prerequisites" in that sentence is too narrow. Page: `App-Worker.md`.

Already corrected in the wiki, so they are closed:

- The wizard **New Feature** is **Prepare Workspace**. The dialog **New Feature** is the worktree Feature. `Workspace-New-Feature.md` says this.
- **Sync to Default** is **Return to Default**. `Workspace-Sync-to-Default.md` says this.
- The definition file is `graymoon.json`.

## Pages that can stay

`App-Connectors.md`, `App-Home.md`, `App-Repository-Catalog.md`, `App-Settings.md`, `Home.md`, `Workspace-Checkout-from-Tags.md`, `Workspace-Custom-Dependencies.md`, `Workspace-Incoming-Commits.md`, `Workspace-New-Feature.md`, `Workspace-Sync-to-Default.md`, `Workspace-Tag-Upgrade.md`, `Workspace-Undo-Push-Commits.md`, `Workspace-Update-Branch-from-Default.md`.

`Workspace-New-Feature.md` and `Workspace-Sync-to-Default.md` stay as redirects.

Optional one sentence, still OK if omitted:

- `App-Connectors.md`: a connector cannot be deleted while a Feature uses its repositories (architecture `05` section 2).
- `Workspace-Checkout-from-Tags.md`: **Return to Default** leaves a tag checkout in place. This page is still the way off a tag.
- `App-Settings.md`: the AI pin and Worker auto-update live on Changes and the Worker page. Settings stays the workspace root path, the Feature storage root, and terminal colors.
- `Workspace-Undo-Push-Commits.md`: "Agent" on this page is the repo `MezzoRecovery.Agent`.
- `App-Home.md`: tiles **Manage Workspaces**, **Manage / Upgrade / Install Worker**, **Manage Connectors**, **View Repositories** still match `Home.razor`. The red **Upgrade Worker** tile is still the mismatch path.
