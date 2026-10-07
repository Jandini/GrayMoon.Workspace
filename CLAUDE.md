# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace layout

`C:\Workspace\GrayMoon` is a thin **workspace repository** (its own `.git`, one commit, `.graymoon.json` + `GitVersion.yml`) that sits on top of several independent sibling repositories developed together. The sibling folders are git-ignored by the root repo, so root `git status` never shows their changes - run git inside the relevant folder.

| Folder | What it is | Git repo? |
|---|---|---|
| `GrayMoon/` | The core product: `GrayMoon.App` (Blazor Server web UI) + `GrayMoon.Agent` (local git/filesystem worker). Public repo. | Yes, own `.git` |
| `GrayMoon.Desktop/` | Windows desktop shell (WPF + WebView2) that wraps `GrayMoon.App` as a child process. Private repo. | Yes, own `.git` |
| `GrayMoon.Release/` | Public landing repo for Desktop downloads, updates and release notes (just a README). Not code. | Yes, own `.git` |
| `GrayMoon.wiki/` | Local checkout of the GitHub wiki (user-facing docs) for the `GrayMoon` repo. Not code. | Wiki repo |

`.graymoon.json` lists the two code repositories (`GrayMoon`, `GrayMoon.Desktop`) managed as the workspace; the `<graymoon-repositories>` block in `.gitignore` is maintained from it, so don't hand-edit that block. `.cursorignore` excludes the wiki and the (non-existent here) `GrayMoon.docs/` from indexing.

There is no root-level build, solution, or dependency file - always operate from inside the relevant sub-repo.

## Which CLAUDE.md applies

- Working in `GrayMoon/` -> see `GrayMoon/CLAUDE.md` for build/test commands and the full App/Agent architecture (SignalR command flow, orchestrators, background jobs, dependency-level sorting, etc.).
- Working in `GrayMoon.Desktop/` -> see `GrayMoon.Desktop/CLAUDE.md` for build/test commands and the desktop shell's process/IPC architecture.

## Combined development

For combined-build setup (sibling clone layout, generating `GrayMoon.slnx`), see the `setup-combined-workspace` skill in `.claude/skills/`.
