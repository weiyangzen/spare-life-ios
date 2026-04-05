import { existsSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { createUnifiedChannelRuntime } from '../handlers/unifiedChannelHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    payload: { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-foundation-bottom.sqlite'));
const payloadPath = resolve(
  args.values.payload ?? new URL('../../fixtures/scene_scan_payload.json', import.meta.url).pathname
);

if (args.values.reset && existsSync(dbPath)) {
  rmSync(dbPath, { force: true });
}

const scenePayload = JSON.parse(readFileSync(payloadPath, 'utf8'));
const runtime = createUnifiedChannelRuntime({ dbPath });
const userId = 'foundation-demo-user';

function request(routeKey, action, body) {
  return runtime.processEnvelope({
    requestId: `${routeKey}-${action}-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`,
    envelopeVersion: '2026-03-26',
    channel: 'openclaw',
    routeKey,
    action,
    body: {
      userId,
      ...body
    }
  });
}

try {
  request('security', 'set_permission', {
    routeKey: '*',
    action: '*',
    effect: 'allow',
    reason: '默认允许，按规则做风控拦截。'
  });

  const sceneScan = request('scene', 'scan', {
    ...scenePayload,
    viewer: {
      ...(scenePayload.viewer ?? {}),
      userId
    }
  });

  const sceneIntent = request('scene', 'intent', {
    ...scenePayload,
    viewer: {
      ...(scenePayload.viewer ?? {}),
      userId
    }
  });

  const directMessage = request('companion', 'send_direct_message', {
    userId,
    contactId: 'lin-zhou',
    text: '这周 Demo 收尾压力有点大，想把周六任务缩成可演示版本。'
  });

  const blockedByRisk = request('companion', 'send_direct_message', {
    userId,
    contactId: 'lin-zhou',
    text: '我想讨论洗钱和外挂操作。'
  });

  const recalled = request('ai_memory', 'recall', {
    userId,
    query: 'Demo 收尾和关系推进怎么安排',
    limit: 4
  });

  const matched = request('ai_memory', 'match', {
    userId,
    query: '给我下一步行动建议',
    candidates: [
      {
        id: 'cand-demo-plan',
        summary: '先把周六 Demo 收尾拆成 90 分钟可演示目标',
        tags: ['Demo', '收尾', '行动']
      },
      {
        id: 'cand-social-chill',
        summary: '约一次轻松散步，先续上关系温度',
        tags: ['散步', '关系', '轻松']
      },
      {
        id: 'cand-risky-trade',
        summary: '直接向陌生人转账购买高风险外挂',
        tags: ['转账', '外挂', '高风险']
      }
    ],
    limit: 3
  });

  const report = request('security', 'report', {
    userId,
    targetType: 'message',
    targetId: 'mock-msg-123',
    reason: 'suspected_scam',
    detail: '对方引导我私下转账。'
  });

  const securityState = request('security', 'inspect', {
    userId,
    auditLimit: 12,
    reportLimit: 8,
    permissionLimit: 8
  });

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          sceneScanStatus: sceneScan.status,
          sceneIntentStatus: sceneIntent.status,
          directMessageStatus: directMessage.status,
          blockedDecision: blockedByRisk.status,
          recallCount: recalled.result?.memories?.length ?? 0,
          matchCount: matched.result?.rankedCandidates?.length ?? 0,
          reportStatus: report.status,
          auditCount: securityState.result?.counts?.audits ?? 0,
          reportCount: securityState.result?.counts?.reports ?? 0
        },
        sceneScan,
        sceneIntent,
        directMessage,
        blockedByRisk,
        recalled,
        matched,
        report,
        securityState,
        foundationState: runtime.inspectFoundationState(userId)
      },
      null,
      2
    )
  );
} finally {
  runtime.close();
}
