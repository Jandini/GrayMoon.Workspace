# AGENTS.md

Guidance for AI coding agents working in the GrayMoon workspace. `CLAUDE.md` in this folder carries the same rules with more detail; keep the two in step.

## Workspace layout

`C:\Workspace\GrayMoon` is a thin workspace repository (`graymoon.json`, `codegraph.json`, `GitVersion.yml`) on top of independent sibling repositories. The sibling folders are git-ignored here, so root `git status` never shows their changes - run git inside the relevant folder. There is no root-level build or solution; always work inside a sub-repo.

| Folder | What it is |
|---|---|
| `GrayMoon/` | Core product: `GrayMoon.App` (Blazor Server) + `GrayMoon.Worker`. Rules: `GrayMoon/AGENTS.md`, `GrayMoon/CLAUDE.md`. |
| `GrayMoon.Desktop/` | Windows desktop shell (WPF + WebView2). Rules: `GrayMoon.Desktop/AGENTS.md`, `GrayMoon.Desktop/CLAUDE.md`. |
| `GrayMoon.Release/` | Public landing repo for Desktop downloads and release notes. Not code. |
| `GrayMoon.wiki/` | Local checkout of the GitHub wiki. Not code. |

Do not hand-edit the `<graymoon-repositories>` block in `.gitignore`; it is maintained from `graymoon.json`.

In a feature worktree, stay inside the feature folder and run git per sub-repo there. Do not `cd` back to `C:\Workspace\GrayMoon`.

## Documentation

- Current-state architecture lives in `GrayMoon/docs/architecture/` and `GrayMoon.Desktop/docs/architecture/`. Update the relevant document in the same change as the behavior it describes.
- Proposals for work not yet built go in `GrayMoon/docs/todo/`.
- Workspace-level documents live in `docs/` here: `docs/code-review/` (the summary of the 2026-11-10 review fixes, kept while manual testing is going on) and `docs/documentation-update/`.
- After any feature, bug fix or other change to product behavior, add one bullet at the top of `## Recent GrayMoon changes` in `GrayMoon.Desktop/README.md`, or edit the existing bullet for that feature. Style: a bold phrase, then ` - ` (ASCII hyphen), what the user sees and why, and what stayed the same. Skip it for questions, reviews, refactors, tests and documentation-only edits.

## Defect-prevention rules

The 2026-11-10 code review (fixes listed by finding number in `docs/code-review/2026-11-10-fix-summary.md`) found recurring patterns behind its bugs. Each has a rule; read the matching section before working in that area. An existing violation in the code is never a pattern to copy.

- **Feature-context writes** - per-context state goes through `WorkspaceRepositoryStateWriter`, never the shared `WorkspaceRepositoryLink`. `GrayMoon/AGENTS.md` "Feature-context scoping".
- **Page state** - a job body loads off-thread and applies inside `InvokeAsync` / `SafeInvoke`; `RequireSelectedContextId()` is captured before the job is queued. `GrayMoon/AGENTS.md` "Blazor page jobs".
- **Lifetimes** - no per-circuit state in singletons; every subscription removed in `Dispose`. `GrayMoon/AGENTS.md` "Service lifetimes and event subscriptions".
- **Destructive work** - delete only for sources whose fetch succeeded; clean every dependent table; re-check before queued destructive work. `GrayMoon/AGENTS.md` "Destructive and merge operations".
- **Failures** - a best-effort step still reports its outcome; a transient error in a wait loop is "not yet". `GrayMoon/AGENTS.md` "Failures, cancellation and waiting".
- **Worker** - validate every external path, `ArgumentList` with `--`, never assume `.git` is a directory. `GrayMoon/AGENTS.md` "Worker: input, processes and git".
- **Trust boundaries** - secrets, allowlists and origin checks required by default. `GrayMoon/AGENTS.md` "Trust boundaries (App)".
- **Desktop** - one parsed message for gate and handler, kill the App child on every failed start, subscribed events, pinned release inputs. `GrayMoon.Desktop/AGENTS.md`.
- **Everywhere** - a fix ships with a regression test that fails on the old code; documents describe what the code does.

## Never commit or push without an explicit request

Never run `git commit` or `git push` (or stage, tag, amend, or open a pull request) in any of these repositories unless the user explicitly asks for that exact action in the current message. Requests like "update the README", "fix it" or "let me build it" are not requests to commit or push. Leave changes uncommitted.
