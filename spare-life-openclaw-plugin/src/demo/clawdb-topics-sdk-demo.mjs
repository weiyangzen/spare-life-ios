import { ClawdbTopicsClient } from '../sdk/clawdbTopicsClient.mjs';

const baseUrl = process.env.CLAWDB_TOPICS_BASE_URL || 'http://127.0.0.1:17880';
const tenantId = process.env.CLAWDB_TOPICS_TENANT_ID || 'default';

async function main() {
  const client = new ClawdbTopicsClient({
    baseUrl,
    requestTimeoutMs: 15_000
  });

  const batch = await client.listTopicsBatch({
    tenantId,
    batchSize: 5,
    cursor: 0
  });

  console.log('topics_batch=', JSON.stringify(batch, null, 2));

  const firstTopic = batch.items?.[0]?.topicId;
  if (!firstTopic) {
    return;
  }

  const shards = await client.listTopicShardsBatch({
    tenantId,
    topicId: firstTopic,
    batchSize: 5,
    cursor: 0
  });

  console.log('topic_shards_batch=', JSON.stringify(shards, null, 2));

  await client.disconnect();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
