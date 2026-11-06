# Wiki (0.1.0) vs code that will ship as 0.2.0

Read-only comparison. Nothing in the wiki, READMEs, or product code was edited.

## How this was judged

There is **no `0.2.0` git tag**. Both code repos are tagged only `0.1.0` (28 Sep 2026). Current `main` (same commit as `docs-b4-release`) is:

| Repo | Tag | HEAD | Commits after `0.1.0` |
| --- | --- | --- | --- |
| `GrayMoon` | `0.1.0` = `9e5517f2` "Install the worker from GrayMoon Desktop..." (#365) | `8257e162` | 117 (`git describe`: `0.1.0-117-g8257e162`) |
| `GrayMoon.Desktop` | `0.1.0` = `0606e01f` same theme (#97) | `7faf92c` | 103 (`0.1.0-103-g7faf92c`) |

"Will ship as 0.2.0" here means **everything after that tag on current `main`**. The running product version is still a GitVersion string based on `0.1.0` plus those commits, not a `0.2.0` tag. Uncertain until a `0.2.0` tag exists: whether every commit on this branch is in the release. Nothing after `8257e162` / `7faf92c` was found on `main`.

`GrayMoon.Release\README.md` is only a landing sentence ("official home for GrayMoon Desktop downloads, updates, and release notes"). It does not list 0.1.0 or 0.2.0 notes. User-visible change list used instead: `GrayMoon.Desktop\README.md` section `## Recent GrayMoon changes` (160 bullets, newest first), then `GrayMoon\docs\architecture\` and `GrayMoon.Desktop\docs\architecture\`, then the code. No `.codegraph` index was present, so this used git, those docs, and targeted reads.

`0.1.0` and `0.2.0` inside walkthroughs are almost always **MezzoRecovery package or tag names** (TapeDrive `0.2.0`, TapeImage `0.1.0`, GitVersion strings like `0.1.0-tape-density.40`). They are not the GrayMoon product version. The product-version examples that are locked to 0.1.0 are called out in the inventory.

## Wiki inventory

40 Markdown files under `GrayMoon.wiki` (39 content pages + `_Sidebar.md`). 348 files in `screenshots\`. 194 image embeds across 34 pages. Wiki git: `master` at `59df2e4` "Update screens", even with `origin/master`. No wiki page is titled as a 0.2.0 product release.

Titles below are the page's own header title when it has one. GitHub wiki otherwise uses the file name.

| Path | Title / role | What it documents | Version lock |
| --- | --- | --- | --- |
| `_Sidebar.md` | Nav | Links every content page. No version. | None |
| `Home.md` | Welcome (no H1) | Guide index, typical day | "version" in prose only |
| `What-is-GrayMoon.md` | What is GrayMoon | .NET multi-repo orchestration, GitVersion | "version" in prose |
| `Install-the-App.md` | Install the App | Docker image `jandini/graymoon:latest`, plus a short Desktop pointer | None |
| `Getting-Started.md` | Getting Started | Worker install, connectors, catalog, first workspace, clone | Example worker semver `0.1.0-fix-sync-to-default.263` vs App `0.1.0-main.262` |
| `Layout.md` | Layout | Sidebar, top bar, Desktop hide-title | Top bar example `0.1.0-main.262` |
| `Shared-Chrome.md` | Shared chrome | Nav, badge, filter search, toasts, overlay, notification cards | Top bar example `0.1.0-upstream-fix.261` |
| `App-Home.md` | Home | Tiles: Workspaces, Worker, Connectors, Repositories | None |
| `App-Workspaces.md` | Workspaces | Grid, Add/Edit, select repos, Remove | `graymoon.json` mentioned once |
| `Restore-Workspace.md` | Restore Workspace | **Restore from repository** | `graymoon.json` |
| `App-Repository-Catalog.md` | Repositories (catalog) | Global GitHub catalog, not the workspace grid | None |
| `App-Connectors.md` | Connectors | GitHub and NuGet connectors, Active / OK | None |
| `App-Worker.md` | Worker | Install, Update, Uninstall, Host, badge self-update, git hooks | "version" in prose; screenshots named `agent-*` |
| `App-Settings.md` | Settings | Workspace root path, Feature storage root, terminal colors | None |
| `Workspace-Overview.md` | Workspace overview | Page table and workflow index | None |
| `Workspace-Repositories.md` | Repositories | Main grid, Branch menu, Push Updated, Sync, PR badges | Example GitVersion `0.1.0-new-branch-demo.39`; tag `0.2.0` is TapeDrive |
| `Workspace-Changes.md` | Changes | Multi-repo git status, stage, Commit Staged / Commit All, diff | None |
| `Workspace-Projects.md` | Projects | `.csproj` catalog | None |
| `Workspace-Packages.md` | Packages | Packable projects, Sync registries | None |
| `Workspace-Files.md` | Files | Pin files, version patterns, Update | Example values `0.1.0-main.55` |
| `Workspace-Dependencies.md` | Dependencies | Graph | None |
| `Workspace-Actions.md` | Actions | Workflow grid, logs, download | None |
| `Workspace-New-Branch.md` | New Branch | Workspace-wide new branch | Example `0.1.0-new-branch-demo.39` |
| `Workspace-Switch-Branch.md` | Switch Branch | Workspace-wide checkout, Skip repos on tags | None |
| `Workspace-Features.md` | Features | Worktree Feature: storage, New Feature dialog, switching | None |
| `Workspace-New-Feature.md` | Redirect | Points at Features; says Prepare Workspace was formerly New Feature | None |
| `Workspace-Prepare-Workspace.md` | Prepare Workspace | Branch + update + synchronized push wizard | None |
| `Workspace-Return-to-Default.md` | Return to Default | Workspace and per-level rewind | None |
| `Workspace-Sync-to-Default.md` | Redirect | Says the action was renamed from Sync to Default | None |
| `Workspace-Restore-Packages.md` | Restore | `dotnet restore` from Sync, and automatic restore on push | None |
| `Workspace-Update-Branch-from-Default.md` | Update Branch | Yellow behind badge, merge `origin/<default>` | None |
| `Workspace-Incoming-Commits.md` | Incoming commits | Red commits badge, Pull | None |
| `Workspace-Undo-Push-Commits.md` | Undo Push Commits | Reset unpushed commits | `0.2.0` here is a package pin in the scenario |
| `Workspace-Custom-Dependencies.md` | Custom dependencies | User-declared level edges | None |
| `Workspace-Checkout-from-Tags.md` | Checkout from tags | Per-repo or Switch Branch off a tag back to `main` | Scenario tags `0.2.0` / `1.0.0` |
| `Workspace-Tag-Upgrade.md` | Tag upgrade | Yellow upgrade badge, check out a newer tag | Scenario `0.1.0` then `0.2.0` |
| `Workspace-Repository-Branch-Management.md` | Branch dialog | Locals, Remotes, Tags, new branch, delete | Scenario tags `0.1.0` |
| `Workspace-Protected-Branch-and-Push-Failure.md` | Protected branch | Commit on default, failed push, undo, single-repo branch, PR | Example `0.1.0-main.54` |
| `Feature-Walkthrough-Library-Update.md` | Library Update | Dependency rollout with frozen tags | Scenario tags `0.1.0` and `0.2.0` |
| `Feature-Walkthrough-Tape-Density.md` | Tape Density | Full feature lifecycle on MezzoRecovery | Example `0.1.0-tape-density.40` |

## Page verdicts

39 content pages. `_Sidebar.md` is navigation only.

| Verdict | Count | Pages |
| --- | --- | --- |
| OK | 13 | `App-Connectors`, `App-Home`, `App-Repository-Catalog`, `App-Settings`, `Home`, `Workspace-Checkout-from-Tags`, `Workspace-Custom-Dependencies`, `Workspace-Incoming-Commits`, `Workspace-New-Feature` (redirect still true), `Workspace-Sync-to-Default` (redirect still true), `Workspace-Tag-Upgrade`, `Workspace-Undo-Push-Commits`, `Workspace-Update-Branch-from-Default` |
| Partial | 21 | `What-is-GrayMoon`, `Getting-Started`, `Install-the-App`, `Layout`, `Shared-Chrome`, `Restore-Workspace`, `App-Workspaces`, `App-Worker`, `Workspace-Overview`, `Workspace-Features`, `Workspace-Changes`, `Workspace-Files`, `Workspace-Dependencies`, `Workspace-Actions`, `Workspace-Projects`, `Workspace-Switch-Branch`, `Workspace-Repository-Branch-Management`, `Workspace-Restore-Packages`, `Workspace-New-Branch`, `Workspace-Protected-Branch-and-Push-Failure`, `Workspace-Return-to-Default` |
| Stale | 5 | `Workspace-Repositories`, `Workspace-Prepare-Workspace`, `Workspace-Packages`, `Feature-Walkthrough-Library-Update`, `Feature-Walkthrough-Tape-Density` |
| Missing page | not a page count | See the last section. The largest holes have no page at all. |

OK means the procedure the page describes still matches the code that was checked. Several OK pages use `0.1.0` only as a MezzoRecovery tag or GitVersion example. Partial means the page is still right about an older control, and silent on a 0.2.0 control on that same screen. Stale means a stated fact is now false.

## Feature delta

Evidence paths are where the user-visible behavior lives. "Update needed" is a note for a later wiki edit, not an edit made here.

| Feature | Evidence in code | Wiki page | Gap | Update needed |
| --- | --- | --- | --- | --- |
| Home tiles and default-workspace redirect | `Components/Pages/Home.razor`; wiki already names **Manage Workspaces**, **Manage / Upgrade / Install Worker**, **Manage Connectors**, **View Repositories** | `App-Home.md` | OK | None found. README "The Home circle follows only whether the Worker is down" is the nav dot, not these tiles. The red **Upgrade Worker** tile is still what the Worker page and architecture describe for a version mismatch. |
| Connectors grid, Add/Edit, test, Active / OK | `Components/Pages/Connectors.razor` | `App-Connectors.md` | OK | A connector cannot be deleted while a Feature uses its repositories (architecture `05` section 2). The page does not say that. Small addition, not a wrong procedure. |
| Global repository catalog | `Components/Pages/Repositories.razor` `@page "/repositories"` | `App-Repository-Catalog.md` | OK | None found at heading level. |
| Settings: root path, Feature storage root, terminal colors | `Components/Pages/Settings.razor` | `App-Settings.md` | OK | AI pin and Worker auto-update are not Settings. They live on Changes and the Worker page. |
| Tag upgrade badge and checkout | `docs/architecture/05` section 7; wiki walkthrough matches the still-present Tags tab | `Workspace-Tag-Upgrade.md` | OK | `0.1.0` / `0.2.0` are TapeDrive tags, not the product. |
| Leave a tag via the branch dialog or Switch Branch | Still a checkout. Return to Default now skips tags (separate row below). | `Workspace-Checkout-from-Tags.md` | OK | Say that **Return to Default** will not move a tag checkout; this page is still the way off a tag. |
| Custom dependency edges | Architecture `05` section 18 | `Workspace-Custom-Dependencies.md` | OK | None found. |
| Incoming commits and Pull | Architecture `05` section 12 | `Workspace-Incoming-Commits.md` | OK | None found. |
| Update Branch from default | Architecture `01` section 6 | `Workspace-Update-Branch-from-Default.md` | OK | None found. |
| Undo Push Commits | Architecture `05` section 13 | `Workspace-Undo-Push-Commits.md` | OK | "Agent" on this page is the repo `MezzoRecovery.Agent`, not the old Worker name. |
| Prepare Workspace was formerly New Feature | `Workspace-New-Feature.md` states this | `Workspace-New-Feature.md` | OK | Keep as a redirect. |
| Sync to Default was renamed Return to Default | `Workspace-Sync-to-Default.md` states this | `Workspace-Sync-to-Default.md` | OK | Keep as a redirect. |
| Product purpose | `docs/architecture/01` section 1 | `What-is-GrayMoon.md` | Partial | Still true for .NET package rollouts. It does not mention Basic Git workspaces, worktree Features, or Desktop. |
| First-run install | `Worker.razor` still shows `irm {app}/api/worker/install \| iex` and the password prompt | `Getting-Started.md` | Partial | Add **Show pairing code** ("The script asks for a one-time pairing code... GrayMoon Desktop does this for you."). The worked example is still `0.1.0-fix-sync-to-default.263`. Screenshots are `agent-install*`. |
| Docker vs Desktop | `Install-the-App.md` Docker commands still match a container-only App | `Install-the-App.md` | Partial | Desktop is one paragraph. No **Check for updates...**, About, or tray. |
| Chrome: sidebar, top bar, hide title | `Layout.md`, `NavMenu.razor` | `Layout.md`, `Shared-Chrome.md` | Partial | Top-bar examples are `0.1.0-main.262` and `0.1.0-upstream-fix.261`. Desktop section stops at hide title. Overlay behavior changed (row below). |
| Loading overlays stay inside the page and cover open dialogs | GrayMoon `#504`, Desktop `#211`; README bullet 1 | `Shared-Chrome.md` | Partial | The page still documents the overlay, Abort, and terminal. It does not say the overlay is clipped to the page and sits over dialogs, under the top bar. |
| Workspaces list, Add, Remove | `Components/Pages/Workspaces.razor`, `Modals/WorkspaceModal.razor` | `App-Workspaces.md` | Partial | Modal now has type radios **.NET Dependency** and **Basic**, plus **Calculate versions with GitVersion** and **GitHub Actions**. Remove, when Features exist, says "Removing this workspace loses track of its Features..." and stays disabled until the acknowledgement is ticked (architecture `05` section 1). Wiki Remove copy does not mention Features. |
| Workspace name stays on this computer | `#490` / Desktop `#197`. A different name alone does not rewrite `graymoon.json` (architecture `05` section 1). | `App-Workspaces.md` | Partial | Wiki treats the name as part of the definition the user is editing. Say the name is local. |
| Restore from repository | `Restore-Workspace.md`; architecture `05` "Restore Workspace" | `Restore-Workspace.md` | Partial | **Restore** stays disabled until the definition read finishes (`#503`). Preflight can block on a missing file, invalid JSON, a newer schema, or an unknown profile. App and Worker versions must match. Success with nothing to fix opens the workspace; the result panel appears only when something needs action. |
| Worker page: Install, Update, Uninstall, Host, badge self-update | `Components/Pages/Worker.razor` `@page "/worker"` and `@page "/agent"` | `App-Worker.md` | Partial | Install command, password, and badge self-update are still described and still in the architecture. The Host grid now also has **Claude**, **Codex**, **Cursor Agent** (install commands), and **CodeGraph**. Desktop shows **Install**, **Install All**, and **Restart** ("Restarts the Worker so it can find an AI agent that was just installed."). Checkbox **Always update the Worker automatically**. Notice **Reinstall the Worker to finish securing GrayMoon.** Button **Show pairing code**. |
| Worker update at Desktop startup | `WorkerUpgradeDialog.xaml`: "The GrayMoon Worker needs an update.", **Not now**, **Update now**, "Always update the Worker automatically" | `App-Worker.md` | Partial | Wiki only documents the red **update** badge and the red **Upgrade Worker** tile. |
| Git hooks | `GitService.cs` still installs `post-commit`, `post-checkout`, `post-merge`, `pre-push`, and now `reference-transaction`. Listen port default is still `9191` (`WorkerOptions.cs`). | `App-Worker.md` "Live git tracking" | Partial | Add `reference-transaction`: a branch created or deleted outside GrayMoon shows up without Sync (`#446`). Wiki says GrayMoon does not overwrite a repo's own hooks in later code (`#` in README: "GrayMoon no longer overwrites a repository's own Git hooks") — confirm before rewriting that section; the install path still writes the shared sync hooks. |
| Workspace pages index | `NavMenu.razor` still: Repositories, Changes, Projects, Packages, Files, Dependencies, Actions | `Workspace-Overview.md` | Partial | Projects, Packages, and Dependencies are hidden for **Basic**. Actions is hidden when **GitHub Actions** is off. Direct URL shows `WorkspacePageGate`: "Projects are only available for .NET Dependency workspaces." or "CI is not enabled for this workspace." and **Back to Repositories**. |
| Features (worktrees) | `CreateFeatureModal.razor`, `WorkspaceFeatureSelector.razor`, architecture `05` section 32 | `Workspace-Features.md` | Partial | Create and switch are documented (**New Feature**, **Based on** = **Current Workspace**). Missing: states **Setting up...**, **Removing...**, **Needs attention** / **Removal incomplete**; banner "This Feature needs attention. Use Repair to continue." and **Repair**; **Feature Status** (**Retry**, **Roll back**, **Remove**, **Continue removal**); Remove Feature checkboxes (delete local branches, delete remote branches, discard uncommitted changes); removal runs in the background and the workspace opens at once; checkbox **Create CodeGraph index**; Feature menu primary **Feature** / **Create PR** / **Remove**. |
| Open in... (Desktop only) | `FeatureOpenInTools.cs`: **Open in...** menu Cursor, Claude CLI, Codex CLI, VS Code, Visual Studio, Terminal, Explorer. Toast `Starting {Label}...`. Button stays disabled until the toast closes. Hidden in a browser tab. | `Workspace-Features.md` (no Open in). Tape Density says open the folder in Cursor yourself. | Partial | New section. Tools can be pinned on the bar beside the selector. Using a tool does not pin it. |
| Git Changes: stage, commit, diff | `WorkspaceGitChanges.razor` still has **Commit Staged** / **Commit All** | `Workspace-Changes.md` | Partial | Those buttons still exist and are still joined as one primary button. The control is now `[Commit Staged or Commit All][AI provider][chevron]`. Menu header **On Commit**: **Generate commit message** (starts ticked) and **Push committed** (starts unticked). Empty message box has the control attached to its right edge. **Open in** menu stays above the diff. Large inventories open collapsed. Ctrl+F searches markdown Preview. Added files offer only After. `{STAGE_NUMBER}`-style braces are kept in Preview. |
| Files and version patterns | `WorkspaceFiles.razor`; version files stored as `versionFiles` in `graymoon.json` (`#438`, `#448`) | `Workspace-Files.md` | Partial | The pin / pattern / **Update** walkthrough is still the feature. Say configurations live in `graymoon.json` and return on Sync, adopt, and Restore. `{@Repo}` needs GitVersion; the dialog says it "requires repository versioning (GitVersion) to be enabled". `{@Repo:branch}` and `{@Repo:commit}` always resolve. |
| Dependencies graph | `WorkspaceDependencies.razor` | `Workspace-Dependencies.md` | Partial | Hover shows the repository type at the bottom-left. Dragging lines a node up with nearby tiles and keeps the place in this browser. Package nodes have rounded corners. The Workspace repository is the top level. |
| Actions | `WorkspaceActions.razor` column **Last Run** | `Workspace-Actions.md` | Partial | Last Run now also shows elapsed time (`FormatRunElapsed`, title "Elapsed ..."). Rows stay after a transient empty response (`#484`). |
| Projects | `WorkspaceProjects.razor` | `Workspace-Projects.md` | Partial | Same-named projects are kept by path (`#483`). Page is absent on a Basic workspace. "mra / Agent" is the MezzoRecovery tool, not the Worker. |
| Switch Branch and per-repo branch dialog | `SwitchBranchModal`, architecture `05` sections 6 and 7 | `Workspace-Switch-Branch.md`, `Workspace-Repository-Branch-Management.md` | Partial | Occupancy labels **Current**, **Feature**, **Workspace**, **Worktree**. Checkout only if unoccupied or current. Deleting a Feature branch opens Remove Feature. An external worktree delete asks twice when the tree is dirty. Inside a Feature, bulk Switch Branch is not offered; the row can show **off feature branch**; the dialog can say **This Feature** and **Return to Feature branch**. Menu text **Create PRs...** on the Switch Branch page is now **Create PR**. |
| New Branch dialog | Still the New Branch tab | `Workspace-New-Branch.md` | Partial | The dialog is still right. The menu list says **Create PRs...**. Code label is **Create PR**. |
| Protected-branch walkthrough | Push rejection and undo still exist | `Workspace-Protected-Branch-and-Push-Failure.md` | Partial | Scenario still holds. It tells the user to open **Create PRs...**. Same label rename. It does not mention **Merge PRs...**. |
| Return to Default | `docs/architecture/05` sections 6 and 14 | `Workspace-Return-to-Default.md` | Partial | Still the Branch-menu and level-rewind action. Tag checkouts are left untouched (`#487`). A single repository shows the loading overlay while it is checked (`#474`). Overlay progress is counts only, not "(failed)". **Merge PRs...** can return repositories itself (next rows), so this is no longer the only way back to default. |
| Restore packages | `WorkspaceOptions` and `PushOrchestrator` still restore after a level push. `DependencyUpdateOrchestrator` never restores. | `Workspace-Restore-Packages.md` | Partial | Manual **Restore** on the Sync menu is still right for .NET Dependency. The notification-popup Update and Push no longer restores (`#501`). A Basic workspace has no Restore item. |
| Repositories grid, Branch menu, Push Updated | `WorkspaceRepositoriesHeader.razor` | `Workspace-Repositories.md` | Stale | Three false statements: menu item **Create PRs...** (code: **Create PR**); package wait "default 3" minutes (code: `PushWaitDependencyTimeoutMinutesPerDependency = 5.0` in `WorkspaceOptions.cs`, README "up to 5 minutes per package"); **Push Updated** described only as Update Only then Push Only. When it can, Update and Push runs two lanes: level N is pushed while level N+1 is still updating (`UpdateAndPushOrchestrator`). Also missing on this page: **Merge PRs...**, repository names linking to GitHub, **GitHub SSO authorization required** / **Authorize SSO**, the **Workspace** group, and the yellow **Push Updated** menu vs **Update & Push...**. |
| Prepare Workspace wizard | `PrepareWorkspaceModal`, architecture `05` section 8 | `Workspace-Prepare-Workspace.md` | Stale | Same 3-minute timeout ("3 packages x 3 minutes"). If any branch cannot be created, the job stops with "Prepare Workspace stopped: branches could not be created in all selected repositories..." and does not update or push. Update and push uses the same two-lane operation as the grid. |
| Packages grid | `WorkspacePackages.razor` headers **Used by** and **Needs** | `Workspace-Packages.md` | Stale | Documented columns are only Package Id, Framework, Registry. Code adds **Used by** (repositories that restore the package, transitive ones "via &lt;package&gt;") and **Needs** (other workspace packages this repository restores). Package Id and a GitHub package name open GitHub package settings. **Sync registries** is still there. `Directory.Packages.props` is honored by Update and Push (`#479`); the page does not mention central package versions. |
| Library Update walkthrough | Same push and PR code as the grid | `Feature-Walkthrough-Library-Update.md` | Stale | Repeats the 3-minute default. Step text is **Create PRs...**. "GrayMoon does not merge for you" is false: **Merge PRs...** merges and can return to the default branch. The tag-upgrade recovery itself (TapeImage `0.1.0` to `0.2.0`) still matches the product. |
| Tape Density walkthrough | Same | `Feature-Walkthrough-Tape-Density.md` | Stale | Same three errors: 3-minute timeout, **Create PRs...**, "GrayMoon does not merge for you" (twice). Prepare Workspace, Changes, and level-by-level update are still real flows. It never uses a worktree Feature or AI commit text. The dependency filter `agent` is the MezzoRecovery package name. |

### Same label error on otherwise usable pages

The header and the level menu both say **Create PR** (`WorkspaceRepositoriesHeader.razor`, `WorkspaceRepositoriesLevelHeader.razor`). These pages still say **Create PRs...**:

- `Workspace-Repositories.md` (also stale for other reasons)
- `Workspace-Prepare-Workspace.md`
- `Workspace-New-Branch.md`
- `Workspace-Switch-Branch.md`
- `Workspace-Return-to-Default.md`
- `Workspace-Protected-Branch-and-Push-Failure.md`
- `Feature-Walkthrough-Library-Update.md`
- `Feature-Walkthrough-Tape-Density.md`

Plural "Create PRs" as a phase name inside a walkthrough can stay. The menu item the user clicks cannot.

### Behavior fixes that do not need their own page

These are real since `0.1.0` and mostly invisible if the wiki never specified the old bug. Mention them only where a page already describes that moment.

- Failed push is shown as a toast and a level error, not a silent stop (`#488`).
- Push Updated from the notification card matches the Repositories page, and that popup path does not restore packages (`#498`, `#501`).
- Pending syncs are applied before Update and Push, so a repository is not skipped (`#478`).
- Git Changes keeps refreshing while the page stays open (`#499`).
- A failed clone stays **not cloned** or **error**, never **in sync** (`#451`).
- Workspace search boxes are focused when the page opens (`#457`).
- Changes nav dot, markdown Preview, and "Back to Repositories" already have code. The wiki Changes page covers Preview only partly (no Ctrl+F, no After-only for added files).
- Binary files no longer crash the diff (`#439`). The Changes page does not need a new section unless it promised a diff for every file.

Internal refactors (LibGit2Sharp for status and gitignore, SQLite writer lock, SignalR bump, test-only commits) are not user-facing. Do not add wiki pages for them.

## Removed or renamed behavior the wiki still describes

| What the wiki says | What the code does now | Where |
| --- | --- | --- |
| Branch menu item **Create PRs...** | **Create PR** | Pages listed above. Primary button is also **Create PR** when a yellow create badge exists. |
| Package wait default **3 minutes** per package (`PushWaitDependencyTimeoutMinutesPerDependency`, default 3). Countdown example `08:59` for 3 packages. | Default is **5.0** minutes (`Models/WorkspaceOptions.cs`). README: "Push Updated waits up to 5 minutes per package". | `Workspace-Repositories.md`, `Workspace-Prepare-Workspace.md`, both walkthroughs |
| "GrayMoon does not merge for you." Merge happens only on GitHub. | **Merge PRs...** opens `BulkMergePullRequestsModal`. Checkbox **Return to default branch**. Scope radios **Merged** (default) and **All repositories**. A single PR dialog has the same checkbox (`MergePullRequestModal.razor`). Hidden in a Feature. Tag checkouts are never returned. | Both walkthroughs, and the Return to Default page which never mentions the checkbox |
| **Push Updated** is Update Only, then Push Only, in one job, waiting for the feed between levels. | That sequential path still exists when the push lane cannot run ("Continue with normal push?"). The normal combined path is two lanes: push a level while later levels are still being updated. | `Workspace-Repositories.md`, `Workspace-Prepare-Workspace.md` |
| Host tab rows: Worker, Dotnet, Git, GitVersion, and "All prerequisites are installed" when those three exist. | Those rows remain. Claude, Codex, Cursor Agent, and CodeGraph are also on the Host tab. "All prerequisites" in the wiki is therefore too narrow. | `App-Worker.md` |
| Packages columns: Package Id, Framework, Registry. | Those three remain. **Used by** and **Needs** were added. Package Id opens GitHub package settings when the package is on GitHub. | `Workspace-Packages.md` |
| Screenshot file names `agent-install.png`, `agent.png`, `home-install-agent.png`, and similar. | The service and the page title are **Worker**. Route `/agent` still works as an alias (`Worker.razor`). The rename commit is after the 0.1.0 tag (`#383` / Desktop `#106`). | `App-Worker.md`, `App-Home.md`, `Getting-Started.md` |

Already corrected in the wiki, so they are not open renames:

- **New Feature** the wizard is **Prepare Workspace**. **New Feature** the dialog is the worktree Feature. `Workspace-New-Feature.md` says this.
- **Sync to Default** is **Return to Default**. `Workspace-Sync-to-Default.md` says this.
- The definition file is `graymoon.json`, not `.graymoon.json`. The wiki uses `graymoon.json`. The rename is `#435`, after 0.1.0, and the wiki already matches.

Not a wiki claim, so not listed as stale copy: Remove Feature no longer looks for or ends programs that have the folder open (`#405` / Desktop `#123`). The Features page never said that it did. If a new Remove Feature section is written, say GrayMoon leaves a `GRAYMOON-PENDING-DELETE.md` marker and deletes the folder later, and that it does stop CodeGraph's own processes.

## New 0.2.0 features with no wiki page

These have no page, and the closest page does not describe them.

1. **AI commit messages and pull request text.** Changes provider segment and **Generate commit message**. New Pull Request writes one title and one Markdown description for every PR in the dialog. Providers: Claude (`claude`), Codex (`codex`), Cursor Agent (`agent`, then `cursor-agent`). A provider that is not installed is omitted. The pinned provider is a gray pin, remembered per workspace on this machine. Failures stay in the AI control. Cursor text can be kept with an amber warning when the CLI exits nonzero after a valid result. Evidence: architecture `05` section 34, `Components/Ai/AiProviderControl.razor`, `WorkspaceGitChanges.razor`. Wiki search: no `Claude`, `Codex`, `CodeGraph`, or "Generate commit".

2. **CodeGraph on a Feature.** New Feature checkbox **Create CodeGraph index** ("Indexes this Feature's code for CodeGraph. The build starts from scratch in this Feature."), ticked by default when the CLI is installed and `graymoon.json` does not set `"codegraph": false`. Overlay can say **Starting CodeGraph index...** and offers **Background** instead of Abort. Remove Feature stops CodeGraph first. Host tab has a CodeGraph version. Evidence: `CreateFeatureModal.razor`, `FeatureCodeGraphService.cs`, `Worker.razor`.

3. **Workspace profile.** Add / Edit Workspace: **.NET Dependency** or **Basic**, **Calculate versions with GitVersion**, **GitHub Actions**. Basic hides the Version column, level groups, dependency badges, Update / Push Updated, and Restore, and shows **Update Files** only while a version file is out of date. **Merge PRs...** sits on the header Branch menu because there are no level menus. Evidence: `WorkspaceModal.razor`, architecture `05` section 1, `WorkspacePageAccess.cs`.

4. **Workspace repository and `graymoon.json`.** Optional repository whose working tree is the workspace folder. Grid group header **Workspace**. Drift banner **Write Workspace definition to disk** or **Dismiss** (`WorkspaceRepositories.razor`). Adopting an existing folder keeps `graymoon.json` and imports `versionFiles`. Restore preflight reads the file from GitHub before creating anything. Evidence: architecture `05` section 1, `#388`, `#437`, `#448`, `#490`.

5. **Desktop shell beyond hide-title.** System menu and tray: **Check for updates...**, **Show title** / **Hide title**, **About**, **Exit**. Update dialogs: "Checking for updates...", "No updates available.", "The update server did not respond. Try again later.", then **Update now** / **Not now** ("Stopping GrayMoon...", "Applying update..."). About: "All repos moving together.", "Free for personal use.", "Commercial use requires a license." First-run About. Worker startup dialog quoted above. **Restart** on the Host tab. **Install All** installs .NET SDK, Git, GitVersion, Claude, Codex, and Cursor Agent, then restarts the Worker. Evidence: `Win32WindowInterop.cs`, `TrayIconService.cs`, `AboutDialog.xaml`, `WorkerUpgradeDialog.xaml`, `UpdateAvailableDialog.xaml`, Desktop architecture `01` sections 8, 9, and 15.

6. **Merge PRs...** as a product action, including **Return to default branch**, **Merged**, and **All repositories**. No page. The walkthroughs say the opposite.

7. **GitHub SSO on a failed clone.** Row heading **GitHub SSO authorization required** and an **Authorize SSO** link. GrayMoon does not open the browser or poll. The sentence lasts for the page session. Evidence: `GitHubSsoAuthorization.Heading`, `RepositorySyncAlert.cs`, `#451`.

8. **Open in... toasts and pins.** Covered as a Features gap above. There is no Desktop page to hang it on. `Install-the-App.md` and `Layout.md` are the only Desktop pages, and they stop at "native window" and hide title.

Smaller additions that belong as sections, not new pages: repository name opens GitHub (`#491`); Actions elapsed time; central package versions; sibling packages in **Needs** (`#495`); search focus; reference-transaction hook; single-repository Return to Default overlay.

Uncertain, so not listed as a shipped screen: a user-facing "versions from default" label inside a Feature. Architecture `05` section 31 says GitVersion at the default tip is ignored for a local repository and the known-gap test is skipped. Do not document that as working.

Intentional limitations the architecture says must not be described as current behavior (section 31): Features can only be based on the current Workspace; every repository gets a worktree; no adopting an existing branch; REST has no Feature endpoints; no MCP server.

## Suggested headings only

Not page rewrites.

### New page: AI commit messages and pull request text

- Where it is
- Commit control
- On Commit
- New Pull Request
- Providers
- What you see when it fails
- What is stored

### New page: Desktop

- Window, tray, and system menu
- Check for updates
- About
- Worker update prompt
- Open in
- Install All and Restart
- What stays in the browser App

### Expand `Workspace-Features.md`

- Selector states
- New Feature
- Create CodeGraph index
- Repair
- Remove Feature
- Open in
- What a Feature will not do

### Expand `App-Workspaces.md` and `Restore-Workspace.md`

- Workspace type
- GitVersion and GitHub Actions
- Workspace repository
- Name stays on this computer
- Restore stays disabled until the definition is read
- Write Workspace definition to disk

### Replace the column section on `Workspace-Packages.md`

- Package Id
- Framework
- Registry
- Used by
- Needs
- Sync registries

### Correct, do not retitle

- `Workspace-Repositories.md`: Create PR, Merge PRs..., five-minute wait, two-lane Update and Push, SSO, GitHub name links
- `Workspace-Prepare-Workspace.md`: stop when a branch fails, five-minute wait, two lanes
- Both walkthroughs: GrayMoon can merge; the 3-minute default is 5; menu label Create PR. Leave the MezzoRecovery tag numbers alone.

## Screenshot references

Another agent owns screenshots. This is only the inventory. 194 embeds, 348 files in `screenshots\`. Every embed uses a relative `screenshots/...` path. Six Markdown files have no images: `_Sidebar.md`, `What-is-GrayMoon.md`, `Install-the-App.md`, `Workspace-Overview.md`, `Workspace-New-Feature.md`, `Workspace-Sync-to-Default.md`.

| Page | Embeds | Notes |
| --- | --- | --- |
| `Feature-Walkthrough-Tape-Density.md` | 61 | Largest set. Includes `workspace2-deps-search-agent.png`. |
| `Feature-Walkthrough-Library-Update.md` | 31 | Tag `0.2.0` screenshots are TapeImage, not the product. |
| `Getting-Started.md` | 28 | Includes `agent-install.png`, `agent-install.gif`, `agent-update.png`, `home-upgrade-agent.png`. |
| `Workspace-Protected-Branch-and-Push-Failure.md` | 27 | |
| `Workspace-Repositories.md` | 22 | |
| `Workspace-Return-to-Default.md` | 19 | |
| `Workspace-Files.md` | 16 | |
| `Workspace-Actions.md` | 15 | |
| `Workspace-Changes.md` | 15 | No AI control in the set. |
| `Workspace-Repository-Branch-Management.md` | 12 | Includes `workspace2-tapeimage-delete-agent-limit-confirm.png` (branch name `agent-limit`). |
| `App-Worker.md` | 8 | All illustrative shots are `agent-*` or `home-upgrade-agent.png`. |
| `Workspace-Checkout-from-Tags.md` | 8 | |
| `Workspace-Switch-Branch.md` | 8 | |
| `Workspace-Tag-Upgrade.md` | 8 | |
| `Workspace-Custom-Dependencies.md` | 7 | |
| `Workspace-Prepare-Workspace.md` | 7 | |
| `Layout.md` | 5 | Includes `desktop-home.png`, `desktop-home-topbar-hidden.png`, `desktop-repositories.png`. |
| `Workspace-Undo-Push-Commits.md` | 5 | |
| `Workspace-Update-Branch-from-Default.md` | 5 | |
| `App-Connectors.md` | 4 | |
| `Workspace-Dependencies.md` | 4 | |
| `Workspace-Incoming-Commits.md` | 4 | |
| `Workspace-New-Branch.md` | 4 | |
| `App-Home.md` | 3 | `home.png`, `home-install-agent.png`, `home-upgrade-agent.png`. |
| `Shared-Chrome.md` | 3 | Push overlay and notification cards, including `workspace-notification-agent-tracking.png`. |
| `Workspace-Features.md` | 3 | Settings, repositories toolbar, `workspace1-new-feature-modal.png`. No Repair, Remove, or CodeGraph. |
| `App-Settings.md` | 2 | `settings.png`, `settings-terminal.png`. |
| `Home.md` | 2 | |
| `Restore-Workspace.md` | 2 | |
| `Workspace-Projects.md` | 2 | |
| `Workspace-Restore-Packages.md` | 2 | |
| `App-Repository-Catalog.md` | 1 | `repositories.png` |
| `App-Workspaces.md` | 1 | `workspaces.png` |
| `Workspace-Packages.md` | 1 | `workspace2-packages.png` — predates Used by and Needs. |

Many screenshot files are not embedded by the count above (348 files, 194 embeds). Unused files were not matched one by one. Filename prefixes that exist on disk include `agent-*`, `connectors-*`, `desktop-*`, `home-*`, `layout-*`, `repositories.png`, `settings-*`, `setup-*`, `workspace-*`, `workspace1-*`, `workspace2-*`, `workspace9-*`, and `graymoon-highlights.gif`.
