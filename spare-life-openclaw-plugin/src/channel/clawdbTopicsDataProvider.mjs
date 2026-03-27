import { spawn } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const CURRENT_DIR = dirname(fileURLToPath(import.meta.url));
const PY_HELPER_PATH = resolve(CURRENT_DIR, '../../scripts/read_clawdb_topics.py');

function expandHome(input) {
  if (!input || typeof input !== 'string') {
    return input;
  }
  if (input.startsWith('~/')) {
    return `${process.env.HOME || ''}/${input.slice(2)}`;
  }
  return input;
}

function normalizeCursor(cursor) {
  if (cursor === undefined || cursor === null || cursor === '') {
    return 0;
  }
  const parsed = Number(cursor);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return 0;
  }
  return Math.floor(parsed);
}

function runPythonAction({ action, payload, pythonBin, timeoutMs }) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(pythonBin, [PY_HELPER_PATH, action], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';
    let settled = false;

    const timeout = setTimeout(() => {
      if (settled) {
        return;
      }
      settled = true;
      child.kill('SIGTERM');
      rejectPromise(new Error(`topic provider timeout after ${timeoutMs}ms (action=${action})`));
    }, timeoutMs);

    child.stdout.on('data', (chunk) => {
      stdout += String(chunk);
    });

    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });

    child.on('error', (error) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeout);
      rejectPromise(error);
    });

    child.on('close', (code) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeout);
      if (code !== 0) {
        const message = stderr.trim() || stdout.trim() || `python exited with code ${code}`;
        rejectPromise(new Error(message));
        return;
      }

      let parsed = null;
      try {
        parsed = JSON.parse(stdout);
      } catch (error) {
        rejectPromise(new Error(`failed to parse provider JSON: ${String(error)}\nstdout=${stdout}`));
        return;
      }
      resolvePromise(parsed);
    });

    child.stdin.write(JSON.stringify(payload || {}));
    child.stdin.end();
  });
}

export class ClawdbTopicsDataProvider {
  constructor(options = {}) {
    this.dataRoot = expandHome(options.dataRoot || '~/.openclaw/clawdb-data');
    this.tenantId = options.tenantId || 'default';
    this.pythonBin = options.pythonBin || process.env.CLAWDB_TOPICS_PYTHON_BIN || 'python3';
    this.timeoutMs = Number(options.timeoutMs || 15_000);
  }

  async listTopicsBatch(params = {}) {
    const payload = {
      dataRoot: this.dataRoot,
      tenantId: params.tenantId || this.tenantId,
      batchSize: Number(params.batchSize || 50),
      cursor: normalizeCursor(params.cursor)
    };
    return await runPythonAction({
      action: 'list_topics',
      payload,
      pythonBin: this.pythonBin,
      timeoutMs: this.timeoutMs
    });
  }

  async listTopicShardsBatch(params = {}) {
    const payload = {
      dataRoot: this.dataRoot,
      tenantId: params.tenantId || this.tenantId,
      topicId: String(params.topicId || '').trim(),
      batchSize: Number(params.batchSize || 20),
      cursor: normalizeCursor(params.cursor)
    };
    if (!payload.topicId) {
      throw new Error('topicId is required');
    }

    return await runPythonAction({
      action: 'list_shards',
      payload,
      pythonBin: this.pythonBin,
      timeoutMs: this.timeoutMs
    });
  }

  async getTopic(params = {}) {
    const payload = {
      dataRoot: this.dataRoot,
      tenantId: params.tenantId || this.tenantId,
      topicId: String(params.topicId || '').trim()
    };
    if (!payload.topicId) {
      throw new Error('topicId is required');
    }

    return await runPythonAction({
      action: 'get_topic',
      payload,
      pythonBin: this.pythonBin,
      timeoutMs: this.timeoutMs
    });
  }
}

export function formatPublicWsUrl({ publicBaseUrl, wsPath }) {
  if (!publicBaseUrl) {
    return '';
  }
  try {
    const base = new URL(publicBaseUrl);
    base.protocol = base.protocol === 'https:' ? 'wss:' : 'ws:';
    base.pathname = wsPath;
    base.search = '';
    return base.toString();
  } catch {
    return '';
  }
}
