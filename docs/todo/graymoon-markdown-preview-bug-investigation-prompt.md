# AI Implementation Prompt — Investigate and Fix GrayMoon Changes Markdown Preview Corruption

## Role and objective

You are an engineering agent working in the **GrayMoon** repository. Investigate and fix a reproducible Markdown preview corruption issue in **Git Changes → Preview → Changes**. Work on the current checkout, inspect the real implementation, and preserve existing functionality. **Do not jump directly to a suspected fix. Phase 0 is mandatory and must produce a sample Markdown file and establish a reproducible failure first.**

Do not commit, push, open a PR, or modify unrelated behavior unless explicitly requested. Use the repository's existing conventions, including line-ending and test conventions. Record actual observations rather than treating prior hypotheses as proven.

## Reported defect and exact fixture

The original Markdown is:

````markdown
---
## Prompt (copy everything below the line for each stage, replacing `{STAGE_NUMBER}`)
---
You are implementing **Stage {STAGE_NUMBER}** of a staged implementation plan for the ingestion diagnostics
endpoint under Jira ticket BAM-3143 (design subtask BAM-3165). You are one of several agents working
different stages of this plan; other stages may be done, in progress elsewhere, or not started — you are
only responsible for your one stage.
````

The user observed the preview displaying a heading apparently truncated after the opening backtick (rendering `\``), and the following paragraph rendering approximately:

```text
You are implementing **Stage&#x20;**&#x6F;f a staged implementation plan for the ingestion diagnostics endpoint ...
```

Symptoms include disappearance of `{STAGE_NUMBER}` both inside inline code and inside bold text, loss of adjacent formatting, and raw HTML entity artifacts such as `&#x20;` and `&#x6F;`. Treat this as an observation of the UI, **not** proof that Markdig, HtmlDiff, the sanitizer, or a specific character is the cause. Note that `---` may have different Markdown meanings depending on placement; preserve this exact input in the regression test rather than normalizing it away.

## Known likely code path (verify against the current branch)

- `src/GrayMoon.App/Services/GitChanges/MarkdownProseDiffService.cs`
  - `Render`, `ToHtml`, `DiffAndSanitize`, `Sanitize`
  - Markdig `Markdown.ToHtml`; `HtmlDiff.HtmlDiff(...).Build()` for Changes; `HtmlSanitizer`.
- `src/GrayMoon.App/Components/Pages/WorkspaceGitChanges.Markdown.cs`
  - `PushMarkdownPreviewAsync`; `EffectiveMdPreviewMode`; original and modified content.
- `src/GrayMoon.App/Components/GitChanges/MarkdownDiffViewer.razor.cs`
  - Transfers HTML to JS.
- `src/GrayMoon.App/Components/GitChanges/MarkdownDiffViewer.razor.js`
  - `setHtml` inserts `innerHTML`; follow-up behavior may mutate the DOM.
- `src/GrayMoon.App.Tests/MarkdownProseDiffServiceTests.cs`
  - Existing tests for Markdown preview, changes, HTML diff, Mermaid, and sanitization.
- `src/GrayMoon.App/GrayMoon.App.csproj`
  - Current Markdig, HtmlDiff and HtmlSanitizer dependencies.

Recheck file locations and versions: they may have changed. `Changes` differs from `After` and `Before` because it diffs two rendered HTML versions. This is a **lead**, not a predetermined root cause.

---

## Phase 0 — Create a sample Markdown document and reproduce the bug (hard gate)

**This phase must be completed before Phase 1. Do not edit production code during Phase 0.**

1. Create a realistic, checked-in-or-temporary fixture under an appropriate existing test-fixture location (prefer `src/GrayMoon.App.Tests/Fixtures/Markdown/`; otherwise document the chosen path), named `stage-placeholder-preview.md`, containing the **exact Markdown** above. Preserve its characters, backticks, curly braces, typography, separators, and line breaks. Use the repository's mandated line-ending convention when writing files; verify the parsed text matches the supplied fixture.
2. Create an explicit **before/after reproduction pair** suitable for the Changes diff view:
   - Before: the exact fixture text.
   - After: the same text except for a tiny, clearly identified change **outside** the placeholder-bearing heading and paragraph (for example, append a trailing sentence on a separate paragraph). Do not alter `{STAGE_NUMBER}`, its surrounding backticks, or its bold markup in either side.
   - Also test identical before/after and a modified version changing text near the placeholder to determine whether the corruption depends on edits or token alignment.
3. Make the sample available through GrayMoon's normal Git Changes workflow, in a test repository/worktree as appropriate, so it can be opened in **Preview → Changes**. Use a tracked file with a baseline commit for the main before/after test. Do not create permanent commits in a user's active repository without authorization; use an isolated temporary repository or test worktree if baseline commits are necessary. Distinguish new/untracked files, which may force `After` mode, from tracked modified files that actually exercise HtmlDiff.
4. Capture the **exact reproducibility matrix**:
   - Preview → Changes for a tracked modified `.md` file (primary case).
   - Preview → After and Preview → Before for the same file.
   - Source/Monaco view, confirming both file contents are intact.
   - Unchanged sides versus a small edit elsewhere; optionally staged versus unstaged if their inputs differ.
5. Record the actual rendered result as **DOM `textContent` and HTML `innerHTML`**, alongside the source Markdown, rather than relying solely on screenshots. A screenshot is useful additional evidence. Identify which modes fail and whether the preview contains literal `&#x...;` strings.
6. Create a focused **failing automated regression test**, preferably using `MarkdownProseDiffService.Render`, asserting that the output of `Changes` represents both `{STAGE_NUMBER}` occurrences correctly and contains no literal escaped-entity artifacts in visible text. For visible-text checks, parse returned HTML with a reliable HTML parser or run an appropriate browser DOM test; do not simply assert that the raw HTML contains/doesn't contain `&`, because valid HTML encoding is expected. Ensure the test tests actual visible semantics. Include the reproduction before/after inputs above.
7. Run the failing test **before production changes**. Save the command, failure output, and relevant rendered snippets in your work notes. If the service test passes but the UI fails, build a UI-level/browser-based reproduction and inspect the following JS mutations. If the UI cannot be exercised in this environment, explicitly distinguish `service reproduced`, `UI reproduced`, and `UI not verified`; do not claim success without evidence.

### Phase 0 exit gate

Proceed to Phase 1 **only after** the defect has been reproduced in the actual Changes rendering path, either with a failing service-level test demonstrating the observed corruption or with a confirmed UI/DOM reproduction. If initial attempts do not reproduce, vary tracked/staged state and minimal before/after edits, then investigate whether the provided Markdown is transformed upstream. **If still not reproduced, stop before applying a speculative fix**: report what was tried, the observed results, and the smallest missing condition required to reproduce.

---

## Phase 1 — Isolate the first failing transformation

Trace the complete path for the same fixture, keeping copies of each intermediate value:

```text
Git file content (original/modified)
  → Worker/App diff DTO and normalization
  → MarkdownProseDiffService.Render
  → RepairUtf8Mojibake
  → Markdig ToHtml (both sides)
  → HtmlDiff.Build (Changes only)
  → HtmlSanitizer.Sanitize
  → image embedding/URL rewriting
  → Blazor JS interop payload
  → setHtml / DOM insertion
  → post-insertion JS transformations and final visible text
```

Compare exact strings at every boundary, especially the inline `<code>{STAGE_NUMBER}</code>`, `<strong>Stage {STAGE_NUMBER}</strong>`, surrounding punctuation, and character entities. Do **not** decode HTML indiscriminately: HTML escaping can be correct within serialized HTML but wrong when escaped entities are shown literally as text.

Run independent controls: Markdig conversion of both sides, HtmlDiff input/output, sanitizer input/output, and browser DOM insertion. Test whether the fault depends on brace tokens, backticks, inline formatting, malformed HTML, escaped HTML entities, whitespace, or differences elsewhere. Identify the **first stage at which correct semantic text is lost**. Record the exact root cause with relevant files/functions and a small before/after artifact.

Pay attention to the difference between valid serialized entities (e.g. `&#x20;` decoded by the browser into a space) and **literal** `&#x20;` displayed to the user. Ensure that a test can distinguish these cases.

## Phase 2 — Design and implement the smallest robust fix

Once the first corrupting stage has been demonstrated:

1. Propose the smallest change in the correct layer. Prefer a structural fix that handles arbitrary inline code, braces, punctuation, entities and bold text over placeholder-specific string substitution or regex patches.
2. Preserve Markdown semantics and diff behavior: old text remains `<del>`-annotated, new text remains `<ins>`-annotated, unchanged text remains readable. Avoid adding extraneous change markers to unchanged placeholders.
3. Preserve HTML safety. Keep untrusted raw HTML inert; do not loosen sanitizer permissions, disable sanitization, use arbitrary `Html.Raw`, or indiscriminately double-decode entities. Maintain safe links and image/Mermaid rendering.
4. Keep `After`/`Before`, added/deleted-file behavior, code fences treated as atomic blocks, Unicode repair, change navigation, and existing UI styling working.
5. If the HtmlDiff library itself cannot correctly represent this case, compare a narrowly scoped adaptation, isolation of atomic inline elements, or a safe alternative diff strategy. Document why the chosen approach is sufficient; **do not replace the entire diff architecture without evidence and justification**.
6. Do not change Git operations, repository persistence, staging, commits, workspace model, or unrelated UX.

## Phase 3 — Regression and compatibility tests

Keep Phase 0's reproducing test, which must now pass. Add targeted cases that are meaningful for the diagnosed root cause:

- Exact reported fixture in `Changes`, `After`, `Before`.
- Unchanged `{STAGE_NUMBER}` in inline backticks and in `**strong**` while unrelated text changes.
- Edits immediately before, inside, or after inline code.
- Multiple placeholders: `{X}`, `${X}`, `{{X}}`, `{STAGE_NUMBER}`.
- Backticks without braces; braces without backticks; adjacent punctuation and parentheses.
- Numeric and named HTML entities, including literal `&amp;`, `&#x20;`, and `&#x6F;`, without double-encoding or unintended decoding.
- Literal HTML-like text such as `<PackageVersion>` remains non-executable and displayed correctly.
- Markdown links, images, tables, fenced code, Mermaid, Unicode/UTF-8 text, CRLF input, and multiline paragraphs.
- Deletions, additions, unchanged content, and correct `<ins>`/`<del>` markers for real changes.
- Sanitizer/security test demonstrating that injected `<script>` or unsafe links still cannot execute.

Prefer a few strong parameterized tests to a large brittle collection. Assert decoded visible text and appropriate DOM structure, not exact serialized HTML whitespace or entity spellings. Run the relevant App test project and broader affected tests; state the commands and results.

## Phase 4 — End-to-end verification and delivery

1. Reopen the same isolated reproduction file in the actual GrayMoon Changes preview and confirm visually and by DOM inspection that the heading is complete, both `{STAGE_NUMBER}` occurrences remain, formatting is preserved, and there are no literal entity artifacts.
2. Verify `After`, `Before`, `Source`, and a normal Markdown diff containing actual insertions and deletions.
3. Review the final diff for unnecessary edits, dependency additions, performance regressions, or XSS risk.
4. Return a concise engineering report containing:
   - **Reproduction evidence**, sample fixture path, and Phase 0 failing test/result.
   - **Root cause**: exact component/function and the first corrupted intermediate representation.
   - **Fix**: files changed and why it is robust.
   - **Test results**: exact commands and outcomes, including end-to-end verification status.
   - **Remaining limitations**, if any.

### Acceptance criteria

- [ ] Phase 0 created the exact sample `.md` fixture and a tracked before/after diff scenario.
- [ ] The bug was reproduced and evidenced **before** production code changes, or the agent explicitly stopped without applying a speculative fix.
- [ ] A regression test fails before the fix and passes afterward.
- [ ] Changes preview shows the entire heading and both `{STAGE_NUMBER}` tokens with correct inline code/strong formatting.
- [ ] No raw `&#x20;` or `&#x6F;` artifacts appear where normal visible text is intended.
- [ ] Real insertions/deletions are still highlighted correctly.
- [ ] After/Before, new/deleted files, Mermaid, images, and existing Markdown behavior remain intact.
- [ ] No sanitizer/security regression, speculative replacement of the rendering stack, or unrelated UX change.
- [ ] Relevant tests pass and any unverified UI behavior is clearly disclosed.

**Begin with Phase 0 now. Do not propose a final implementation before observing the failure.**
