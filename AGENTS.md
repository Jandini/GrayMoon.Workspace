# AGENTS.md

Guidance for AI coding agents working in the GrayMoon workspace. `CLAUDE.md` in this folder carries the same rules with more detail; keep the two in step.

## Workspace layout

`C:\Workspace\GrayMoon` is a thin workspace repository (`graymoon.json`, `codegraph.json`, `GitVersion.yml`) on top of independent sibling repositories. The sibling folders are git-ignored here, so root `git status` never shows their changes - run git inside the relevant folder. There is no root-level build or solution; always work inside a sub-repo.

| Folder | What it is |
|---|---|
| `GrayMoon/` | Core product: `GrayMoon.App` (Blazor Server) + `GrayMoon.Worker`. Rules: `GrayMoon/AGENTS.md`, `GrayMoon/CLAUDE.md`. |
| `GrayMoon.Desktop/` | Windows desktop shell (WPF + WebView2). Rules: `GrayMoon.Desktop/CLAUDE.md`. |
| `GrayMoon.Release/` | Public landing repo for Desktop downloads and release notes. Not code. |
| `GrayMoon.wiki/` | Local checkout of the GitHub wiki. Not code. |

Do not hand-edit the `<graymoon-repositories>` block in `.gitignore`; it is maintained from `graymoon.json`.

In a feature worktree, stay inside the feature folder and run git per sub-repo there. Do not `cd` back to `C:\Workspace\GrayMoon`.

## Documentation

- Current-state architecture lives in `GrayMoon/docs/architecture/` and `GrayMoon.Desktop/docs/architecture/`. Update the relevant document in the same change as the behavior it describes.
- Proposals for work not yet built go in `GrayMoon/docs/todo/`.
- After any feature, bug fix or other change to product behavior, add one bullet at the top of `## Recent GrayMoon changes` in `GrayMoon.Desktop/README.md`, or edit the existing bullet for that feature. Style: a bold phrase, then ` - ` (ASCII hyphen), what the user sees and why, and what stayed the same. Skip it for questions, reviews, refactors, tests and documentation-only edits.

## Never commit or push without an explicit request

Never run `git commit` or `git push` (or stage, tag, amend, or open a pull request) in any of these repositories unless the user explicitly asks for that exact action in the current message. Requests like "update the README", "fix it" or "let me build it" are not requests to commit or push. Leave changes uncommitted.
