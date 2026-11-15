"""OpenAI-compatible front door for kronii's LLM server(s).

With only ARC_URL set, every request goes to llama.cpp on the Arc. With BONSAI_URL
set as well, routing is, in order:
  1. A request naming the second model (BONSAI_MODEL) goes to that backend.
  2. Anything else goes to llama.cpp on the Arc, unless the Arc is already
     serving a request (it runs one slot) and the prompt is short enough that
     a cold prefill there is cheaper than queueing. Then it overflows. Long
     prompts never overflow: their KV cache lives on the Arc, and re-prefilling
     30k+ tokens elsewhere costs more than the wait.
  3. Non-inference paths (/health, /slots, /props, ...) go to the Arc.

Every response carries X-LLM-Backend so a client can see where it ran.
"""

import json
import logging
import os

from aiohttp import ClientSession, ClientTimeout, TCPConnector, web

LISTEN = os.environ.get("LISTEN", "0.0.0.0:8080")
ARC_URL = os.environ.get("ARC_URL", "http://127.0.0.1:8081")
# Empty: no second backend, everything goes to the Arc.
BONSAI_URL = os.environ.get("BONSAI_URL", "")
BONSAI_MODEL = os.environ.get("BONSAI_MODEL", "ternary-bonsai-2-27b")
# Estimated prompt tokens above which a request stays queued on the Arc.
OVERFLOW_MAX_TOKENS = int(os.environ.get("OVERFLOW_MAX_TOKENS", "16000"))
# bonsaid batches concurrent streams; past this many in flight, stop overflowing.
BONSAI_MAX_INFLIGHT = int(os.environ.get("BONSAI_MAX_INFLIGHT", "4"))

INFERENCE_PATHS = {
    "/v1/chat/completions",
    "/chat/completions",
    "/v1/completions",
    "/completions",
    "/completion",
}
HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade", "content-length", "host",
}

log = logging.getLogger("llm-router")
inflight = {"arc": 0, "bonsai": 0}
URLS = {"arc": ARC_URL, "bonsai": BONSAI_URL}
BACKENDS = ("arc", "bonsai") if BONSAI_URL else ("arc",)


def estimate_tokens(body):
    """Rough prompt size: ~3.5 characters per token, tool schemas included."""
    parts = [body.get("messages"), body.get("prompt"), body.get("tools")]
    chars = sum(len(json.dumps(p)) for p in parts if p is not None)
    return int(chars / 3.5)


def choose(body):
    """Return (backend, reason) for one inference request."""
    if not BONSAI_URL:
        return "arc", "model"
    if body.get("model") == BONSAI_MODEL:
        return "bonsai", "model"
    if inflight["arc"] == 0:
        return "arc", "model"
    est = estimate_tokens(body)
    if est > OVERFLOW_MAX_TOKENS:
        return "arc", f"queued (arc busy, ~{est} tok too long to overflow)"
    if inflight["bonsai"] >= BONSAI_MAX_INFLIGHT:
        return "arc", "queued (arc busy, bonsai full)"
    return "bonsai", f"overflow (arc busy, ~{est} tok)"


async def proxy(request, backend, body_bytes):
    session = request.app["session"]
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_BY_HOP}
    url = URLS[backend] + request.rel_url.path_qs
    inflight[backend] += 1
    try:
        async with session.request(request.method, url, headers=headers, data=body_bytes) as up:
            resp = web.StreamResponse(status=up.status)
            for k, v in up.headers.items():
                if k.lower() not in HOP_BY_HOP:
                    resp.headers[k] = v
            resp.headers["X-LLM-Backend"] = backend
            await resp.prepare(request)
            try:
                async for chunk in up.content.iter_any():
                    await resp.write(chunk)
                await resp.write_eof()
            except ConnectionResetError:
                # The client went away. Leaving this block closes the upstream
                # connection, which makes the server cancel the generation.
                log.info("%s: client disconnected, upstream request dropped", backend)
            return resp
    finally:
        inflight[backend] -= 1


async def handle(request):
    body_bytes = await request.read()
    if request.method == "POST" and request.path in INFERENCE_PATHS:
        try:
            body = json.loads(body_bytes)
        except ValueError:
            return await proxy(request, "arc", body_bytes)
        backend, reason = choose(body)
        if backend == "bonsai" and body.get("model") != BONSAI_MODEL:
            body["model"] = BONSAI_MODEL
            body_bytes = json.dumps(body).encode()
        log.info("%s %s model=%s -> %s: %s", request.method, request.path,
                 body.get("model"), backend, reason)
        return await proxy(request, backend, body_bytes)
    return await proxy(request, "arc", body_bytes)


async def models(request):
    """Both backends' models in one list, so clients can discover either."""
    session = request.app["session"]
    data = []
    for backend in BACKENDS:
        try:
            async with session.get(URLS[backend] + "/v1/models") as r:
                data += (await r.json()).get("data", [])
        except Exception as e:  # one GPU down must not hide the other
            log.warning("models: %s unreachable: %s", backend, e)
    return web.json_response({"object": "list", "data": data})


async def status(request):
    return web.json_response({"inflight": inflight, "overflow_max_tokens": OVERFLOW_MAX_TOKENS})


async def on_startup(app):
    app["session"] = ClientSession(
        timeout=ClientTimeout(total=None, sock_connect=10),
        connector=TCPConnector(limit=0),
        auto_decompress=False,
    )


async def on_cleanup(app):
    await app["session"].close()


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    app = web.Application(client_max_size=256 * 1024 * 1024)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    app.router.add_get("/v1/models", models)
    app.router.add_get("/router/status", status)
    app.router.add_route("*", "/{tail:.*}", handle)
    host, port = LISTEN.rsplit(":", 1)
    web.run_app(app, host=host, port=int(port), access_log=None)


if __name__ == "__main__":
    main()
