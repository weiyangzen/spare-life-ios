#!/usr/bin/env node

import http from "node:http";

const port = Number.parseInt(process.env.XIANXIA_PROXY_PORT ?? "17881", 10);
const upstreamOrigin = process.env.XIANXIA_PROXY_UPSTREAM ?? "http://100.82.60.69:17880";
const upstreamBase = new URL(upstreamOrigin);

let mode = (process.env.XIANXIA_PROXY_MODE ?? "online").trim().toLowerCase() === "offline"
  ? "offline"
  : "online";

function writeJSON(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "content-length": Buffer.byteLength(body),
  });
  res.end(body);
}

function controlResponse(res) {
  writeJSON(res, 200, { ok: true, mode, upstream: upstreamBase.origin });
}

async function proxyRequest(req, res, requestURL) {
  const upstreamURL = new URL(requestURL.pathname + requestURL.search, upstreamBase);
  const upstreamResponse = await fetch(upstreamURL, {
    method: req.method,
    headers: {
      accept: req.headers.accept ?? "application/json",
      "content-type": req.headers["content-type"] ?? "application/json",
    },
  });

  const body = Buffer.from(await upstreamResponse.arrayBuffer());
  const headers = {
    "content-type": upstreamResponse.headers.get("content-type") ?? "application/json; charset=utf-8",
    "cache-control": upstreamResponse.headers.get("cache-control") ?? "no-store",
    "content-length": body.byteLength,
  };
  res.writeHead(upstreamResponse.status, headers);
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  const requestURL = new URL(req.url ?? "/", `http://127.0.0.1:${port}`);

  if (requestURL.pathname === "/__control") {
    const requestedMode = requestURL.searchParams.get("mode");
    if (requestedMode === "online" || requestedMode === "offline") {
      mode = requestedMode;
      console.log(`[xianxia-proxy] mode=${mode}`);
    }
    controlResponse(res);
    return;
  }

  if (mode === "offline") {
    writeJSON(res, 503, {
      ok: false,
      error: "Proxy is intentionally offline for Xianxia cache fallback validation.",
    });
    return;
  }

  try {
    await proxyRequest(req, res, requestURL);
  } catch (error) {
    writeJSON(res, 502, {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`[xianxia-proxy] listening on http://127.0.0.1:${port}`);
  console.log(`[xianxia-proxy] upstream=${upstreamBase.origin}`);
  console.log(`[xianxia-proxy] mode=${mode}`);
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}
