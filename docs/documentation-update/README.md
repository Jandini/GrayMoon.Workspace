# Documentation update for 0.2.0

This folder is the work plan for the GrayMoon 0.2.0 documentation pass. The product READMEs, the wiki, the architecture docs, `docs/todo`, and the code stay as they are until a developer edits them from these notes.

The wiki and the public `GrayMoon/README.md` describe 0.1.0. There is no `0.2.0` git tag. Both code repos are tagged only `0.1.0` (28 Sep 2026). The comparison is current `main` after that tag:

- GrayMoon: 117 commits, HEAD `8257e162` (`git describe`: `0.1.0-117-g8257e162`). Tag `0.1.0` is `9e5517f2`.
- GrayMoon.Desktop: 103 commits, HEAD `7faf92c` (`0.1.0-103-g7faf92c`). Tag `0.1.0` is `0606e01f`.

The running product version is still a GitVersion string based on `0.1.0` plus those commits. Whether every commit on this `main` is in the release stays open until a `0.2.0` tag exists.

## Decisions

READMEs are rewritten for developers who build and run the product.

Screenshots are reduced to about 60-80 real captures and recaptured from the running app with a shot list. Image-generation prompts are not the method, because the shots depend on exact UI text, colors, and seeded data.

Nothing in `docs/todo` is fully shipped, so the delete list is empty.

## Documents

- [What needs update](what-needs-update.md) lists every file and wiki page to change, with the verdict and the fact that is wrong.
- [README rewrite](readme-rewrite.md) says how each README should read, including the section outlines for the three entry READMEs.
- [Wiki 0.2.0](wiki-0.2.0.md) is the wiki plan: stale pages, new sections, and the one behavior each partial page must gain.
- [Screenshots](screenshots.md) is the capture policy, the shot-list template, and the keep / recapture / drop groups.
- [Plans to delete](plans-to-delete.md) records the empty delete list, the two partial todo notes, and the five open todos.

## Evidence

`_raw/` holds the specialist notes. When those notes disagree, follow the specialist: README verdicts from `01-readmes.md`, wiki verdicts from `02-wiki-vs-code.md`, plan status from `03-plans-to-delete.md`, screenshot counts from `04-screenshots.md`.

- [README and entry-document audit](_raw/01-readmes.md)
- [Wiki versus code](_raw/02-wiki-vs-code.md)
- [Planning docs](_raw/03-plans-to-delete.md)
- [Screenshot inventory](_raw/04-screenshots.md)
