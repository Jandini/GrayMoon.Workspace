# Branch persistence analysis

Scope: where GrayMoon creates or deletes git branches, and whether the `RepositoryBranches` table is kept up to date.
Finding: Remove Feature deletes branches in git but never updates `RepositoryBranches`, so deleted branches stay persisted.
Analysis only; no code was changed or run.

## Where branches are created or deleted

| Path | Git action | `RepositoryBranches` updated? |
|---|---|---|
| `WorkspaceBranchOperations.DeleteBranchAsync` (`WorkspaceBranchOperations.cs:787`, manual delete) | local or remote delete | Yes, removes matching rows (`:845-852`) |
| `WorkspaceGitService.ReturnToDefault.cs:152` | deletes current local branch | Yes |
| `WorkspaceGitService.CreateBranchesAsync` (`WorkspaceGitService.Branches.cs:269`) and `WorkspaceBranchOperations.CreateBranchAsync` (`:683`) | create | Yes, via `EnsureLocalBranch(es)PersistedAsync` |
| Push, set-upstream | create remote ref | Yes, remote rows added |
| Full `RefreshBranches` via `RepositoryBranchWriter.PersistAsync` | none | Yes, authoritative add/remove/update |
| **Remove Feature** (`WorkspaceFeatureOperations.cs:892`, local delete) | local delete | **No** |
| **Remove Feature** (`WorkspaceFeatureOperations.cs:965`, remote delete) | remote delete | **No** |
| **Feature roll-back** (`WorkspaceFeatureOperations.cs:2090`) | local delete | **No** |
| Create Feature (`CreateGitWorktree`) | probably creates the Feature branch (worker side not checked) | **No** |

A search for `RepositoryBranches`, `PersistBranches` and `RefreshBranches` under `Services/Features/` returns nothing.

## Why deleted branches stay

- **No write on the success path.** After `DeleteBranch` succeeds (`:905`, `:980`) the code only sets the report outcome.
- **No later cleanup.** `FinalizeFeatureRemovalAsync` (`:1095`) deletes only Feature rows and the context. Its doc comment says the Workspace refresh is "a separate operation started when the user leaves".
- **Quick Fetch does not fix it.** `WorkspaceGitService.Fetch.cs:123` calls `PersistBranchesAsync` with `localBranches: null` and `remoteBranches: null`. The removal guard at `RepositoryBranchWriter.cs:113` then skips branch rows, so only tags are refreshed.
- **Result.** Rows go stale until an explicit branch refresh (`/api/branches/refresh` or `RefreshBranchesForRepositoryAsync`). `PruneRemoteBranchesAsync` only covers remote rows after `fetch --prune`.

## Considerations for a fix

1. **Row keys differ.** Manual delete matches `BranchName == branchName` with `IsRemote`. Remote rows are stored as `origin/<name>` (`EnsureRemoteBranchPersistedAsync`), but Remove Feature passes the bare name. Prefix `origin/` for remote deletes or the cleanup silently matches nothing.
2. **Which link.** The branch lives in the main repository, so rows belong to the special Workspace's `WorkspaceRepositoryId`. Verify this is the correct id for Feature contexts.
3. **Only on success.** Remove rows only for `Deleted` outcomes. `Kept`, `KeptUnmerged` and `Failed` leave the branch in git, so its row must stay.
4. **Concurrency.** Removal fans out with `Task.WhenAll`. Use a short-lived context per row from `dbContextFactory` (as at `:847`); the shared `AppDbContext` is not thread-safe.
5. **Broadcast.** Manual delete sends `WorkspaceSynced`. Remove Feature should send it too, or rely on the refresh when the user leaves.
6. **Roll-back and Create Feature.** Roll-back needs the same fix. Create Feature probably needs the mirror fix: `EnsureLocalBranchPersistedAsync` for the new branch.

## Implemented design

`RepositoryBranchWriter` is now the single owner of single-branch row changes: `AddLocalBranchesAsync`, `AddRemoteBranchAsync`, `RemoveBranchAsync` and `ToRemoteBranchName`. Remote names are normalized to `origin/<name>` in one place, and tags are never touched.

- `WorkspaceGitService`, `WorkspaceBranchOperations` (create, set-upstream, delete) and Return to default no longer carry their own copies of the add/remove logic; they delegate to the writer.
- `WorkspaceFeatureOperations` records the Feature branch after Create and Repair succeed, and removes rows only after git confirmed the delete (Remove local, Remove remote, roll-back). Kept, unmerged or failed deletes leave the row.
- Each Feature write runs in its own DI scope, so parallel per-repository work never shares a DbContext. A failed row write is logged and reconciled by the next branch refresh; it does not fail an operation whose git work already happened.
- Tests: `FeatureBranchPersistenceTests` (7). Two of them fail without the Feature-operations change. Full `GrayMoon.App.Tests` suite: 1471 passed.

Not changed: `WorkspacePushService` still adds remote rows inline inside its larger save, and `BuildSnapshot` still injects the expected Feature branch at display time.