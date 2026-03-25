import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { createMasterFlowRuntime } from '../handlers/masterFlowHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    bundle: { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-master-flow.sqlite'));
const bundlePath = resolve(
  args.values.bundle ?? new URL('../../fixtures/master_asset_bundle.json', import.meta.url).pathname
);

if (args.values.reset && existsSync(dbPath)) {
  unlinkSync(dbPath);
}

const bundle = JSON.parse(readFileSync(bundlePath, 'utf8'));
const runtime = createMasterFlowRuntime({ dbPath });
const userId = 'demo-user';

try {
  const firstImport = runtime.importMasterAssetBundle({
    bundle,
    sourcePath: bundlePath
  });
  const secondImport = runtime.importMasterAssetBundle({
    bundle,
    sourcePath: bundlePath
  });

  const home = runtime.openMasterHome({
    userId,
    query: '转岗 AI 产品',
    domainKey: null
  });

  const firstChat = runtime.chatWithMaster({
    userId,
    masterId: 'daosheng-hefu',
    topic: 'AI 产品转岗',
    memoryScope: 'cross_master',
    message: '我想在 30 天内转岗做 AI 产品经理，但之前一直在做运营，担心简历说服力不够，而且现金流只能撑三个月。'
  });

  const secondChat = runtime.chatWithMaster({
    userId,
    masterId: 'daosheng-hefu',
    sessionId: firstChat.session.id,
    topic: 'AI 产品转岗',
    memoryScope: 'master_only',
    message: '基于你已经记住的目标和经历，告诉我第一周该先补作品集还是先投岗位。'
  });

  const homeAfterChat = runtime.openMasterHome({
    userId,
    query: ''
  });

  const restored = runtime.restoreRecentMaster({
    userId,
    sessionId: secondChat.session.id
  });

  const consultation = runtime.consultMasters({
    userId,
    issue: '我想转岗 AI 产品经理，同时不能让现金流断掉，也想确保节奏能持续。',
    masterIds: ['daosheng-hefu', 'zeng-guofan', 'wang-yangming'],
    shareMode: 'cross_master'
  });

  const blockedMutation = runtime.attemptCatalogMutation({
    operation: 'create',
    masterId: 'custom-master'
  });

  const trackedCTA = runtime.trackCTAAction({
    userId,
    sourceKind: 'consultation',
    sourceId: consultation.consultation.id,
    masterId: consultation.members[0].masterId,
    ctaId: consultation.merged.ctas[0].id,
    route: consultation.merged.ctas[0].route,
    effectKind: consultation.merged.ctas[0].effectKind
  });

  const state = runtime.inspectMasterState(userId);

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          firstImportStatus: firstImport.status,
          secondImportStatus: secondImport.status,
          matchedDomains: home.domains.length,
          recentUnreadBeforeRestore: homeAfterChat.recentChats[0]?.unreadCount ?? 0,
          recentUnreadAfterRestore: restored.session.unreadCount,
          rememberedItems: state.counts.memories,
          consultationMembers: consultation.members.length,
          blockedMutationReason: blockedMutation.reason,
          ctaEvents: state.counts.ctaEvents
        },
        firstImport,
        home,
        firstChat,
        secondChat,
        restored,
        consultation,
        blockedMutation,
        trackedCTA,
        state
      },
      null,
      2
    )
  );
} finally {
  runtime.close();
}
