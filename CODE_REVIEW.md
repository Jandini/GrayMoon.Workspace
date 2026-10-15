# GrayMoon Code Review

Date: 2026-10-15
Scope: `GrayMoon/` (App, Worker, Common, Abstractions, Application) and `GrayMoon.Desktop/`.
Method: targeted static review. I scanned both repos for risky patterns (process launching, sync-over-async, empty catches, raw SQL, `async void`), then read the security-relevant paths in full: `Program.cs`, `RequestSecurityMiddleware`, `WorkerSecretMiddleware`, `HookListenerHostedService`, `SelfUpdateCommand`, `DesktopNotificationHub`, `WorkerInstaller`.
This is NOT an exhaustive audit. The ~54k-line App was sampled, not read end to end. Findings marked "verify" were not confirmed by running code, and no exploit was executed.

Overall: the codebase is mature and clearly security-aware (origin checks, worker secret, AES-GCM token storage, `ArgumentList`-style process launching with explanatory comments, no TODO/HACK debt, no `new HttpClient()` in the App, no string-built SQL). The issues below are mostly gaps at trust boundaries plus maintainability pressure from very large classes.

## Summary

| # | Severity | Area | Issue |
|---|---|---|---|
| 1 | High | Security | Worker self-update executes a remote script from a URL the Worker never validates; the URL derives from the HTTP `Host` header |
| 2 | Medium | Security | Origin/Host checks do not stop DNS rebinding; `AllowedHosts` is `*` |
| 3 | Medium | Security | Worker hook listener (127.0.0.1:9191) has no authentication or Origin check |
| 4 | Medium | Security | Worker-secret enforcement has a downgrade window (missing secret accepted until first pairing) |
| 5 | Low | Security | Command-line string built by concatenation in `SelfUpdateCommand` |
| 6 | Medium | Maintainability | God classes and a 420-line composition root |
| 7 | Medium | Data layer | `EnsureCreated()` plus hand-rolled migrations; shared-cache SQLite; redundant PRAGMAs |
| 8 | Low | Reliability | `async void` startup/exit paths and blocking calls in Desktop |
| 9 | Low | Reliability | Fire-and-forget request handling in the hook listener, unbounded body read |
| 10 | Low | Code quality | Misc: string-built process args, blocking `.Result`, stale docs |

---

## 1. High - Worker self-update runs an unvalidated remote script

Files:
- `GrayMoon/src/GrayMoon.Worker/Commands/SelfUpdateCommand.cs:14-35`
- `GrayMoon/src/GrayMoon.App/Components/Pages/Worker.razor:418-421`
- `GrayMoon/src/GrayMoon.App/Hubs/DesktopNotificationHub.cs:92`

What happens: the App builds `installUrl` from the incoming request (`NavigationManager.BaseUri` in Blazor, `http.Request.Scheme/Host` in `UpgradeWorker`), sends it to the Worker over SignalR, and the Worker runs:

```
cmd.exe /c start "" /b powershell.exe -NoProfile -NonInteractive -Command "$env:...='1'; irm '<installUrl>' | iex"
```

Problems:
- The Worker performs **no validation** of `InstallUrl` (scheme, host, loopback/configured-host allowlist). Whoever can make the App emit a URL, or send `SelfUpdate` on the hub, gets code execution as the developer on their machine.
- The URL's host comes from the request `Host` header, which is attacker-influenced (see #2), and `AllowedHosts` is `"*"` (`appsettings.json:34`).
- The Desktop's equivalent path (`WorkerInstaller.TryCreateInstallScriptUrl`) does validate that the address is local, and disables redirects and checks the media type. The Worker's path has none of that, so the two code paths have inconsistent safety.
- `CLAUDE.md` says the `SelfUpdate` payload must never change (old Workers must keep updating). That constrains the fix: validate on the **App** side (build the URL from configured/loopback values, not the Host header) and add validation to the **Worker** for newly installed Workers.

Plausible chain (verify): a web page the developer visits rebinds its DNS name to 127.0.0.1 (see #2), loads the Blazor UI under the attacker's hostname, and triggers "Update Worker". `BaseUri` is then `http://attacker.example:8384/`, the Worker pipes the attacker's script into `iex`.

Fix:
1. App: never derive `installUrl` from request `Host`. Use a configured public base URL, or the loopback address the server bound to.
2. Worker: reject `InstallUrl` unless it is `http(s)`, the host is loopback or matches the host of the connected App hub, and the path is exactly `/api/worker/install`.
3. Prefer downloading the script to a file and running it with `-File`/`ArgumentList` over `irm | iex`; consider signature or hash verification.

## 2. Medium - Origin check does not stop DNS rebinding; no Host validation

Files: `GrayMoon/src/GrayMoon.App/Services/Security/RequestSecurityMiddleware.cs:74-125`, `GrayMoon.App/appsettings.json:34`

- `IsAllowedOriginHost` accepts an Origin whose host **equals the request Host header**. Under DNS rebinding both are the attacker's hostname, so the check passes by construction. The middleware's own doc comment states that GrayMoon has no login, so this check is the only barrier.
- Any `localhost` / `127.0.0.1` Origin on **any port** is allowed (`IsLoopbackHost`), so any other local web server or dev server can drive the REST API and hubs from a browser page.
- `0.0.0.0` is treated as loopback. It is not a legitimate Origin host.
- `X-Forwarded-Host` is trusted without a configured proxy allowlist. Browsers cannot set it, but any non-browser client can; do not use it for a security decision unless `ForwardedHeaders` is configured with known proxies.
- Requests with no `Origin` always pass. That is intentional (Worker, curl), but it means non-browser local processes have full access, which should be documented as the threat model.

Fix:
- Enforce a Host allowlist. Because Desktop always runs its own App on loopback (it never connects to Docker), desktop mode can use a fixed, strict allowlist (`localhost`, `127.0.0.1`, `[::1]`) with no configuration. Only Docker (browser-only web app) mode needs a configurable hostname list. This is the standard rebinding defense and defeats the "Origin == Host" bypass.
- Compare Origin to the exact expected origin (scheme + host + port), not host only, and drop the blanket loopback-any-port rule.
- Remove `0.0.0.0` from `IsLoopbackHost`.

## 3. Medium - Hook listener is unauthenticated and CSRF-able

File: `GrayMoon/src/GrayMoon.Worker/Hosted/HookListenerHostedService.cs`

- `POST http://127.0.0.1:9191/hook/{commit|checkout|merge|push}` accepts a JSON body with `repositoryId`, `workspaceId`, `repositoryPath`. There is no secret, no `Origin` rejection, and no `Content-Type` check.
- A browser page can send a "simple" cross-site POST (`Content-Type: text/plain`, body is JSON) to a loopback address without a preflight, and `JsonSerializer.Deserialize` does not care about the content type. Result: any website can make the Worker enqueue sync jobs for arbitrary paths. Direct impact is limited to triggering git status/sync work and DoS (job-queue flooding), but `repositoryPath` is attacker-controlled input flowing into worker jobs - verify it is validated against known repository roots downstream.
- `Request.InputStream` is read with `ReadToEndAsync` with no size cap.

Fix: have the hook script send a per-install secret header (the Worker already has `WorkerSecretProvider`), reject requests carrying an `Origin` header, require `application/json`, cap the body size, and validate `repositoryPath` against the registered repository set.

## 4. Medium - Worker-secret downgrade window

File: `GrayMoon/src/GrayMoon.App/Services/Security/WorkerSecretMiddleware.cs:57-72`

A missing secret is accepted (with a warning) until some Worker has proved it has the secret, unless `Security:RequireWorkerSecret` is on. This is a sensible upgrade path, but it means a fresh install, or an install whose "seen" state is lost, lets any local process connect as the Worker or fetch connector tokens via `/repos/{id}/connector`. Consider defaulting `RequireWorkerSecret` to true for new installs (keeping the grace path only for installs that pre-date the feature), and surface a persistent UI warning while the window is open.

## 5. Low - Command line built by string concatenation

File: `SelfUpdateCommand.cs:14-16`

`BuildLaunchArguments` embeds `installUrl` inside single quotes inside double quotes with no escaping. A URL containing `'` or `"` breaks out of the quoting. This is subsumed by fixing #1 (strict URL validation), but the construction is fragile on its own; use `-EncodedCommand` or write a script file and pass it via `-File` with `ArgumentList`.

## 6. Medium - God classes and a very large composition root

Largest non-test files (lines):

| File | Lines |
|---|---|
| `App/Services/Features/WorkspaceFeatureOperations.cs` | 2613 |
| `Worker/Services/GitService.cs` | 1468 |
| `App/Services/Workspaces/WorkspaceFileVersionService.cs` | 1239 |
| `App/Services/Workspaces/WorkspacePushService.cs` | 1233 |
| `Desktop/Services/HostPrerequisiteInstaller.cs` | 1152 |
| `App/Services/Application/WorkspaceBranchOperations.cs` | 1027 |
| `App/Migrations.Features.cs` | 947 |
| `Worker/Services/GitWorktreeService.cs` | 900 |

- `WorkspaceFeatureOperations` at 2.6k lines (Create, Remove, Repair, rollback, reporting) is the clearest candidate to split by operation, each with its own testable collaborator set. `RemoveFeatureWorkspaceRefreshTests.cs` (1344 lines) is a symptom: the class is hard to test in pieces.
- The `WorkspaceRepositories` Blazor page is spread over ~10 partial files (`.BulkMerge`, `.Merge`, `.Loading`, `.Update`, `.Branches`, ...). Partial classes hide size; the page is effectively a god component sharing mutable state (the docs already warn about `_disposed` / disposable gates). Extract child components or view-model services.
- `Program.cs` registers roughly 190 services inline in one 420-line top-level script. Group them into `AddXxx()` extension methods per feature (Git, GitHub, Features, Security, Background services). It also makes registrations testable (e.g. a "all hosted services resolve" test).
- The CLAUDE.md rule "pages must not resolve orchestrators/`WorkspaceGitService`" is documented, with listed "allowed leftovers". A small architecture test (NetArchTest or similar) would enforce it instead of relying on review.

## 7. Medium - Data layer

File: `Program.cs:96-108, 313-333`, `Migrations.cs`, `Migrations.Features.cs`

- Schema is created with `EnsureCreated()` and evolved by ~1.5k lines of hand-written, idempotent migration methods that can never be deleted. This works, but you lose EF's migration history, tooling, down-migrations, and drift detection, and the startup cost grows with every shipped migration. Consider adopting EF Core migrations from a baseline snapshot (keeping the legacy methods only to bring very old databases up to that baseline).
- `Cache=Shared` is forced onto the connection string. Microsoft documents shared-cache mode as discouraged; with WAL and a per-connection `busy_timeout` it is unnecessary and can cause table-level `SQLITE_LOCKED` errors rather than the `SQLITE_BUSY` retries it is meant to avoid. The git history already shows SQLITE_BUSY problems (`Serialize SQLite writers...`). Verify whether dropping shared cache removes the need for the write serialization workaround.
- `PRAGMA busy_timeout` and `foreign_keys` are set by `SqliteConnectionPragmasInterceptor` on every open, yet `Program.cs:330-332` also runs `journal_mode`, `busy_timeout`, `synchronous` once on a single connection. `journal_mode=WAL` is persistent so that one is fine; the other two are per-connection and the startup statements are redundant (and `synchronous` is silently NOT applied to other connections). Move them all into the interceptor.
- `dbContext.Database.EnsureCreated()` is the synchronous overload in an async startup path; use `EnsureCreatedAsync()`.
- Scoped `AppDbContext` shared across a whole Blazor circuit is a known hazard (documented in `AGENTS.md`). The mitigation relies on convention; where background work can run concurrently on the same scope, prefer creating contexts from `IDbContextFactory` per operation.

## 8. Low - `async void` and blocking calls in Desktop

Files (`GrayMoon.Desktop/src/GrayMoon.Desktop`): `App.xaml.cs:35, 282, 394`, `MainWindow.xaml.cs:88, 286, 310, 629, 667, 676`, `UpdateCheckDialog.xaml.cs:43`, `UpdateAvailableDialog.xaml.cs:61`

- Event handlers are legitimately `async void`, but `OnStartup`, `OnExit`, `OnSourceInitialized` and `WebMessageReceived` run important logic (process launch, shutdown, bridge dispatch). An unhandled exception in any of them crashes the process via the dispatcher rather than being logged. Confirm each has a top-level try/catch that logs and shows a recoverable error; `CoreWebView2_WebMessageReceived` (the JS-to-native bridge) especially.
- `App.xaml.cs:394` uses `.GetAwaiter().GetResult()` in the elevated installer helper. Acceptable in a short-lived helper, but it blocks the calling thread and will deadlock if ever called from the UI thread; make the helper entry `async Task Main`-style.
- `HostPrerequisiteInstaller.cs:500-523` wraps blocking `ReadToEnd()` calls in `Task.Run` and then reads `.Result`. After `WaitForExit` this is safe in practice, but `await process.StandardOutput.ReadToEndAsync(ct)` is simpler and cancellable. The App's `GitHubPullRequestMergeService.cs:161-164` reads `.Result` on four tasks; verify they are awaited via `Task.WhenAll` first, otherwise exceptions surface wrapped in `AggregateException`.

## 9. Low - Hook listener robustness

File: `HookListenerHostedService.cs:36-50, 125-130`

- `_ = HandleRequestAsync(context, ct)` is fire-and-forget; faults are caught inside, but there is no concurrency cap, so a flood of requests creates unbounded in-flight handlers.
- `DisposeAsync` awaits `_listenTask` after `Cancel()` but `GetContextAsync()` only observes the token through `.WaitAsync(ct)`, so the underlying accept stays pending until `_listener.Close()` runs afterwards (the order should be Cancel, Stop/Close, then await).
- `HttpListener` with a `127.0.0.1` prefix fails with `HttpListenerException` if the port is taken; `StartAsync` lets that propagate and takes the whole Worker host down. Catch it and log an actionable message, or retry on another port.

## 10. Low - Smaller items

- `WebMessageBridgeService.cs:177, 220, 228` builds `explorer.exe` arguments as `$"\"{path}\""` strings with `UseShellExecute = true`. Windows paths cannot contain `"`, so this is not exploitable today, but `ArgumentList` (as already used for the "Open in" tools in the same file) is the safer, consistent choice.
- Empty `catch` blocks and `Console.Write*` usage are limited in the App and Desktop (the broader scan hits were all in unrelated sibling projects); no action needed there. Worth a lint rule (`CA1031`/`S108`) to keep it that way.
- Log location: the App writes to `CommonApplicationData\GrayMoon\Logs` (all-users, `ProgramData`), while Desktop docs say data lives under `%LocalAppData%\GrayMoon\`. Verify the Desktop override (`GRAYMOON_Desktop__LogDirectory`) is always applied; otherwise logs (which include repo paths and URLs, e.g. the `InstallUrl` line in `SelfUpdateCommand`) land in a location readable by other local users.
- `CLAUDE.md` references `Program.cs ~line 95-96` for DbContext registration; it is now at lines 106-108. Prefer symbol references over line numbers in docs.
- Code-generated/vendored output (`GrayMoon.Desktop/artifacts/bundle/...`) is present in the working tree and gets indexed by tooling; make sure it is git-ignored and excluded from analyzers and CodeGraph.

## What is done well

- Token handling: AES-256-GCM, per-install key, DPAPI on Windows, legacy key kept decrypt-only with re-encryption; tokens passed to git via `http.extraHeader` and never written to disk.
- Worker secret plus Origin rejection on worker-only endpoints; thorough tests (`WorkerSecretTests`).
- Process launching centralized (`CommandLineService`, `RepositoryAccessCommandLineService`) with non-interactive git environment, and Desktop launches tools via `ArgumentList` with comments explaining why.
- Path validation (`GitRepositoryPathValidator`) for staging/commit, resilience pipelines (Polly) around git and GitHub calls, ETag and rate-limit tracking.
- Extensive test projects for every layer, `TreatWarningsAsErrors` in Desktop, no raw string-concatenated SQL (raw SQL is confined to migrations and PRAGMAs).

## Suggested order of work

1. Fix #1 and #2 together (Host allowlist, fixed install URL, Worker-side URL validation) - this closes the only high-impact chain found.
2. Add a secret and Origin rejection to the hook listener (#3) and default `RequireWorkerSecret` on for new installs (#4).
3. Move SQLite PRAGMAs into the interceptor and evaluate dropping `Cache=Shared` (#7).
4. Break up `WorkspaceFeatureOperations` and move DI registrations into per-feature extension methods (#6).
5. Add try/catch with logging to the Desktop `async void` entry points (#8).

---

## Appendix - Findings ordered by risk of breaking functionality when fixed

Lowest risk first, so the early items can be done safely and the later ones get dedicated testing. "Risk" means the chance that applying the fix changes behavior users or installed components rely on.

| Order | Finding | Fix risk | Why |
|---|---|---|---|
| 1 | #10 Smaller items (ArgumentList for explorer.exe, docs line refs, gitignore for bundle output) | Very low | Cosmetic or equivalent behavior; covered by existing `WebMessageBridgeTests` |
| 2 | #9 Hook listener robustness (dispose order, port-in-use handling, concurrency cap) | Low | Internal to the Worker; only changes failure and shutdown paths |
| 3 | #8 Desktop `async void` try/catch and logging | Low | Adds error handling only; avoid changing the startup sequence |
| 4 | #5 Quoting in `SelfUpdateCommand` | Low | Must still launch the same install flow; test on a real Windows Worker |
| 5 | #7a Move PRAGMAs into the interceptor, `EnsureCreatedAsync` | Low-Medium | Same settings, different place; run the SQLite concurrency tests |
| 6 | #3 Hook listener secret / Origin / size cap | Medium | Hook scripts already written into user repos send no secret. Accept requests without the header for one release (warn), or hooks silently stop syncing |
| 7 | #4 Default `RequireWorkerSecret` on for new installs | Medium | Only for fresh installs; an old Worker without the secret would be locked out until reinstalled |
| 8 | #2 Host allowlist, exact Origin match, drop loopback-any-port | Medium (desktop mode) / Medium-High (Docker mode) | Desktop mode is always loopback with the App started by Desktop, so a strict fixed allowlist is low risk there (still test the WebView2 origin). Docker mode is browser-only and can be reached by arbitrary hostnames, ports and reverse proxies, so it needs a configurable allowlist and testing behind a proxy |
| 9 | #1 Self-update URL validation | Medium-High | In Docker mode the Worker must accept the container host as the App address, so a loopback-only Worker check would break it (allow the host the hub connected to). `SelfUpdate` payload must not change (old Workers must keep updating). Validate on the App side first; add Worker-side checks only for new Workers, and test the Desktop `UpgradeWorker` flow |
| 10 | #7b Drop `Cache=Shared` | Medium-High | Can change locking behavior and re-expose `SQLITE_BUSY`; the write-serialization workaround may still be needed. Load-test before shipping |
| 11 | #7c Adopt EF Core migrations | High | Touches every existing user database; needs a baseline and upgrade tests from old schema versions. Never remove the legacy `Migrate*Async` methods |
| 12 | #6 Split god classes, restructure DI | High | Large refactor over the most-used code (Create/Remove Feature, push, page state); the DI move is mechanical, the class splits are not. Do incrementally behind the existing tests |

Security-priority note: #1 and #2 are the highest-impact findings but sit in the medium-high fix-risk band, so ship them carefully (App-side change first, compatibility paths kept) rather than rushing them.

## Deployment model (clarification applied to this review)

- Docker = GrayMoon.App as a browser-only web app. GrayMoon.Desktop never connects to a Docker container.
- Desktop = Desktop always starts and owns its own App child process on loopback, with the App running alongside it.
- Effect on findings: #2 is easier to fix in desktop mode (fixed loopback allowlist) and only Docker mode needs configurable hosts; #1's `DesktopNotificationHub.UpgradeWorker` path exists only in desktop mode (loopback host), while the Worker-page "Update" path (`NavigationManager.BaseUri`) is the one reachable in Docker mode and is the more exposed one, since the Docker App is network-reachable. The "Docker or reverse-proxy" and "Desktop's WebView2" concerns in the appendix apply to separate deployments, not one combined setup.

## Status of low-risk fixes (applied 2026-10-15)

- #5 `SelfUpdateCommand.BuildLaunchArguments` now rejects non-http(s) URLs and URLs containing quote or shell-special characters (new theory test added).
- #9 `HookListenerHostedService`: actionable error when the port cannot be bound (still fails startup), in-flight cap of 64 requests (503 above it), listener closed before awaiting the accept loop on dispose.
- #8 Desktop: added catch-and-log to the update-check dialog load, tray top-bar toggle, exit (placement save moved inside the try), and first-run About. Other `async void` handlers were already guarded, so the finding was narrower than first written.
- #10 Doc line reference replaced with a symbol reference. Not changed: the `explorer.exe` launches (switching to `ArgumentList` risks changing how `/select,` is parsed for no real gain, since Windows paths cannot contain quotes) and the artifacts ignore (`artifacts/` is already git-ignored).
- Not started: #7a, #3 and everything after it in the appendix.
