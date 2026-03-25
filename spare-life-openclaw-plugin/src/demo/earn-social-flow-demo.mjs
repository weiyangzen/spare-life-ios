import { existsSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { createEarnSocialRuntime } from '../handlers/earnSocialFlowHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-earn-social.sqlite'));
if (args.values.reset && existsSync(dbPath)) {
  unlinkSync(dbPath);
}

const runtime = createEarnSocialRuntime({ dbPath });
const userId = 'demo-user';

try {
  const firstHome = runtime.openEarnSocialHome({
    userId,
    laneId: 'job_hiring',
    viewerTags: ['AI 产品', '作品集', '转岗']
  });

  const firstDeck = runtime.browsePersonaDeck({
    userId,
    laneId: 'job_hiring',
    viewerTags: ['AI 产品', '作品集']
  });
  const likedCard = firstDeck.cards[0];
  const secondCard = firstDeck.cards.find((card) => card.agentId !== likedCard.agentId) ?? firstDeck.cards[0];

  const likedFeedback = runtime.recordPersonaFeedback({
    userId,
    laneId: 'job_hiring',
    agentId: likedCard.agentId,
    feedback: 'like',
    reason: '岗位标签和反馈速度都合适'
  });

  const publishedIntent = runtime.publishIntent({
    userId,
    laneId: 'job_hiring',
    templateId: 'job_seek',
    mode: 'direct',
    targetAgentId: likedCard.agentId,
    viewerTags: ['AI 产品', 'B 端工具'],
    formPayload: {
      role: 'AI 产品经理',
      experience: '做过 B 端效率工具，正在补作品集',
      city: '上海',
      salary: 35000
    }
  });

  const secondDeck = runtime.browsePersonaDeck({
    userId,
    laneId: 'job_hiring',
    intentId: publishedIntent.intent.id,
    viewerTags: ['AI 产品', 'B 端工具']
  });

  const icebreak = runtime.startDualAgentIcebreak({
    userId,
    intentId: publishedIntent.intent.id,
    targetAgentId: likedCard.agentId
  });
  const consentOne = runtime.recordHumanConsent({
    sessionId: icebreak.session.id,
    side: 'initiator',
    granted: true
  });
  const consentTwo = runtime.recordHumanConsent({
    sessionId: icebreak.session.id,
    side: 'counterpart',
    granted: true
  });
  const leadProgress = runtime.advanceLeadStage({
    leadId: consentTwo.lead.id,
    userId,
    stageKey: 'active_delivery',
    detail: {
      nextAction: '双方改为真人沟通，开始推进岗位对齐与面试安排'
    }
  });
  const leadOutcome = runtime.recordLeadOutcome({
    leadId: consentTwo.lead.id,
    userId,
    outcomeCode: 'interview_scheduled',
    detail: {
      scheduledAt: '2026-03-27T19:00:00+08:00',
      interviewer: '嘉禾 招聘方分身'
    }
  });
  const leadSettlement = runtime.settleLeadOutcome({
    leadId: consentTwo.lead.id,
    userId,
    settlementType: 'reward',
    amount: 18,
    detail: {
      reason: '已促成求职赛道进入真人面试'
    }
  });

  const trends = runtime.exploreLaneTrends({
    userId,
    claimLaneId: 'job_hiring'
  });
  const duplicateTrendClaim = runtime.exploreLaneTrends({
    userId,
    claimLaneId: 'job_hiring'
  });

  const arena = runtime.createArenaMatch({
    userId,
    laneId: 'job_hiring',
    theme: 'AI 产品岗位 30 秒抢答',
    challengerAgentId: likedCard.agentId,
    opponentAgentId: secondCard.agentId
  });
  runtime.castArenaVote({
    matchId: arena.match.id,
    voterUserId: 'spectator-one',
    preferredSide: 'challenger',
    weight: 1
  });
  runtime.castArenaVote({
    matchId: arena.match.id,
    voterUserId: 'spectator-two',
    preferredSide: 'challenger',
    weight: 2
  });
  const resolvedArena = runtime.resolveArenaMatch({
    userId,
    matchId: arena.match.id
  });

  const firstBondTask = consentTwo.bondTasks[0];
  runtime.completeBondTask({
    userId,
    taskId: firstBondTask.id,
    increment: 1
  });
  const completedCheckin = runtime.completeBondTask({
    userId,
    taskId: firstBondTask.id,
    increment: 1
  });
  const completedSharedGoal = runtime.completeBondTask({
    userId,
    taskId: consentTwo.bondTasks[1].id,
    increment: 1
  });

  const finalHome = runtime.openEarnSocialHome({
    userId,
    laneId: 'job_hiring',
    viewerTags: ['AI 产品', '面试']
  });
  const state = runtime.inspectEarnSocialState(userId);

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          laneCount: state.counts.lanes,
          templateCount: state.counts.templates,
          feedCardTypes: [...new Set(finalHome.home.feed.map((card) => card.cardType))],
          finalIntentStatus: publishedIntent.intent.id === state.recentIntents[0]?.id ? state.recentIntents[0]?.status : state.recentIntents.find((item) => item.id === publishedIntent.intent.id)?.status ?? null,
          publishedIntentRoute: publishedIntent.intent.route,
          deckSizeBeforeIntent: firstDeck.cards.length,
          deckSizeAfterIntent: secondDeck.cards.length,
          icebreakStatusAfterHandoff: consentTwo.session.status,
          humanThreadRoute: consentTwo.route,
          leadStage: state.recentLeads[0]?.currentStageKey ?? null,
          leadOutcome: state.recentLeads[0]?.outcome?.outcomeCode ?? null,
          leadSettlementCount: state.recentLeads[0]?.settlements?.length ?? 0,
          leadAuditEvents: state.recentLeads[0]?.auditTrail?.length ?? 0,
          bondLevel: completedSharedGoal.bond.level,
          bondMilestones: state.counts.bondMilestones,
          trendTopLane: trends.trends[0]?.laneTitle ?? null,
          trendRewardApplied: Boolean(trends.reward?.applied),
          duplicateTrendRewardBlocked: duplicateTrendClaim.reward?.applied === false,
          arenaWinner: resolvedArena.match.winnerSide,
          arenaSettlementApplied: resolvedArena.settlement.applied,
          leadSettlementApplied: leadSettlement.settlementLedger.applied || leadSettlement.settlementLedger.reason === 'duplicate_rule',
          walletBalance: state.wallet.balance,
          ledgerEntries: state.counts.ledgerEntries
        },
        firstHome,
        firstDeck,
        likedFeedback,
        publishedIntent,
        secondDeck,
        icebreak,
        consentOne,
        consentTwo,
        leadProgress,
        leadOutcome,
        leadSettlement,
        trends,
        duplicateTrendClaim,
        arena,
        resolvedArena,
        completedCheckin,
        completedSharedGoal,
        finalHome,
        state
      },
      null,
      2
    )
  );
} finally {
  runtime.close();
}
