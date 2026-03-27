# iPhone 通过 Tailscale 读取 ClawDB（topics + topic shards）接入说明

## 1. 目标与现状

你当前机器已经部署了 `clawdb-topics` 通道，运行参数如下：

- 监听地址：`0.0.0.0:17880`
- HTTP 基础路径：`/v1/clawdb-topics`
- WebSocket 路径：`/v1/clawdb-topics/ws`
- ClawDB 数据源：`~/.openclaw/clawdb-data`

你提供的 Tailscale IP 为：`100.82.60.69`

因此 iPhone 侧可直接使用：

- HTTP Base URL：`http://100.82.60.69:17880/v1/clawdb-topics`
- WS URL：`ws://100.82.60.69:17880/v1/clawdb-topics/ws`

## 2. 前置条件（必须满足）

1. iPhone 安装并登录 Tailscale。
2. iPhone 与这台服务器处于同一个 Tailnet。
3. 服务器侧 OpenClaw Gateway 正在运行。

建议在服务器执行：

```bash
openclaw gateway restart
openclaw channels status --json
```

确认 `clawdb-topics` 账户状态为：

- `configured: true`
- `running: true`
- `localWsUrl: ws://127.0.0.1:17880/v1/clawdb-topics/ws`

## 3. iPhone 侧接入方式

可用两种方式：

1. HTTP 拉取（最简单）
2. WebSocket 长连接（推荐，用于持续分页与低延迟请求）

---

### 3.1 HTTP：读取 topics（按批懒加载）

请求：

```http
GET http://100.82.60.69:17880/v1/clawdb-topics/topics?batchSize=20&cursor=0&tenantId=default
```

说明：

- `batchSize`：每批数量。
- `cursor`：偏移游标（字符串或数字都可，返回里有 `nextCursor`）。
- `tenantId`：默认 `default`。

返回关键字段：

- `data.items[]`：topic 列表。
- `data.nextCursor`：下一批游标，为 `null` 表示结束。

---

### 3.2 HTTP：读取 topic shards（从新到旧）

请求：

```http
GET http://100.82.60.69:17880/v1/clawdb-topics/topics/{topicId}/shards?batchSize=20&cursor=0&tenantId=default
```

示例（topicId 需 URL Encode）：

```http
GET /v1/clawdb-topics/topics/group%3Axxx%3A%3Ageptopic-000001/shards?batchSize=20&cursor=0&tenantId=default
```

返回关键字段：

- `data.items[]`：shard 列表，顺序已按“新 shard -> 旧 shard”。
- `item.shardOrdinal`：分片序号。
- `data.nextCursor`：下一页游标。

## 4. WebSocket 长连接协议（推荐）

连接地址：

```text
ws://100.82.60.69:17880/v1/clawdb-topics/ws
```

### 4.1 拉取 topics（批量）

发送：

```json
{
  "id": "req-1",
  "op": "topics.list",
  "params": {
    "tenantId": "default",
    "batchSize": 20,
    "cursor": 0
  }
}
```

### 4.2 拉取 shards（批量，新到旧）

发送：

```json
{
  "id": "req-2",
  "op": "topics.shards.list",
  "params": {
    "tenantId": "default",
    "topicId": "group:xxx::geptopic-000001",
    "batchSize": 20,
    "cursor": 0
  }
}
```

### 4.3 单 topic 详情

发送：

```json
{
  "id": "req-3",
  "op": "topic.get",
  "params": {
    "tenantId": "default",
    "topicId": "group:xxx::geptopic-000001"
  }
}
```

### 4.4 心跳

发送：

```json
{
  "id": "ping-1",
  "op": "ping",
  "params": {}
}
```

统一响应格式：

```json
{
  "id": "req-1",
  "ok": true,
  "data": { }
}
```

失败时：

```json
{
  "id": "req-1",
  "ok": false,
  "error": "..."
}
```

## 5. iOS 端最小分页策略（建议）

1. 首屏调用 `topics.list(batchSize=20,cursor=0)`。
2. 保存 `nextCursor`，滚动到底再请求下一批。
3. 点进某个 topic 后，调用 `topics.shards.list(topicId, batchSize=20, cursor=0)`。
4. 按返回顺序渲染（已是新 shard -> 旧 shard）。
5. 若 `nextCursor == null`，停止分页。

## 6. 自检命令（服务器上执行）

```bash
# 健康检查
curl -fsS http://127.0.0.1:17880/health | jq

# topics 测试
curl -fsS 'http://127.0.0.1:17880/v1/clawdb-topics/topics?batchSize=2&cursor=0&tenantId=default' | jq

# OpenClaw 侧状态
openclaw channels status --json
```

## 7. 常见问题

### 7.1 iPhone 连不上 `100.82.60.69`

排查顺序：

1. iPhone Tailscale 是否已连接同一 Tailnet。
2. 服务器 Tailscale 是否在线。
3. 服务器 gateway 是否在跑：`openclaw gateway status`。
4. 端口是否被本机防火墙拦截（`17880`）。

### 7.2 iPhone 必须使用 HTTPS/WSS

当前是 `http/ws`（Tailnet 内可用）。
如果 iOS 网络策略要求 TLS，请在服务器前加反向代理并暴露 `https/wss`，然后把 app URL 改为：

- `https://<your-domain>/v1/clawdb-topics`
- `wss://<your-domain>/v1/clawdb-topics/ws`

## 8. 结论

对你现在这台机器（Tailscale `100.82.60.69`）而言，iPhone 可直接接：

- `http://100.82.60.69:17880/v1/clawdb-topics/topics`
- `http://100.82.60.69:17880/v1/clawdb-topics/topics/{topicId}/shards`
- `ws://100.82.60.69:17880/v1/clawdb-topics/ws`

即可完成：

1. topics 懒加载分页读取
2. topic shards 按新到旧懒加载分页读取
