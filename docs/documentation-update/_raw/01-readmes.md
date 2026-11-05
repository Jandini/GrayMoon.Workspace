# README and entry-document audit

Audit date: 2026-11-05. Read-only. No product docs, READMEs, wiki pages, or code were edited.

Audience assumed for the eventual README rewrite: developers who need setup, layout, how to build and test, where code lives, what each screen or command does, and what is current. Marketing tone means slogans, benefit claims, vague promises, and landing-page voice.

Method: read every `README.md` under the workspace except `node_modules`, `bin`, `obj`, and `.git`. Read workspace and repo `CLAUDE.md` / `AGENTS.md` only for statements that would mislead a developer. Sampled architecture docs that those READMEs link to (indexes in full, Desktop host behavior and known gaps, GrayMoon product-model opening and extension-guide known gaps). Compared claims with current code (`graymoon.json` filename, bridge commands, host prerequisites, feature storage root) and with git history since the architecture indexes' recorded baselines. Skimmed `GrayMoon.Desktop/README.md` section `## Recent GrayMoon changes` (235 bullets) as a clue to behavior the other READMEs never state. Did not audit `GrayMoon.wiki` page bodies. Did not audit `GrayMoon/docs/todo/` bodies.

Code checked out at audit time:

- GrayMoon `8257e162` (2026-11-05) `Keep loading overlays within the page and dialogs below the top bar`. `git describe`: `0.1.0-117-g8257e162`. Only product tag found: `0.1.0`.
- GrayMoon.Desktop `7faf92c` (2026-11-05), same overlay change. Only Desktop tag found: `0.1.0`.
- Architecture indexes still say they were reviewed through GrayMoon `e4385f4a` (2026-10-17) and Desktop `5142205` (2026-10-17). Those commits are 42 and 40 commits behind HEAD. Many later commits did edit the numbered architecture files; the index hashes were not moved.

## File counts

| Set | Count | Notes |
|---|---|---|
| `README.md` files found | 7 | No `C:\Workspace\GrayMoon\README.md` |
| Agent rule files read | 5 | Root `CLAUDE.md` and `AGENTS.md`; `GrayMoon/CLAUDE.md` and `AGENTS.md`; `GrayMoon.Desktop/CLAUDE.md`. Desktop has no `AGENTS.md`. |
| Architecture files sampled | 13 | GrayMoon index + `01`-`07`; Desktop index + `01`-`04` |
| Wiki pages linked from a product README | 4 targets | Home, Getting Started, two feature walkthroughs. Local wiki has those files. Bodies not audited. |
| Verdicts that must change before a 0.2.0 release | 6 files | Listed at the end |
| Can wait | the rest | Including a new workspace-root README |

Verdicts: **OK** means a developer can trust it for its role, with at most a sentence to tidy. **UPDATE** means keep the document and fix specific stale or missing parts. **REWRITE** means the document's job and voice are wrong for a developer (or a release landing), not that every sentence is false.

## What current behavior the public README never explains

`GrayMoon.Desktop/README.md` `## Recent GrayMoon changes` is the only place many of these are written in README form. Architecture files were updated for most of them; the public `GrayMoon/README.md` was not. Themes a developer README should either state briefly or point at `docs/architecture` for:

- Workspace name is local. `graymoon.json` does not store it (`9d2ed4d5`). The public README still says the file holds "repositories, profile, version files" and does not say the name stays on this computer.
- Optional `"codegraph": true`, New Feature "Create CodeGraph index", and Remove Feature waiting on CodeGraph.
- Tag pins in the Workspace definition, and tag checkouts skipped by Return to Default and other mutating batch operations.
- Central package versions (`Directory.Packages.props`) in Update and Push.
- Packages page "Used by" column, and repository names / GitHub Packages ids as links.
- Update and Push as two lanes (a level can push while a higher level is still updating). Package wait is per package (changelog says up to 5 minutes). The notification-popup Push Updated path does not restore packages. The public README still says every rollout forces a clean `dotnet restore` after each level.
- Push failures surface in the UI (they used to be silent). Actions rows survive a transient empty GitHub run list. Last Run shows duration.
- Commit menu: only installed AI CLIs, Generate commit message on by default, On Commit options, pinned provider. PR text uses the branch's commit subjects. Cursor text can be kept when the CLI exits nonzero after a successful generation.
- Worker version mismatch is a startup dialog with "Always update the Worker automatically", plus a Host-tab Restart in Desktop. Install All includes Claude and Codex, not only Cursor Agent.
- Git Changes: large inventories (about 1,500 paths) open collapsed; an open page keeps refreshing; markdown Preview keeps `{PLACEHOLDER}` text and has Ctrl+F including Mermaid labels.
- Loading overlays sit inside the page, under the top bar, and cover open dialogs.
- Restore Workspace stays disabled until the definition check finishes.

The changelog also contains history that is no longer the filename or the behavior. Older bullets still say `.graymoon.json`. Current code constant is `graymoon.json` (`GrayMoon.Common/Manifest/WorkspaceManifestFile.cs`, `FileName`). One bullet tells the reader it was superseded: "Later superseded for the startup mismatch: that case is a dialog with a red Update now button. See above."

Two titles are duplicated, which breaks the agent rule "edit the existing bullet":

- "A failed push is no longer silent, and the Open in tools only appear in Desktop"
- "Packages shows which repositories use each package"

## Wiki links (not audited)

`GrayMoon/README.md` sends "everything else" to the GitHub wiki. Linked targets:

- https://github.com/Jandini/GrayMoon/wiki
- https://github.com/Jandini/GrayMoon/wiki/Getting-Started
- https://github.com/Jandini/GrayMoon/wiki/Feature-Walkthrough-Library-Update
- https://github.com/Jandini/GrayMoon/wiki/Feature-Walkthrough-Tape-Density
- Screenshot images under `https://raw.githubusercontent.com/wiki/Jandini/GrayMoon/screenshots/`

Those four pages exist in the local `GrayMoon.wiki` checkout (`Home.md`, `Getting-Started.md`, `Feature-Walkthrough-Library-Update.md`, `Feature-Walkthrough-Tape-Density.md`). Do not treat the wiki as the developer spec. The in-repo spec is `GrayMoon/docs/architecture/`. A developer README should link the wiki as the user guide and the architecture folder as the current-behavior reference.

`## Coming soon` in the public README (Azure DevOps, MCP in Desktop) has no matching note under `GrayMoon/docs/todo/`. Nothing in `src` names Azure DevOps or an MCP server. Those bullets are unbuilt promises, not a roadmap a developer can find in the repo.

Todo files present, not audited: `connector-token-failure-handling.md`, `generated-package-context-write.md`, `git-changes-large-changeset-scale.md`, `pr-description-commit-history.md`, `push-package-wait-and-circuit-crash.md`, `sqlite-synchronous-per-connection.md`, `worker-damaged-install-probe.md`.

---

## Missing: `C:\Workspace\GrayMoon\README.md`

- Role: would be the developer entry for the thin workspace repo.
- Verdict: **ADD** (no file today). Can wait past 0.2.0 if contributors are pointed at root `CLAUDE.md`.
- Why: the workspace root is its own git repo (`graymoon.json`, `codegraph.json`, `GitVersion.yml`) and the product folders are nested and gitignored. There is no root build. A developer who opens `C:\Workspace\GrayMoon` and looks for a README finds nothing. Root `CLAUDE.md` already explains the layout, and it is accurate. The gap is for humans, not for agents.
- The Desktop README's clone picture does not match this folder. It tells people to create `C:\Workspace\GrayMoon` (the product repo) next to `C:\Workspace\GrayMoon.Desktop`. This workspace already uses `C:\Workspace\GrayMoon` as the thin root, with the product at `C:\Workspace\GrayMoon\GrayMoon`. Those two layouts cannot share that path. See the Desktop README entry.
- Replacement sections if someone adds it later: what this repo is (not the product); sibling folders and which ones are git repos; do not build at the root; which README and `CLAUDE.md` to open; feature worktrees stay inside the feature folder.

---

## `C:\Workspace\GrayMoon\CLAUDE.md`

- Role: agent rules for the workspace, not a product README. Developers will still follow it for layout.
- Verdict: **OK**.
- Why it does not mislead: the folder table matches the tree (product, Desktop, Release, wiki). It says there is no root solution, git status at the root hides sibling repos, and build commands live in the sub-repos. Feature-worktree example `~/.graymoon/GrayMoon/features/<name>/` matches the product default (`FeatureStorageRootPath` example `C:\Users\name\.graymoon`, then `{root}\{WorkspaceName}\features`).
- Do not "fix" it into a product README. It correctly sends product build rules to `GrayMoon/CLAUDE.md` and Desktop build rules to `GrayMoon.Desktop/CLAUDE.md`.

## `C:\Workspace\GrayMoon\AGENTS.md`

- Role: shorter agent copy of the workspace rules.
- Verdict: **OK**.
- Same layout as `CLAUDE.md`. No product claims. No marketing.

---

## `C:\Workspace\GrayMoon\GrayMoon\README.md`

- Role: user-facing GitHub landing for the public product. Contributors get one sentence at the bottom.
- Verdict: **REWRITE** before 0.2.0.
- Why: the page is a landing page. It does not say how to build, test, or where projects live. It pins install to the 0.1.0 artifact. It states one rollout behavior that is no longer true for every entry point.

Marketing and landing-page voice (short quotes):

- Tagline: "One workspace. Every repository. Always in sync."
- "GrayMoon is the missing control plane."
- "built for how teams work today: fast, parallel, AI-assisted development"
- Section title: "Why teams pick GrayMoon"
- "exactly the workflow AI coding agents create"
- "no more hunting for which repo you forgot to check out"
- "no more `git status` in a dozen terminals"
- "you're cloning your first workspace in minutes"
- "Coming soon" promises Azure DevOps ("so teams whose code and CI live in Azure DevOps are not locked to one host") and "MCP in GrayMoon Desktop" ("a stable tool surface"). Neither is in the code or in `docs/todo/`.

Stale or over-broad for current behavior:

- Install is a direct URL to `GrayMoon.Desktop-stable-Setup.exe` on the **0.1.0** GitHub release, plus `winget install graymoon` commented as "Awaiting winget package approval." The only tag in either repo is `0.1.0`. Shipping 0.2.0 without editing this ships the old installer. Architecture doc `03` describes a manual winget submission; it does not record that a package was approved. The "awaiting approval" line is an unverified status slogan, not a setup step.
- "forcing a clean `dotnet restore` after each level's packages are available" describes every package rollout. Current code does not. `DependencyUpdateOrchestrator` does not restore; restore is on the push lane or a manual action (`GrayMoon/CLAUDE.md`). The notification popup's Push Updated / Level N Only path updates and pushes without that restore (commit `e87bcb05`, also the top of the Desktop changelog). The two-lane push itself is real and is missing from this README.
- The feature list is a compressed tour (Git Changes markdown Preview, Mermaid, Ctrl+F, AI commit and PR text, profiles, `graymoon.json`, Actions grid, worktree Features). It is not wrong as a sketch, and it is not something a developer can build or debug from. Screenshots are wiki GIFs, not a map of routes.
- "Documentation" says every page and workflow lives in the wiki, then one contributor sentence points at `docs/architecture`, `CLAUDE.md`, and `AGENTS.md`. A developer who stops at the wiki never sees the in-repo spec.

What is already fine to keep as facts, in plainer words: two processes (App in Docker or inside Desktop; Worker on the host); Desktop does not attach to Docker; Docker example `docker run ... -p 8384:8384 jandini/graymoon:latest`; port 8384; Worker install from the Worker page; dual license files; link to architecture.

Replacement sections (do not paste marketing back in):

1. What GrayMoon is (one paragraph: multi-repo workspace, App orchestrates, Worker does git and files).
2. Two ways to run it (Desktop child process on `127.0.0.1:8384`; Docker web app plus a host Worker). State that they never share one App.
3. Repository layout (`src/GrayMoon.App`, `Worker`, `Application`, `Abstractions`, `Common`, and the three test projects; `GrayMoon.slnx`).
4. Requirements (.NET 10 SDK, Git; GitVersion, GitHub connector, and AI CLIs are optional and what they unlock).
5. Build and test (the three `dotnet test` projects, `dotnet tool restore`).
6. Run the App and the Worker locally, and the Docker command, including where the database file is in each mode.
7. Main screens in one line each (Repositories, Changes, Projects, Packages, Files, Deps, Actions, Worker, connectors) and where Features sit.
8. Workspace definition (`graymoon.json` name, what it stores, what stays on the machine: display name, pinned AI provider).
9. Where current behavior is written (`docs/architecture/`) and where the user guide is (wiki links).
10. What is not in this version (Azure DevOps, Desktop MCP) as a short absence, or omit it.
11. License.

## `C:\Workspace\GrayMoon\GrayMoon\CLAUDE.md`

- Role: agent and contributor build guide. Also the only build/run page the public README points at.
- Verdict: **UPDATE**. Can wait until after the public README rewrite, because this file is already the real developer guide.
- Why: commands match the tree (`GrayMoon.slnx` exists; eight projects; three test projects). The long architecture summary tracks recent behavior (two-lane Update and Push, CodeGraph, version lock, context scoping, page-scoped overlays, tag pins excluded from mutating batches). It is denser than a README and that is appropriate here.
- Misleading if skimmed: the App bullet says it "runs in Docker" and that SQLite is "at `/app/db` (volume-mounted)" before "Deployment modes" explains Desktop. Desktop does not use `/app/db`. Data lives under `%LocalAppData%\GrayMoon\Data\graymoon.db` (Desktop README and Desktop architecture). A developer who copies the first App paragraph will look for the wrong database.
- Docker build sample `VERSION=1.0.0` is a placeholder argument, not the product version. Leave it or label it as a sample.
- The "Task completion" rule that prepends a bullet to the Desktop README changelog is why that README is 175 KB. Note it when the changelog is split out, so agents do not keep appending there.

Replacement is not a new outline. Fix the App paragraph so Docker and Desktop are both stated at the first mention, with both database paths.

## `C:\Workspace\GrayMoon\GrayMoon\AGENTS.md`

- Role: agent safety rules (DbContext, migrations, feature scoping, tag pins, changelog style).
- Verdict: **OK**.
- These are coding rules, not a product tour. They match `CLAUDE.md` and the extension guide. They do not describe user-facing behavior a README must carry. The changelog-style rule has the same process side effect as `CLAUDE.md`; do not treat that as a product-doc defect.

## `C:\Workspace\GrayMoon\GrayMoon\.cursor\README.md`

- Role: index of Cursor rules for this repo.
- Verdict: **UPDATE**. Can wait.
- The table omits `.cursor/rules/gray-unchecked-checkbox-radio.mdc`, which is on disk and is stated in `AGENTS.md` and `CLAUDE.md`. The other ten rule files in the table exist.
- Replacement sections: keep the Windows/shell notes; add the missing rule row. Not a product README.

## `C:\Workspace\GrayMoon\GrayMoon\src\GrayMoon.App\Data\Migrations\README.md`

- Role: developer note for the hand-written migration steps.
- Verdict: **OK**.
- Matches `CLAUDE.md` "Database schema" and architecture `03`: `EnsureCreated`, then `Migrations.RunAllAsync`, `user_version`, legacy step 1, strict steps, `VACUUM INTO` backup, idempotent steps, do not edit a shipped step. No marketing. No version number to go stale, because it says "append the next version".

---

## `C:\Workspace\GrayMoon\GrayMoon\docs\architecture\README.md`

- Role: developer index for the current-state architecture.
- Verdict: **UPDATE** before 0.2.0 (the index, not a rewrite of the set).
- Why the body is mostly the right document: reading order, two-process rule, feature diagram, page list, and "App must not touch local git" match the code and `CLAUDE.md`. Tone is developer, not marketing. "GrayMoon is a control plane for multi-repository .NET development" is a job description, not a slogan.
- Stale header: "Code baseline reviewed through: `e4385f4a86e388f8af80e4a7f3ff5ba828ec0f6b`" (2026-10-17). HEAD is `8257e162` (2026-11-05), 42 commits later. Later commits edited the numbered files (central package versions, local workspace name, package consumers, CodeGraph on New Feature, Claude/Codex install, push failure visibility, Actions duration, Worker auto-update). A reader who trusts the hash will think the folder stopped in October, or will ignore newer text because the header disagrees.
- "State documented" line does not name CodeGraph, central package versions, local-only workspace name, or Worker auto-update, even though the numbered docs now do.
- Policy sentence overclaims: "it is the only documentation kept in the repository." The same repo also has `README.md`, `CLAUDE.md`, `AGENTS.md`, `.cursor/`, and `docs/todo/`. The next bullets explain the real policy (current behavior here, proposals in `docs/todo/`). The "only documentation" sentence will make a rewrite delete the README or the todo folder.
- "GrayMoon in one paragraph" still says the product "discovers their projects and package relationships" as if every workspace does. Profiles (Basic vs .NET) are listed later under core workflows. Lead with the profile gate so a Basic workspace is not described as a .NET graph.

Replacement sections: keep the reading order and the two diagrams. Replace the header block (date or commit, state line). Replace the policy sentence so README, CLAUDE, and `docs/todo` have explicit roles.

## Numbered GrayMoon architecture docs

Sampled, not read line by line. Git history from `419c203f` ("Refresh architecture docs") through `8257e162` shows most behavior commits also edit `docs/architecture/`. That is the right maintenance pattern. Verdicts below are "safe to treat as the spec, with named holes", not "rewrite".

### `01-product-model-and-user-workflows.md`

- Role: developer (and the user-workflow half of the spec).
- Verdict: **OK** for 0.2.0, after the index hash is fixed.
- Opening is concrete (clone, branch, update, restore, commit, push, wait, PR) and says GrayMoon does not replace Git. Terminology covers Workspace, profile, Feature, context, `graymoon.json`. Later commits updated this file for local workspace names, central package versions, CodeGraph on create, PR commit history, repository links. No marketing section.
- Do not copy "Why teams pick GrayMoon" into this file.

### `02-system-architecture.md`

- Role: developer.
- Verdict: **OK**.
- "Solution projects" lists the eight `src` projects that exist. Deployment paragraph states Docker and Desktop as mutually exclusive, and names `codegraph` as a Worker host tool. Updated for Worker auto-update and the notification-popup restore skip.

### `03-data-model-and-persistence.md`

- Role: developer.
- Verdict: **OK**.
- Touched for local workspace name, package consumers, path-based project identity, Actions duration, push row races. Not re-read in full. Migrations README points here and agrees with `CLAUDE.md`.

### `04-runtime-communication-and-concurrency.md`

- Role: developer.
- Verdict: **UPDATE**. Can wait if 0.2.0 does not promise a concurrency rewrite.
- The file is maintained (Git Changes watchers, two-lane push, package-wait diagnostics, CodeGraph). Two behavior commits did not touch it or any architecture file:
  - `39251c09` isolates file-version check coalescing per host (`FileVersionCheckCoalescer`).
  - `a8315544` preserves planned dependency levels during a synchronized push (`WorkspacePushService`).
- A developer debugging a push that "skips" a level or a file-version check that bleeds across hosts will not find those rules here.
- Sections to add or extend, not a new outline: file-version check coalescing; planned levels during synchronized push. Leave the rest.

### `05-user-capability-reference.md`

- Role: developer page-by-page reference of what the user can do.
- Verdict: **UPDATE**. Can wait for a full pass; one preview gap is user-visible.
- This is the file a rewritten README should point to for "what the screen does". It was updated for package consumers, GitHub links, bulk-merge return-to-default, Actions empty responses, Actions duration, AI draft retention, PR descriptions, CodeGraph on New Feature, Cursor nonzero exit, sibling package access.
- Not updated for `3731b5c1`: Git Changes markdown Preview keeps curly-brace tokens such as `{STAGE_NUMBER}`. That behavior is only in the Desktop changelog and in `MarkdownProseDiffService`.
- `8257e162` (overlays under the top bar, over dialogs) updated `CLAUDE.md` and the Desktop changelog, not this file.
- Sections to extend: Changes markdown Preview; loading overlay stacking. Do not rewrite the page list.

### `06-developer-extension-guide.md`

- Role: developer rules and known gaps.
- Verdict: **OK**.
- Known gaps are labeled "still true" and are the right place for open defects (self-update URL trust, hook listener without a secret, `dotnet restore` reported as success, large Git Changes snapshots, and others). This audit did not re-verify every gap against code. Do not delete them during a README rewrite. `docs/todo/git-changes-large-changeset-scale.md` is correctly deferred, not described as shipped.

### `07-git-changes-projection-and-tree.md`

- Role: developer, Changes pipeline and scale.
- Verdict: **OK**, with the Preview exception owned by `05`.
- Updated for large-inventory loading (`29aed9c2`) and watcher renewal (`8a246600`). The curly-brace preview change is a render detail, not this pipeline. Point the README at this file for "how Changes stays in sync", not at the 235 changelog bullets.

---

## `C:\Workspace\GrayMoon\GrayMoon.Desktop\README.md`

- Role: developer entry for the private shell, plus an unbounded user-facing changelog.
- Verdict: **UPDATE** before 0.2.0. The build, run, and release sections should stay. The changelog should not stay in this shape.
- Size: 175308 bytes, 572 lines. Lines 32-272 are `## Recent GrayMoon changes` (235 bullets). The developer guide starts at "Repository layout" (line 273) and is the part to keep.

What is already developer-grade (keep, edit in place):

- Quick facts: Windows 10 22H2+, .NET 10, WPF + WebView2, Velopack 1.2.161, channels `stable` / `main` / branch, user data under `%LocalAppData%\GrayMoon\`, App logs under `%ProgramData%\GrayMoon\Logs\`.
- Prerequisites name SDK `10.0.301` with `rollForward: latestMinor`, WebView2, and both sibling repos for combined build.
- Build, test, `Publish-GrayMoonBundle.ps1`, `Validate-Bundle.ps1`, `New-VelopackPackage.ps1 -Channel main`.
- Dev run: `Prepare-DevRun.ps1` publishes the sibling App into the Desktop output; a plain `dotnet build` does not refresh it; `Desktop:DevAppExecutablePath`; fixed port 8384; exit when the port is taken.
- Architecture mermaid matches the process model (Job Object, named pipe, `/hubs/desktop`, `/hub/worker`, Velopack feed).
- Release table matches architecture `03`: `main` manual prerelease unsigned; other branches isolated feeds; SemVer tag `stable` signed and bundles the latest GrayMoon release tag. Secrets are names only.
- Data locations and dual-license table match the architecture index.
- Combined solution "10 `.csproj`" is right: 8 GrayMoon + 2 Desktop.

What a developer will get wrong:

- Clone layout and the init snippet use `C:\Workspace\GrayMoon` as the product repo and `C:\Workspace\GrayMoon.Desktop` as the shell. The dev-run sample path is `C:\Workspace\GrayMoon\src\GrayMoon.App\bin\Debug\net10.0\GrayMoon.App.exe`. In this workspace those paths are `C:\Workspace\GrayMoon\GrayMoon\...` and `C:\Workspace\GrayMoon\GrayMoon.Desktop`. Relative `../GrayMoon` from the Desktop repo is the real contract; the absolute `C:\Workspace\...` picture fights the thin workspace root.
- Stable checklist shows `git tag 0.1.0` and `git push origin 0.1.0`. The prose says to tag whatever GitVersion computes, then the sample repeats the only tag that already exists. Copying it for 0.2.0 retags 0.1.0. Same example in the layout table ("SemVer tags like `0.1.0`") and in Quick facts (`0.1.0-desktop.23` as an example of the scheme). Keep one example and mark it as the 0.1.0 shape, not the next command to run.
- Native-bridge sentence omits Restart Worker. It lists Open in tools, Install All, and Install Worker. Code has a thirteenth command, `RestartWorker`, and it is privileged (below).
- `## Recent GrayMoon changes` is a user diary, not current behavior. Bullets say "you", name toasts and button colors, and include "Later superseded". Two titles are duplicated. Older bullets still say `.graymoon.json`. Agent rules require a new bullet on every user-visible change and say to edit rather than duplicate; the file shows the edit rule is not holding. About 40 Desktop commits since the October architecture baseline touched this README; 4 touched `docs/architecture/`. The changelog became the product history because the shell repo is where the rule points, not because Desktop implemented those features.

Overview tone is light but acceptable ("so developers can run GrayMoon without opening a browser tab"). Do not expand it into the public README's "Why teams pick GrayMoon".

Replacement sections (the file already has most of these; do not invent a second guide):

1. What Desktop is (thin host, not a second product).
2. Requirements and the sibling layout, with relative paths, plus one sentence on the thin workspace root versus a fresh pair of clones.
3. Initialize, open, build, test, bundle, validate, local Velopack package.
4. Run in development and from `artifacts\bundle`, including the port and `Prepare-DevRun.ps1`.
5. Process and bridge (add Restart Worker next to Install Worker).
6. Release channels, secrets, and a tag example that is clearly a sample.
7. Data locations and licensing.
8. Where behavior lives: `docs/architecture/` here for the host; `GrayMoon/docs/architecture/` for the product; GitHub Releases for notes. Remove the growing bullet list from the README, or replace it with a pointer. If a short "since 0.1.0" note is required for the release, keep it to behavior a Desktop developer must know (bridge commands, update check bounds, Worker auto-update, Install All including Claude and Codex), not every Blazor pixel.

## `C:\Workspace\GrayMoon\GrayMoon.Desktop\CLAUDE.md`

- Role: agent and contributor commands for the shell.
- Verdict: **UPDATE**. Same pass as the architecture command list. Not a rewrite.
- Commands match the README (`Initialize-DevelopmentWorkspace.ps1`, both solutions, `Prepare-DevRun.ps1`, bundle scripts). Release-channel paragraph matches architecture `03`.
- Misleading: `HostPrerequisiteInstaller` is described as "Install All for .NET SDK / Git / GitVersion / Cursor Agent". Code and architecture `01` also install `claudeCli` and `codexCli`, in that order, before Cursor Agent (`HostPrerequisiteIds.InstallOrder`). An agent adding a prerequisite will follow the shorter list.
- The bridge sentence does not name `RestartWorker`.
- "10 .csproj" breakdown in the solutions table is correct.

Sections to fix in place: Install All list; bridge command list. Leave the command block alone.

## `C:\Workspace\GrayMoon\GrayMoon.Desktop\docs\architecture\README.md`

- Role: developer index for the shell.
- Verdict: **UPDATE** before 0.2.0 (header and native-capability list).
- "Verified against" is Desktop `5142205` and GrayMoon `e4385f4a` (both 2026-10-17). Same hash problem as the product index. Body text is ahead of the hash: Install All on the capability list includes Claude, Codex, and Cursor Agent; Open in includes Codex CLI; Worker upgrade dialog is described.
- Header still says "WebView2 bridge (12 commands incl. Open in Codex CLI), Install All (incl. Cursor Agent)". There are 13 `WebMessageCommands` constants. `RestartWorker` is the one missing from the written list of 12. "incl. Cursor Agent" understates Install All; the capability list lower in the same file already includes Claude and Codex. Make the header match that list.
- "Open in" capabilities and the Feature paragraph match `OpenInToolCatalog` (Cursor, VS Code, Visual Studio, Claude CLI, Codex CLI, Terminal, Explorer). Good.
- Policy line is accurate for this repo: architecture folder, `README.md`, and `CLAUDE.md` are the docs. It also says the README holds the "user-facing change list", which locks in the 235-bullet section. When the changelog moves, change this sentence too.

## `01-product-and-host-behavior.md`

- Role: developer, current host behavior.
- Verdict: **UPDATE** before 0.2.0.
- Stale sentences:
  - "Typed native commands (`WebMessageCommands`, 12):" and the following list. The list ends at `InstallWorker`. `WebMessage.cs` also defines `RestartWorker`.
  - "The WebView2 message-source origin check ... applies only to `InstallHostPrerequisites` and `InstallWorker`." `MainWindow.IsPrivilegedWebMessage` also returns true for `RestartWorker`. Restart runs an elevated helper (`--restart-worker`). A developer who trusts the doc will leave Restart off the origin check.
- Install All order and the Claude/Codex/Cursor install commands match `HostPrerequisiteIds` and the installer. Worker auto-update ("Always update the Worker automatically", `SetWorkerAutoUpdate`, dialog skipped when `AutoUpdate` is set) matches the November changelog and is written here, not only in the README bullets. Open-in launch details (Cursor Electron CLI, `wt.exe` for Claude and Codex) match `OpenInToolCatalog`.
- Section to add: `RestartWorker` (who sends it, elevated helper, origin check, result message). Put it next to Install Worker. Do not rewrite startup, tray, or updates.

## `02-runtime-architecture-and-integration.md`

- Role: developer, process and hub integration.
- Verdict: **OK** on a sample. Not fully read.
- Touched for Worker auto-update (`3730f68`) and Claude/Codex install (`14ba321`). The command-count bug is in `01` and the index. If `02` repeats "12 commands" or omits `RestartWorker`, fix that sentence in the same edit as `01`. This audit did not find the string `RestartWorker` anywhere under Desktop `docs/architecture/`.

## `03-build-bundle-updates-and-distribution.md`

- Role: developer, build, Velopack, winget, signing.
- Verdict: **UPDATE**. Small. Do it with the Desktop README tag example.
- Winget section is procedural and matches the README: stable uses `*Setup.exe`; `main` and branch publish `*Setup.zip`; updater uses `releases.<channel>.json` and nupkgs; submission to `microsoft/winget-pkgs` is manual. It does not say "awaiting approval". The public README should follow this file, not the other way around.
- Step 1 of the winget procedure says tag `X.Y.Z`, "e.g. `0.1.0`". Same footgun as the Desktop README checklist.
- Update-check failure text was updated in `e29e2ac` ("The update server did not respond. Try again later." on timeout). That part is current. Signing section names the publisher and the allow-list (`GrayMoon.Desktop.exe`, `GrayMoon.App.exe`, `graymoon-worker.exe`). Leave it.
- Sections to touch: the tag example only.

## `04-developer-extension-guide.md`

- Role: developer extension rules and known gaps.
- Verdict: **OK**.
- Known gaps still match the code that was checked: `BuildManifestService` "registered but not used" is also what Desktop `CLAUDE.md` says. "Bridge commands the App never sends" (`CopyToClipboard`, `OpenLocalRepositoryFolder`, `OpenExternalUrl`) matches the index. "`WorkerInstaller` has no lock of its own" plus the `Global\GrayMoonWorkerInstall` mutex in `install-worker.ps1` matches `01` ("That mutex is the only guard"). The changelog line "Two Worker installs can no longer corrupt each other" is that mutex, not a second lock inside `WorkerInstaller`. Do not delete the gap.
- Add `RestartWorker` to the bridge rules in section 4 or 16 when `01` gains the command, so the extension guide does not still say elevation is only Install All and Install Worker.

---

## `C:\Workspace\GrayMoon\GrayMoon.Release\README.md`

- Role: release landing. The whole file is:

```
# GrayMoon.Release
The official home for GrayMoon Desktop downloads, updates, and release notes.
```

- Verdict: **REWRITE** before 0.2.0.
- Why: architecture `03` says this repository is the only public installer and update feed, and that installers must not be mirrored to `Jandini/GrayMoon`. The public product README does not send people here for the current release. It deep-links the 0.1.0 `Setup.exe`. This README has no version, no asset name, no channel (`stable` vs `main`), no update-feed filename, and no pointer to release notes or the license. "Official home" is a label, not instructions.
- It is not full of marketing adjectives. It is empty. A developer or a release publisher cannot tell what to upload or what a user should download.

Replacement sections:

1. What this repository is (Velopack feed and GitHub Releases; not the source).
2. Channels: `stable` (signed `Setup.exe`, full release), `main` and branch (unsigned `Setup.zip`, prerelease). An installed app stays on its channel.
3. What a user downloads, and that in-app update uses `releases.<channel>.json` plus nupkgs, not the setup exe.
4. Where the source and the user guide live (`Jandini/GrayMoon`, `Jandini/GrayMoon.Desktop` private, wiki).
5. License pointer (the installer shows `Licensing-Overview.txt`).
6. What not to do (do not attach installers to the GrayMoon product repo).

---

## Priority

### Must change before a 0.2.0 release

These are what a developer or a downloader will trust on release day. The numbered architecture books are largely already current; the entry pages are not.

1. `GrayMoon/README.md` - **REWRITE**. It is the public page, it installs 0.1.0, it claims every rollout restores, and it is a landing page. Point build/test at the layout and at `docs/architecture`, and point the user guide at the wiki without making the wiki the spec.
2. `GrayMoon.Release/README.md` - **REWRITE**. The feed repo cannot stay a two-line slogan when 0.2.0 is published there.
3. `GrayMoon.Desktop/README.md` - **UPDATE**. Fix the absolute clone paths and the `git tag 0.1.0` sample. Stop using `## Recent GrayMoon changes` as the behavior spec (split or replace; update the architecture policy sentence that calls it the change list). Add Restart Worker beside the other bridge commands in the architecture blurb.
4. `GrayMoon.Desktop/docs/architecture/01-product-and-host-behavior.md` - **UPDATE**. 13 commands, not 12. `RestartWorker` is origin-checked and elevated. The current sentences omit it.
5. `GrayMoon.Desktop/docs/architecture/README.md` - **UPDATE**. Same command count and Install All parenthetical. Move the "verified against" hashes, or drop them so they cannot claim October.
6. `GrayMoon/docs/architecture/README.md` - **UPDATE**. The baseline hash is 42 commits behind the files it introduces. Fix the "only documentation in the repository" sentence so the README rewrite has a place to live.

Also in that same Desktop pass, one line in `GrayMoon.Desktop/CLAUDE.md` (Install All omits Claude and Codex) and the `0.1.0` example in architecture `03`. Those are part of items 3 and 4, not extra projects.

### Can wait

- `GrayMoon/CLAUDE.md` - state Desktop database path next to `/app/db`. The file is already the build guide.
- `GrayMoon/docs/architecture/04` and `05` - add file-version coalescing per host, planned push levels, curly-brace markdown preview, overlay stacking. The rest of those files moved with the code.
- `GrayMoon/docs/architecture/01`, `02`, `03`, `06`, `07` - leave, except the index hash that points at them.
- `GrayMoon.Desktop/docs/architecture/02` and `04` - confirm they do not repeat "12 commands"; add `RestartWorker` to the extension rules when `01` changes. Known gaps can stay.
- `GrayMoon.Desktop/docs/architecture/03` - tag example only, with the README checklist.
- Workspace root `CLAUDE.md` and `AGENTS.md`, `GrayMoon/AGENTS.md` - accurate agent rules.
- `GrayMoon/.cursor/README.md` - add the missing checkbox rule.
- `Migrations/README.md` - accurate.
- A new `C:\Workspace\GrayMoon\README.md` - useful, not required to ship 0.2.0.
- Wiki pages and `docs/todo/` - other work. Do not promote "Coming soon" Azure DevOps or Desktop MCP into the developer README unless a todo or a design note exists.
