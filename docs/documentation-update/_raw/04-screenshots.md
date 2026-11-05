# Screenshot inventory for the 0.2.0 docs update

Scope searched: `GrayMoon.wiki/` (all markdown pages), `GrayMoon/README.md`, `GrayMoon.Desktop/README.md`,
`GrayMoon.Release/README.md`, `GrayMoon/.cursor/README.md`, `GrayMoon/src/GrayMoon.App/Data/Migrations/README.md`,
and every `docs/architecture/**/*.md` file in `GrayMoon/` and `GrayMoon.Desktop/`.

Method: enumerated every image file by extension (`png`, `jpg`, `jpeg`, `gif`, `webp`, `svg`) on disk, then grepped every
markdown file for `![alt](path)` image syntax to build a reference map. Pixel dimensions were read cheaply from file
headers (`System.Drawing.Image` size, no decode of pixel content) for a representative sample per group. Byte-identical
duplicates were confirmed with MD5 hashes, not by eye. `GrayMoon.wiki` is excluded from this workspace's `.cursorignore`,
so the `Read` tool could not open the PNG/GIF bytes directly (`Permission denied`) — every "what it shows" note below is
inferred from filename, markdown alt text, and surrounding prose, not from visually inspecting pixels. Treat anything not
explicitly hedged as "unknown" as a best-effort inference, not a confirmed visual check.

## Totals

- **348 image files** in `GrayMoon.wiki/screenshots/` (346 `.png`, 2 `.gif`), **57.6 MB** total.
- **315 distinct image paths** referenced from wiki markdown across **32 wiki pages**, **345 total `![]()` embeds** (some images reused across pages).
- **32 files in `screenshots/` are orphaned** — on disk but not referenced by any wiki page (some of these *are* used by `GrayMoon/README.md` via the raw.githubusercontent wiki mirror, see below).
- **1 broken reference**: `GrayMoon/README.md` embeds `screenshots/worker-install.gif`, which does not exist anywhere in the wiki (the real file is `agent-install.gif`). This is a dead image today in the public README.
- **0 case-sensitivity mismatches** between markdown references and on-disk filenames (checked because GitHub's wiki/raw hosting is case-sensitive; every reference that resolves locally will also resolve there).
- **Architecture docs embed zero screenshots** — all image references in `docs/architecture/**/*.md` were badge SVGs only (none found); the grep for image syntax returned no matches in either repo's architecture folder.
- Non-screenshot images (product icons/logos: `GrayMoon/res/moon*.png`, `GrayMoon.Desktop/res/moon*.png`, `wwwroot/moon.svg`, `wwwroot/icons/*.svg`) are **not UI screenshots** and are out of scope for a "refresh screenshots" pass; excluded from the counts above.

## Where the screenshots live and how they're consumed

- All 348 real screenshots live in **one folder**: `GrayMoon.wiki/screenshots/`.
- The wiki pages reference them with **relative paths** (`screenshots/foo.png`), so they render correctly inside the wiki.
- `GrayMoon/README.md` references a **small subset (9 images)** via the wiki's raw GitHub mirror
  (`https://raw.githubusercontent.com/wiki/Jandini/GrayMoon/screenshots/...`), not local paths. That means the README's
  screenshots are a curated highlight reel, separate from (but overlapping with) the wiki's full set.
- `GrayMoon.Desktop/README.md` and `GrayMoon.Release/README.md` contain **no screenshot images**, only build-status badge SVGs.

## Inventory by page / feature group

Grouped by the wiki page(s) that embed the images, since most images are one-to-one with a single doc page and a single UI
moment. Dimensions are representative samples per group (taken from `System.Drawing.Image` size, not a full decode), file
sizes are the group's min–avg–max. "Captured" is the most common `LastWriteTime` for files in that group, used only as a
freshness signal, not proof of UI change.

| Group (wiki page(s)) | Images | Dimensions | Size (KB) | Captured | What it shows |
|---|---|---|---|---|---|
| `App-Home.md`, `Home.md` | `home.png`, `home-install-agent.png`, `home-upgrade-agent.png` (3, 1 orphaned on disk is a dup name — `home.png` reused by both pages) | 2142×1175 | 112–139 | home.png: **16/10**; home-install/upgrade-agent: 20/08 | Blazor Home page: default state, state while the Worker needs installing, state while the Worker needs upgrading. |
| `App-Workspaces.md`, `Restore-Workspace.md` | `workspaces.png`, `workspaces-restore-modal.png` | ~2142×1175 | 72–119 | **16/10** | Workspaces list page and the Restore Workspace modal. |
| `App-Worker.md`, `Getting-Started.md` (`agent-*`) | 7 PNG + `agent-install.gif` | 2142×1175 (gif 1348×765) | 46–118 | 20/08 | Worker Host page states: install, update, uninstall, version-mismatch banner, push notification; the `.gif` is a short PowerShell install screen recording. |
| `App-Connectors.md`, `Getting-Started.md` (`connectors*`, `setup-*connector*`) | `connectors.png`/`connectors-active-ok.png` (byte-identical, see Duplicates), `connectors-error-inactive.png`, `connectors-status-testing.png`, plus 6 `setup-*connector*` images | 2142×1175 | 67–93 | 20/08; `connectors.png`/`connectors-active-ok.png` **16/10** | Connectors page: empty/OK/error/testing states, and the Getting Started connector setup flow (Add Connector modal, GitHub/NuGet filled, OK). |
| `App-Settings.md`, `Workspace-Features.md` | `settings.png`, `settings-terminal.png` | 2142×1175 | 138–141 | **16/10** | Settings page, general tab and terminal tab. |
| `App-Repository-Catalog.md`, `Getting-Started.md` (`setup-repositories-*`, `setup-select-repos-*`) | `repositories.png` + ~10 `setup-select-repos-*` / `setup-repositories-*` | 2064–2142×1175–1179 | 68–157 | 20/08 | Repository catalog: empty, fetched, the Select Repositories modal with search/topic filters, and multi-select states. |
| `Getting-Started.md` (`setup-add-workspace-*`, `setup-demo-*`) | 6 images | ~2064×1179 | 77–356 | 20/08 | Add Workspace modal, the "demo" workspace not-cloned / syncing / synced states, including a large (356 KB) clone-overlay capture. |
| `Layout.md` | `layout-sidebar-collapsed*.png`, `desktop-home*.png`, `desktop-repositories.png` | Browser shots 2064×1179; **Desktop shots 1016×678 (smaller — WPF window, not full browser)** | 139–268 | Desktop shots **25/08**; sidebar shots 20/08 | Collapsed sidebar with/without top bar (web), and the WPF Desktop shell's Home/Repositories pages with/without top bar. |
| `Workspace-Changes.md`, `Shared-Chrome.md`, README | 15 images incl. `workspace-changes-md-diff.png`, `workspace-changes-md-preview.png`, `workspace2-changes-*` (empty/1-repo/2-repos/5-repos/staged/unstaged/after-commit/after-push) | 2064–2142×1175–1179 | 44–286 | 20/08; `workspace-changes-md-preview.png` **27/09** | Git Changes page across repo counts, staging flows, markdown diff and markdown preview. Note: `workspace-changes-md-preview.png` is notably fresher than the rest of this page's images — the Desktop README calls out a markdown-preview rendering fix (curly-brace text), which is a plausible reason this one was recaptured while its siblings weren't. |
| `Workspace-Incoming-Commits.md` (`workspace9-incoming-commits-*`) | 4 PNG + 2 orphaned siblings (`workspace9-incoming-commits-red-pull.png`, `workspace9-update-branch-*`) | ~2064×1179 | 66–75 | 20/08 (some 18–19/08) | Incoming Commits before/after/synchronizing/error states, workspace #9. |
| `Workspace-Files.md`, `Workspace-Custom-Dependencies.md` (`workspace2-files-*`) | 19 images (3 orphaned: `workspace2-files-update-checking.png` ≡ `workspace2-files-update-overlay.png` byte-identical, `workspace2-files-view-env-selected.png`, `workspace2-files-mezzorecovery-level4.png` ≡ `workspace2-files-dep-badge-tooltip.png` byte-identical) | 2064×1179 | 44–208 | **25/08** | Files page: empty, Add Files dialog, search results, grid with configured file deps, custom-dependency badges. |
| `Feature-Walkthrough-Library-Update.md` | 31 refs / 38 files on disk (7 orphaned, e.g. `workspace2-library-update-before.png`, `-after-push.png`, `-after-push-updated.png`, `-mezzo-build-logs.png`, `-tape-build-logs.png`, `-level3-merged-before-sync.png`, `-level3-only-after-check.png`) | 1850–2142×1175–1179 | avg 193 (15–406) | 20/08 | Long step-by-step walkthrough of updating a shared library across an 11-repo dependency tree: branch → push → CI failure → fix → recovery → bulk PR creation → three levels of "Return to Default". This is the single longest, most repetitive sequence in the wiki. |
| `Feature-Walkthrough-Tape-Density.md` | 61 refs / 60 files on disk (some orphaned: `-overlay-progress.png`, `-level2-current-state.png`, `-level2-only-overlay.png`, `-pr-dialog-all-repos-before-fill.png`, `-changes-A-diffs-after-wait.png`) | 1988–2142×1175–1179 | avg 191 (53–395) | 20/08 | The **largest single group in the wiki** — a second, even longer step-by-step feature walkthrough (branch, implement, commit, push, CI, PR, 3-level sync-to-default), largely structurally identical to the Library-Update walkthrough but with different repo names/data. |
| `Workspace-Protected-Branch-and-Push-Failure.md` (`workspace2-protected-*`) | 27 images | 2064×1179 | 54–488 | **25/08** | Walkthrough of a protected-branch push rejection (GH013), undo, new branch, PR, merge, fetch, sync-to-main recovery. |
| `Workspace-Repositories.md`, `Workspace-Return-to-Default.md`, `Workspace-Switch-Branch.md`, `Workspace-New-Branch.md`, `Workspace-Tag-Upgrade.md`, `Workspace-Repository-Branch-Management.md`, `Workspace-Undo-Push-Commits.md`, `Workspace-Restore-Packages.md`, `Workspace-Checkout-from-Tags.md` (`workspace2-*` and `workspace-*` core grid/branch/sync screens) | ~70 images | 2064–2142×1175–1179 | 56–492 | 20/08 | Core Repositories-page mechanics reused across many procedural pages: branch menu, sync/fetch/restore dropdowns and overlays, tag upgrade badges, per-repo Branch dialog tabs (Locals/Remotes/Tags/New Branch), undo-push modal. Many of these (e.g. `workspace2-repositories.png`, `workspace2-sync-dropdown.png`, `workspace2-sync-push-modal.png`) are reused 2–4× across different pages — see Duplicates below. |
| `Workspace-Custom-Dependencies.md` (`workspace2-custom-deps-*`) | 6 images + 1 shared with Files page | 2064×1179 | 172–209 | **25/08** | Custom dependency override dialogs for TapeTools / Solution, before/after bubbling to Level 4. |
| `Workspace-Actions.md`, both Feature Walkthroughs (`workspace1-actions-*`, `workspace2-actions-*`, `workspace2-tape-density-actions-*`) | ~20 images (1 orphaned: `workspace1-actions-failed-filter.png`) | 2064×1179 | 56–206 | 20/08 | GitHub Actions status grid and filters: none/failed/search, running/success/failed deploy, expanded/collapsed logs. |
| `Workspace-Update-Branch-from-Default.md` (`workspace1-`/`workspace9-update-branch-*`) | 6 files, 2 pairs byte-identical across workspace1/workspace9 | 2064×1179 | 75–131 | 20/08 (workspace1 18/08, workspace9 20/08) | "Update Branch from Default" behind-badge and dialog, captured twice for two different workspace contexts — the workspace1 and workspace9 images are literally the same bytes (see Duplicates). |
| `GrayMoon/README.md` only | `graymoon-highlights.gif` | 1400×790 | 698 | 26/08 | Animated highlight reel for the public README's top banner — largest single file in the set. |

## Specific issues found

**Broken reference**
- `GrayMoon/README.md:86` embeds `screenshots/worker-install.gif`. No file with that name exists in `GrayMoon.wiki/screenshots/` (only `agent-install.gif` does, which is what every wiki page uses for the same PowerShell install recording). This image has likely been broken since the Worker was renamed from "Agent" to "Worker" in the UI and the GIF was renamed but the README link wasn't updated.

**Byte-identical duplicates** (confirmed by MD5, not just filename similarity)
- `connectors.png` ≡ `connectors-active-ok.png`
- `workspace2-files-dep-badge-tooltip.png` ≡ `workspace2-files-mezzorecovery-level4.png`
- `workspace2-files-update-checking.png` ≡ `workspace2-files-update-overlay.png`
- `workspace1-update-branch-behind-badge.png` ≡ `workspace9-update-branch-behind-badge.png`
- `workspace1-update-branch-dialog.png` ≡ `workspace9-update-branch-dialog.png`

These are either copy-paste captures (same screen, saved twice under two names) or deliberate reuse across two procedural
pages. Either way, each pair only needs one real screenshot; the second filename can be a copy or a redirect note.

**Orphaned files** (on disk, referenced by no wiki page; 32 total) — mostly superseded intermediate states from the two
long walkthroughs (`workspace2-library-update-*`, `workspace2-tape-density-*`) and the Files page, plus a few one-offs
(`workspace1-actions-failed-filter.png`, `workspace2-sync-main-overlay.png`, `workspace9-incoming-commits-red-pull.png`).
`graymoon-highlights.gif` and `workspace-changes-md-preview.png` are "orphaned" only in the sense that no *wiki* page
embeds them directly — both are used by `GrayMoon/README.md` via the raw-content mirror, so they are not actually dead.

**Reused across multiple pages** (not duplicates, same file referenced from 2–4 different docs) — most reused:
`workspace2-repositories.png` (4×), `home-upgrade-agent.png` (3×), plus ~2× each for `workspace2-dependencies.png`,
`workspace2-deps-search-api.png`, `workspace2-sync-dropdown.png`, `workspace2-sync-push-modal.png`,
`workspace2-sync-to-default-dialog.png`, `settings.png`, `workspaces.png`, `agent-install.png`/`.gif`,
`home-install-agent.png`, `agent-update.png`, `agent-update-host.png`, and others. A capture pass only needs to retake
each underlying screen once and the reuse is free.

## Likely stale vs. likely accurate

Only called out where the surrounding text, a recent capture date, or a matching Desktop README changelog entry makes it
reasonably clear — everything else is **unknown** without opening the pixels, which this pass did not do for most files.

- **Likely still accurate (freshest batch, 16/10/2026, ~3 weeks old):** `home.png`, `settings.png`, `settings-terminal.png`,
  `connectors.png`/`connectors-active-ok.png`, `agent.png`, `workspace2-repositories.png`, `workspace1-new-feature-modal.png`,
  `workspaces.png`, `workspaces-restore-modal.png`. These were already recaptured recently enough that they most likely
  reflect current chrome, unless a very recent, still-uncaptured change landed after 16/10.
- **Possibly stale by a specific, named UI change:** `workspace-changes-md-preview.png` (captured 27/09) predates nothing
  obviously, but its *siblings* on `Workspace-Changes.md` (captured 20/08) predate the Desktop README's "Markdown preview
  keeps curly-brace text" fix — if that fix changed what a preview with `{PLACEHOLDER}`-style text renders like, the older
  Changes-page screenshots on that page could be showing the pre-fix rendering. Flagged as **possibly stale**, not
  confirmed, since this pass didn't open the pixels.
- **Unknown but old (bulk of the set, captured 20/08/2026, ~11 weeks old):** everything under `workspace2-tape-density-*`,
  `workspace2-library-update-*`, the Getting Started / setup-* flow, Actions, Branch/Sync/Restore mechanics, Worker
  install/update/uninstall, Incoming Commits. No specific evidence either way that the underlying UI changed; age alone is
  not proof of staleness, but it is the largest share of the set and the longest to re-verify by hand.
- **Unknown but slightly fresher (captured 25/08/2026):** Desktop shell shots, Protected-Branch walkthrough, Custom
  Dependencies, Files page. No specific evidence of drift.
- **Confirmed broken, not "stale":** `worker-install.gif` (dead link in `GrayMoon/README.md`).

## Decision: reduce the screenshot count (A), not AI-generated recreation prompts (B)

**Recommendation: do (A) — cut the screenshot count sharply, then recapture the smaller survivor set by hand (or with a
scripted browser/WPF capture pass). Do not use an image-generation model to recreate these screenshots.**

Why not (B): these are not illustrative or decorative images — they are pixel-accurate evidence of a real Blazor Server
page and a real WPF/WebView2 shell, including exact grid layouts, exact button and badge colors (the docs literally say
"red ↑0 ↓1", "purple merged", "green PR badges" — color is load-bearing content), exact modal copy, and seeded demo data
(`MezzoRecovery`, `TapeTools`, `TapeDrive`, specific PR numbers, specific tag versions like `0.2.0`). An image model has
no access to this app's actual Blazor theme, fonts, component library, or live data, so it cannot reproduce any of that
faithfully — at best it produces a plausible-looking dashboard that resembles no real GrayMoon screen, and a developer
reading the wiki will immediately notice the UI doesn't match what they're looking at. AI-generated UI screenshots also
drift in subtle, hard-to-review ways (slightly wrong labels, invented buttons, inconsistent chrome between "screenshots"
of the same app) and they erode trust in developer documentation faster than simply having fewer, older-but-real images.
A smaller set of real captures, kept current, is more trustworthy than a larger set that includes anything synthetic.

Where "AI prompts" are genuinely useful: not as image-generation prompts, but as a **shot list** — a short, structured
brief that tells a human (or an agent driving a real browser/WPF window) exactly what to open, size, seed, and click
before pressing the shutter. That is a text artifact that drives a real capture, not a generated image. This document's
shot-list template (below) is that artifact.

### 1. Recommended policy

- **Target count: roughly 60–80 screenshots**, down from 348 on disk / 315 referenced — cut by collapsing the two
  near-duplicate long walkthroughs and removing per-state repetition, not by deleting whole topics.
  - Keep **one** long end-to-end walkthrough (`Feature-Walkthrough-Tape-Density.md`, the larger/more complete of the two)
    at full step-by-step resolution; fold `Feature-Walkthrough-Library-Update.md` down to a short "same flow, different
    repo set" note that reuses 4–6 key frames (start, branch, one failure/recovery moment, final all-green grid) instead
    of its own ~30-image sequence.
  - For procedural pages (`Workspace-Repositories.md`, `Workspace-Return-to-Default.md`, `Workspace-Switch-Branch.md`,
    `Workspace-Tag-Upgrade.md`, `Workspace-Undo-Push-Commits.md`, `Workspace-Repository-Branch-Management.md`, etc.), keep
    one "before" and one "after" image per distinct outcome and drop the intermediate dialog/overlay/menu frames where the
    body text can describe the click instead of showing it.
  - Keep exactly one copy of every byte-identical duplicate pair listed above; delete the second filename everywhere it's
    referenced (point both pages at the surviving file).
  - Fix or remove the one broken reference (`worker-install.gif` → `agent-install.gif`) regardless of the broader cutback.
- **Where they live:** keep the single `GrayMoon.wiki/screenshots/` folder as the one source of truth; do not introduce a
  second location. `GrayMoon/README.md` keeps pulling its ~9-image highlight subset from the same wiki mirror.
- **Naming:** keep the existing `<area>-<state>.png` convention (e.g. `workspace2-sync-dropdown.png`,
  `workspace-changes-md-diff.png`) — it already encodes page + UI state well enough to grep. For the one surviving
  walkthrough, keep the `workspace2-tape-density-<step>-<state>.png` pattern; don't invent a new scheme during the cutback.
- **Format:** PNG for static states (current convention), GIF only for genuinely multi-step interactions that are hard to
  show as a single frame (`agent-install.gif`, `graymoon-highlights.gif`) — keep that split, don't convert everything to
  one or the other.

### 2. Shot list template

Use one of these blocks per surviving (or newly needed) screenshot when handing off a recapture pass to a person or a
later agent driving a real browser/WPF window:

```
### <filename>.png
- Page / route: <e.g. /workspace/2/repositories>
- App surface: <Blazor web UI | WPF Desktop shell>
- Window / viewport size: <e.g. 2142x1175 browser viewport | 1016x678 Desktop window>
- Prerequisite data / seed state: <workspace name, repo set, branch name, tags, PR numbers, etc. needed to reproduce the
  scene — e.g. "MezzoRecovery workspace, TapeDrive repo on tag 0.1.0, TapeTools upgrade badge visible">
- Steps to reach this exact state: <numbered, click-by-click>
- What must be visible / highlighted: <e.g. "red ↑0 ↓1 badge", "purple merged PR badge", "Found 2 of 4 packages text">
- Replaces / supersedes: <old filename(s) this retires, if any>
```

### 3. Keep / drop / recapture

- **Keep as-is (freshest, 16/10 batch — no action needed unless a specific 0.2.0 change touches them):** `home.png`,
  `settings.png`, `settings-terminal.png`, `connectors.png` (also covers `connectors-active-ok.png`, delete the dup name),
  `agent.png`, `workspace2-repositories.png`, `workspace1-new-feature-modal.png`, `workspaces.png`,
  `workspaces-restore-modal.png`.
- **Recapture first / highest value (core screens reused across the most pages — fixing these fixes the most docs at
  once):** `workspace2-dependencies.png`, `workspace2-sync-dropdown.png`, `workspace2-sync-push-modal.png`,
  `workspace2-sync-to-default-dialog.png`, `workspace-changes-md-diff.png`, `workspace-changes-md-preview.png`,
  `home-upgrade-agent.png`, `home-install-agent.png`, `agent-install.png`/`.gif`, `agent-update.png`,
  `agent-update-host.png`.
- **Recapture as part of trimming the big walkthrough, not 1:1:** everything under `workspace2-tape-density-*` (60
  images) and `workspace2-library-update-*` (38 images) — pick ~15–20 key frames across the surviving walkthrough instead
  of recapturing all ~98.
- **Drop outright (duplicates / orphans / dead link):** `workspace2-files-mezzorecovery-level4.png` (dup of
  `workspace2-files-dep-badge-tooltip.png`), `workspace2-files-update-checking.png` (dup of
  `-update-overlay.png`), one of each `workspace1`/`workspace9` update-branch pair, the 32 orphaned files listed above
  that no page links to (verify each against README usage first — two of them are not actually dead), and the
  `worker-install.gif` reference in `GrayMoon/README.md` (point it at `agent-install.gif` or drop the row).
- **Leave for a case-by-case human/agent judgment call, no blanket verdict (not opened as pixels in this pass):** the
  remaining ~150–180 images in `Workspace-Protected-Branch-and-Push-Failure.md`, `Workspace-Custom-Dependencies.md`,
  `Workspace-Files.md`, `Getting-Started.md`'s setup-* sequence, `Workspace-Actions.md`, and the branch/tag/restore
  procedural pages — these are old enough (10–11 weeks) to be worth a quick visual diff against the live app during the
  0.2.0 pass, but nothing in the surrounding text or filenames proves they're wrong.
