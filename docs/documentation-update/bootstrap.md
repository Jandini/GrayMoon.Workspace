# Bootstrap: running the 0.2.0 documentation pass

Start here. The other files in this folder are the audit (what is wrong) and the plan (how to fix it). This file is the execution order: what to open, in what sequence, and when each phase is done. It adds no new findings.

Reviewed against the repo on 2026-11-05: GrayMoon HEAD `8257e162` (`0.1.0-117-g8257e162`), GrayMoon.Desktop HEAD `7faf92c` (`0.1.0-103-g7faf92c`). Before starting, confirm both are still HEAD (`git log -1 --format="%H"` in each repo). If either has moved, re-check the specific facts this plan cites in that repo's architecture docs before trusting the verdicts below — do not re-run the whole audit for a handful of new commits.

## Order of work

Do the phases in this order. Each later phase assumes the one before it is either done or deliberately deferred to "Can wait".

Screenshot capture was stopped before the rewrite. Home and Worker install, upgrade, and update shots, including `agent-install.gif`, are not used. Other existing screenshots stay. New behavior is described in prose. Do not recapture those install shots, and do not point `GrayMoon/README.md` at `agent-install.gif`.

### 1. Screenshots: one capture session, files only

Source: [screenshots.md](screenshots.md) for the keep / recapture / drop groups and the shot-list template, [screenshot-trial.md](screenshot-trial.md) for the runnable capture procedure and safety rules, `_raw/04-screenshots.md` for the full per-page inventory.

Do this before the README and wiki rewrites. The shots are of the running app, so they do not wait for final page wording. The later rewrite embeds these files and is written to match them. This session does not edit a wiki page or a README, and it does not delete a retired image. Deletes happen when the rewrite stops referencing the old file.

Read screenshot-trial.md's hard safety rules before touching either live workspace. Workspace 1 is this dev checkout. Before the first navigation or capture, ask the user to open the browser viewport full screen and wait until they confirm. A narrow viewport makes a narrow page screenshot. File only a `Page.captureScreenshot` taken after `Emulation.setDeviceMetricsOverride` (`deviceScaleFactor` 1). That call hits 2142×1175 and 2064×1179 exactly. The browser pane screenshot does not, and every shot still needs a human accept before filing because the accept is about the UI state.

Capture this set, and nothing beyond it:

1. The "first, because several pages share them" list in screenshots.md.
2. One shot for each "New 0.2.0 controls that have no shot" item in screenshots.md. Name the file in the session log. The wiki page that will embed it does not exist yet.
3. About 15 to 20 key frames for the surviving Tape Density walkthrough. Library Update reuses 4 to 6 of those frames. Do not recapture the rest of the roughly 98 walkthrough files.
4. From the remaining older images, recapture only a file whose live screen has actually drifted. Compare during this session. Leave a match on disk as-is.

The Keep list is recaptured only when that compare shows the 0.2.0 screen has changed. `workspace1-new-feature-modal.png` is on the Keep list and still needs a new shot, because it has no Repair, Remove, or CodeGraph.

Done when: every file above is an accepted PNG in `GrayMoon.wiki/screenshots/`, a session log names each file and the screen it shows, both workspaces match their before record, and no wiki page or README was edited.

### 2. README rewrites and architecture-index fixes (before 0.2.0)

Source: [readme-rewrite.md](readme-rewrite.md) for voice and section outlines, [what-needs-update.md](what-needs-update.md) for the fact list, `_raw/01-readmes.md` for full reasoning.

1. `GrayMoon/README.md` - REWRITE, using the 11-section outline in readme-rewrite.md. Drop the marketing passages it lists. Drop the `worker-install.gif` embed. Do not replace it with `agent-install.gif`.
2. `GrayMoon.Release/README.md` - REWRITE, using the 6-section outline.
3. `GrayMoon.Desktop/README.md` - UPDATE in place. Fix the clone-path sample, the `git tag 0.1.0` sample, add Restart Worker to the bridge sentence. Decide where `## Recent GrayMoon changes` goes (see "Decision needed" below) before touching this file further.
4. `GrayMoon.Desktop/docs/architecture/01-product-and-host-behavior.md` - UPDATE: 13 `WebMessageCommands`, not 12; add `RestartWorker` to the origin-check sentence.
5. `GrayMoon.Desktop/docs/architecture/README.md` - UPDATE: header command count and Install All parenthetical; move or drop the "verified against" hashes.
6. `GrayMoon/docs/architecture/README.md` - UPDATE: baseline hash, "State documented" line, the "only documentation in the repository" sentence.

Done when: the 6 files above match their verdicts, and `GrayMoon/CLAUDE.md`, `GrayMoon.Desktop/CLAUDE.md`, and `GrayMoon.Desktop/docs/architecture/03-build-bundle-updates-and-distribution.md` have had the one-line fixes readme-rewrite.md calls out in the same pass (Install All list, `0.1.0` tag example).

### 3. Wiki: fix the 5 stale pages, then the 21 partial pages, then add the 6 missing topics

Source: [wiki-0.2.0.md](wiki-0.2.0.md) for headings and evidence, `_raw/02-wiki-vs-code.md` for the full feature-by-feature delta.

1. Stale pages first, because they state a false fact: `Workspace-Repositories.md`, `Workspace-Prepare-Workspace.md`, `Workspace-Packages.md`, `Feature-Walkthrough-Library-Update.md`, `Feature-Walkthrough-Tape-Density.md`. Apply the renamed-label fix (**Create PRs...** → **Create PR**) everywhere it appears in the same pass — it touches 8 pages total, listed in wiki-0.2.0.md "Renamed labels".
2. Partial pages: add the one behavior each page is missing, per the table in wiki-0.2.0.md. Order doesn't matter within this group.
3. New pages/sections: AI commit and PR text, CodeGraph on New Feature, Basic vs .NET Dependency, Workspace repository and `graymoon.json`, Desktop shell, Merge PRs..., GitHub SSO. Headings only are specified; write the body from the evidence paths cited for each.

Embed the files from step 1. Write the page so it matches the shot. Drop the second file in each byte-identical pair, and the `worker-install.gif` reference, only after no page still points at them. Trim `Feature-Walkthrough-Library-Update.md` to a short note that reuses 4 to 6 Tape Density frames.

Done when: 0 pages state the 3-minute wait, the **Create PRs...** label, or "GrayMoon does not merge for you," the 7 missing topics above each have a page or section, and the wiki references about 60-80 screenshot files total, none of them byte-identical duplicates.

### 4. docs/todo notes: update the 2 partial ones

Source: [plans-to-delete.md](plans-to-delete.md), `_raw/03-plans-to-delete.md`.

- `GrayMoon/docs/todo/pr-description-commit-history.md` - rewrite sections 1-2 to match `docs/architecture/05-user-capability-reference.md`; leave step 4 as open work.
- `GrayMoon/docs/todo/push-package-wait-and-circuit-crash.md` - leave the wiki-timeout bullet in "still open" until step 3 above fixes the wiki; then remove it.

The 5 NOT IMPLEMENTED notes and the TO DELETE list (empty) need no action in this pass.

### 5. Can wait

Everything under "Can wait" in [what-needs-update.md](what-needs-update.md) and `_raw/01-readmes.md`'s priority list. Pick these up after 1-4 ship, or opportunistically alongside a related change. The new root `C:\Workspace\GrayMoon\README.md` belongs here.

## Decision needed before step 2.3

`GrayMoon.Desktop/README.md`'s `## Recent GrayMoon changes` (235 bullets) has to stop growing before the README rewrite is durable, or the next task will re-append to it per the `update-desktop-readme.mdc` rule. readme-rewrite.md's recommendation: move the history to GitHub Release notes for `GrayMoon.Desktop`, keep at most a short "since 0.1.0" behavior note in the README, and update two policy sentences that currently call this section the spec:

- `GrayMoon.Desktop/docs/architecture/README.md` ("the README holds the user-facing change list")
- The task-completion rule in `GrayMoon/CLAUDE.md` / the workspace rule `update-desktop-readme.mdc` that prepends a bullet here

This is a product decision (where does the changelog live), not a doc-wording fix — confirm it with whoever owns the release process before editing those two policy sentences.

## Out of scope for this pass

- `GrayMoon/docs/architecture/01, 02, 03, 06, 07` and `GrayMoon.Desktop/docs/architecture/02, 04` body content (only their index hashes/header counts are in scope).
- Wiki pages marked OK (13 of them) and `docs/todo` notes marked NOT IMPLEMENTED (5 of them) - no edit needed.
- Committing or pushing any of this. Per workspace rules, nothing in `GrayMoon`, `GrayMoon.Desktop`, or `GrayMoon.wiki` gets committed or pushed without an explicit request for that exact action.
