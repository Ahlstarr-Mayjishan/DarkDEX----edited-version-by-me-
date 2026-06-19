# DarkDEX++ Local Helper

DarkDEX++ can run independently using the `DEX++_compiled.luau` file, or fetch the script via the C++ Local Helper Server at `http://localhost:8080/script`.

## What does the Helper Server do?

`HelperServer/DEX_Helper.exe` currently supports:

- `GET /status`: Checks if the server is running.
- `GET /script`: Returns the content of `DEX++_compiled.luau` to be loaded locally via `loadstring`.
- `POST /normalize-source`: Runs a lightweight source normalization pass, currently focused on readable variable renaming.
- `POST /deobfuscate`: Compatibility alias for `/normalize-source`.
- `POST /analyze-source`: Quickly analyzes raw/cached source code and returns a JSON object containing the line count, function count, remote calls, risk signals, and prominent identifiers.
- `POST /analyze-source-fast`: Routes source to the compiled Rust lexical analyzer, then falls back to C++.
- `POST /analyze-source-deep`: Routes source through Python, then Rust, then C++.
- `POST /analyze-source-auto`: Selects Python for source below 256 KB and Rust for larger payloads, with automatic fallback.
- `POST /index-source`: Stores a cached source file in the helper's in-memory analysis index.
- `POST /search-source`: Searches the helper's in-memory source index and returns ranked JSON results.
- `GET /worker-status`: Shows which language workers are available and what role each worker owns.
- `POST /decompile`: Proxies bytecode to Potassium's local `Decompiler.exe` server when available.
- `GET /index-status`: Returns the current in-memory index size.
- `GET /tool-state`: Returns the latest live DEX tool state reported from Roblox.
- `POST /tool-state`: Accepts a small JSON snapshot of live DEX tool state for the external dashboard.
- `POST /index-save`: Persists the helper source index to `dex_helper_index.dat`.
- `POST /index-load`: Reloads the helper source index from `dex_helper_index.dat`.
- `POST /index-clear`: Clears the helper's in-memory source index.
- `POST /log`: Records logs from the Property Tracker into `dex_server_logs.txt`.

The helper accepts multiple local clients concurrently, with a small worker cap to keep indexing/search/status/log requests responsive without letting request spikes create unlimited threads.

In DEX settings, `Use Local Helper` is off by default. Turn it on only when you want local source indexing/search. `Log Property Changes To Helper` is also off by default because high-frequency property changes can create a lot of local HTTP/log traffic.

Update checks are pinned by `Settings.AutoUpdateRef` by default (`v3.1`). Branch refs such as `main` or `master` are ignored unless `Settings.AutoUpdateAllowBranch` is explicitly enabled, so auto-update does not silently track a moving branch.

Important: the helper can proxy bytecode to Potassium's external `Decompiler.exe`, but Roblox still has to enumerate scripts and extract bytecode through the executor first. That bytecode extraction step cannot be moved outside the client from Luau. The helper reduces the source lifting/search/analysis work, while cache-first indexing reduces repeated bytecode pulls.

## Quick Start

1. Open `HelperServer/DEX_Helper.exe`.
2. Open `http://localhost:8080/` for the external Helper Dashboard.
3. In your executor, run:

```lua
loadstring(game:HttpGet("http://localhost:8080/script"))()
```

If your executor does not allow `game:HttpGet` requests to localhost, copy the contents of `DEX++_compiled.luau` directly into the executor.

## Dashboard guide

The helper dashboard now shows the important startup states directly:

- `Script delivery`: shows whether `/script` is ready and how large the current compiled script is.
- `Copy loadstring`: copies the Roblox loadstring without opening the raw script page.
- `Current Roblox session`: shows the connected game name, `PlaceId`, `GameId`, `JobId`, and executor after DEX reports in.
- `Code Search` progress: shows which game is being indexed, progress percent, cached scripts, new decompile count, skipped scripts, failures, and helper-indexed source count.
- `First run guide`: a beginner flow for starting the helper, running DEX, indexing, then searching outside Roblox.

If the dashboard says `Roblox waiting`, run the loadstring in Roblox. If it says `script missing`, rebuild with `python .\build.py`.

## Rebuilding

Build the Luau bundle:

```powershell
python .\build.py
```

Build the Helper C++ executable:

```powershell
cd .\HelperServer
.\compile.bat
```

Build and validate the Python/Rust workers:

```powershell
.\HelperWorkers\build.ps1
```

If `DEX_Helper.exe` is currently running, close the helper console window before compiling, as Windows may lock the executable file.

## What should I do to decompile faster?

The most effective approach currently is using the following pipeline:

- Enable caching under `Code Search > Index Scripts`.
- Only decompile scripts that have not been cached yet.
- Use `ClientIndex` so that tools avoid scanning the instance tree repeatedly.
- Prioritize decompiling the script that is currently open/clicked first.
- Normalize source, run `analyze-source`, and push cached source into the helper index after the source code is retrieved.
- When using Potassium's external `Decompiler.exe`, enable `Use Local Helper`; DarkDEX++ will prefer helper decompile before native decompile and uses a longer helper decompile timeout.

## Local Analysis Engine

When `DEX_Helper.exe` is running and `Settings > Decompiler > Use Local Helper` is enabled, `Code Search > Index Scripts` delegates extra work to the helper:

- decompiled/cached source is sent to `/index-source`;
- the helper keeps a fast in-memory index and persists it to `dex_helper_index.dat` once after an index run, instead of rewriting the file for every script;
- `Code Search` and shared `ClientIndex.SearchCached` prefer `/search-source`;
- helper search results include match type, score, confidence, freshness, source snippets, and compact source analysis;
- `Client Intelligence > Index` shows helper index health, local cache coverage, and live client-surface coverage;
- if the helper is offline or the helper index is empty, DarkDEX++ falls back to the old Luau cache scan.

The helper loads `dex_helper_index.dat` on startup. Running `Index Scripts` refreshes entries and saves the updated helper index automatically.

For smoother Roblox sessions, use the browser dashboard at `http://localhost:8080/` for source search, index health, live DEX tool state, and paste-in analysis. Keep `Log Property Changes To Helper` disabled unless you are actively debugging property changes.

The dashboard also includes a passive `Remote Contract Analyzer`: copy logs from Remote Spy, paste them into the dashboard, and it will summarize remote paths, call direction, methods, sample arguments, frequency, and risk wording. It does not fire or fuzz remotes.

## Polyglot worker roles

The helper uses multiple languages by responsibility instead of by decoration:

- C++: local HTTP server, route handling, cache/index, dashboard delivery, search, and Potassium decompiler proxy.
- Python: deeper source summaries, risk hints, beginner-friendly recommendations, and JSON shaping via `HelperWorkers/python/deep_source_analyzer.py`.
- Rust: high-throughput lexical analysis for large source payloads via `HelperWorkers/rust_source_analyzer`.

Routing is explicit: `/analyze-source-fast` prefers Rust, `/analyze-source-deep` prefers Python, and `/analyze-source-auto` selects by payload size. C++ remains the final in-process fallback, so analysis still works when Python or Rust is missing.

Use `http://localhost:8080/worker-status` to see which workers are detected.

## Inspector Hub

`Inspector Hub` centralizes DEX/inspector signals into one action view:

- snapshot of live client surface, cache coverage, service size, scripts, remotes, parts, and UI objects;
- hot/risky remotes ranked by runtime call activity, class, and suspicious names;
- quick risk queue from remote names and cached script-source signals;
- copyable inspector brief for AI handoff or debugging notes.

`Client Intelligence` includes a `Hub` shortcut that opens the Inspector Hub snapshot.

## Task Router

`Task Router` assigns work to the best layer for the job:

- C++ helper for indexing, search, analysis, cache, and export;
- Luau UI for selection, trees, buttons, and immediate interactions;
- runtime monitor roles for live client data and timelines;
- AI context packaging when you want a clean prompt or handoff.

## Plugin Experiments

The build scripts now bundle every `.lua`/`.luau` file under `Plugins/` into `dex/plugins/` before DEX++ starts. This means experimental tools can live as plugins instead of being added directly to the core module list.

Current bundled plugins:

- `HttpSpy.lua`
- `LoadedModuleSpy.lua`
- `MetatableHookManager.lua`
- `RemoteSpy.lua`
- `TableEditor.lua`
- `TaskRouterLab.lua`

## Copy to AI + helper analysis

In the Explorer, the `Copy to AI` option will automatically copy the object summary to your clipboard. If the object is a script that is already in the decompile cache and the local helper is running, the prompt will include the `Cached source analysis` so that the AI can understand it faster without reading the entire source code.

The copied analysis is compacted into line/function/require/remote/risk counts plus prominent identifiers, instead of pasting raw helper JSON into the prompt.

The helper can speed up the backend/source lifting side when `Decompiler.exe` is reachable, but it cannot remove the client-side cost of finding script instances, reading metadata, extracting bytecode, UI updates, and HTTP transfer. Cache hits are therefore the biggest win.

# Support Executor

- Potassium
