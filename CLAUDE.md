# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace layout

`C:\Workspace\GrayMoon` is a thin **workspace repository** (its own `.git`, with `graymoon.json`, `codegraph.json` and `GitVersion.yml`) that sits on top of independent sibling repositories developed together. The sibling folders are git-ignored by the root repo, so root `git status` never shows their changes - run git inside the relevant folder.

| Folder | What it is | Git repo? |
|---|---|---|
| `GrayMoon/` | The core product: `GrayMoon.App` (Blazor Server web UI and orchestration) + `GrayMoon.Worker` (local git/filesystem worker, `graymoon-worker`). Public repo. | Yes, own `.git` |
| `GrayMoon.Desktop/` | Windows desktop shell (WPF + WebView2) that wraps `GrayMoon.App` as a child process. Private repo. | Yes, own `.git` |
| `GrayMoon.Release/` | Public landing repo for Desktop downloads, updates and release notes (just a README). Not code. Optional. | Yes, own `.git` |
| `GrayMoon.wiki/` | Optional local checkout of the GitHub wiki (user-facing docs) for the `GrayMoon` repo. Not code. | Wiki repo |

`graymoon.json` lists the two code repositories (`GrayMoon`, `GrayMoon.Desktop`) managed as the workspace; the `<graymoon-repositories>` block in `.gitignore` is maintained from it, so don't hand-edit that block. `codegraph.json` is maintained by GrayMoon when the definition has `"codegraph": true`. `.cursorignore` excludes the wiki and other non-code folders from indexing.

There is no root-level build, solution, or dependency file - always operate from inside the relevant sub-repo.

### Feature worktrees

A GrayMoon feature (for example `~/.graymoon/GrayMoon/features/<name>/`) has the same layout, but each folder is a git worktree. The root is a worktree of the workspace repo, and `GrayMoon/` and `GrayMoon.Desktop/` each contain a `.git` file that points to `C:/Workspace/GrayMoon/<repo>/.git/worktrees/...`. Stay inside the feature folder, and run git per sub-repo there. Don't `cd` back to `C:\Workspace\GrayMoon`. The branch is set separately in each worktree.

## Which CLAUDE.md applies

- Working in `GrayMoon/` -> see `GrayMoon/CLAUDE.md` and `GrayMoon/AGENTS.md` for build/test commands, coding rules and the App/Worker architecture summary.
- Working in `GrayMoon.Desktop/` -> see `GrayMoon.Desktop/CLAUDE.md` for build/test commands and the desktop shell's process/IPC architecture.

## Documentation

Each code repository keeps a current-state architecture reference:

- `GrayMoon/docs/architecture/` (start at `README.md`)
- `GrayMoon.Desktop/docs/architecture/` (start at `README.md`)

Proposals and design notes for work not yet built go in `GrayMoon/docs/todo/`. When behavior changes, update the relevant architecture document in the same change. Repository `README.md` files stay user/developer facing and link to the architecture folder.

After any feature, bug fix or other change to product behavior, add one bullet at the top of `## Recent GrayMoon changes` in `GrayMoon.Desktop/README.md`, or edit the existing bullet for that feature. The full style is in `.cursor/rules/update-desktop-readme.mdc`: start with a bold phrase, then ` - ` (ASCII hyphen), describe what the user sees and why, and finish with what stayed the same. Skip this for questions, reviews, refactors, tests and documentation-only edits.

## Never commit or push without an explicit request

Never run `git commit` or `git push` (or stage, tag, amend, or open a pull request) in any of these repositories unless the user explicitly asks for that exact action in the current message. Requests like "update the README", "fix it" or "let me build it" are not requests to commit or push. Leave changes uncommitted.

## Combined development

Clone `GrayMoon` and `GrayMoon.Desktop` as siblings. `GrayMoon.Desktop/GrayMoon.slnx` is the combined solution (Desktop plus the GrayMoon projects); `GrayMoon.Desktop/build/Initialize-DevelopmentWorkspace.ps1` prepares the layout. See the "Clone layout", "Initialize workspace" and "Build" sections of `GrayMoon.Desktop/README.md`.
