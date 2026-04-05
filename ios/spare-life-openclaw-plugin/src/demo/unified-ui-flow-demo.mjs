import { existsSync, readFileSync, rmSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import {
  buildCounterpartParticipantKey,
  buildSelfParticipantKey
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';
import { createCompanionChatRuntime } from '../handlers/companionChatHandler.mjs';
import { createEarnSocialRuntime } from '../handlers/earnSocialFlowHandler.mjs';
import { createMasterFlowRuntime } from '../handlers/masterFlowHandler.mjs';
import { createMyDashboardRuntime } from '../handlers/myDashboardHandler.mjs';
import { createSceneFlowRuntime } from '../handlers/sceneScanHandler.mjs';
import { createUnifiedUIRuntime } from '../handlers/unifiedUIHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    bundle: { type: 'string' },
    payload: { type: 'string' },
    'backup-dir': { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-unified-ui.sqlite'));
const bundlePath = resolve(
  args.values.bundle ?? new URL('../../fixtures/master_asset_bundle.json', import.meta.url).pathname
);
const payloadPath = resolve(
  args.values.payload ?? new URL('../../fixtures/scene_scan_payload.json', import.meta.url).pathname
);
const backupDir = resolve(args.values['backup-dir'] ?? join(tmpdir(), 'spare-life-unified-ui-backups'));

if (args.values.reset && existsSync(dbPath)) {
  unlinkSync(dbPath);
}
if (args.values.reset && existsSync(backupDir)) {
  rmSync(backupDir, { recursive: true, force: true });
}

const scenePayload = JSON.parse(readFileSync(payloadPath, 'utf8'));
const masterBundle = JSON.parse(readFileSync(bundlePath, 'utf8'));
const userId = scenePayload.viewer?.userId ?? 'demo-user';
const vaultSecret = 'unified-ui-demo-secret';

{
  const runtime = createSceneFlowRuntime({ dbPath });
  try {
    runtime.handleSceneScan(scenePayload);
    runtime.handleSceneIntent(scenePayload);
  } finally {
    runtime.close();
  }
}

{
  const runtime = createMasterFlowRuntime({ dbPath });
  try {
    runtime.importMasterAssetBundle({
      bundle: masterBundle,
      sourcePath: bundlePath
    });
    runtime.chatWithMaster({
      userId,
      masterId: 'daosheng-hefu',
      topic: 'AI 产品转岗',
      memoryScope: 'cross_master',
      message: '我想做 AI 产品转岗，但需要一个先收敛范围再推进的计划。'
    });
    runtime.chatWithMaster({
      userId,
      masterId: 'wang-yangming',
      topic: '作品集梳理',
      memoryScope: 'master_only',
      message: '帮我把作品集里最该先讲清楚的三段经历挑出来。'
    });
  } finally {
    runtime.close();
  }
}

{
  const runtime = createEarnSocialRuntime({ dbPath });
  try {
    const home = runtime.openEarnSocialHome({
      userId,
      laneId: 'job_hiring',
      viewerTags: ['AI 产品', '作品集']
    });
    const deck = runtime.browsePersonaDeck({
      userId,
      laneId: 'job_hiring',
      viewerTags: ['AI 产品', '作品集']
    });
    const likedCard = deck.cards[0];
    runtime.recordPersonaFeedback({
      userId,
      laneId: 'job_hiring',
      agentId: likedCard.agentId,
      feedback: 'like',
      reason: '更像真实可推进的对象'
    });
    const published = runtime.publishIntent({
      userId,
      laneId: 'job_hiring',
      templateId: 'job_seek',
      mode: 'direct',
      targetAgentId: likedCard.agentId,
      viewerTags: ['AI 产品', 'B 端工具'],
      formPayload: {
        role: 'AI 产品经理',
        experience: '做过效率工具，正在补作品集',
        city: '上海',
        salary: 35000
      }
    });
    const icebreak = runtime.startDualAgentIcebreak({
      userId,
      intentId: published.intent.id,
      targetAgentId: likedCard.agentId
    });
    runtime.recordHumanConsent({
      sessionId: icebreak.session.id,
      side: 'initiator',
      granted: true
    });
    const consent = runtime.recordHumanConsent({
      sessionId: icebreak.session.id,
      side: 'counterpart',
      granted: true
    });
    runtime.advanceLeadStage({
      leadId: consent.lead.id,
      userId,
      stageKey: 'active_delivery',
      detail: {
        nextAction: '改为真人跟进面试安排'
      }
    });
    runtime.recordLeadOutcome({
      leadId: consent.lead.id,
      userId,
      outcomeCode: 'interview_scheduled',
      detail: {
        scheduledAt: '2026-03-27T19:00:00+08:00'
      }
    });
    runtime.settleLeadOutcome({
      leadId: consent.lead.id,
      userId,
      settlementType: 'reward',
      amount: 18,
      detail: {
        reason: '进入真人面试'
      }
    });
    runtime.openEarnSocialHome({
      userId,
      laneId: home.selectedLaneId ?? 'job_hiring',
      viewerTags: ['AI 产品', '面试']
    });
  } finally {
    runtime.close();
  }
}

let directConversationId = null;
{
  const runtime = createCompanionChatRuntime({ dbPath });
  try {
    const directTurn = runtime.sendDirectMessage({
      userId,
      contactId: 'lin-zhou',
      text: '周六我想和你把 Demo 收成一个能演示的版本，先不再扩功能。'
    });
    directConversationId = directTurn.conversation.id;
    runtime.updateContactMask({
      userId,
      contactId: 'lin-zhou',
      tone: 'gentle',
      openness: 'open',
      boundaryTags: ['先说真实压力', '给明确邀请'],
      overrideRules: ['demo_weekend'],
      signature: '先把压力和目标说清。'
    });
    const stageDraft = runtime.draftSharedStage({
      userId,
      contactId: 'lin-zhou',
      text: '我这周末想把 Demo 收口，但怕自己又乱加需求。'
    });
    runtime.grantStageAccess({
      userId,
      conversationId: directConversationId,
      participantKey: buildSelfParticipantKey('agent'),
      granted: true
    });
    runtime.grantStageAccess({
      userId,
      conversationId: directConversationId,
      participantKey: buildCounterpartParticipantKey('lin-zhou', 'agent'),
      granted: true
    });
    runtime.postStageMessage({
      userId,
      conversationId: directConversationId,
      participantKey: buildSelfParticipantKey('agent'),
      content: stageDraft.selfAgentDraft
    });
    runtime.postStageMessage({
      userId,
      conversationId: directConversationId,
      participantKey: buildCounterpartParticipantKey('lin-zhou', 'agent'),
      content: stageDraft.counterpartAgentDraft
    });
    const ritual = runtime.scheduleRelationshipRitual({
      userId,
      contactId: 'lin-zhou',
      kind: 'duo_task',
      scheduledFor: '2026-03-27T14:00:00+08:00',
      note: '一起把 Demo 收尾'
    });
    runtime.completeRelationshipRitual({
      userId,
      ritualId: ritual.ritual.id,
      note: '已完成收尾并约好复盘'
    });
  } finally {
    runtime.close();
  }
}

{
  const runtime = createMyDashboardRuntime({ dbPath, backupDir });
  try {
    const initial = runtime.openMyHome({
      userId,
      principalKey: 'self_human',
      principalRole: 'owner',
      vaultSecret
    });
    runtime.updateProfile({
      userId,
      displayName: '林闻',
      agentDisplayName: '闻闻分身',
      headline: '把焦虑拆成计划，把记忆炼成可信分身',
      growthFocus: '让分身先学会识别边界，再学会替我出面',
      city: '上海',
      occupation: 'AI 产品探索者'
    });
    runtime.completeTrainingTask({
      userId,
      taskId: initial.sync.trainingTasks[0].id
    });
    runtime.resolveErrorReplay({
      userId,
      replayId: initial.sync.errorReplays[0].id,
      resolvedNote: '统一走安全替代路径'
    });
    runtime.updatePersonaConfig({
      userId,
      growthMode: 'resonant',
      awakeningSeed: 58,
      activeMaskId: 'career_mask',
      dna: {
        warmth: 68,
        curiosity: 86,
        directness: 74,
        playfulness: 52,
        steadiness: 88
      },
      values: ['真实', '边界', '长期主义'],
      masks: [
        {
          id: 'career_mask',
          label: '职业出面',
          scenarioKey: 'career_mode',
          tone: 'calm_confident',
          openness: 'medium',
          boundaryTags: ['不夸大经历', '先确认交付边界'],
          styleTags: ['利落', '有温度'],
          isDefault: true
        }
      ]
    });
    runtime.saveMemoryEntry({
      userId,
      vaultSecret,
      title: '现金流底线',
      summary: '接下来 90 天不能做高风险决定。',
      content: '现金流只够 90 天，转岗动作要保留兜底方案。',
      memoryKind: 'constraint',
      permissionScope: 'private',
      emotion: 'anxious',
      source: 'weekly_review',
      tags: ['现金流', '转岗']
    });
    runtime.updateAuthorization({
      userId,
      resourceKey: 'contacts',
      status: 'authorized',
      detail: '允许分身读取熟人关系上下文'
    });
    runtime.createLocalBackup({
      userId,
      label: 'after-unified-home'
    });
  } finally {
    runtime.close();
  }
}

const unifiedRuntime = createUnifiedUIRuntime({ dbPath, backupDir });

try {
  const xianxiaHome = unifiedRuntime.openWaterfallHome({
    userId,
    homeKey: 'xianxia'
  });
  unifiedRuntime.saveFeedScrollState({
    userId,
    surfaceKey: xianxiaHome.surfaceKey,
    anchorCardId: xianxiaHome.cards[0]?.cardId,
    anchorOffset: 168
  });
  unifiedRuntime.trackFeedCardEvent({
    userId,
    surfaceKey: xianxiaHome.surfaceKey,
    cardId: xianxiaHome.cards[0]?.cardId,
    cardType: xianxiaHome.cards[0]?.cardType,
    referenceId: xianxiaHome.cards[0]?.referenceId,
    eventType: 'impression',
    route: xianxiaHome.cards[0]?.route
  });

  const masterHome = unifiedRuntime.openWaterfallHome({
    userId,
    homeKey: 'masters',
    query: 'AI 产品'
  });
  unifiedRuntime.saveFeedScrollState({
    userId,
    surfaceKey: masterHome.surfaceKey,
    anchorCardId: masterHome.cards[1]?.cardId,
    anchorOffset: 240
  });
  unifiedRuntime.trackFeedCardEvent({
    userId,
    surfaceKey: masterHome.surfaceKey,
    cardId: masterHome.cards[1]?.cardId,
    cardType: masterHome.cards[1]?.cardType,
    referenceId: masterHome.cards[1]?.referenceId,
    eventType: 'open',
    route: masterHome.cards[1]?.route
  });

  const earnHome = unifiedRuntime.openWaterfallHome({
    userId,
    homeKey: 'earn_social',
    laneId: 'job_hiring',
    viewerTags: ['AI 产品', '面试']
  });
  unifiedRuntime.saveFeedScrollState({
    userId,
    surfaceKey: earnHome.surfaceKey,
    anchorCardId: earnHome.cards[2]?.cardId,
    anchorOffset: 312
  });
  unifiedRuntime.trackFeedCardEvent({
    userId,
    surfaceKey: earnHome.surfaceKey,
    cardId: earnHome.cards[0]?.cardId,
    cardType: earnHome.cards[0]?.cardType,
    referenceId: earnHome.cards[0]?.referenceId,
    eventType: 'continue',
    route: earnHome.cards[0]?.route
  });

  const myHome = unifiedRuntime.openWaterfallHome({
    userId,
    homeKey: 'my',
    principalKey: 'self_human',
    principalRole: 'owner',
    vaultSecret
  });
  unifiedRuntime.saveFeedScrollState({
    userId,
    surfaceKey: myHome.surfaceKey,
    anchorCardId: myHome.cards[0]?.cardId,
    anchorOffset: 196
  });
  unifiedRuntime.trackFeedCardEvent({
    userId,
    surfaceKey: myHome.surfaceKey,
    cardId: myHome.cards[0]?.cardId,
    cardType: myHome.cards[0]?.cardType,
    referenceId: myHome.cards[0]?.referenceId,
    eventType: 'impression',
    route: myHome.cards[0]?.route
  });

  const messagesHub = unifiedRuntime.openConversationHub({
    userId,
    limit: 8
  });
  unifiedRuntime.saveFeedScrollState({
    userId,
    surfaceKey: messagesHub.surfaceKey,
    anchorCardId: messagesHub.hubList[0]?.conversationId,
    anchorOffset: 128
  });

  const messageDetail = unifiedRuntime.openConversationDetail({
    userId,
    conversationId: directConversationId,
    markRead: true,
    limit: 40
  });
  unifiedRuntime.saveFeedScrollState({
    userId,
    surfaceKey: messageDetail.surfaceKey,
    anchorCardId: messageDetail.contextArea.cards[0]?.cardId,
    anchorOffset: 88
  });
  unifiedRuntime.trackFeedCardEvent({
    userId,
    surfaceKey: messageDetail.surfaceKey,
    cardId: messageDetail.contextArea.cards[0]?.cardId,
    cardType: messageDetail.contextArea.cards[0]?.cardType,
    referenceId: messageDetail.contextArea.cards[0]?.referenceId,
    eventType: 'open',
    route: messageDetail.contextArea.cards[0]?.route
  });

  const inspection = unifiedRuntime.inspectUnifiedUIState({
    userId
  });

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          xianxiaCardTypes: [...new Set(xianxiaHome.cards.map((card) => card.cardType))],
          masterCardTypes: [...new Set(masterHome.cards.map((card) => card.cardType))],
          earnCardTypes: [...new Set(earnHome.cards.map((card) => card.cardType))],
          myCardTypes: [...new Set(myHome.cards.map((card) => card.cardType))],
          xianxiaScrollAnchor: inspection.scrollStates.find((item) => item.surfaceKey === xianxiaHome.surfaceKey)?.anchorCardId ?? null,
          masterScrollAnchor: inspection.scrollStates.find((item) => item.surfaceKey === masterHome.surfaceKey)?.anchorCardId ?? null,
          messagesUnreadTotal: messagesHub.unreadTotal,
          messageHubHighlights: messagesHub.highlights.length,
          messageDetailContextTypes: messageDetail.contextArea.cards.map((card) => card.sourceKind),
          messageTimelineGroups: messageDetail.timeline.groups.length,
          myPrivacyBackups: myHome.cards.find((card) => card.sourceKind === 'my_privacy')?.metrics.find((metric) => metric.label === '备份')?.value ?? null,
          cardEventCount: inspection.counts.cardEvents,
          scrollStateCount: inspection.counts.scrollStates
        },
        xianxiaHome,
        masterHome,
        earnHome,
        myHome,
        messagesHub,
        messageDetail,
        inspection
      },
      null,
      2
    )
  );
} finally {
  unifiedRuntime.close();
}
