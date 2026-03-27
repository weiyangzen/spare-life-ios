import { WebSocket as NodeWebSocket } from 'ws';

const DEFAULT_HTTP_BASE_PATH = '/v1/clawdb-topics';
const DEFAULT_WS_PATH = '/v1/clawdb-topics/ws';

function normalizeBaseUrl(baseUrl) {
  const parsed = new URL(baseUrl);
  parsed.pathname = parsed.pathname.replace(/\/$/, '');
  parsed.search = '';
  parsed.hash = '';
  return parsed.toString();
}

function buildWsUrl(baseUrl, wsPath = DEFAULT_WS_PATH) {
  const parsed = new URL(baseUrl);
  parsed.protocol = parsed.protocol === 'https:' ? 'wss:' : 'ws:';
  parsed.pathname = wsPath;
  parsed.search = '';
  return parsed.toString();
}

function buildHttpUrl(baseUrl, path, searchParams = {}) {
  const parsed = new URL(baseUrl);
  parsed.pathname = path;
  parsed.search = '';
  for (const [key, value] of Object.entries(searchParams)) {
    if (value === undefined || value === null || value === '') {
      continue;
    }
    parsed.searchParams.set(key, String(value));
  }
  return parsed.toString();
}

function nextRequestId() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export class ClawdbTopicsClient {
  constructor(options = {}) {
    if (!options.baseUrl) {
      throw new Error('baseUrl is required');
    }

    this.baseUrl = normalizeBaseUrl(options.baseUrl);
    this.httpBasePath = options.httpBasePath || DEFAULT_HTTP_BASE_PATH;
    this.wsPath = options.wsPath || DEFAULT_WS_PATH;
    this.wsUrl = options.wsUrl || buildWsUrl(this.baseUrl, this.wsPath);
    this.requestTimeoutMs = Number(options.requestTimeoutMs || 15_000);

    this.WebSocketImpl =
      options.WebSocketImpl ||
      (typeof globalThis.WebSocket === 'function' ? globalThis.WebSocket : NodeWebSocket);

    this.ws = null;
    this.pending = new Map();
  }

  isConnected() {
    return Boolean(this.ws && this.ws.readyState === 1);
  }

  async connect() {
    if (this.isConnected()) {
      return;
    }

    const ws = new this.WebSocketImpl(this.wsUrl);

    await new Promise((resolvePromise, rejectPromise) => {
      let settled = false;
      const timeout = setTimeout(() => {
        if (settled) {
          return;
        }
        settled = true;
        try {
          ws.close();
        } catch {
          // Ignore close errors.
        }
        rejectPromise(new Error(`websocket connect timeout after ${this.requestTimeoutMs}ms`));
      }, this.requestTimeoutMs);

      const cleanup = () => {
        clearTimeout(timeout);
      };

      ws.onopen = () => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        resolvePromise();
      };

      ws.onerror = (event) => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        rejectPromise(new Error(`websocket connect error: ${String(event?.message || 'unknown')}`));
      };
    });

    ws.onmessage = (event) => {
      this._handleMessage(event.data);
    };

    ws.onclose = () => {
      this._rejectAllPending(new Error('websocket_closed'));
      this.ws = null;
    };

    ws.onerror = () => {
      // Close handler will reject pending requests.
    };

    this.ws = ws;
  }

  async disconnect() {
    if (!this.ws) {
      return;
    }
    const current = this.ws;
    this.ws = null;
    this._rejectAllPending(new Error('websocket_closed'));

    await new Promise((resolvePromise) => {
      current.onclose = () => {
        resolvePromise();
      };
      try {
        current.close();
      } catch {
        resolvePromise();
      }
    });
  }

  _rejectAllPending(error) {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timeout);
      pending.reject(error);
    }
    this.pending.clear();
  }

  _handleMessage(raw) {
    let payload = null;
    try {
      payload = JSON.parse(String(raw));
    } catch {
      return;
    }

    const id = String(payload?.id || '');
    if (!id || !this.pending.has(id)) {
      return;
    }

    const pending = this.pending.get(id);
    clearTimeout(pending.timeout);
    this.pending.delete(id);

    if (payload.ok) {
      pending.resolve(payload.data);
      return;
    }

    pending.reject(new Error(String(payload.error || 'request_failed')));
  }

  async _requestWs(op, params = {}) {
    await this.connect();

    const requestId = nextRequestId();
    const payload = {
      id: requestId,
      op,
      params
    };

    return await new Promise((resolvePromise, rejectPromise) => {
      const timeout = setTimeout(() => {
        this.pending.delete(requestId);
        rejectPromise(new Error(`request_timeout:${op}`));
      }, this.requestTimeoutMs);

      this.pending.set(requestId, {
        resolve: resolvePromise,
        reject: rejectPromise,
        timeout
      });

      try {
        this.ws.send(JSON.stringify(payload));
      } catch (error) {
        clearTimeout(timeout);
        this.pending.delete(requestId);
        rejectPromise(error);
      }
    });
  }

  async _requestHttp(path, searchParams = {}) {
    const url = buildHttpUrl(this.baseUrl, path, searchParams);
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'accept': 'application/json'
      }
    });

    const payload = await response.json();
    if (!response.ok || !payload?.ok) {
      const message = payload?.error || `http_error_${response.status}`;
      throw new Error(String(message));
    }

    return payload.data;
  }

  async listTopicsBatch(params = {}) {
    if (this.isConnected()) {
      return await this._requestWs('topics.list', {
        tenantId: params.tenantId,
        batchSize: params.batchSize,
        cursor: params.cursor
      });
    }

    return await this._requestHttp(`${this.httpBasePath}/topics`, {
      tenantId: params.tenantId,
      batchSize: params.batchSize,
      cursor: params.cursor
    });
  }

  async listTopicShardsBatch(params = {}) {
    if (!params.topicId) {
      throw new Error('topicId is required');
    }

    if (this.isConnected()) {
      return await this._requestWs('topics.shards.list', {
        topicId: params.topicId,
        tenantId: params.tenantId,
        batchSize: params.batchSize,
        cursor: params.cursor
      });
    }

    return await this._requestHttp(
      `${this.httpBasePath}/topics/${encodeURIComponent(params.topicId)}/shards`,
      {
        tenantId: params.tenantId,
        batchSize: params.batchSize,
        cursor: params.cursor
      }
    );
  }

  async getTopic(params = {}) {
    if (!params.topicId) {
      throw new Error('topicId is required');
    }

    if (this.isConnected()) {
      return await this._requestWs('topic.get', {
        topicId: params.topicId,
        tenantId: params.tenantId
      });
    }

    return await this._requestHttp(`${this.httpBasePath}/topics/${encodeURIComponent(params.topicId)}`, {
      tenantId: params.tenantId
    });
  }

  async *iterateTopics(options = {}) {
    const batchSize = Number(options.batchSize || 50);
    let cursor = options.cursor ?? 0;

    while (true) {
      const page = await this.listTopicsBatch({
        tenantId: options.tenantId,
        batchSize,
        cursor
      });
      for (const item of page.items || []) {
        yield item;
      }
      if (!page.nextCursor && page.nextCursor !== 0) {
        break;
      }
      cursor = Number(page.nextCursor);
    }
  }

  async *iterateTopicShards(options = {}) {
    if (!options.topicId) {
      throw new Error('topicId is required');
    }

    const batchSize = Number(options.batchSize || 20);
    let cursor = options.cursor ?? 0;

    while (true) {
      const page = await this.listTopicShardsBatch({
        topicId: options.topicId,
        tenantId: options.tenantId,
        batchSize,
        cursor
      });
      for (const item of page.items || []) {
        yield item;
      }
      if (!page.nextCursor && page.nextCursor !== 0) {
        break;
      }
      cursor = Number(page.nextCursor);
    }
  }
}

export function createClawdbTopicsClient(options) {
  return new ClawdbTopicsClient(options);
}
