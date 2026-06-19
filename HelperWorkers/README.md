# DEX++ Helper Workers

The local helper is intentionally polyglot:

- `C++` owns the HTTP server, cache, index, dashboard, routing, and decompiler proxy.
- `Python` owns flexible deep source summaries and beginner-facing JSON hints.
- `Rust` owns optional high-throughput lexical analysis when compiled as a sidecar worker.

## Python deep analyzer

Run directly:

```powershell
Get-Content some-script.luau | python .\HelperWorkers\python\deep_source_analyzer.py
```

The C++ helper calls this worker from `POST /analyze-source-deep` and for smaller `POST /analyze-source-auto` payloads when Python is available.

## Rust source analyzer

Build:

```powershell
cd .\HelperWorkers\rust_source_analyzer
cargo build --release
```

The Rust worker handles `POST /analyze-source-fast` and source payloads of at least 256 KB sent to `POST /analyze-source-auto`. If its binary is unavailable, the router falls back without failing the request.

Build and validate all workers from the repository root:

```powershell
.\HelperWorkers\build.ps1
```
