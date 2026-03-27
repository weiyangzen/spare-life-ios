import { ClawdbTopicsDataProvider } from './clawdbTopicsDataProvider.mjs';
import {
  CHANNEL_ID,
  createClawdbTopicsChannelPlugin
} from './clawdbTopicsChannelPlugin.mjs';

function buildProviderFromConfig(cfg, accountId) {
  const channels = cfg?.channels || {};
  const section = channels[CHANNEL_ID] || channels.clawdbTopics || channels.clawdb_topics || {};
  const base = {
    dataRoot: section.dataRoot || '~/.openclaw/clawdb-data',
    tenantId: section.tenantId || 'default',
    pythonBin: section.pythonBin || process.env.CLAWDB_TOPICS_PYTHON_BIN || 'python3',
    timeoutMs: Number(section.requestTimeoutMs || 15_000)
  };

  if (!accountId || accountId === 'default' || !section?.accounts?.[accountId]) {
    return new ClawdbTopicsDataProvider(base);
  }

  return new ClawdbTopicsDataProvider({
    ...base,
    ...section.accounts[accountId]
  });
}

const plugin = {
  id: 'spare-life-openclaw-plugin',
  name: 'Spare Life ClawDB Topics Channel',
  description: 'OpenClaw channel exposing ClawDB topics over long-lived WebSocket + lazy topic/shard pulls.',
  configSchema: {
    type: 'object',
    additionalProperties: false,
    properties: {}
  },
  register(api) {
    api.registerChannel({
      plugin: createClawdbTopicsChannelPlugin({
        logger: api.logger
      })
    });

    api.registerTool(
      {
        name: 'clawdb_topics_list_batch',
        label: 'ClawDB Topics List Batch',
        description: 'Return one lazy batch of canonical topics from ClawDB (newest to oldest).',
        parameters: {
          type: 'object',
          additionalProperties: false,
          properties: {
            account_id: { type: 'string' },
            tenant_id: { type: 'string' },
            batch_size: { type: 'number' },
            cursor: { type: 'number' }
          }
        },
        async execute(_toolCallId, params) {
          const provider = buildProviderFromConfig(api.config, params.account_id);
          const data = await provider.listTopicsBatch({
            tenantId: params.tenant_id,
            batchSize: params.batch_size,
            cursor: params.cursor
          });

          const brief = (data.items || [])
            .slice(0, 20)
            .map((item, index) => {
              const shardInfo = item.shardCount > 0 ? ` shards=${item.shardCount}` : '';
              return `${index + 1}. ${item.topicId} msgs=${item.messageCount}${shardInfo}`;
            })
            .join('\n');

          return {
            content: [
              {
                type: 'text',
                text: brief || 'No topics returned in this batch.'
              }
            ],
            details: data
          };
        }
      },
      { names: ['clawdb_topics_list_batch'] }
    );

    api.registerTool(
      {
        name: 'clawdb_topic_shards_list_batch',
        label: 'ClawDB Topic Shards List Batch',
        description: 'Return one lazy batch of shards for a topic (newest shard to oldest shard).',
        parameters: {
          type: 'object',
          additionalProperties: false,
          required: ['topic_id'],
          properties: {
            account_id: { type: 'string' },
            tenant_id: { type: 'string' },
            topic_id: { type: 'string' },
            batch_size: { type: 'number' },
            cursor: { type: 'number' }
          }
        },
        async execute(_toolCallId, params) {
          const provider = buildProviderFromConfig(api.config, params.account_id);
          const data = await provider.listTopicShardsBatch({
            topicId: params.topic_id,
            tenantId: params.tenant_id,
            batchSize: params.batch_size,
            cursor: params.cursor
          });

          const brief = (data.items || [])
            .slice(0, 20)
            .map((item, index) => `${index + 1}. ${item.topicId} shard=${item.shardOrdinal} msgs=${item.messageCount}`)
            .join('\n');

          return {
            content: [
              {
                type: 'text',
                text: brief || 'No shards returned in this batch.'
              }
            ],
            details: data
          };
        }
      },
      { names: ['clawdb_topic_shards_list_batch'] }
    );

    api.registerCli(
      ({ program }) => {
        const command = program
          .command('clawdb-topics')
          .description('Inspect ClawDB topics and shard pagination');

        command
          .command('topics')
          .option('--batch-size <n>', 'batch size', '20')
          .option('--cursor <n>', 'cursor offset', '0')
          .option('--tenant-id <id>', 'tenant id', 'default')
          .action(async (opts) => {
            const provider = buildProviderFromConfig(api.config);
            const data = await provider.listTopicsBatch({
              tenantId: opts.tenantId,
              batchSize: Number(opts.batchSize),
              cursor: Number(opts.cursor)
            });
            console.log(JSON.stringify(data, null, 2));
          });

        command
          .command('shards')
          .argument('<topicId>', 'canonical topic id')
          .option('--batch-size <n>', 'batch size', '20')
          .option('--cursor <n>', 'cursor offset', '0')
          .option('--tenant-id <id>', 'tenant id', 'default')
          .action(async (topicId, opts) => {
            const provider = buildProviderFromConfig(api.config);
            const data = await provider.listTopicShardsBatch({
              topicId,
              tenantId: opts.tenantId,
              batchSize: Number(opts.batchSize),
              cursor: Number(opts.cursor)
            });
            console.log(JSON.stringify(data, null, 2));
          });
      },
      { commands: ['clawdb-topics'] }
    );

    api.logger.info('spare-life clawdb topics channel registered');
  }
};

export default plugin;
