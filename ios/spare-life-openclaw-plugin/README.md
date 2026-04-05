# spare-life-openclaw-plugin

OpenClaw channel/plugin workspace for Spare Life.

This repository now includes a `clawdb-topics` channel that:

1. Maintains a long-lived WebSocket service.
2. Exposes ClawDB topics to app clients with lazy batch pull.
3. Exposes topic shards with lazy pull from newest shard to oldest shard.

## Structure

- `manifests/`: channel metadata and plugin descriptors.
- `src/inbound/`: normalize incoming channel payloads.
- `src/outbound/`: build outgoing channel responses.
- `src/adapters/`: platform-specific adapters.
- `src/schemas/`: shared payload schemas and validation contracts.
- `src/handlers/`: orchestration for request and response flow.
- `src/channel/`: `clawdb-topics` OpenClaw channel plugin + gateway runtime.
- `src/sdk/`: app SDK client (`ClawdbTopicsClient`).
- `fixtures/`: sample payloads for local testing.
- `tests/`: plugin-focused tests.

## Install As Local OpenClaw Channel

```bash
npm install
bash ./scripts/install_openclaw_channel.sh
```

This script will:

1. Install/link this repo into OpenClaw plugin registry.
2. Enable plugin `spare-life-openclaw-plugin`.
3. Write channel config at `channels.clawdb-topics`.
4. Auto-fill `publicBaseUrl` with Tailscale IPv4 if available.

Then start OpenClaw gateway:

```bash
openclaw gateway
```

Check status:

```bash
openclaw channels status --json
```

## SDK Endpoints

Default local endpoints after gateway starts:

- HTTP base: `http://127.0.0.1:17880/v1/clawdb-topics`
- WS: `ws://127.0.0.1:17880/v1/clawdb-topics/ws`

HTTP routes:

- `GET /health`
- `GET /v1/clawdb-topics/topics?batchSize=50&cursor=0&tenantId=default`
- `GET /v1/clawdb-topics/topics/{topicId}`
- `GET /v1/clawdb-topics/topics/{topicId}/shards?batchSize=20&cursor=0&tenantId=default`

WS ops:

- `ping`
- `topics.list`
- `topics.shards.list`
- `topic.get`

## App SDK Usage

```js
import { ClawdbTopicsClient } from "spare-life-openclaw-plugin";

const client = new ClawdbTopicsClient({
  baseUrl: "http://127.0.0.1:17880"
});

const topics = await client.listTopicsBatch({ batchSize: 20, cursor: 0 });
const shards = await client.listTopicShardsBatch({
  topicId: topics.items[0].topicId,
  batchSize: 10,
  cursor: 0
});
```

Demo:

```bash
npm run clawdb-topics-sdk-demo
```

## Public Reachability Without Stable IP

Tailscale is enough.

Recommended flow:

1. Install and login Tailscale on this machine.
2. Keep channel host as `0.0.0.0` and port `17880`.
3. Use Tailscale IP or MagicDNS hostname as `publicBaseUrl`.
4. App uses `ws://<tailscale-ip>:17880/v1/clawdb-topics/ws` (or `wss://` behind HTTPS proxy).

Helper:

```bash
./scripts/resolve_public_ws_url.sh
```

If you cannot use Tailscale in the app network, use a tunnel/proxy and set:

- `channels.clawdb-topics.publicBaseUrl = https://<public-host>`
