"""MCP bridge between Antigravity and the local DEX++ Helper Server.

Run this file as a stdio MCP server. It intentionally uses only Python's
standard library and never handles an OpenAI/Google API key.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


SERVER_NAME = "dex-helper"
SERVER_VERSION = "1.0.0"
PROTOCOL_VERSION = "2024-11-05"
DEFAULT_HELPER_URL = "http://127.0.0.1:8080"
MAX_INPUT_BYTES = 2 * 1024 * 1024


def helper_base_url() -> str:
    url = os.environ.get("DEX_HELPER_URL", DEFAULT_HELPER_URL).rstrip("/")
    parsed = urlparse(url)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
        raise ValueError("DEX_HELPER_URL must point to a local HTTP address.")
    return url


def helper_request(path: str, body: str | None = None) -> str:
    data = None if body is None else body.encode("utf-8")
    if data is not None and len(data) > MAX_INPUT_BYTES:
        raise ValueError("Input is larger than the 2 MB MCP bridge limit.")

    request = Request(
        helper_base_url() + path,
        data=data,
        method="POST" if data is not None else "GET",
        headers={
            "Content-Type": "text/plain; charset=utf-8",
            "Accept": "application/json, text/plain",
            "X-MCP-Client": "Antigravity",
        },
    )
    try:
        with urlopen(request, timeout=20) as response:
            return response.read().decode("utf-8", errors="replace")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"DEX++ Helper returned HTTP {exc.code}: {detail}") from exc
    except URLError as exc:
        raise RuntimeError(
            "Cannot connect to DEX++ Helper at "
            f"{helper_base_url()}. Start HelperServer/DEX_Helper.exe first."
        ) from exc


def display_result(raw: str) -> str:
    try:
        return json.dumps(json.loads(raw), ensure_ascii=False, indent=2)
    except json.JSONDecodeError:
        return raw


TOOLS: list[dict[str, Any]] = [
    {
        "name": "dex_helper_status",
        "description": "Check whether the local DEX++ Helper Server is running.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "dex_worker_status",
        "description": "Show availability and roles of the DEX++ language workers.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "dex_toolchain_status",
        "description": "Show the Python, Rust, compiler, and setup toolchain status.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "dex_index_status",
        "description": "Show the current DEX++ in-memory source index statistics.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "dex_analyze_source",
        "description": "Analyze Luau source with the local DEX++ Helper Server.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {
                    "type": "string",
                    "description": "Luau source code to analyze.",
                },
                "mode": {
                    "type": "string",
                    "enum": ["auto", "fast", "deep", "builtin"],
                    "default": "auto",
                    "description": "Analyzer routing mode.",
                },
            },
            "required": ["source"],
            "additionalProperties": False,
        },
    },
    {
        "name": "dex_analyze_remotes",
        "description": "Analyze RemoteSpy log text and summarize remote contracts.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "logs": {
                    "type": "string",
                    "description": "RemoteSpy log text to analyze.",
                }
            },
            "required": ["logs"],
            "additionalProperties": False,
        },
    },
]


def call_tool(name: str, arguments: dict[str, Any]) -> str:
    static_routes = {
        "dex_helper_status": "/status",
        "dex_worker_status": "/worker-status",
        "dex_toolchain_status": "/toolchain-status",
        "dex_index_status": "/index-status",
    }
    if name in static_routes:
        return display_result(helper_request(static_routes[name]))

    if name == "dex_analyze_source":
        source = arguments.get("source")
        mode = arguments.get("mode", "auto")
        if not isinstance(source, str) or not source.strip():
            raise ValueError("'source' must be a non-empty string.")
        routes = {
            "auto": "/analyze-source-auto",
            "fast": "/analyze-source-fast",
            "deep": "/analyze-source-deep",
            "builtin": "/analyze-source",
        }
        if mode not in routes:
            raise ValueError("'mode' must be auto, fast, deep, or builtin.")
        return display_result(helper_request(routes[mode], source))

    if name == "dex_analyze_remotes":
        logs = arguments.get("logs")
        if not isinstance(logs, str) or not logs.strip():
            raise ValueError("'logs' must be a non-empty string.")
        return display_result(helper_request("/analyze-remotes", logs))

    raise ValueError(f"Unknown tool: {name}")


def success(request_id: Any, result: Any) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def failure(request_id: Any, code: int, message: str) -> dict[str, Any]:
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {"code": code, "message": message},
    }


def handle_message(message: dict[str, Any]) -> dict[str, Any] | None:
    method = message.get("method")
    request_id = message.get("id")

    if method == "initialize":
        requested = message.get("params", {}).get("protocolVersion")
        return success(
            request_id,
            {
                "protocolVersion": requested or PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
            },
        )
    if method == "notifications/initialized":
        return None
    if method == "ping":
        return success(request_id, {})
    if method == "tools/list":
        return success(request_id, {"tools": TOOLS})
    if method == "tools/call":
        params = message.get("params", {})
        name = params.get("name", "")
        arguments = params.get("arguments") or {}
        try:
            text = call_tool(name, arguments)
            return success(
                request_id,
                {"content": [{"type": "text", "text": text}], "isError": False},
            )
        except (ValueError, RuntimeError) as exc:
            return success(
                request_id,
                {"content": [{"type": "text", "text": str(exc)}], "isError": True},
            )
    if request_id is None:
        return None
    return failure(request_id, -32601, f"Method not found: {method}")


def read_message() -> tuple[dict[str, Any] | None, str]:
    first_line = sys.stdin.buffer.readline()
    if not first_line:
        return None, "newline"

    if first_line.lower().startswith(b"content-length:"):
        length = int(first_line.split(b":", 1)[1].strip())
        while True:
            header = sys.stdin.buffer.readline()
            if header in {b"\r\n", b"\n", b""}:
                break
        payload = sys.stdin.buffer.read(length)
        return json.loads(payload.decode("utf-8")), "headers"

    return json.loads(first_line.decode("utf-8")), "newline"


def write_message(message: dict[str, Any], framing: str) -> None:
    payload = json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if framing == "headers":
        sys.stdout.buffer.write(f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii"))
        sys.stdout.buffer.write(payload)
    else:
        sys.stdout.buffer.write(payload + b"\n")
    sys.stdout.buffer.flush()


def main() -> int:
    while True:
        try:
            message, framing = read_message()
            if message is None:
                return 0
            response = handle_message(message)
            if response is not None:
                write_message(response, framing)
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as exc:
            print(f"DEX++ MCP protocol error: {exc}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
