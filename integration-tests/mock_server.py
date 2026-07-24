#!/usr/bin/env python3
"""Loopback-only recording backend for hermetic native SDK runtime checks."""

import argparse
import json
import signal
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


MAX_REQUEST_BODY_BYTES = 1024 * 1024
SENSITIVE_NAMES = {
    "authorization",
    "cookie",
    "proxy-authorization",
    "set-cookie",
    "x-api-key",
    "api-key",
    "apikey",
    "token",
}


def is_sensitive(name: str) -> bool:
    normalized = name.lower().replace("_", "-")
    return normalized in SENSITIVE_NAMES or normalized.endswith("-token")


def redact_path(value: str) -> str:
    parsed = urlsplit(value)
    query = [
        (key, "[REDACTED]" if is_sensitive(key) else item)
        for key, item in parse_qsl(parsed.query, keep_blank_values=True)
    ]
    return urlunsplit(("", "", parsed.path, urlencode(query), parsed.fragment))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port-file", required=True)
    parser.add_argument("--requests-file", required=True)
    parser.add_argument("--tls-cert")
    parser.add_argument("--tls-key")
    parser.add_argument("--tls-port-file")
    args = parser.parse_args()

    tls_arguments = (args.tls_cert, args.tls_key, args.tls_port_file)
    if any(tls_arguments) and not all(tls_arguments):
        parser.error("--tls-cert, --tls-key, and --tls-port-file must be used together")

    requests_path = Path(args.requests_file)
    write_lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        server_version = "AppstackRuntimeRecorder/1"
        sys_version = ""

        def do_GET(self) -> None:
            path = urlsplit(self.path).path
            self.record(None)
            if path.endswith("/config"):
                if path.startswith("/ios/"):
                    match_url = (
                        f"http://127.0.0.1:{http_server.server_port}"
                        "/attribution/match/runtime_validation_app"
                    )
                elif tls_server is not None:
                    match_url = (
                        f"https://127.0.0.1:{tls_server.server_port}"
                        "/attribution/match"
                    )
                else:
                    self.respond(500, {"error": "TLS match endpoint is not configured"})
                    return
                self.respond(
                    200,
                    {
                        "app_id": "runtime_validation_app",
                        "sdk_enabled": True,
                        "match_url": match_url,
                        "use_install_detection_v2": False,
                    },
                )
                return
            if "/attribution/match" in path:
                self.respond(
                    200,
                    {
                        "deeplink_id": "runtime-validation-deeplink",
                        "app_id": "runtime_validation_app",
                        "redirection_url": "https://example.invalid/app",
                        "timestamp": "2026-07-13T00:00:00Z",
                        "method": "GET",
                        "url": "https://example.invalid/deeplink",
                        "query_params": {
                            "runtime_validation": "attributed",
                            "unicode": "café 🚀",
                            "source": "local-recorder",
                        },
                        "path_params": {},
                        "cookies": {},
                        "install_id": "runtime-validation-install",
                        "event_type": "install",
                        "date_day": "2026-07-13",
                    },
                )
                return
            self.respond(404, {"error": "unknown path"})

        def do_POST(self) -> None:
            body = self.read_json_body()
            if body is _BODY_TOO_LARGE:
                return
            self.record(body)
            path = urlsplit(self.path).path
            if path.endswith("/events"):
                self.respond(200, {"status": "success", "message": "ok"})
                return
            if path == "/runtime-result":
                self.respond(200, {"status": "recorded"})
                return
            self.respond(404, {"error": "unknown path"})

        def read_json_body(self):
            raw_length = self.headers.get("Content-Length", "0")
            try:
                length = int(raw_length)
            except ValueError:
                self.respond(400, {"error": "invalid content length"})
                return _BODY_TOO_LARGE
            if length < 0 or length > MAX_REQUEST_BODY_BYTES:
                self.respond(413, {"error": "request body too large"})
                return _BODY_TOO_LARGE
            raw = self.rfile.read(length) if length else b""
            if not raw:
                return None
            try:
                return json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                return {"_invalid_json": True}

        def record(self, body) -> None:
            entry = {
                "method": self.command,
                "path": redact_path(self.path),
                "headers": {
                    key.lower(): "[REDACTED]" if is_sensitive(key) else value
                    for key, value in self.headers.items()
                },
                "body": body,
            }
            with write_lock:
                with requests_path.open("a", encoding="utf-8") as stream:
                    stream.write(json.dumps(entry, ensure_ascii=False) + "\n")
                    stream.flush()

        def respond(self, status: int, value) -> None:
            payload = json.dumps(value, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, _format: str, *_args) -> None:
            return

    http_server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    tls_server = None
    tls_thread = None
    if all(tls_arguments):
        tls_server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        tls_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls_context.load_cert_chain(args.tls_cert, args.tls_key)
        tls_server.socket = tls_context.wrap_socket(tls_server.socket, server_side=True)
        Path(args.tls_port_file).write_text(
            str(tls_server.server_port), encoding="utf-8"
        )
        tls_thread = threading.Thread(target=tls_server.serve_forever, daemon=True)
        tls_thread.start()

    Path(args.port_file).write_text(str(http_server.server_port), encoding="utf-8")

    def stop(_signum, _frame) -> None:
        threading.Thread(target=http_server.shutdown, daemon=True).start()
        if tls_server is not None:
            threading.Thread(target=tls_server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    http_server.serve_forever()
    http_server.server_close()
    if tls_server is not None:
        tls_server.shutdown()
        tls_server.server_close()
    if tls_thread is not None:
        tls_thread.join(timeout=1)


_BODY_TOO_LARGE = object()


if __name__ == "__main__":
    main()
