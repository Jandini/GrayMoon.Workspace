# What needs update

One inventory for the 0.2.0 documentation pass. Audit date 2026-11-05. Evidence is in `_raw/`. The feature-by-feature wiki delta stays in [wiki-0.2.0.md](wiki-0.2.0.md). Screenshot counts and the shot list stay in [screenshots.md](screenshots.md).

Verdicts: **REWRITE** means the document's job and voice are wrong for a developer. **UPDATE** means keep the document and fix the named facts. **ADD** means there is no page yet.

## Before 0.2.0

These are the pages a developer or a downloader will trust on release day.

### READMEs and architecture indexes

| Path | Verdict | Fact that is wrong or missing |
| --- | --- | --- |
| `GrayMoon/README.md` | REWRITE | The install link is the 0.1.0 `GrayMoon.Desktop-stable-Setup.exe`. The page says every rollout is "forcing a clean `dotnet restore` after each level's packages are available". `DependencyUpdateOrchestrator` does not restore. The page is a landing page: it has no build, test, or project layout. |
| `GrayMoon.Release/README.md` | REWRITE | The file is the sentence "The official home for GrayMoon Desktop downloads, updates, and release notes." It names no version, asset, channel (`stable` / `main`), or `releases.<channel>.json` feed. |
| `GrayMoon.Desktop/README.md` | UPDATE | Clone samples use `C:\Workspace\GrayMoon` as the product repo. The stable checklist shows `git tag 0.1.0` and `git push origin 0.1.0`. `## Recent GrayMoon changes` is 235 bullets above the developer guide. The bridge blurb omits `RestartWorker`. |
| `GrayMoon.Desktop/docs/architecture/01-product-and-host-behavior.md` | UPDATE | The file says "Typed native commands (`WebMessageCommands`, 12)" and ends the list at `InstallWorker`. `WebMessage.cs` also defines `RestartWorker` (13 constants). `MainWindow.IsPrivilegedWebMessage` returns true for `RestartWorker`. Restart runs an elevated helper (`--restart-worker`). |
| `GrayMoon.Desktop/docs/architecture/README.md` | UPDATE | "Verified against" is Desktop `5142205` and GrayMoon `e4385f4a` (both 2026-10-17). The header says "WebView2 bridge (12 commands incl. Open in Codex CLI), Install All (incl. Cursor Agent)". The capability list lower in the same file already includes Claude and Codex. |
| `GrayMoon/docs/architecture/README.md` | UPDATE | "Code baseline reviewed through" is `e4385f4a86e388f8af80e4a7f3ff5ba828ec0f6b` (2026-10-17), 42 commits behind HEAD `8257e162`. The policy sentence says the architecture folder "is the only documentation kept in the repository." The one-paragraph opener describes every workspace as discovering projects and package relationships. |

Same Desktop pass, one line each, already covered by the rows above:

- `GrayMoon.Desktop/CLAUDE.md` describes Install All as ".NET SDK / Git / GitVersion / Cursor Agent". `HostPrerequisiteIds.InstallOrder` also installs `claudeCli` and `codexCli` before Cursor Agent. The bridge sentence omits `RestartWorker`.
- `GrayMoon.Desktop/docs/architecture/03-build-bundle-updates-and-distribution.md` winget step 1 says tag `X.Y.Z`, "e.g. `0.1.0`".

### Stale wiki pages

39 content pages: 13 OK, 21 partial, 5 stale. These five state a fact the code now contradicts. Verdict for each is **UPDATE**. Correct them. Leave the titles.

| Path | Fact that is wrong or missing |
| --- | --- |
| `GrayMoon.wiki/Workspace-Repositories.md` | Menu text is **Create PRs...**. Code label is **Create PR**. Package wait is "default 3" minutes. Code default is `PushWaitDependencyTimeoutMinutesPerDependency = 5.0` in `WorkspaceOptions.cs`. **Push Updated** is described only as Update Only, then Push Only. The normal path is two lanes (`UpdateAndPushOrchestrator`). **Merge PRs...**, GitHub name links, **GitHub SSO authorization required**, and the **Workspace** group are absent. |
| `GrayMoon.wiki/Workspace-Prepare-Workspace.md` | Same 3-minute wait ("3 packages x 3 minutes") and **Create PRs...**. If any branch cannot be created, the job stops with "Prepare Workspace stopped: branches could not be created in all selected repositories..." and does not update or push. Update and push uses the same two-lane operation as the grid. |
| `GrayMoon.wiki/Workspace-Packages.md` | Documented columns are Package Id, Framework, and Registry. `WorkspacePackages.razor` also has **Used by** and **Needs**. Package Id and a GitHub package name open GitHub package settings. `Directory.Packages.props` is honored by Update and Push (`#479`). The 3-minute wait, **Create PRs...**, and the merge sentence are on the other four stale pages. |
| `GrayMoon.wiki/Feature-Walkthrough-Library-Update.md` | Repeats the 3-minute default, the **Create PRs...** menu label, and "GrayMoon does not merge for you." **Merge PRs...** merges and can return to the default branch. The TapeImage `0.1.0` to `0.2.0` tag-upgrade recovery still matches. Leave those tag numbers. |
| `GrayMoon.wiki/Feature-Walkthrough-Tape-Density.md` | Same three false statements, and "GrayMoon does not merge for you" appears twice. Prepare Workspace, Changes, and the level-by-level update are still real flows. The walkthrough never uses a worktree Feature or AI commit text. |

The three shared false statements, on the pages where the wiki audit found them:

- Package wait default is 3 minutes, with countdown `08:59` for 3 packages. Code is 5.0 minutes. Pages: `Workspace-Repositories.md`, `Workspace-Prepare-Workspace.md`, both walkthroughs.
- Menu label **Create PRs...**. Code is **Create PR** (`WorkspaceRepositoriesHeader.razor`, `WorkspaceRepositoriesLevelHeader.razor`). Stale pages in that set: the two above plus both walkthroughs. Partial pages with the same label are listed in [wiki-0.2.0.md](wiki-0.2.0.md).
- "GrayMoon does not merge for you." **Merge PRs...** exists. Both walkthroughs. `Workspace-Repositories.md` omits the command.

### Missing wiki topics

| Topic | Where it goes | Verdict | What is missing |
| --- | --- | --- | --- |
| AI commit and pull-request text | New page | ADD | Changes provider segment, **Generate commit message**, and New Pull Request text. Wiki search found no `Claude`, `Codex`, `CodeGraph`, or "Generate commit". Evidence: architecture `05` section 34, `Components/Ai/AiProviderControl.razor`, `WorkspaceGitChanges.razor`. |
| CodeGraph on New Feature | Section on `Workspace-Features.md` | ADD | Checkbox **Create CodeGraph index**, overlay **Starting CodeGraph index...**, **Background**, and Remove Feature stopping CodeGraph. Evidence: `CreateFeatureModal.razor`, `FeatureCodeGraphService.cs`, `Worker.razor`. |
| Basic vs .NET Dependency | Section on `App-Workspaces.md` and `Workspace-Overview.md` | ADD | Radios **.NET Dependency** and **Basic**, **Calculate versions with GitVersion**, **GitHub Actions**. Evidence: `WorkspaceModal.razor`, architecture `05` section 1, `WorkspacePageAccess.cs`. |
| Workspace repository and `graymoon.json` | Section on `App-Workspaces.md` and `Restore-Workspace.md` | ADD | Local workspace name, group header **Workspace**, banner **Write Workspace definition to disk**. Evidence: architecture `05` section 1, `#388`, `#437`, `#448`, `#490`. |
| Desktop shell | New page | ADD | **Check for updates...**, **About**, Worker restart, **Open in...**. `Install-the-App.md` and `Layout.md` stop at the Docker commands and Hide title. Evidence: Desktop architecture `01` sections 8, 9, and 15. |
| **Merge PRs...** | Section on `Workspace-Repositories.md` | ADD | `BulkMergePullRequestsModal`: **Return to default branch**, **Merged**, **All repositories**. Hidden in a Feature. |
| GitHub SSO on a failed clone | Section on the repositories grid | ADD | Row heading **GitHub SSO authorization required** and **Authorize SSO**. Evidence: `GitHubSsoAuthorization.Heading`, `RepositorySyncAlert.cs`, `#451`. |
| **Open in...** | Desktop page and `Workspace-Features.md` | ADD | Menu Cursor, Claude CLI, Codex CLI, VS Code, Visual Studio, Terminal, Explorer. Toast `Starting {Label}...`. Hidden in a browser tab. Evidence: `FeatureOpenInTools.cs`. |

Heading outlines are in [wiki-0.2.0.md](wiki-0.2.0.md).

## Wiki pages

`GrayMoon.wiki` has 40 Markdown files: 39 content pages plus `_Sidebar.md`. Wiki git: `master` at `59df2e4` "Update screens", even with `origin/master`. `_Sidebar.md` is navigation only.

**OK (13).** The procedure still matches the code that was checked. `0.1.0` on several of these is a MezzoRecovery tag or a GitVersion example.

`App-Connectors.md`, `App-Home.md`, `App-Repository-Catalog.md`, `App-Settings.md`, `Home.md`, `Workspace-Checkout-from-Tags.md`, `Workspace-Custom-Dependencies.md`, `Workspace-Incoming-Commits.md`, `Workspace-New-Feature.md` (redirect still true), `Workspace-Sync-to-Default.md` (redirect still true), `Workspace-Tag-Upgrade.md`, `Workspace-Undo-Push-Commits.md`, `Workspace-Update-Branch-from-Default.md`.

**Partial (21).** The older control is still right. A 0.2.0 control on that same screen is missing. Do these in the same wiki pass as the stale pages. The one behavior each page must gain is in [wiki-0.2.0.md](wiki-0.2.0.md).

`What-is-GrayMoon.md`, `Getting-Started.md`, `Install-the-App.md`, `Layout.md`, `Shared-Chrome.md`, `Restore-Workspace.md`, `App-Workspaces.md`, `App-Worker.md`, `Workspace-Overview.md`, `Workspace-Features.md`, `Workspace-Changes.md`, `Workspace-Files.md`, `Workspace-Dependencies.md`, `Workspace-Actions.md`, `Workspace-Projects.md`, `Workspace-Switch-Branch.md`, `Workspace-Repository-Branch-Management.md`, `Workspace-Restore-Packages.md`, `Workspace-New-Branch.md`, `Workspace-Protected-Branch-and-Push-Failure.md`, `Workspace-Return-to-Default.md`.

**Stale (5).** Listed in Before 0.2.0.

## Architecture and agent docs

Stale claims a developer will copy. The file list in Before 0.2.0 is the release cut. Claims marked "can wait" are real and are scheduled under Can wait.

**Bridge command count.** `GrayMoon.Desktop/docs/architecture/01-product-and-host-behavior.md` and `GrayMoon.Desktop/docs/architecture/README.md` say 12 `WebMessageCommands`. There are 13. `RestartWorker` is missing from both written lists. The origin check is documented for `InstallHostPrerequisites` and `InstallWorker` only. `RestartWorker` is privileged and elevated. `GrayMoon.Desktop/CLAUDE.md` omits the command. The string `RestartWorker` was not found under `GrayMoon.Desktop/docs/architecture/`. Before 0.2.0 for `01` and the Desktop architecture index. Confirm `GrayMoon.Desktop/docs/architecture/02-runtime-architecture-and-integration.md` in the same edit. Add the command to sections 4 or 16 of `GrayMoon.Desktop/docs/architecture/04-developer-extension-guide.md` when `01` changes.

**Baseline hashes and October review dates.** `GrayMoon/docs/architecture/README.md` still says reviewed through `e4385f4a86e388f8af80e4a7f3ff5ba828ec0f6b` (2026-10-17). HEAD is `8257e162` (2026-11-05), 42 commits later. Later commits edited the numbered files (central package versions, local workspace name, package consumers, CodeGraph on New Feature, Claude/Codex install, push failure visibility, Actions duration, Worker auto-update). The "State documented" line omits CodeGraph, central package versions, local-only workspace name, and Worker auto-update. `GrayMoon.Desktop/docs/architecture/README.md` says verified against Desktop `5142205` and GrayMoon `e4385f4a` (both 2026-10-17). Desktop `5142205` is 40 commits behind `7faf92c`. Before 0.2.0. Move the hashes or drop them.

**Docker-only database path.** The first App paragraph in `GrayMoon/CLAUDE.md` says the App "runs in Docker" and that SQLite is "at `/app/db` (volume-mounted)". Desktop data lives under `%LocalAppData%\GrayMoon\Data\graymoon.db`. Can wait. State both modes and both paths at the first mention. Docker build sample `VERSION=1.0.0` is a placeholder argument.

**Install All missing Claude and Codex.** `GrayMoon.Desktop/CLAUDE.md` lists .NET SDK, Git, GitVersion, and Cursor Agent. Code and Desktop architecture `01` also install Claude and Codex, in that order, before Cursor Agent. The Desktop architecture index header says "incl. Cursor Agent". The capability list in that same file already includes Claude and Codex. Make the header match the list (before 0.2.0). Fix the `CLAUDE.md` sentence in that pass.

**Tag samples still 0.1.0.** `GrayMoon/README.md` deep-links the 0.1.0 setup exe and comments winget "Awaiting winget package approval." Architecture `03` describes a manual winget submission and does not record an approved package. `GrayMoon.Desktop/README.md` shows `git tag 0.1.0`, `git push origin 0.1.0`, "SemVer tags like `0.1.0`", and Quick facts example `0.1.0-desktop.23`. Desktop architecture `03` says "e.g. `0.1.0`". Keep one sample and mark it as the 0.1.0 shape. The public README and the Desktop checklist are before 0.2.0. The architecture `03` example goes in that same pass.

**Policy sentences that block the rewrite.** `GrayMoon/docs/architecture/README.md`: "it is the only documentation kept in the repository." The repo also has `README.md`, `CLAUDE.md`, `AGENTS.md`, `.cursor/`, and `docs/todo/`. `GrayMoon.Desktop/docs/architecture/README.md` says the Desktop README holds the "user-facing change list", which locks in the 235-bullet section. Change that sentence when the changelog moves.

## Can wait

- `GrayMoon/CLAUDE.md`. Add the Desktop database path beside `/app/db`. The file is already the build guide. When the Desktop changelog moves, update the task-completion rule that prepends a bullet to `GrayMoon.Desktop/README.md` (that rule is why the README is 175 KB).
- `GrayMoon/docs/architecture/04-runtime-communication-and-concurrency.md`. Add file-version check coalescing per host (`39251c09`, `FileVersionCheckCoalescer`) and planned dependency levels during a synchronized push (`a8315544`, `WorkspacePushService`).
- `GrayMoon/docs/architecture/05-user-capability-reference.md`. Add Changes markdown Preview keeping curly-brace tokens such as `{STAGE_NUMBER}` (`3731b5c1`, `MarkdownProseDiffService`), and loading overlays under the top bar and over dialogs (`8257e162`). Leave the page list.
- `GrayMoon/docs/architecture/01-product-model-and-user-workflows.md`, `02-system-architecture.md`, `03-data-model-and-persistence.md`, `06-developer-extension-guide.md`, `07-git-changes-projection-and-tree.md`. Leave. The index hash that points at them is the before-0.2.0 fix. Known gaps in `06` stay.
- `GrayMoon.Desktop/docs/architecture/02-runtime-architecture-and-integration.md`. If it repeats "12 commands" or omits `RestartWorker`, fix that sentence with `01`. Known gaps in `04-developer-extension-guide.md` stay. Add `RestartWorker` to its bridge rules when `01` gains the command.
- `GrayMoon.Desktop/docs/architecture/03-build-bundle-updates-and-distribution.md`. Tag example only, with the Desktop README checklist. Update-check failure text and the signing allow-list are current. The public README should follow this file on winget.
- `C:\Workspace\GrayMoon\CLAUDE.md` and `AGENTS.md`, and `GrayMoon/AGENTS.md`. Accurate. Leave them as agent rules.
- `GrayMoon/.cursor/README.md`. Add the missing row for `.cursor/rules/gray-unchecked-checkbox-radio.mdc`. The other ten rule files in the table exist.
- `GrayMoon/src/GrayMoon.App/Data/Migrations/README.md`. Accurate.
- A new `C:\Workspace\GrayMoon\README.md`. The workspace root has no README. Root `CLAUDE.md` already explains the layout. Useful for humans, and 0.2.0 can ship while contributors are pointed at `CLAUDE.md`.
- Azure DevOps and "MCP in GrayMoon Desktop" in the public README `## Coming soon`. Nothing in `src` or `GrayMoon/docs/todo/` names them. Omit them from the developer README.
- OK wiki pages. They can stay. Optional one-line additions are in [wiki-0.2.0.md](wiki-0.2.0.md).
