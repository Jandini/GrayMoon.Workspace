# README rewrite

How each README should read for a developer who builds and runs GrayMoon. The audit found 7 `README.md` files. There is no `C:\Workspace\GrayMoon\README.md`.

Write for setup, layout, build and test, where the code lives, what each screen or command does, and what is current. The in-repo behavior reference is `GrayMoon/docs/architecture/` and `GrayMoon.Desktop/docs/architecture/`. The wiki is the user guide.

Do not paste the replacement bodies from this note. Follow the outlines.

The README audit counted 235 bullets in `GrayMoon.Desktop/README.md` section `## Recent GrayMoon changes`. The wiki audit counted 160 bullets in that same section. This plan uses 235.

## Missing: `C:\Workspace\GrayMoon\README.md`

Verdict: **ADD**. Can wait past 0.2.0 while people are pointed at root `CLAUDE.md`.

The workspace root is its own git repo (`graymoon.json`, `codegraph.json`, `GitVersion.yml`). Product folders are nested and gitignored. There is no root build. Root `CLAUDE.md` matches the tree. The gap is for humans.

The Desktop README's clone picture uses `C:\Workspace\GrayMoon` as the product repo beside `C:\Workspace\GrayMoon.Desktop`. This workspace already uses `C:\Workspace\GrayMoon` as the thin root, with the product at `C:\Workspace\GrayMoon\GrayMoon`. Those two layouts cannot share that path. Say so if this file is added.

Sections if someone adds it later:

1. What this repo is (the thin workspace repo, separate from the product).
2. Sibling folders and which ones are git repos.
3. Do not build at the root.
4. Which README and `CLAUDE.md` to open (`GrayMoon/README.md`, `GrayMoon/CLAUDE.md`, `GrayMoon.Desktop/README.md`, `GrayMoon.Desktop/CLAUDE.md`).
5. Feature worktrees stay inside the feature folder.

## `GrayMoon/README.md`

Verdict: **REWRITE** before 0.2.0.

Role today: user-facing GitHub landing. Contributors get one sentence at the bottom. It does not say how to build, test, or where projects live. It pins install to the 0.1.0 artifact. It states one rollout behavior that is wrong for every entry point.

### Passages that must leave

All of these are in `GrayMoon/README.md`:

- "One workspace. Every repository. Always in sync."
- "GrayMoon is the missing control plane."
- "built for how teams work today: fast, parallel, AI-assisted development"
- Section title "Why teams pick GrayMoon"
- "exactly the workflow AI coding agents create"
- "no more hunting for which repo you forgot to check out"
- "no more `git status` in a dozen terminals"
- "you're cloning your first workspace in minutes"
- `## Coming soon`: Azure DevOps ("so teams whose code and CI live in Azure DevOps are not locked to one host") and "MCP in GrayMoon Desktop" ("a stable tool surface"). Neither is in the code or in `docs/todo/`.
- The direct URL to `GrayMoon.Desktop-stable-Setup.exe` on the 0.1.0 GitHub release, and the winget line "Awaiting winget package approval."
- "forcing a clean `dotnet restore` after each level's packages are available"

Point install at `GrayMoon.Release` and at the channel feed described in `GrayMoon.Desktop/docs/architecture/03-build-bundle-updates-and-distribution.md`. That file does not say "awaiting approval."

Restore belongs on the push lane or on a manual action (`GrayMoon/CLAUDE.md`). The notification popup's Push Updated / Level N Only path updates and pushes without that restore (`e87bcb05`). Two-lane Update and Push is missing from this README and belongs in the behavior section, with a pointer to architecture `05`.

The compressed feature tour (Git Changes markdown Preview, Mermaid, Ctrl+F, AI commit and PR text, profiles, `graymoon.json`, Actions, worktree Features) can stay as one line per screen. It is a map of routes, with the detail left in architecture `05` and the wiki.

"Documentation" currently sends every page and workflow to the wiki, then one contributor sentence points at `docs/architecture`, `CLAUDE.md`, and `AGENTS.md`. Link the wiki as the user guide and `docs/architecture/` as the current-behavior reference.

### Facts to keep, in plainer words

- Two processes: the App in Docker or inside Desktop, and the Worker on the host.
- Desktop does not attach to Docker. The two modes never share one App.
- Docker example `docker run ... -p 8384:8384 jandini/graymoon:latest`. Port 8384.
- Worker install from the Worker page.
- Dual license files.
- Link to `docs/architecture/`.

### Section outline

1. What GrayMoon is. One paragraph: multi-repo workspace, App orchestrates, Worker does git and files.
2. Two ways to run it. Desktop child process on `127.0.0.1:8384`. Docker web app plus a host Worker. State that they never share one App.
3. Repository layout. `src/GrayMoon.App`, `Worker`, `Application`, `Abstractions`, `Common`, and the three test projects. `GrayMoon.slnx`.
4. Requirements. .NET 10 SDK and Git. GitVersion, the GitHub connector, and the AI CLIs are optional. Say what each one unlocks.
5. Build and test. The three `dotnet test` projects. `dotnet tool restore`.
6. Run the App and the Worker locally, and the Docker command. Say where the database file is in each mode (`/app/db` in Docker, `%LocalAppData%\GrayMoon\Data\graymoon.db` in Desktop).
7. Main screens in one line each: Repositories, Changes, Projects, Packages, Files, Deps, Actions, Worker, connectors. Say where Features sit.
8. Workspace definition. `graymoon.json`: what it stores, and what stays on the machine (display name, pinned AI provider). The name is local (`9d2ed4d5`). The file constant is `graymoon.json` (`GrayMoon.Common/Manifest/WorkspaceManifestFile.cs`, `FileName`).
9. Where current behavior is written (`docs/architecture/`) and where the user guide is (wiki links: Home, Getting Started, the two feature walkthroughs).
10. What is absent in this version (Azure DevOps, Desktop MCP), as a short absence, or omit it.
11. License.

Screenshot images on this page are a short highlight set pulled from `https://raw.githubusercontent.com/wiki/Jandini/GrayMoon/screenshots/`. One embed is broken: `screenshots/worker-install.gif`. The file on disk is `agent-install.gif`. Fix that link when the README is rewritten. Capture policy is in [screenshots.md](screenshots.md).

## `GrayMoon.Desktop/README.md`

Verdict: **UPDATE** before 0.2.0.

Role: developer entry for the private shell, plus an unbounded changelog. Size: 175308 bytes, 572 lines. Lines 32-272 are `## Recent GrayMoon changes` (235 bullets). The developer guide starts at "Repository layout" (line 273). Keep that guide. Edit it in place.

The Recent GrayMoon changes list is a changelog. It should not stay as 200-plus bullets in the developer intro. Bullets address "you", name toasts and button colors, and include "Later superseded". Older bullets still say `.graymoon.json`. Two titles are duplicated, which breaks the rule "edit the existing bullet":

- "A failed push is no longer silent, and the Open in tools only appear in Desktop"
- "Packages shows which repositories use each package"

About 40 Desktop commits since the October architecture baseline touched this README. 4 touched `docs/architecture/`. Current behavior belongs in the architecture docs. The history can live in the GitHub Release notes for `GrayMoon.Desktop`. Host behavior stays in `GrayMoon.Desktop/docs/architecture/`. Product behavior stays in `GrayMoon/docs/architecture/`. When the bullet list leaves this file, change the policy sentence in `GrayMoon.Desktop/docs/architecture/README.md` that calls the README the "user-facing change list". Also change the task-completion rule in `GrayMoon/CLAUDE.md` that prepends a new bullet here, or agents will keep appending.

If a short "since 0.1.0" note is required in the README, keep it to behavior a Desktop developer must know: bridge commands (including Restart Worker), update-check bounds, Worker auto-update, and Install All including Claude and Codex.

Overview tone can stay ("so developers can run GrayMoon without opening a browser tab"). Do not copy "Why teams pick GrayMoon" into this file.

### Already developer-grade (keep)

- Quick facts: Windows 10 22H2+, .NET 10, WPF + WebView2, Velopack 1.2.161, channels `stable` / `main` / branch, user data under `%LocalAppData%\GrayMoon\`, App logs under `%ProgramData%\GrayMoon\Logs\`.
- Prerequisites: SDK `10.0.301` with `rollForward: latestMinor`, WebView2, both sibling repos for the combined build.
- Build, test, `Publish-GrayMoonBundle.ps1`, `Validate-Bundle.ps1`, `New-VelopackPackage.ps1 -Channel main`.
- Dev run: `Prepare-DevRun.ps1` publishes the sibling App into the Desktop output. A plain `dotnet build` does not refresh it. `Desktop:DevAppExecutablePath`. Fixed port 8384. Exit when the port is taken.
- The architecture mermaid (Job Object, named pipe, `/hubs/desktop`, `/hub/worker`, Velopack feed).
- Release table: `main` manual prerelease unsigned. Other branches use isolated feeds. A SemVer tag on `stable` is signed and bundles the latest GrayMoon release tag. Secrets are names only.
- Data locations and the dual-license table.
- Combined solution "10 `.csproj`" (8 GrayMoon + 2 Desktop).

### Fix in place

- Clone layout and the init snippet. Relative `../GrayMoon` from the Desktop repo is the contract. State the thin workspace root (`C:\Workspace\GrayMoon\GrayMoon` and `C:\Workspace\GrayMoon\GrayMoon.Desktop`) beside a fresh pair of clones. The dev-run sample `C:\Workspace\GrayMoon\src\GrayMoon.App\bin\Debug\net10.0\GrayMoon.App.exe` is the fresh-pair path.
- Tag samples. `git tag 0.1.0`, `git push origin 0.1.0`, "SemVer tags like `0.1.0`", and `0.1.0-desktop.23` must leave as the next command to run. Keep one example and mark it as the 0.1.0 shape. The prose already says to tag whatever GitVersion computes.
- Native-bridge sentence. It lists Open in tools, Install All, and Install Worker. Add Restart Worker. Code has a thirteenth command, `RestartWorker`, and it is privileged.

Same pass: Install All in `GrayMoon.Desktop/CLAUDE.md` (add Claude and Codex), and the `0.1.0` example in `GrayMoon.Desktop/docs/architecture/03-build-bundle-updates-and-distribution.md`.

### Section outline

The file already has most of these. Do not invent a second guide.

1. What Desktop is. Thin host, separate from a second product.
2. Requirements and the sibling layout, with relative paths, plus one sentence on the thin workspace root versus a fresh pair of clones.
3. Initialize, open, build, test, bundle, validate, local Velopack package.
4. Run in development and from `artifacts\bundle`, including the port and `Prepare-DevRun.ps1`.
5. Process and bridge. Add Restart Worker next to Install Worker.
6. Release channels, secrets, and a tag example that is clearly a sample.
7. Data locations and licensing.
8. Where behavior lives. `docs/architecture/` here for the host. `GrayMoon/docs/architecture/` for the product. GitHub Releases for the change history. The growing bullet list leaves the README.

This README contains no screenshot images. Build-status badge SVGs can stay.

## `GrayMoon.Release/README.md`

Verdict: **REWRITE** before 0.2.0.

The whole file is:

> The official home for GrayMoon Desktop downloads, updates, and release notes.

That sentence must leave. It is a label. A publisher cannot tell what to upload, and a user cannot tell what to download. The file is empty of marketing adjectives. Architecture `03` says this repository is the only public installer and update feed, and that installers must not be attached to `Jandini/GrayMoon`. The public product README deep-links the 0.1.0 `Setup.exe` and does not send people here.

### Section outline

1. What this repository is. Velopack feed and GitHub Releases. The source lives in the other repos.
2. Channels. `stable` (signed `Setup.exe`, full release). `main` and branch (unsigned `Setup.zip`, prerelease). An installed app stays on its channel.
3. What a user downloads. In-app update uses `releases.<channel>.json` plus nupkgs.
4. Where the source and the user guide live (`Jandini/GrayMoon`, `Jandini/GrayMoon.Desktop` private, the wiki).
5. License pointer. The installer shows `Licensing-Overview.txt`.
6. Attach installers to this repo. Leave them off the GrayMoon product repo.

## `GrayMoon/docs/architecture/README.md`

Verdict: **UPDATE** before 0.2.0. This is the developer index. Keep the reading order, the two-process rule, the feature diagram, the page list, and "App must not touch local git".

"GrayMoon is a control plane for multi-repository .NET development" can stay. It is a job description.

Replace the header block. The baseline hash is 42 commits behind the files it introduces. Name CodeGraph, central package versions, the local-only workspace name, and Worker auto-update on the state line, because the numbered docs already cover them.

Replace "it is the only documentation kept in the repository." Give `README.md`, `CLAUDE.md`, `AGENTS.md`, and `docs/todo/` explicit roles: current behavior in this folder, proposals in `docs/todo/`, build commands in `CLAUDE.md`, the developer entry in `README.md`.

"GrayMoon in one paragraph" says the product "discovers their projects and package relationships" as if every workspace does. Lead with the profile gate so a Basic workspace is described on its own terms. Profiles are already listed later under core workflows.

Do not copy "Why teams pick GrayMoon" into this file or into `01-product-model-and-user-workflows.md`.

## `GrayMoon.Desktop/docs/architecture/README.md`

Verdict: **UPDATE** before 0.2.0. Developer index for the shell.

Replace the header "WebView2 bridge (12 commands incl. Open in Codex CLI), Install All (incl. Cursor Agent)". There are 13 commands. `RestartWorker` is the missing one. Install All in the header should match the capability list already in this file: Claude, Codex, and Cursor Agent.

Move or drop "Verified against" Desktop `5142205` and GrayMoon `e4385f4a` (2026-10-17).

Open in capabilities and the Feature paragraph match `OpenInToolCatalog` (Cursor, VS Code, Visual Studio, Claude CLI, Codex CLI, Terminal, Explorer). Keep them.

The policy line is accurate for this repo (architecture folder, `README.md`, and `CLAUDE.md`). It also says the README holds the "user-facing change list". When the changelog moves, change that sentence. Point history at GitHub Releases, and current behavior at this folder.

## `GrayMoon/.cursor/README.md`

Verdict: **UPDATE**. Can wait.

Role: index of Cursor rules for the product repo. Keep the Windows and shell notes. Add the missing table row for `.cursor/rules/gray-unchecked-checkbox-radio.mdc`. That file is on disk and is named in `AGENTS.md` and `CLAUDE.md`. The other ten rule files in the table exist. This is a rules index, separate from a product README.

## `GrayMoon/src/GrayMoon.App/Data/Migrations/README.md`

Verdict: **OK**. Leave it.

Role: developer note for the hand-written migration steps. It matches `CLAUDE.md` "Database schema" and architecture `03`: `EnsureCreated`, then `Migrations.RunAllAsync`, `user_version`, legacy step 1, strict steps, `VACUUM INTO` backup, idempotent steps, append the next version, do not edit a shipped step. No version number to go stale.
