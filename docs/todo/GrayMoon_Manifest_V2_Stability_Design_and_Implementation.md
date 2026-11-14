# GrayMoon — `graymoon.json` v2 Stability and Read-Only State

**Document type:** Technical design + staged implementation plan + AI-agent bootstrap prompt  
**Status:** Proposed, not implemented  
**Date:** 2026-11-14  
**Source inspected:** `Jandini/GrayMoon` default branch (`main`), via GitHub connector. Recheck the implementation branch before editing.

---

## 1. Decision and executive summary

**Preserve manifest schema v2 once a workspace definition has adopted it.** Turning the last read-only Source repository back to writable must **not** turn a version-2 `graymoon.json` back into version 1, and must **not** remove the read-only flags merely because all their values are now false. In a v2 definition, write explicit `reference: false` values for the Workspace default and for writable Source entries. A future true/false toggle should normally change a boolean and, where appropriate, remove a now-inapplicable recorded branch revision; it should not repeatedly change the schema version or the presence of every `reference` field.

**Keep reading both v1 and v2.** Do not force legacy v1 definitions to v2 merely because the installed GrayMoon supports v2. A v1 manifest should remain v1 when it has never used v2-only data. Upgrade to v2 when the user first sets read-only state (including explicit state changes that must be persisted) or otherwise introduces a v2-only branch revision. From that point, the schema level is **sticky**. No implicit downgrade.

**Compatibility caveat:** A *new* GrayMoon can read both versions; this does **not** make an *old* GrayMoon able to read version 2. The current format intentionally uses `version: 2` for `reference` and branch-revision data; older binaries may refuse it. Do not promise that old GrayMoon will ignore unknown `reference` keys. Retain this safety barrier rather than inserting v2 fields into a v1 file.

**No redesign of read-only semantics, restores, tag pins, or UI is required.** This is a manifest persistence/serialization stabilization change with focused regression tests.

## 2. Confirmed behavior in the code

### 2.1 Root cause: content-derived schema selection

`src/GrayMoon.Common/Manifest/WorkspaceManifestFile.cs` defines `SchemaVersion = 1` and `MaxSchemaVersion = 2`. Today `Serialize` ignores the incoming `manifest.SchemaVersion` when choosing the output version:

```csharp
SchemaVersion = UsesReferenceData(manifest) ? MaxSchemaVersion : SchemaVersion
```

`UsesReferenceData` returns true when the Workspace default or any repository has a non-null `reference`, or when a repository has a nonempty `branch`. An explicit `false` qualifies as v2 data; **an absent** (`null`) reference does not. Thus version numbers oscillate when the application's generated model changes between explicit booleans and nulls.

`TryParse` deliberately rejects `reference` or `branch` in a v1 file (`Workspace definition uses reference or branch, which needs "version": 2`). This is a schema safety feature, not a defect.

### 2.2 Why toggling the final read-only repository downgrades the file

`src/GrayMoon.App/Services/WorkspaceManifest/WorkspaceManifestService.cs` currently does:

```csharp
var writeReference = workspace.ReferenceDefault || sourceLinks.Any(l => l.IsReference);
// Per Source: Reference = writeReference ? actualState : null
// Workspace: Reference = writeReference ? workspace.ReferenceDefault : null
```

When a Workspace has no read-only Sources and `ReferenceDefault` is false, `BuildFromDatabaseAsync` drops all `reference` properties. `WriteAuthoritativeManifestAsync` then builds from the DB, reads the existing definition, preserves recorded pins and file-owned settings, and serializes. Because `Serialize` chooses the version from the generated *content*, the result can fall back to `version: 1` even when the existing file was v2.

This is an intentional compatibility optimization, but it is poor for **already-upgraded** manifests: the JSON diff becomes noisy and the next lock upgrades it again.

### 2.3 Important existing semantics to retain

- `repository.reference ?? workspace.reference ?? false` determines a Source's effective read-only state (`WorkspaceRepositoryRevisionPins.IsReference` and `RestoreDefinitionEvaluator`). **An absent per-repository key does not universally mean false**: if `workspace.reference` is true, the repository inherits true. For a writable exception under a true default, `repository.reference: false` is necessary.
- `workspace.reference` controls the default only for Source repositories added later. It does **not** retroactively change existing Source entries.
- A writable Source cannot retain a `branch` + `commit` *read-only revision*. `WorkspaceRepositoryRevisionPins.CopyOnto` correctly drops such a revision upon unlocking. **Keep this rule.**
- A `tag` + `commit` pin has independent meaning and must survive unlocking. **Keep this rule.**
- The file is the authoritative store for recorded tag/branch revisions; the DB does not hold these pins.
- Drift detection already compares effective read-only state, treating missing and explicit false as equivalent when the default is false; branch/commit revisions are ignored by drift. **Keep semantic comparison, not a raw JSON comparison.**
- `WorkspaceReferenceOperations.ChangeAsync` updates read-only flags in a single database save and then calls `SyncDefinitionToDiskAsync`, followed by revision recording when appropriate. Preserve the structural lock, activation checks, and the existing ordering.
- `codegraph`, `ai`, tag pins, version-file entries, and unrelated repository configuration must survive authoritative rewrites.

### 2.4 Tests documenting the current unwanted behavior

The existing tests explicitly expect downgrading. These expectations need to change **only where a v2 file already exists**:

- `src/GrayMoon.Common.Tests/WorkspaceManifestReferenceTests.cs`: `A_definition_without_reference_data_stays_version_1_whatever_version_it_is_given`.
- `src/GrayMoon.App.Tests/WorkspaceManifestReferenceTests.cs`: `Writing_the_definition_drops_the_branch_and_commit_of_a_repository_that_is_writable_again` currently checks that the resulting manifest is v1 and lacks every `reference` property.
- Keep the positive test `Nothing_is_written_when_no_repository_is_read_only_and_the_default_is_off`, but ensure it models a *never-upgraded* Workspace/v1 definition, not a v2 source.

Do **not** simply invert all tests to always write v2. That would gratuitously upgrade every v1 workspace.

## 3. Desired contract

| Existing definition / transition | Resulting schema | Read-only fields | Revision pins |
|---|---:|---|---|
| Fresh or existing v1; all sources writable, default false, no v2 data | 1 | `reference` omitted, as today | Legacy tag pins unchanged |
| v1 → first lock of one Source | 2 | Explicit Workspace default and per-Source booleans | Record branch revision if applicable |
| v2 → unlock one Source, other Sources remain read-only | 2 | Explicit `false` on unlocked Source, others unchanged | Remove unlocked Source's branch revision; preserve tag pin |
| v2 → unlock the **last** read-only Source | 2 | `workspace.reference: false` and per-Source `reference: false` remain | Remove read-only branch revision only |
| v2 → change only the Workspace default from true to false | 2 | Change only the default's boolean when normalized | Existing per-Source values unchanged |
| v2 containing all false values → save again | 2 | No changes | No changes |
| v2 all-false → lock again | 2 | Only necessary booleans/revision values change | Record new revision when applicable |
| v2 with a read-only revision of a Source that is now writable | 2 | Writable state explicit | Drop invalid `branch` + `commit` |
| v2 with a writable Source pinned to a tag | 2 | Writable state explicit | Preserve `tag` + `commit` |
| Existing v1 with no `reference` keys, default absent | 1 until upgraded | Effective default is false | No behavior change |

### 3.1 Example: v1 → v2 → v2 (never v1 again)

These examples elide unrelated fields only to show the schema behavior; production output retains the full supported manifest structure.

**Before first lock (v1):**

```json
{
  "version": 1,
  "workspace": { "profile": { "type": "basic", "versioning": "none", "ci": "none" } },
  "connectors": [],
  "repositories": [
    { "name": "Api", "repositoryUrl": "https://github.com/acme/Api.git", "connectorUrl": "https://github.com" },
    { "name": "Web", "repositoryUrl": "https://github.com/acme/Web.git", "connectorUrl": "https://github.com" }
  ]
}
```

**After locking `Api` (v2):**

```json
{
  "version": 2,
  "workspace": {
    "profile": { "type": "basic", "versioning": "none", "ci": "none" },
    "reference": false
  },
  "connectors": [],
  "repositories": [
    { "name": "Api", "repositoryUrl": "https://github.com/acme/Api.git", "connectorUrl": "https://github.com", "reference": true },
    { "name": "Web", "repositoryUrl": "https://github.com/acme/Web.git", "connectorUrl": "https://github.com", "reference": false }
  ]
}
```

If GrayMoon captured a revision on the locked `Api`, it would also hold a valid `branch` and full `commit` hash.

**After unlocking `Api` (still v2):**

```json
{
  "version": 2,
  "workspace": {
    "profile": { "type": "basic", "versioning": "none", "ci": "none" },
    "reference": false
  },
  "connectors": [],
  "repositories": [
    { "name": "Api", "repositoryUrl": "https://github.com/acme/Api.git", "connectorUrl": "https://github.com", "reference": false },
    { "name": "Web", "repositoryUrl": "https://github.com/acme/Web.git", "connectorUrl": "https://github.com", "reference": false }
  ]
}
```

Only the `reference` transition, plus removal of any now-invalid branch pin, should be relevant to this toggle. Repeated saves must not reintroduce v1.

## 4. Implementation design

### 4.1 Separate **schema capability** from **feature values**

Introduce an explicit version-resolution rule:

```text
outputVersion = max(
    validExistingFileVersion,  // if an existing definition was successfully parsed
    versionRequiredByContent, // v2 for explicit reference/branch data, v1 otherwise
    requestedVersion          // when a caller deliberately requests an already-supported version
)
```

Cap/reject unsupported future versions; do not silently rewrite a future version back to 2. In particular, `Serialize` must **not discard a valid `SchemaVersion = 2` merely because all read-only fields are false or absent**.

**Critical migration trap:** `BuildFromDatabaseAsync` currently constructs the model with `manifestFile.CurrentSchemaVersion` (2). If `Serialize` is changed to honor that version without changing the model-building path, every otherwise-legacy v1 manifest would unexpectedly become v2. Adjust the baseline model-building/version-resolution path **in the same change**. Two acceptable approaches:

1. **Recommended:** Build the DB-derived baseline with schema v1 when no v2 feature is needed; read the existing manifest and explicitly preserve its v2 schema if already upgraded; upgrade only when content requires v2.
2. Alternatively, add a deliberately named schema-policy parameter to the authoritative writer, populated only *after* inspecting the existing file. Keep a single source of truth for the resolution rule.

Do not add a global setting or database migration solely to remember schema version; the persisted `graymoon.json` already contains it. No existing schema field needs to be added.

### 4.2 A v2 definition has stable explicit flags

Once the output schema resolves to v2, derive `workspace.reference` and each Source repository's `reference` from the actual persisted database state and emit explicit `true`/`false`, **including the all-false case**. Do not infer every existing repository's value solely from `workspace.reference`; each Source has its own `IsReference` flag.

Keep the current v1 representation minimal when no upgrade occurred. For an existing v2 manifest that is sparsely populated or hand-edited, a one-time canonicalization to explicit per-Source flags is acceptable **if effective states are preserved**; subsequent rewrites must be stable. Prefer minimizing this initial normalization when feasible, but do not create ambiguous inheritance rules.

### 4.3 Read existing definition before finalizing its version

`WorkspaceManifestService.WriteAuthoritativeManifestAsync` should:

1. Resolve the Workspace repository and read `graymoon.json` (using existing Worker file access).
2. Parse it when present. Reject future schema according to the existing policy, rather than overwriting it as a v2 definition.
3. Build authoritative state from DB, without unintentionally forcing v2 for v1-only Workspaces.
4. Resolve the output schema from prior persisted version + newly required features.
5. Populate explicit reference state for v2; omit it for legacy v1 when no v2 state is required.
6. Carry over file-owned `codegraph` / `ai` and unlinked `versionFiles` and revision pins using existing helpers.
7. Drop branch/commit revisions that are invalid once the Source is writable; retain tag pins.
8. Serialize canonically. If the canonical contents already equal the current contents, do not request a write. Otherwise use the existing `WriteRepositoryFile` path with `onlyIfChanged`.

Ensure concurrency and context scoping follow established GrayMoon rules. Do not bypass the Workspace structural lock for setting read-only mode, and do not add a competing writer that races against pin updates.

### 4.4 Keep the serializer pure and predictable

In `WorkspaceManifestFile.Serialize`, preserve a valid explicit v2 `SchemaVersion`. The new version rule should be in a small, separately tested helper instead of scattered `if` branches. Do not make `Serialize` look up the DB or read files. It receives the model and serializes it.

Keep `TryParse`, `IsNewerSchema`, `ReadPinnedRevision`, normalization, validation, and field order compatible with the existing v1/v2 contracts. A `version: 1` manifest containing `reference` or `branch` remains invalid.

### 4.5 Minimal diffs and idempotence

For an already-canonical v2 file:

- Toggling one Source should not remove/re-add reference keys on unrelated Sources.
- Toggling the Workspace default should not rewrite Source states unnecessarily.
- Repeating a save with unchanged logical content must produce identical serialized bytes; ideally the Worker receives no redundant write command.
- No unrelated changes to connector ordering, repository identities, profile, AI, CodeGraph, version files, file endings or custom data beyond the serializer's established canonical representation.

**Scope control:** A full lossless JSON patch engine is not part of this change. The existing canonical serializer can remain. Focus on eliminating schema oscillation and unnecessary write requests, not preserving every hand-edited whitespace layout.

## 5. Staged implementation plan

### Phase 0 — Characterization (no production changes)

- Verify code on the actual development branch before implementing; the inspection underlying this document used `main`.
- Create a v1 fixture with two writable Sources and default false.
- Transition: v1 → lock one Source → unlock → lock again. Capture the exact JSON at each step, demonstrating the existing v1/v2/v1/v2 oscillation.
- Record existing behavior for `workspace.reference: true`, explicit writable Source overrides, tag pins and read-only branch revisions.
- Add failing regression tests for **sticky v2**; don't alter the expected production behavior yet.

**Exit:** tests reproduce the unwanted downgrade without changing other behavior.

### Phase 1 — Version policy in the Common manifest serializer

- Implement an explicit rule preserving a requested version 2 even when v2-only properties are null/false.
- Retain automatic upgrade when data requires v2.
- Ensure a legacy v1 model without v2 features still serializes as v1.
- Do not modify the v1 parser guard or future-version refusal.
- Update obsolete tests that assert the serializer *must* downgrade every v2 model with no reference data.

**Exit:** common-unit tests pass for v1 and v2 round-trips and schema safety.

### Phase 2 — Authoritative writer resolves existing schema

- Adjust DB model generation and `WriteAuthoritativeManifestAsync` together so `CurrentSchemaVersion = 2` does not accidentally upgrade every v1.
- Preserve existing v2 after reading the persisted file.
- For v2, emit actual DB-derived explicit `reference` booleans, including false for all Sources and Workspace default.
- For v1 with no v2 data, continue omitting `reference` and writing v1.
- Keep all recorded-revision and file-owned-section copy logic.

**Exit:** the all-false transition retains `version: 2` and explicit flags; untouched v1 stays v1.

### Phase 3 — Integration and failure safety

- Exercise the `WorkspaceReferenceOperations` facade: lock/unlock one Source, lock/unlock all, set default, and no-op saves.
- Ensure duplicate writes are skipped when canonical content is unchanged.
- Preserve validation of unpushed commits and existing Worker/connection error handling.
- Ensure a failed file write generates a warning and does not falsely claim the manifest was saved (current DB/file consistency policy preserved; do not introduce silent rollback behavior).
- Validate `RestoreDefinitionEvaluator`, preflight and restore against both schemas.

**Exit:** no behavioral regression outside manifest representation.

### Phase 4 — Regression matrix

Required tests:

| Scenario | Assertion |
|---|---|
| Never-upgraded v1, all false | Remains v1; no `reference` keys |
| v1 first true Source | v2; all Source flags explicit |
| v2 last Source unlocked | Remains v2; flags explicitly false |
| v2 all false serialized twice | Identical output; no redundant write |
| v2 true → false → true | Never downgrades; no unrelated toggles |
| `workspace.reference = true`, Source override false | Source stays writable after restore |
| Workspace default true → false, Sources unchanged | Existing Source states unchanged |
| Unlock Source with branch + commit | Removes read-only revision; keeps v2 |
| Unlock Source with tag + commit | Retains tag pin and commit; keeps v2 |
| v2 with no `reference` keys | Preserves v2; normalization maintains effective values |
| v1 file with v2 fields | Still rejected |
| v3 file | Still rejected as newer; never rewritten down to v2 |
| v1/v2 restore evaluation | Same effective read-only states as before |
| v2 `reference: false` in drift comparison | No false-positive drift when DB false |
| `ai`, `codegraph`, `versionFiles`, tag pins | Preserved exactly by relevant rewrite logic |
| Unsupported/malformed existing definition | Existing failure policy preserved; no surprise downgrade |
| Repeat no-op reference change | Does not rewrite definition |

**Exit:** all focused tests, Common tests, App tests, and existing Worker/restore tests pass.

### Phase 5 — Documentation and verification

- Update `docs/architecture/03-data-model-and-persistence.md` and relevant manifest contract comments to state: **v1 remains v1 until needed; v2 never implicitly downgrades; explicit false is persisted for v2**.
- Update developer-facing manifest version rules and obsolete test comments.
- Run the full relevant build/test commands according to repository instructions; provide results and any pre-existing failures.
- Review the final diff to confirm only intended areas changed.

**Exit:** design is reflected in code, tests, and repo documentation.

## 6. Non-goals and guardrails

- No v3 manifest.
- No new UI, modals, toggles, settings, or database migrations.
- No automatic PR, commit, or push.
- No change to read-only repository operational policy, pinned snapshots, Feature worktrees or orchestration.
- No weakening of the v1/v2 schema guard for older clients.
- No conversion of all existing v1 manifests to v2.
- No change to the semantic `repository.reference ?? workspace.reference ?? false` fallback.
- No retention of a `branch` + `commit` read-only revision on an unlocked writable Source.
- No removal of a valid tag pin merely because a Source becomes writable.
- No broad refactoring of the entire manifest subsystem.

## 7. AI coding-agent bootstrap prompt

> **Task:** Implement the `graymoon.json` manifest v2 stability design in this file. Read all sections before editing. Follow the repository's `AGENTS.md`, `CLAUDE.md`, and code conventions. Work on the currently checked-out implementation branch; do not silently switch branches. This is a narrowly scoped, low-regression-risk change.
>
> **Mandatory Phase 0:** Inspect `WorkspaceManifestFile.Serialize`, `UsesReferenceData`, `WorkspaceManifestService.BuildFromDatabaseAsync`, `WriteAuthoritativeManifestAsync`, `WorkspaceRepositoryRevisionPins.CopyOnto`, `WorkspaceReferenceOperations.ChangeAsync`, restore evaluator, and the related existing tests. Create red tests proving that a v2 manifest with the last Source unlocked becomes v1 today. Confirm all assumptions against current code before production edits. If the target branch differs from the snapshot documented here, document the differences and adapt safely.
>
> **Behavior to implement:** Legacy v1 definitions without read-only features remain v1. v2 definitions retain `version: 2` indefinitely under normal GrayMoon writes, even when all Sources and the default become false. In v2, persist explicit `reference: true` or `reference: false` from the DB for each Source and default. Preserve tag pins, remove invalid read-only branch revisions on unlocking, preserve unrelated manifest sections, and keep v1/v2 parsing and future-version protections intact. Never silently force all v1 files to v2 because `CurrentSchemaVersion` is 2.
>
> **Implementation approach:** Separate model/version policy from content-presence detection. Make serializer version resolution explicit and testable. Preserve the actual schema version of an existing parsed manifest at the authoritative write boundary. If you reorder read/build steps, retain existing error handling, Worker file-access patterns, concurrency semantics, and file-owned-section merges. Keep changes minimal. Do not create a database schema migration or redesign JSON formatting.
>
> **Testing:** Implement the full matrix in Section 5, update contradictory legacy assertions, run targeted and wider tests, then inspect the diff manually. Include an end-to-end true→false→true scenario and a workspace-default-true + writable Source override case. Verify v1 and v2 restore behavior and no unnecessary writes.
>
> **Deliverable:** Code, updated tests, updated architecture comments/docs, and a short final implementation report with changed paths, precise behavioral before/after, test commands/results, outstanding issues, and evidence that old v1 definitions remain stable. Do not commit, push or open a PR unless expressly instructed.

## 8. Relevant code index

- `src/GrayMoon.Common/Manifest/WorkspaceManifestFile.cs` — serializer, parser, version guards.
- `src/GrayMoon.Common/Manifest/WorkspaceManifest.cs` — versioned model and nullable reference fields.
- `src/GrayMoon.Common/Manifest/IWorkspaceManifestFile.cs` — public contract (currently describes content-derived write version).
- `src/GrayMoon.App/Services/WorkspaceManifest/WorkspaceManifestService.cs` — DB projection, authoritative rewrite, drift and file-owned settings.
- `src/GrayMoon.App/Services/WorkspaceManifest/WorkspaceRepositoryRevisionPins.cs` — effective reference resolution, tag/branch pin preservation.
- `src/GrayMoon.App/Services/Application/WorkspaceReferenceOperations.cs` — lock/default toggles, DB save and manifest-write invocation.
- `src/GrayMoon.App/Services/Application/RestoreDefinitionEvaluator.cs` — restore fallback semantics.
- `src/GrayMoon.Common.Tests/WorkspaceManifestReferenceTests.cs` — existing schema/serialization tests.
- `src/GrayMoon.App.Tests/WorkspaceManifestReferenceTests.cs` — existing rewrite, pin, and drift tests.
- `src/GrayMoon.App.Tests/ReferenceRestoreTests.cs` — restore coverage.
- `docs/architecture/03-data-model-and-persistence.md` — architecture reference to update.

---

**Acceptance statement:** Once the manifest has reached version 2, switching every read-only repository off writes explicit `false` values and retains version 2. Switching back on changes the necessary values, rather than rebuilding the manifest as a different schema. GrayMoon continues to restore legacy v1 and v2 definitions correctly, without making old GrayMoon binaries accept v2.
