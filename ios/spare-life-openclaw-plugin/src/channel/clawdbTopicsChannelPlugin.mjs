import fs from 'node:fs';

import { ClawdbTopicsDataProvider } from './clawdbTopicsDataProvider.mjs';
import { ClawdbTopicsGatewayServer } from './clawdbTopicsGatewayServer.mjs';

export const CHANNEL_ID = 'clawdb-topics';
export const DEFAULT_ACCOUNT_ID = 'default';

const runningServers = new Map();

const channelConfigSchema = {
  schema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      enabled: { type: 'boolean' },
      name: { type: 'string' },
      host: { type: 'string' },
      port: { type: 'number', minimum: 1, maximum: 65535 },
      httpBasePath: { type: 'string' },
      wsPath: { type: 'string' },
      dataRoot: { type: 'string' },
      tenantId: { type: 'string' },
      pythonBin: { type: 'string' },
      requestTimeoutMs: { type: 'number', minimum: 1000, maximum: 120000 },
      publicBaseUrl: { type: 'string' },
      accounts: {
        type: 'object',
        additionalProperties: {
          type: 'object'
        }
      }
    }
  },
  uiHints: {
    host: {
      label: 'Gateway Host',
      placeholder: '0.0.0.0',
      help: 'Bind host for the local topic gateway service'
    },
    port: {
      label: 'Gateway Port',
      placeholder: '17880',
      help: 'Port used for HTTP + WebSocket topic access'
    },
    dataRoot: {
      label: 'ClawDB Data Root',
      placeholder: '~/.openclaw/clawdb-data',
      help: 'Root path that contains parquet/topics files'
    },
    publicBaseUrl: {
      label: 'Public Base URL',
      placeholder: 'https://your-tailnet-hostname.ts.net:17880',
      help: 'Externally reachable base URL; used to advertise public WS endpoint'
    }
  }
};

function normalizeAccountId(rawAccountId) {
  const value = String(rawAccountId || DEFAULT_ACCOUNT_ID).trim();
  return value || DEFAULT_ACCOUNT_ID;
}

function resolveChannelSection(cfg) {
  const channels = cfg?.channels || {};
  return (
    channels[CHANNEL_ID] ||
    channels.clawdbTopics ||
    channels.clawdb_topics ||
    {}
  );
}

function resolveAccountConfig(cfg, accountId) {
  const section = resolveChannelSection(cfg);
  const normalizedAccountId = normalizeAccountId(accountId);

  const globalConfig = {
    enabled: section.enabled !== false,
    name: section.name || normalizedAccountId,
    host: section.host || '0.0.0.0',
    port: Number(section.port || 17880),
    httpBasePath: section.httpBasePath || '/v1/clawdb-topics',
    wsPath: section.wsPath || '/v1/clawdb-topics/ws',
    dataRoot: section.dataRoot || '~/.openclaw/clawdb-data',
    tenantId: section.tenantId || 'default',
    pythonBin: section.pythonBin || process.env.CLAWDB_TOPICS_PYTHON_BIN || 'python3',
    requestTimeoutMs: Number(section.requestTimeoutMs || 15_000),
    publicBaseUrl: section.publicBaseUrl || ''
  };

  const accountOverrides =
    normalizedAccountId === DEFAULT_ACCOUNT_ID
      ? section
      : section?.accounts?.[normalizedAccountId] || {};

  return {
    accountId: normalizedAccountId,
    ...globalConfig,
    ...accountOverrides,
    enabled: accountOverrides?.enabled !== false && globalConfig.enabled !== false
  };
}

function listAccountIds(cfg) {
  const section = resolveChannelSection(cfg);
  const explicit = section?.accounts && typeof section.accounts === 'object'
    ? Object.keys(section.accounts).filter(Boolean)
    : [];
  if (explicit.length > 0) {
    return explicit;
  }
  return [DEFAULT_ACCOUNT_ID];
}

function isConfigured(account) {
  const expanded = String(account.dataRoot || '').replace(/^~\//, `${process.env.HOME || ''}/`);
  const topicsDir = `${expanded}/parquet/topics`;
  return fs.existsSync(topicsDir);
}

function buildSnapshotFromAccount(account) {
  return {
    accountId: account.accountId,
    name: account.name,
    enabled: account.enabled !== false,
    configured: isConfigured(account),
    host: account.host,
    port: account.port,
    dataRoot: account.dataRoot,
    tenantId: account.tenantId,
    publicBaseUrl: account.publicBaseUrl,
    pythonBin: account.pythonBin
  };
}

export function createClawdbTopicsChannelPlugin({ logger } = {}) {
  return {
    id: CHANNEL_ID,
    meta: {
      id: CHANNEL_ID,
      label: 'ClawDB Topics',
      selectionLabel: 'ClawDB Topics Gateway',
      docsPath: '/channels/clawdb-topics',
      docsLabel: 'clawdb-topics',
      blurb: 'Expose ClawDB topics + shards over a persistent WebSocket for app-side lazy pulls.',
      order: 200
    },
    capabilities: {
      chatTypes: ['direct'],
      media: false,
      threads: false,
      reactions: false,
      polls: false
    },
    reload: {
      configPrefixes: ['channels.clawdb-topics', 'channels.clawdbTopics', 'channels.clawdb_topics']
    },
    configSchema: channelConfigSchema,
    config: {
      listAccountIds,
      resolveAccount: (cfg, accountId) => resolveAccountConfig(cfg, accountId),
      defaultAccountId: () => DEFAULT_ACCOUNT_ID,
      isConfigured: (account) => isConfigured(account),
      describeAccount: (account) => buildSnapshotFromAccount(account)
    },
    status: {
      defaultRuntime: {
        accountId: DEFAULT_ACCOUNT_ID,
        running: false,
        connected: false,
        clients: 0
      },
      buildAccountSnapshot: ({ account, runtime }) => ({
        ...buildSnapshotFromAccount(account),
        running: Boolean(runtime?.running),
        connected: Boolean(runtime?.connected),
        clients: Number(runtime?.clients || 0),
        localBaseUrl: runtime?.localBaseUrl || null,
        localWsUrl: runtime?.localWsUrl || null,
        publicHttpBase: runtime?.publicHttpBase || null,
        publicWsUrl: runtime?.publicWsUrl || null,
        lastError: runtime?.lastError || null,
        lastStartAt: runtime?.lastStartAt || null,
        lastStopAt: runtime?.lastStopAt || null
      })
    },
    outbound: {
      deliveryMode: 'direct',
      sendText: async () => {
        throw new Error('clawdb-topics channel is read-only and does not support outbound chat delivery.');
      }
    },
    gateway: {
      startAccount: async (ctx) => {
        const account = ctx.account;

        const existing = runningServers.get(account.accountId);
        if (existing) {
          try {
            await existing.stop();
          } catch {
            // Ignore stale server shutdown errors.
          }
          runningServers.delete(account.accountId);
        }

        const provider = new ClawdbTopicsDataProvider({
          dataRoot: account.dataRoot,
          tenantId: account.tenantId,
          pythonBin: account.pythonBin,
          timeoutMs: account.requestTimeoutMs
        });

        const server = new ClawdbTopicsGatewayServer({
          provider,
          host: account.host,
          port: account.port,
          httpBasePath: account.httpBasePath,
          wsPath: account.wsPath,
          publicBaseUrl: account.publicBaseUrl,
          logger: ctx.log || logger,
          onStats: (stats) => {
            ctx.setStatus({
              accountId: account.accountId,
              running: true,
              connected: true,
              clients: stats.clients,
              localBaseUrl: stats.localBaseUrl,
              localWsUrl: stats.localWsUrl,
              publicHttpBase: stats.publicHttpBase,
              publicWsUrl: stats.publicWsUrl
            });
          }
        });

        await server.start();

        runningServers.set(account.accountId, server);

        ctx.setStatus({
          accountId: account.accountId,
          running: true,
          connected: true,
          clients: 0,
          localBaseUrl: server.getLocalBaseUrl(),
          localWsUrl: server.getLocalWsUrl(),
          publicHttpBase: server.getPublicHttpBase(),
          publicWsUrl: server.getPublicWsUrl()
        });

        await new Promise((resolvePromise) => {
          const shutdown = async () => {
            try {
              await server.stop();
            } catch {
              // Ignore shutdown errors.
            }
            runningServers.delete(account.accountId);
            resolvePromise();
          };

          if (ctx.abortSignal.aborted) {
            void shutdown();
            return;
          }

          ctx.abortSignal.addEventListener('abort', () => {
            void shutdown();
          }, { once: true });
        });
      },
      stopAccount: async (ctx) => {
        const existing = runningServers.get(ctx.accountId);
        if (!existing) {
          return;
        }

        await existing.stop();
        runningServers.delete(ctx.accountId);
      }
    }
  };
}
