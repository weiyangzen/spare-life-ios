import http from 'node:http';

import { WebSocketServer } from 'ws';

import { formatPublicWsUrl } from './clawdbTopicsDataProvider.mjs';

function jsonResponse(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store'
  });
  res.end(payload);
}

function parseBatchSize(input, fallback) {
  const parsed = Number(input);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  const rounded = Math.floor(parsed);
  if (rounded < 1) {
    return 1;
  }
  if (rounded > 500) {
    return 500;
  }
  return rounded;
}

function parseCursor(input) {
  const parsed = Number(input);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return 0;
  }
  return Math.floor(parsed);
}

function normalizePath(inputPath) {
  if (!inputPath || inputPath === '/') {
    return '/';
  }
  const trimmed = String(inputPath).replace(/^\/+|\/+$/g, '').replace(/\/+/g, '/');
  return trimmed ? `/${trimmed}` : '/';
}

export class ClawdbTopicsGatewayServer {
  constructor(options = {}) {
    this.provider = options.provider;
    this.host = options.host || '0.0.0.0';
    this.port = Number(options.port || 17880);
    this.httpBasePath = normalizePath(options.httpBasePath || '/v1/clawdb-topics');
    this.wsPath = normalizePath(options.wsPath || `${this.httpBasePath}/ws`);
    this.publicBaseUrl = options.publicBaseUrl || '';
    this.logger = options.logger || console;

    this.httpServer = null;
    this.wsServer = null;
    this.clients = new Set();
    this.boundPort = this.port;
    this.keepAliveInterval = null;
    this.onStats = typeof options.onStats === 'function' ? options.onStats : null;
  }

  getLocalBaseUrl() {
    return `http://127.0.0.1:${this.boundPort}`;
  }

  getLocalWsUrl() {
    return `ws://127.0.0.1:${this.boundPort}${this.wsPath}`;
  }

  getPublicWsUrl() {
    return formatPublicWsUrl({
      publicBaseUrl: this.publicBaseUrl,
      wsPath: this.wsPath
    });
  }

  getPublicHttpBase() {
    if (!this.publicBaseUrl) {
      return '';
    }
    try {
      const parsed = new URL(this.publicBaseUrl);
      parsed.pathname = this.httpBasePath;
      parsed.search = '';
      return parsed.toString();
    } catch {
      return '';
    }
  }

  _emitStats() {
    if (!this.onStats) {
      return;
    }
    this.onStats({
      clients: this.clients.size,
      localBaseUrl: this.getLocalBaseUrl(),
      localWsUrl: this.getLocalWsUrl(),
      publicHttpBase: this.getPublicHttpBase(),
      publicWsUrl: this.getPublicWsUrl()
    });
  }

  async _handleHttpRequest(req, res) {
    const requestUrl = new URL(req.url || '/', this.getLocalBaseUrl());
    const pathname = normalizePath(requestUrl.pathname);

    if (pathname === '/health') {
      jsonResponse(res, 200, {
        ok: true,
        service: 'clawdb-topics-gateway',
        now: new Date().toISOString(),
        clients: this.clients.size,
        localWsUrl: this.getLocalWsUrl(),
        publicWsUrl: this.getPublicWsUrl()
      });
      return;
    }

    if (req.method !== 'GET') {
      jsonResponse(res, 405, {
        ok: false,
        error: 'method_not_allowed'
      });
      return;
    }

    try {
      if (pathname === `${this.httpBasePath}/topics`) {
        const batchSize = parseBatchSize(requestUrl.searchParams.get('batchSize'), 50);
        const cursor = parseCursor(requestUrl.searchParams.get('cursor'));
        const tenantId = requestUrl.searchParams.get('tenantId') || undefined;

        const data = await this.provider.listTopicsBatch({
          batchSize,
          cursor,
          tenantId
        });

        jsonResponse(res, 200, {
          ok: true,
          data
        });
        return;
      }

      if (pathname.startsWith(`${this.httpBasePath}/topics/`) && pathname.endsWith('/shards')) {
        const prefix = `${this.httpBasePath}/topics/`;
        const topicSegment = pathname.slice(prefix.length, pathname.length - '/shards'.length);
        const topicId = decodeURIComponent(topicSegment);
        const batchSize = parseBatchSize(requestUrl.searchParams.get('batchSize'), 20);
        const cursor = parseCursor(requestUrl.searchParams.get('cursor'));
        const tenantId = requestUrl.searchParams.get('tenantId') || undefined;

        const data = await this.provider.listTopicShardsBatch({
          topicId,
          batchSize,
          cursor,
          tenantId
        });

        jsonResponse(res, 200, {
          ok: true,
          data
        });
        return;
      }

      if (pathname.startsWith(`${this.httpBasePath}/topics/`)) {
        const topicSegment = pathname.slice(`${this.httpBasePath}/topics/`.length);
        const topicId = decodeURIComponent(topicSegment);
        const tenantId = requestUrl.searchParams.get('tenantId') || undefined;

        const data = await this.provider.getTopic({
          topicId,
          tenantId
        });

        jsonResponse(res, 200, {
          ok: true,
          data
        });
        return;
      }

      jsonResponse(res, 404, {
        ok: false,
        error: 'not_found'
      });
    } catch (error) {
      jsonResponse(res, 500, {
        ok: false,
        error: String(error?.message || error || 'unknown_error')
      });
    }
  }

  async _handleWsRequest(socket, request) {
    const requestUrl = new URL(request.url || '/', this.getLocalBaseUrl());
    const pathname = normalizePath(requestUrl.pathname);
    if (pathname !== this.wsPath) {
      socket.destroy();
      return;
    }

    this.wsServer.handleUpgrade(request, socket, Buffer.alloc(0), (ws) => {
      this.wsServer.emit('connection', ws, request);
    });
  }

  async _handleWsMessage(ws, rawMessage) {
    let payload = null;
    try {
      payload = JSON.parse(String(rawMessage));
    } catch {
      ws.send(
        JSON.stringify({
          id: null,
          ok: false,
          error: 'invalid_json'
        })
      );
      return;
    }

    const requestId = String(payload?.id || '');
    const op = String(payload?.op || '');
    const params = payload?.params && typeof payload.params === 'object' ? payload.params : {};

    if (!requestId || !op) {
      ws.send(
        JSON.stringify({
          id: requestId || null,
          ok: false,
          error: 'invalid_request'
        })
      );
      return;
    }

    try {
      let data = null;
      if (op === 'ping') {
        data = { pong: true, now: new Date().toISOString() };
      } else if (op === 'topics.list') {
        data = await this.provider.listTopicsBatch({
          batchSize: parseBatchSize(params.batchSize, 50),
          cursor: parseCursor(params.cursor),
          tenantId: params.tenantId
        });
      } else if (op === 'topics.shards.list') {
        data = await this.provider.listTopicShardsBatch({
          topicId: String(params.topicId || '').trim(),
          batchSize: parseBatchSize(params.batchSize, 20),
          cursor: parseCursor(params.cursor),
          tenantId: params.tenantId
        });
      } else if (op === 'topic.get') {
        data = await this.provider.getTopic({
          topicId: String(params.topicId || '').trim(),
          tenantId: params.tenantId
        });
      } else {
        throw new Error(`unsupported_op:${op}`);
      }

      ws.send(
        JSON.stringify({
          id: requestId,
          ok: true,
          data
        })
      );
    } catch (error) {
      ws.send(
        JSON.stringify({
          id: requestId,
          ok: false,
          error: String(error?.message || error || 'unknown_error')
        })
      );
    }
  }

  async start() {
    if (this.httpServer) {
      return;
    }

    this.httpServer = http.createServer((req, res) => {
      void this._handleHttpRequest(req, res);
    });

    this.wsServer = new WebSocketServer({ noServer: true });

    this.wsServer.on('connection', (ws) => {
      this.clients.add(ws);
      this._emitStats();

      ws.send(
        JSON.stringify({
          id: 'welcome',
          ok: true,
          data: {
            now: new Date().toISOString(),
            service: 'clawdb-topics-gateway'
          }
        })
      );

      ws.on('message', (message) => {
        void this._handleWsMessage(ws, message);
      });

      ws.on('close', () => {
        this.clients.delete(ws);
        this._emitStats();
      });

      ws.on('error', () => {
        this.clients.delete(ws);
        this._emitStats();
      });
    });

    this.httpServer.on('upgrade', (request, socket) => {
      void this._handleWsRequest(socket, request);
    });

    await new Promise((resolvePromise, rejectPromise) => {
      this.httpServer.once('error', rejectPromise);
      this.httpServer.listen(this.port, this.host, () => {
        resolvePromise();
      });
    });

    const address = this.httpServer.address();
    if (address && typeof address === 'object' && typeof address.port === 'number') {
      this.boundPort = address.port;
    }

    this.keepAliveInterval = setInterval(() => {
      for (const client of this.clients) {
        if (client.readyState !== 1) {
          continue;
        }
        try {
          client.ping();
        } catch {
          // Ignore stale client ping errors.
        }
      }
    }, 25_000);

    this.keepAliveInterval.unref?.();

    this.logger.info?.(
      `[clawdb-topics] gateway listening on ${this.getLocalBaseUrl()} ws=${this.getLocalWsUrl()}`
    );
    this._emitStats();
  }

  async stop() {
    if (!this.httpServer) {
      return;
    }

    if (this.keepAliveInterval) {
      clearInterval(this.keepAliveInterval);
      this.keepAliveInterval = null;
    }

    for (const client of this.clients) {
      try {
        client.close(1001, 'server_shutdown');
      } catch {
        // Ignore close errors.
      }
    }
    this.clients.clear();

    if (this.wsServer) {
      try {
        this.wsServer.close();
      } catch {
        // Ignore.
      }
      this.wsServer = null;
    }

    await new Promise((resolvePromise) => {
      this.httpServer.close(() => {
        resolvePromise();
      });
    });

    this.httpServer = null;
    this._emitStats();
  }
}
