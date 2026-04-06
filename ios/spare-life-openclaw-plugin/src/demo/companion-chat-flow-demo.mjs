import { existsSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import {
  buildCounterpartParticipantKey,
  buildGroupParticipantKey,
  buildSelfParticipantKey
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';
import { createCompanionChatRuntime } from '../handlers/companionChatHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-companion-chat.sqlite'));
if (args.values.reset && existsSync(dbPath)) {
  unlinkSync(dbPath);
}

const runtime = createCompanionChatRuntime({ dbPath });
const userId = 'demo-user';

try {
  const initialHome = runtime.openMessagesHome({
    userId,
    limit: 8
  });
  const initialLocatorOpen = runtime.openConversation({
    userId,
    locator: initialHome.recentChats[0]?.locator,
    markRead: false,
    limit: 12
  });

  const directTurn = runtime.sendDirectMessage({
    userId,
    contactId: 'lin-zhou',
    text: '我这两天被 Demo 和作品集压得有点紧，周六想和你一起把可演示版本收尾。'
  });
  const homeAfterDirect = runtime.openMessagesHome({
    userId,
    limit: 8
  });
  const searchHits = runtime.searchConversation({
    userId,
    conversationId: directTurn.conversation.id,
    query: 'Demo 收尾',
    limit: 8
  });

  const maskUpdate = runtime.updateContactMask({
    userId,
    contactId: 'lin-zhou',
    tone: 'gentle',
    openness: 'open',
    boundaryTags: ['先说真实压力', '给明确邀请', '别急着求结论'],
    overrideRules: ['work_stress_first_empathy'],
    signature: '先把压力说清，再一起定动作。',
    changeSummary: '工作压力场景下，对周琳先共情再推进'
  });

  const sharedStageDraft = runtime.draftSharedStage({
    userId,
    contactId: 'lin-zhou',
    text: '这周末想一起收尾 Demo，但我怕自己先慌掉。'
  });
  runtime.grantStageAccess({
    userId,
    conversationId: directTurn.conversation.id,
    participantKey: buildSelfParticipantKey('agent'),
    granted: true
  });
  runtime.grantStageAccess({
    userId,
    conversationId: directTurn.conversation.id,
    participantKey: buildCounterpartParticipantKey('lin-zhou', 'agent'),
    granted: true
  });
  runtime.postStageMessage({
    userId,
    conversationId: directTurn.conversation.id,
    participantKey: buildSelfParticipantKey('human'),
    content: '我先说真人视角：周六我只想收尾可演示版本，不再加新功能。'
  });
  runtime.postStageMessage({
    userId,
    conversationId: directTurn.conversation.id,
    participantKey: buildSelfParticipantKey('agent'),
    content: sharedStageDraft.selfAgentDraft
  });
  runtime.postStageMessage({
    userId,
    conversationId: directTurn.conversation.id,
    participantKey: buildCounterpartParticipantKey('lin-zhou', 'agent'),
    content: sharedStageDraft.counterpartAgentDraft
  });
  const sharedStageClosure = runtime.postStageMessage({
    userId,
    conversationId: directTurn.conversation.id,
    participantKey: buildCounterpartParticipantKey('lin-zhou', 'human'),
    content: '可以，我周六下午留 90 分钟陪你把 Demo 收成能讲清楚的版本。'
  });

  const ritualScheduled = runtime.scheduleRelationshipRitual({
    userId,
    contactId: 'lin-zhou',
    kind: 'duo_task',
    scheduledFor: '2026-03-27T14:00:00+08:00',
    note: '一起把 Demo day 版本收尾并做一张纪念卡'
  });
  const ritualCompleted = runtime.completeRelationshipRitual({
    userId,
    ritualId: ritualScheduled.ritual.id,
    note: '已经一起收尾完 Demo，并把下次复盘时间也定了。'
  });

  const groupBefore = runtime.openGroupConversation({
    userId,
    groupId: 'weekend-makers',
    limit: 20
  });
  runtime.postGroupMessage({
    userId,
    groupId: 'weekend-makers',
    actorKey: buildSelfParticipantKey('human'),
    content: '我建议周六前半段先砍需求，后半段只演示一个闭环。'
  });
  const noisyGroupMessage = runtime.postGroupMessage({
    userId,
    groupId: 'weekend-makers',
    actorKey: buildGroupParticipantKey('chen-miao', 'human'),
    content: '好耶冲冲冲！！！'
  });
  runtime.postGroupMessage({
    userId,
    groupId: 'weekend-makers',
    actorKey: buildGroupParticipantKey('lin-zhou', 'human'),
    content: '同意，先砍需求再 Demo，会比两头都顾更稳。'
  });

  const voteLaunch = runtime.launchGroupVote({
    userId,
    groupId: 'weekend-makers',
    question: '周六这轮先做哪件事？',
    options: ['先砍需求', '先做 Demo day', '先写复盘']
  });
  const demandCutOption = voteLaunch.vote.options.find((option) => option.label === '先砍需求');
  runtime.castGroupVote({
    userId,
    voteId: voteLaunch.vote.id,
    voterKey: 'self',
    optionId: demandCutOption.optionId
  });
  runtime.castGroupVote({
    userId,
    voteId: voteLaunch.vote.id,
    voterKey: 'lin-zhou',
    optionId: demandCutOption.optionId
  });
  runtime.castGroupVote({
    userId,
    voteId: voteLaunch.vote.id,
    voterKey: 'chen-miao',
    optionId: demandCutOption.optionId
  });
  const closedVote = runtime.castGroupVote({
    userId,
    voteId: voteLaunch.vote.id,
    voterKey: 'he-qi',
    optionId: voteLaunch.vote.options.find((option) => option.label === '先做 Demo day').optionId
  });
  const groupSummary = runtime.summarizeGroup({
    userId,
    groupId: 'weekend-makers',
    voteId: voteLaunch.vote.id
  });

  const reopenedDirect = runtime.openConversation({
    userId,
    conversationId: directTurn.conversation.id,
    markRead: true,
    limit: 40
  });
  const finalHome = runtime.openMessagesHome({
    userId,
    limit: 8
  });
  const state = runtime.inspectCompanionState({
    userId
  });

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          initialRecentTop: initialHome.recentChats[0]?.title ?? null,
          initialRecentCardID: initialHome.recentChats[0]?.canonicalCardID ?? null,
          initialRecentLocatorKind: initialHome.recentChats[0]?.locator?.kind ?? null,
          initialHomeHandoffTarget: initialHome.handoff?.targetSurface ?? null,
          initialHomeHandoffRouteKind: initialHome.handoff?.route?.kind ?? null,
          locatorOpenConversationID: initialLocatorOpen.conversation.id,
          topAfterDirect: homeAfterDirect.recentChats[0]?.title ?? null,
          searchHitCount: searchHits.hits.length,
          unreadAfterDirectReply: directTurn.conversation.unreadCount,
          unreadAfterOpen: reopenedDirect.conversation.unreadCount,
          maskHistoryCount: maskUpdate.history.length,
          fourRoleActors: [...new Set(sharedStageClosure.messages.map((message) => message.actorRole))],
          relationshipLevelAfterRitual: ritualCompleted.relationship.level,
          relationshipWarmthAfterRitual: ritualCompleted.relationship.warmthScore,
          ritualCount: ritualCompleted.rituals.length,
          memoryLayers: reopenedDirect.contextCards.find((card) => card.cardType === 'memory')?.payload.map((item) => item.layer) ?? [],
          latestMemorySummary: reopenedDirect.contextCards.find((card) => card.cardType === 'memory')?.payload[0]?.summary ?? null,
          groupMessagesBefore: groupBefore.messages.length,
          noisyMessageSuppressed: noisyGroupMessage.suppressed,
          closedVoteStatus: closedVote.vote.status,
          closedVoteSummary: closedVote.vote.resultSummary,
          groupSummarySuppressedCount: groupSummary.summary.suppressedCount,
          finalRecentTop: finalHome.recentChats[0]?.title ?? null,
          totalMessages: state.counts.messages,
          totalVotes: state.counts.votes,
          totalSummaries: state.counts.summaries,
          totalRituals: state.counts.rituals
        },
        initialHome,
        initialLocatorOpen,
        directTurn,
        homeAfterDirect,
        searchHits,
        maskUpdate,
        sharedStageDraft,
        sharedStageClosure,
        ritualScheduled,
        ritualCompleted,
        groupBefore,
        noisyGroupMessage,
        voteLaunch,
        closedVote,
        groupSummary,
        reopenedDirect,
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
