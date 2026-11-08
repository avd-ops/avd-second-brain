# Personal project, not for production, provided as is; not affiliated with the author's employer, Liquidware or Microsoft.
"""HTTP handler and stdlib server for the v1 deterministic Concierge (docs/v1-review.md section 4).

Endpoints:
  GET  /healthz -> {"ok": true, "schema": "avd-concierge/v1"}
  POST /search  -> {"question": str, "top": int (optional, default 10)} -> {"hits": [...]}
  POST /facts   -> {"ids": [str, ...], "estate": str (optional)}        -> {"schema": "avd-concierge-facts/v1", ...}
"""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .concierge import Concierge, ConciergeError


def handle_request(
    method: str,
    path: str,
    body: Any,
    concierge: Concierge,
) -> tuple[int, dict[str, Any]]:
    """Pure request dispatcher for /healthz, /search and /facts; returns (status_code, json_dict)."""
    if method == "GET" and path == "/healthz":
        return 200, {
            "ok": True,
            "schema": "avd-concierge/v1",
            "factsRootConfigured": concierge.facts_root is not None,
        }
    if method != "POST":
        return 405, {"error": "method not allowed"}
    if not isinstance(body, dict):
        return 400, {"error": "request body must be a JSON object"}

    if path == "/search":
        question = body.get("question")
        top = body.get("top", 10)
        if not isinstance(question, str) or not question.strip():
            return 400, {"error": "question must be a non-empty string"}
        if isinstance(top, bool) or not isinstance(top, int) or top < 1 or top > 50:
            return 400, {"error": "top must be an integer between 1 and 50"}
        return 200, {"hits": concierge.search(question=question, top=top)}

    if path == "/facts":
        ids = body.get("ids")
        estate = body.get("estate")
        if estate is not None and not isinstance(estate, str):
            return 400, {"error": "estate must be a string"}
        try:
            return 200, concierge.facts(ids=ids, estate=estate)
        except ConciergeError as error:
            return 400, {"error": str(error)}

    return 404, {"error": "not found"}


def serve(concierge: Concierge, host: str = "127.0.0.1", port: int = 8081) -> None:
    """Runs the stdlib HTTP server for local or container use."""

    class Handler(BaseHTTPRequestHandler):
        def _send(self, status: int, payload: dict[str, Any]) -> None:
            raw = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self) -> None:  # noqa: N802
            status, payload = handle_request("GET", self.path.split("?", 1)[0], None, concierge)
            self._send(status, payload)

        def do_POST(self) -> None:  # noqa: N802
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length > 0 else b"{}"
            try:
                body = json.loads(raw.decode("utf-8"))
            except ValueError:
                self._send(400, {"error": "invalid JSON"})
                return
            status, payload = handle_request("POST", self.path.split("?", 1)[0], body, concierge)
            self._send(status, payload)

        def log_message(self, fmt: str, *args: Any) -> None:
            return

    with ThreadingHTTPServer((host, port), Handler) as httpd:
        httpd.serve_forever()
