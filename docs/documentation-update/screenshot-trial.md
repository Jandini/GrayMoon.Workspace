# Screenshot trial

A runnable procedure for taking the screenshots called for in [screenshots.md](screenshots.md). It establishes the capture mechanics (viewport, review, filing) and the safety rules for driving the two live workspaces. It does not list which shots to take. That list is screenshots.md's "Recapture" groups and the shot-list template.

Run this against a live `GrayMoon.App` at `http://localhost:8384`. Confirmed reachable and both workspaces present during this trial (2026-11-05):

- `http://localhost:8384/workspaces/1` - **GrayMoon** workspace. This is the self-hosting Workspace: the Workspace repository row *is* this checked-out `C:\Workspace\GrayMoon` tree. Repository rows: `GrayMoon` and `GrayMoon.Desktop`, both on branch `docs-b4-release`.
- `http://localhost:8384/workspaces/2` - **MezzoRecovery** workspace. The .NET Dependency demo workspace (Level 1-4 grid: `MezzoRecovery.Solution`, `.Api`, `.TapeTools`, `.Agent`, `.Tape`, `.Mezzo`, `MezzoRecovery`, `.TapeDrive`, `.TapeImage`, `.Website`, `.DockerBase`), all on `main`.

Routes are `/workspaces/{id}` for the landing (Repositories) page, then the sidebar links (Changes, Files, Actions, ... ) for the rest. There is no `/workspaces/{id}/repositories` route. That 404s. Confirmed by probing both during this trial.

The sizing trial on 2026-11-05 did not change either workspace. It only opened Home, the Workspaces list, and MezzoRecovery's Repositories page. At 2142×1175 that grid showed all 11 repositories, every row on `main`, every row `↑0 ↓0` and **in sync**, and no horizontal overflow.

## Hard safety rules

These apply to both workspaces for the whole session. They are not suggestions to weigh against convenience.

1. **Never touch the default branch of either workspace.** Workspace 1's repositories are on `docs-b4-release`, not `main`/`master`. Workspace 2's repositories are on `main`. Whatever a shot needs (a new branch, a commit, a PR), do it on a new branch or inside a worktree Feature, never as a commit directly on the branch the grid already shows.
2. **Never run Merge PRs..., Return to Default, Push Updated/Update & Push, or any Sync/Restore that writes to GitHub**, on either workspace. Screenshots of those *menus and dialogs* in their unopened or confirmation state are fine (a modal is just UI); actually completing the merge, push, or rewind is not.
3. **Never discard, reset, or stash changes on the Workspace 1 Workspace-repository row.** That row is this live dev tree. Before this trial it already carried real uncommitted work (a prior `docs/documentation-update/bootstrap.md` and a `README.md` edit from an earlier task) and showed a red ahead/changed badge for that reason. A screenshot session must not run a bulk "discard" or "hard sync" action there. It has no way to tell real in-progress work from demo clutter. If a shot needs a clean Changes page, use Workspace 2 or a Feature worktree, not the Workspace 1 root tree.
4. **Record the starting state of both workspaces before making any demo change**, and confirm the same state afterward (same branch per repo, same ahead/behind counts on rows you did not touch, no stray branches left behind, no Features left registered). Take the "before" Repositories-page screenshot of each workspace you touch as that record, even if it is not one of the shots on the list. The 2026-11-05 sizing captures are not that record. Take a fresh one at the start of the real session.
5. **Prefer a worktree Feature for anything that needs a branch, a commit, or a dirty working tree.** Features are disposable: Remove Feature at the end of the session deletes the branch and the worktree together, and nothing it does reaches the default branch unless Merge PRs... is run (rule 2 says don't). Only use a bare new branch on the main grid when the shot specifically needs the non-Feature flow (e.g. `Workspace-New-Branch.md`, `Workspace-Switch-Branch.md`).
6. **Pushing is allowed only when a shot requires server-side state** (a PR badge, an Actions run, a protected-branch rejection) **and only to a throwaway branch name that is deleted afterward**, never to `main`/`master`/`docs-b4-release`. If a shot can be faked locally (a local commit is enough to show a diff or a stage), don't push for it.
7. **Stop and ask** if a step in the shot list is ambiguous about which of these rules it needs, rather than guessing in the permissive direction.

## Capture mechanics

### Ask for a full-screen viewport first

A narrow viewport lays the page out in a narrow column, and that is the screenshot you get. Before any navigation or capture in a real session, ask the user to open the browser viewport full screen, then wait. Do not open the app, resize it yourself, or take a shot until they confirm it is full screen. Device-metrics override does not replace that step. It sets the filed pixel size after the viewport is already full screen.

Confirmed on this machine on 2026-11-05. Two calls, in this order, produce a PNG whose pixel size equals the requested size. They run only after the user has confirmed the full-screen viewport.

Target sizes, from the existing wiki set (`screenshots.md`): **2142×1175** for a Blazor web page, or **2064×1179** when the file you are replacing is already that size. **1016×678** is the WPF Desktop shell. This trial confirmed the two Blazor sizes only. Desktop still needs its own window sized to 1016×678 before a capture of that window. Do not use the browser calls below for a Desktop shot.

### The call that files

1. Set the viewport with `Emulation.setDeviceMetricsOverride`:
   - `width` and `height`: the shot's target (2142 and 1175, or 2064 and 1179)
   - `deviceScaleFactor`: `1`
   - `mobile`: `false`
2. Confirm with `Runtime.evaluate` that `innerWidth` / `innerHeight` equal that target, and that `document.documentElement.scrollWidth` and `scrollHeight` are not larger. If the scroll size is larger, the grid is clipped. Do not file that capture.
3. Capture with `Page.captureScreenshot`:
   - `format`: `"png"`
   - `fromSurface`: `true`
   - `captureBeyondViewport`: `false`
4. The tool writes the response to a JSON file because it is larger than the inline limit. The file's top-level field is `data` (base64 PNG). Decode that field to a real `.png`. Do not file the JSON.
5. Read the decoded PNG's pixel dimensions with `System.Drawing.Image` (same method as `_raw/04-screenshots.md`). **Width and height must equal the requested width and height.** This trial got 2142×1175 and 2064×1179 on the nose. There is no aspect-ratio tolerance. A miss is a failed capture: say so and recapture. Do not ask the user to accept a wrong size, and do not crop or resize the file to force it.

Re-apply step 1 immediately before every `Page.captureScreenshot`. The browser tool clears device emulation when a turn ends. Do not assume an override from an earlier turn is still in effect.

Measured results from this trial, MezzoRecovery Repositories and Home:

| Request | `Page.captureScreenshot` | Scroll size vs viewport |
|---|---|---|
| 2142×1175 | 2142×1175 | equal, no overflow |
| 2064×1179 | 2064×1179 | equal, no overflow |

At 2142×1175 the MezzoRecovery grid showed every column through the green **in sync** badges, with all four levels on screen.

### The call that does not file

`browser_take_screenshot` captures the browser pane, not the emulated viewport. On this machine it saved **3332×1781** both before the override and after requesting 2142×1175. That is a different aspect ratio (delta about 2.6% versus 2142×1175), not a scaled copy. The inline thumbnail is downscaled again and will look plausible either way. Do not measure that thumbnail, and do not copy that PNG into `GrayMoon.wiki/screenshots/`.

`computer_screenshot` is a fixed 1456×840 canvas. It cannot produce either wiki size. Do not use it for these shots.

### Settle the circuit before capturing

A hard navigation to a deep link can render a blank page or a real "GrayMoon needs to reload" banner. Also, the accessibility tree always contains an `h2` with that exact text inside `.blazor-error-copy`. During this trial that node had a **0×0** bounding rect while the page on screen was the normal Home page. A zero-rect heading is the hidden Blazor error template. Ignore it.

1. Navigate to `/` first. Then move with in-app links (sidebar, workspace name). A fresh hard navigation to `/workspaces/{id}` is less reliable.
2. Decide from pixels and geometry, not from the accessibility tree alone. The reload banner is real only when that heading's `getBoundingClientRect` has a non-zero width and height, or when the screenshot is blank.
3. Wait until transient overlays are gone. The Workspaces list shows **Fetching repositories...** and an **Abort** button while it loads. Capture the grid after that overlay is gone.
4. Take one throwaway `Page.captureScreenshot`, decode it, and confirm the pixel size and that the page has real content. Only the next capture is a candidate.

### Review before filing

1. Show the user the **decoded** PNG (the file whose dimensions you measured), not the pane thumbnail.
2. State the requested size, the actual size, and whether the content the shot block names is fully visible (menus, columns, the right edge of a wide grid).
3. Wait for an explicit accept, reject, or "recapture at a different size" before filing. Size is already an automatic reject when the pixels do not match. The accept is about the UI state.
4. On accept, copy the decoded PNG to the filename in that shot's block, inside `GrayMoon.wiki/screenshots/`, and follow its "Replaces / supersedes" line. Do not auto-crop or auto-resize. A forced resize distorts text and badge colors, which screenshots.md treats as load-bearing.

## Exact instructions for the real session

Do this as its own session, before the README and wiki rewrites ([bootstrap.md](bootstrap.md) step 1). File the PNGs and write a session log of each filename and the screen it shows. Do not edit a wiki page or a README in this session. The later rewrite embeds these files and is written to match them. One shot, start to finish, including the accept, before the next shot.

1. Read the hard safety rules above. If the app is not answering at `http://localhost:8384`, stop. Do not open it yet.
2. Ask the user to open the browser viewport full screen, and wait for them to say it is. A narrow viewport makes a narrow page screenshot. Do not navigate or capture before that confirmation.
3. Settle the circuit on `/` using the checks above.
4. For each workspace this session will touch, open its Repositories page and take a before capture with the filing call. Keep that PNG out of `GrayMoon.wiki/screenshots/`. Write down, per repository row: branch, ahead/behind, PR badge. For Workspace 1, also write down the uncommitted file list on the Workspace-repository row. That list is the cleanup check.
5. Take shots in the order in [bootstrap.md](bootstrap.md) step 3, using one block per file from the template in [screenshots.md](screenshots.md):
   1. Open the page by clicking in the app, not by pasting a deep link into a cold tab.
   2. If the block needs a branch, a commit, or a dirty tree, do it through a Feature worktree (safety rule 5), not on the row the grid already shows.
   3. Reach the exact state the block describes (seed data, badge, dialog open). Stop and ask when a step would break a safety rule.
   4. Run the filing call: set the viewport, confirm scroll size, `Page.captureScreenshot`, decode, measure.
   5. Show the decoded PNG and wait for accept, reject, or a size change.
   6. On accept, file it under the block's filename and note which old filename(s) it replaces.
   7. On reject, note why (wrong state, clipped content, UI does not match the written procedure). Either redo the setup or flag the page's prose in `what-needs-update.md`. A capture that cannot match what the page says to click is evidence the page is stale, not only a bad screenshot.
6. Run the cleanup below before ending the session.

Desktop shots (`desktop-home.png`, `desktop-home-topbar-hidden.png`, `desktop-repositories.png`) are a separate pass. Size the WPF window to 1016×678, capture that window, and measure the PNG the same way. Do not send those through `Emulation.setDeviceMetricsOverride`.

## Cleanup (end of every session)

1. Remove every Feature worktree created for the session (Remove Feature, including its branches, local and remote if one was pushed).
2. Delete any throwaway branch pushed under rule 6 that is not cleaned up by Remove Feature.
3. Confirm both workspaces' Repositories pages match the "before" record from safety rule 4: same branch per repository row, same ahead/behind/PR badges on rows that were not part of this session's shots.
4. Confirm Workspace 1's Workspace-repository row still shows exactly the uncommitted work that was there before the session (do not commit it, do not discard it). Verify its file list is unchanged from the "before" screenshot.
5. Leave everything uncommitted and unpushed beyond what rule 6 explicitly allowed. This session does not commit or push on the operator's behalf for any repository outside a disposable Feature or branch that gets deleted in steps 1-2.
6. Call `Emulation.clearDeviceMetricsOverride` so the browser tab is not left at the wiki viewport.
