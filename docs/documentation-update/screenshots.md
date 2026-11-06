# Screenshots

Policy for the 0.2.0 wiki and README images. The full group inventory, dimensions, and capture dates are in `_raw/04-screenshots.md`. This file is the cut and the recapture brief.

The wiki audit counted 194 image embeds across 34 pages. This plan uses the screenshot audit: 345 `![]()` embeds, 315 distinct paths, 32 wiki pages.

## Counts

All 348 real screenshots live in `GrayMoon.wiki/screenshots/` (346 `.png`, 2 `.gif`, 57.6 MB).

- 315 distinct paths are referenced from wiki markdown, across 32 wiki pages, in 345 embeds. Some files are reused on 2 to 4 pages.
- 32 files in `screenshots/` are referenced by no wiki page.
- 1 broken reference: `GrayMoon/README.md` embeds `screenshots/worker-install.gif`. That file is not in the wiki folder. The file that exists is `agent-install.gif`. The public README image is dead today. Wiki pages already use `agent-install.gif`.
- 0 case-sensitivity mismatches between markdown and on-disk names.
- Architecture docs embed zero screenshots. Image syntax in `docs/architecture/` matched badge SVGs only.
- `GrayMoon/README.md` references 9 images through `https://raw.githubusercontent.com/wiki/Jandini/GrayMoon/screenshots/`. `GrayMoon.Desktop/README.md` and `GrayMoon.Release/README.md` have no screenshot images.
- Product icons (`GrayMoon/res/moon*.png`, `GrayMoon.Desktop/res/moon*.png`, `wwwroot/moon.svg`, `wwwroot/icons/*.svg`) are out of scope.

`graymoon-highlights.gif` and `workspace-changes-md-preview.png` have no wiki embed. Both are used by `GrayMoon/README.md` through the raw-content mirror. Treat them as live until the README rewrite drops them.

Byte-identical pairs (MD5):

- `connectors.png` and `connectors-active-ok.png`
- `workspace2-files-dep-badge-tooltip.png` and `workspace2-files-mezzorecovery-level4.png`
- `workspace2-files-update-checking.png` and `workspace2-files-update-overlay.png`
- `workspace1-update-branch-behind-badge.png` and `workspace9-update-branch-behind-badge.png`
- `workspace1-update-branch-dialog.png` and `workspace9-update-branch-dialog.png`

Most reused files, so one recapture fixes several pages: `workspace2-repositories.png` (4 pages), `home-upgrade-agent.png` (3), and about two pages each for `workspace2-dependencies.png`, `workspace2-deps-search-api.png`, `workspace2-sync-dropdown.png`, `workspace2-sync-push-modal.png`, `workspace2-sync-to-default-dialog.png`, `settings.png`, `workspaces.png`, `agent-install.png`, `agent-install.gif`, `home-install-agent.png`, `agent-update.png`, `agent-update-host.png`.

Pixels were not opened for most files. "What it shows" in the raw inventory comes from the filename, the alt text, and the surrounding prose. The 2026-10-16 batch is the freshest. The bulk of the set was captured 2026-08-20. Confirm an old shot against the live app before calling it wrong.

## Decision

Cut to about 60-80 screenshots, down from 348 files on disk and 315 referenced paths. Collapse the two long walkthroughs and the per-state repeats. Keep the topics.

Recapture the survivor set from the running app (Blazor Server in a browser, or the WPF Desktop window). An image model is the wrong tool for these shots. The docs depend on exact grid layout, exact button and badge colors (the pages say "red ↑0 ↓1", "purple merged", "green PR badges"), exact modal copy, and seeded data (`MezzoRecovery`, `TapeTools`, `TapeDrive`, PR numbers, tag `0.2.0` as a TapeDrive tag).

The shot list below is the brief for a person or a later agent driving the real window. It is a text checklist. It is the capture method. The runnable procedure for actually driving the window, sizing the viewport, and getting each shot approved before filing it is [screenshot-trial.md](screenshot-trial.md).

Capture runs as its own session, before the README and wiki rewrites ([bootstrap.md](bootstrap.md) step 1). That session files accepted PNGs and does not edit page text. The rewrite later embeds those files and drops the retired ones. New 0.2.0 controls are shot in that session even though their wiki pages are not written yet.

### Policy

- Keep one long walkthrough: `Feature-Walkthrough-Tape-Density.md`. Fold `Feature-Walkthrough-Library-Update.md` down to a short note that the flow is the same on another repo set, and reuse 4 to 6 frames (start, branch, one failure and recovery, final all-green grid).
- On procedural pages (`Workspace-Repositories.md`, `Workspace-Return-to-Default.md`, `Workspace-Switch-Branch.md`, `Workspace-Tag-Upgrade.md`, `Workspace-Undo-Push-Commits.md`, `Workspace-Repository-Branch-Management.md`, and the same family), keep one before and one after per distinct outcome. The body text carries the intermediate click.
- Keep one file from each byte-identical pair. Point every page at the surviving name.
- Point `GrayMoon/README.md` at `agent-install.gif`, or remove that image row, in either the README rewrite or this cut.
- One folder stays the source: `GrayMoon.wiki/screenshots/`. The README highlight set, about 9 images, keeps using the wiki raw mirror.
- Keep the `<area>-<state>.png` names (`workspace2-sync-dropdown.png`, `workspace-changes-md-diff.png`). The surviving walkthrough keeps `workspace2-tape-density-<step>-<state>.png`.
- PNG for a static state. GIF only for a multi-step recording that one frame cannot show (`agent-install.gif`, `graymoon-highlights.gif`).
- Browser captures in the current set are about 2142x1175 (some 2064x1179). Desktop shell captures are 1016x678. Use those sizes in the shot list unless the page needs another viewport.
- When a Worker shot is recaptured, name it for Worker. The page title is Worker. Route `/agent` remains an alias. See [wiki-0.2.0.md](wiki-0.2.0.md).

## Shot list template

One block per surviving or new screenshot. Hand it to whoever is driving the real browser or Desktop window.

```
### <filename>.png
- Page / route: <e.g. /workspace/2/repositories>
- App surface: <Blazor web UI | WPF Desktop shell>
- Window / viewport size: <e.g. 2142x1175 browser viewport | 1016x678 Desktop window>
- Prerequisite data / seed state: <workspace name, repo set, branch name, tags, PR numbers, and the scene, e.g. "MezzoRecovery workspace, TapeDrive repo on tag 0.1.0, TapeTools upgrade badge visible">
- Steps to reach this exact state: <numbered, click-by-click>
- What must be visible / highlighted: <e.g. "red ↑0 ↓1 badge", "purple merged PR badge", "Found 2 of 4 packages text">
- Replaces / supersedes: <old filename(s) this retires, if any>
```

New 0.2.0 controls that have no shot in the current wiki set, and need a block when that page is written: the Changes AI control and **On Commit** menu, **Create CodeGraph index**, Feature **Repair** and Remove Feature, Packages **Used by** and **Needs**, **Merge PRs...**, **Authorize SSO**, Desktop **Check for updates...** and **About**, Host-tab **Restart** and **Install All** with Claude and Codex. The Changes set has no AI control. `workspace1-new-feature-modal.png` has no Repair, Remove, or CodeGraph. `workspace2-packages.png` predates **Used by** and **Needs**.

## Keep

No recapture unless a 0.2.0 change touches the screen. Freshest batch, captured 2026-10-16:

- `home.png`
- `settings.png`
- `settings-terminal.png`
- `connectors.png` (also covers `connectors-active-ok.png`)
- `agent.png`
- `workspace2-repositories.png`
- `workspace1-new-feature-modal.png`
- `workspaces.png`
- `workspaces-restore-modal.png`

`workspace-changes-md-preview.png` (2026-09-27) is newer than its Changes siblings (2026-08-20). The curly-brace Preview fix may have changed what `{PLACEHOLDER}` looks like. It is on the recapture-first list. The raw pass did not open the pixels, so this is a flag, and the file is still a real capture.

## Recapture

**First, because several pages share them:**

- `workspace2-dependencies.png`
- `workspace2-sync-dropdown.png`
- `workspace2-sync-push-modal.png`
- `workspace2-sync-to-default-dialog.png`
- `workspace-changes-md-diff.png`
- `workspace-changes-md-preview.png`
- `home-upgrade-agent.png`
- `home-install-agent.png`
- `agent-install.png` and `agent-install.gif`
- `agent-update.png`
- `agent-update-host.png`

**Walkthroughs, as a trim.** `workspace2-tape-density-*` is 61 embeds and 60 files (the largest group). `workspace2-library-update-*` is 31 embeds and 38 files. Pick about 15 to 20 key frames for the surviving Tape Density walkthrough. Library Update reuses 4 to 6 of those frames. Do not recapture all of the roughly 98 files.

**Judge against the live app during the same pass.** No blanket drop. The raw pass did not open the pixels. About 150 to 180 images, captured around 2026-08-20 or 2026-08-25:

- `Workspace-Protected-Branch-and-Push-Failure.md` (27 images)
- `Workspace-Custom-Dependencies.md`
- `Workspace-Files.md` (19 images, after the duplicate drops below)
- `Getting-Started.md` setup sequence (`setup-add-workspace-*`, `setup-demo-*`, `setup-select-repos-*`, `setup-repositories-*`, connector setup)
- `Workspace-Actions.md` (about 20, shared with the walkthroughs)
- Branch, tag, and restore procedural pages in the `workspace2-*` / `workspace-*` grid set (about 70 images across those pages, many already shared)

`Layout.md` Desktop shots (`desktop-home.png`, `desktop-home-topbar-hidden.png`, `desktop-repositories.png`) are 1016x678 and were captured 2026-08-25. Recapture them with the new Desktop page if Check for updates, About, or the system menu must be visible. Sidebar-collapsed web shots can wait for the visual diff.

## Drop

- The second name in each byte-identical pair: `connectors-active-ok.png`, `workspace2-files-mezzorecovery-level4.png`, `workspace2-files-update-checking.png`, and one file from each `workspace1` / `workspace9` update-branch pair.
- The 32 unreferenced files, after a check that `GrayMoon/README.md` still needs `graymoon-highlights.gif` and `workspace-changes-md-preview.png`. The rest are mostly intermediate frames from the two walkthroughs (`workspace2-library-update-*`, `workspace2-tape-density-*`) and the Files page, plus `workspace1-actions-failed-filter.png`, `workspace2-sync-main-overlay.png`, and `workspace9-incoming-commits-red-pull.png`. The raw file lists the walkthrough orphans by suffix (`-before`, `-after-push`, `-after-push-updated`, `-mezzo-build-logs`, `-tape-build-logs`, `-level3-merged-before-sync`, `-level3-only-after-check`, `-overlay-progress`, `-level2-current-state`, `-level2-only-overlay`, `-pr-dialog-all-repos-before-fill`, `-changes-A-diffs-after-wait`).
- The `worker-install.gif` reference in `GrayMoon/README.md`.

Group totals, embed counts, and the per-page table are in `_raw/04-screenshots.md`. Do not copy that inventory into the wiki.
