"""HTTP gate in front of the on-demand llama-server.

Any TCP connection to the old socket-activated proxy loaded the model, and the
Hermes gateways probe their endpoint at startup (/v1/props, /v1/models,
/api/tags, ...), so the 14 GiB model was resident from login. This answers
those metadata probes itself and only forwards real work (anything that is not
a GET/HEAD, i.e. completions) to the backend socket that wakes llama-server.

argv: listen_port backend_port model_alias n_ctx
"""

import http.client
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LISTEN_PORT, BACKEND_PORT, ALIAS, N_CTX = (
    int(sys.argv[1]),
    int(sys.argv[2]),
    sys.argv[3],
    int(sys.argv[4]),
)

# Shaped like llama-server's own replies, trimmed to what clients read.
PROPS = {
    "default_generation_settings": {"n_ctx": N_CTX, "model": ALIAS},
    "model_alias": ALIAS,
    "total_slots": 1,
}
MODELS = {
    "object": "list",
    "models": [{"name": ALIAS, "model": ALIAS}],
    "data": [
        {
            "id": ALIAS,
            "object": "model",
            "created": 0,
            "owned_by": "llamacpp",
            "meta": {"n_ctx": N_CTX},
        }
    ],
}
STATIC = {
    "/health": {"status": "ok"},
    "/v1/health": {"status": "ok"},
    "/props": PROPS,
    "/v1/props": PROPS,
    "/models": MODELS,
    "/v1/models": MODELS,
}
HOP_BY_HOP = {"connection", "keep-alive", "transfer-encoding", "content-length"}


class Gate(BaseHTTPRequestHandler):
    # HTTP/1.0: forwarded bodies are close-delimited, so streamed (SSE)
    # completions pass through without re-chunking.
    protocol_version = "HTTP/1.0"

    def log_message(self, *args):
        pass

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _static(self):
        obj = STATIC.get(self.path.split("?", 1)[0].rstrip("/") or "/")
        if obj is None:
            self._json(404, {"error": {"code": 404, "message": "File Not Found"}})
        else:
            self._json(200, obj)

    do_GET = do_HEAD = _static

    def _forward(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP_BY_HOP}
        # The first request waits for the model to load (the backend only
        # accepts once /health is up), so no read timeout.
        conn = http.client.HTTPConnection("127.0.0.1", BACKEND_PORT, timeout=None)
        try:
            conn.request(self.command, self.path, body=body, headers=headers)
            resp = conn.getresponse()
        except OSError as e:
            # Backend socket stopped (e.g. gamemode freed the GPU).
            self._json(503, {"error": {"code": 503, "message": f"llama-cpp unavailable: {e}"}})
            return
        self.send_response(resp.status, resp.reason)
        for k, v in resp.getheaders():
            if k.lower() not in HOP_BY_HOP:
                self.send_header(k, v)
        self.end_headers()
        while chunk := resp.read1(65536):
            self.wfile.write(chunk)
            self.wfile.flush()
        conn.close()

    do_POST = do_PUT = do_PATCH = do_DELETE = _forward


ThreadingHTTPServer(("127.0.0.1", LISTEN_PORT), Gate).serve_forever()
