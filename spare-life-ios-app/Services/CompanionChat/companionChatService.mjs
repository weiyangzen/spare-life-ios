import {
  clipText
} from '../../Domain/Models/masterContracts.mjs';
import {
  buildConversationRoute,
  buildCounterpartParticipantKey,
  buildDefaultDirectParticipants,
  buildDefaultGroupParticipants,
  buildGroupParticipantKey,
  buildGroupVoteRoute,
  buildMaskRoute,
  buildMessagesHomeRoute,
  buildRelationshipRoute,
  buildRitualTitle,
  buildSelfParticipantKey,
  collectMaskTerms,
  COMPANION_CONTACT_SEEDS,
  COMPANION_GROUP_SEEDS,
  deriveRelationshipLevelFromWarmth
} from '../../Domain/Models/companionContracts.mjs';
import {
  clampScore,
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';
import {
  collapseMemoryLayers
} from '../../LocalBackend/ConversationMemory/companionRecallService.mjs';

function minutesBefore(nowIso, minutes) {
  return new Date(new Date(nowIso).getTime() - minutes * 60_000).toISOString();
}

export function buildCompanionWorkspaceSeed({ userId, nowIso = isoNow() }) {
  const contacts = COMPANION_CONTACT_SEEDS.map((contact) => ({
    ...contact,
    userId,
    createdAt: nowIso,
    updatedAt: nowIso
  }));
  const groups = COMPANION_GROUP_SEEDS.map((group) => ({
    ...group,
    userId,
    route: buildConversationRoute({
      conversationId: stableId('companion-conversation', userId, group.id),
      kind: 'group',
      groupId: group.id
    }),
    createdAt: nowIso,
    updatedAt: nowIso
  }));

  const directSeeds = [
    {
      contactId: 'lin-zhou',
      warmthScore: 61,
      latestSummary: '最近围绕作品集和 Demo 收尾互相打气，节奏偏紧但愿意一起拆解。',
      memorialCard: {
        title: '第一次一起做 Demo 收尾',
        summary: '你们已经形成“先缩范围，再一起推进”的默契。',
        createdAt: minutesBefore(nowIso, 360)
      },
      messages: [
        {
          actorKey: buildSelfParticipantKey('human'),
          actorRole: 'self_human',
          channelKind: 'timeline',
          content: '昨天把作品集拆了一半，但还是担心周末 Demo 收不完。',
          createdAt: minutesBefore(nowIso, 160),
          unreadForOwner: 0
        },
        {
          actorKey: buildCounterpartParticipantKey('lin-zhou', 'human'),
          actorRole: 'counterpart_human',
          channelKind: 'timeline',
          content: '先别把范围想太满，我们把周六目标压成一个能演示的版本就够了。',
          createdAt: minutesBefore(nowIso, 150),
          unreadForOwner: 1
        }
      ]
    },
    {
      contactId: 'chen-miao',
      warmthScore: 74,
      latestSummary: '和陈淼的联系偏轻松，最近在讨论跑步和周末咖啡。',
      memorialCard: {
        title: '上周跑步后喝咖啡',
        summary: '轻松场景下更容易自然打开话题。',
        createdAt: minutesBefore(nowIso, 720)
      },
      messages: [
        {
          actorKey: buildSelfParticipantKey('human'),
          actorRole: 'self_human',
          channelKind: 'timeline',
          content: '这周忙得有点乱，可能得把跑步改成散步了。',
          createdAt: minutesBefore(nowIso, 500),
          unreadForOwner: 0
        },
        {
          actorKey: buildCounterpartParticipantKey('chen-miao', 'human'),
          actorRole: 'counterpart_human',
          channelKind: 'timeline',
          content: '也行呀，那就散步完顺手买杯咖啡，别把周末安排成 KPI。',
          createdAt: minutesBefore(nowIso, 480),
          unreadForOwner: 0
        }
      ]
    },
    {
      contactId: 'he-qi',
      warmthScore: 49,
      latestSummary: '关系在升温，但更依赖清晰边界和确定时间安排。',
      memorialCard: {
        title: '第一次一起做设计复盘',
        summary: '通过明确时间盒和分工，避免了各说各话。',
        createdAt: minutesBefore(nowIso, 960)
      },
      messages: [
        {
          actorKey: buildSelfParticipantKey('human'),
          actorRole: 'self_human',
          channelKind: 'timeline',
          content: '周日晚我想和你对一下新版本复盘，但最好控制在 30 分钟内。',
          createdAt: minutesBefore(nowIso, 980),
          unreadForOwner: 0
        },
        {
          actorKey: buildCounterpartParticipantKey('he-qi', 'human'),
          actorRole: 'counterpart_human',
          channelKind: 'timeline',
          content: '可以，先把要看的 3 个问题发我，我好提前准备。',
          createdAt: minutesBefore(nowIso, 960),
          unreadForOwner: 0
        }
      ]
    }
  ];

  const groupSeeds = [
    {
      groupId: 'weekend-makers',
      messages: [
        {
          actorKey: buildGroupParticipantKey('lin-zhou', 'human'),
          actorRole: 'group_human',
          channelKind: 'timeline',
          content: '这周六先做 Demo day 还是先把需求砍一轮？',
          createdAt: minutesBefore(nowIso, 220),
          unreadForOwner: 1,
          signalScore: 78
        },
        {
          actorKey: buildGroupParticipantKey('chen-miao', 'human'),
          actorRole: 'group_human',
          channelKind: 'timeline',
          content: '我倾向先砍需求，不然一上来展示会虚。',
          createdAt: minutesBefore(nowIso, 208),
          unreadForOwner: 1,
          signalScore: 74
        },
        {
          actorKey: buildGroupParticipantKey('he-qi', 'human'),
          actorRole: 'group_human',
          channelKind: 'timeline',
          content: '哈哈哈哈冲冲冲！！！',
          createdAt: minutesBefore(nowIso, 205),
          unreadForOwner: 1,
          signalScore: 18
        }
      ]
    }
  ];

  return {
    contacts,
    groups,
    directSeeds,
    groupSeeds
  };
}

function maskToneGuidance(tone) {
  switch (tone) {
    case 'playful':
      return '用一点轻松和画面感，避免把氛围压得太重。';
    case 'steady':
      return '优先把需求和时间边界说清，再补情绪。';
    case 'direct':
      return '可以更直接表达真实诉求，但不要把判断压到对方身上。';
    case 'gentle':
    default:
      return '先接住情绪，再给具体请求。';
  }
}

function opennessGuidance(openness) {
  switch (openness) {
    case 'open':
      return '这次可以先说真实感受，再抛出邀请。';
    case 'guarded':
      return '这次先给一个明确请求，不要一次抖出太多情绪。';
    case 'balanced':
    default:
      return '这次先给对方一个上下文，再说明你想要什么回应。';
  }
}

function actionHintForContact(contactId) {
  switch (contactId) {
    case 'lin-zhou':
      return '把目标缩成“周六只收尾可演示版本”，会比泛泛地说很累更容易得到回应。';
    case 'chen-miao':
      return '给一个轻量邀约，比如散步或咖啡，比抽象地说想聊天更容易接住。';
    case 'he-qi':
      return '把时间盒和想讨论的 2-3 个问题列清楚，对方会更安心。';
    default:
      return '把你期待的下一步说具体。';
  }
}

export function composeSelfAgentAssist({ contact, userMessage, mask, recalledMemories = [], relationship }) {
  const memoryLead = recalledMemories[0]
    ? `记得你们上次停在：${clipText(recalledMemories[0].summary, 48)}。`
    : `${contact.displayName} 这边更容易接住具体而不失温度的表达。`;
  const relationshipLead = relationship?.latestSummary
    ? `当前关系摘要：${clipText(relationship.latestSummary, 46)}。`
    : '';
  const boundaryLine = (mask?.boundaryTags ?? []).slice(0, 2).join('、') || '保留一点边界感';

  return `${memoryLead}${relationshipLead}${maskToneGuidance(mask?.tone)}${opennessGuidance(
    mask?.openness
  )}守住“${boundaryLine}”，${actionHintForContact(contact.id)}`;
}

export function composeCounterpartReply({ contact, userMessage, recalledMemories = [], relationship }) {
  const normalized = sanitizeText(userMessage);
  const opening = recalledMemories[0]
    ? `我还记得上次你提到“${clipText(recalledMemories[0].summary, 34)}”。`
    : '';
  const warmthLead =
    clampScore(relationship?.warmthScore ?? 40) >= 65
      ? '你可以直接把想法丢过来，我愿意一起接。'
      : '你先把最关键的部分告诉我，我们一点点来。';

  let action = '先把这次最想推进的一步定下来，我陪你一起拆。';
  if (/担心|焦虑|压力|撑/.test(normalized)) {
    action = '先别急着证明自己，我们把范围缩小到今晚或周末能完成的一步。';
  } else if (/周末|咖啡|散步|跑步/.test(normalized)) {
    action = '那我们就约个低负担版本，先把联系续上，不用一次聊很深。';
  } else if (/复盘|计划|时间|30\s*分钟/.test(normalized)) {
    action = '可以，把你想讨论的点列出来，我会按那个节奏配合。';
  }

  return `${opening}${warmthLead}${action}`.trim();
}

export function composeCounterpartAgentReply({ contact, userMessage, relationship }) {
  const tension = /担心|焦虑|压力|卡住/.test(sanitizeText(userMessage))
    ? '先帮 TA 把压力拆成一个更小的答复单元。'
    : '可以让 TA 先确认边界，再决定是不是立刻接手。';
  const warmth = clampScore(relationship?.warmthScore ?? 40);
  return `我先替 ${contact.displayName} 做边界说明：当前关系温度约 ${Math.round(
    warmth
  )} 分。${tension}`;
}

export function computeWarmthDelta({ text = '', ritualKind = null, voteResolved = false }) {
  const normalized = sanitizeText(text);
  let delta = 2;
  if (/一起|安排|周末|共创|完成|谢谢|愿意/.test(normalized)) {
    delta += 5;
  }
  if (/担心|焦虑|压力|卡住/.test(normalized)) {
    delta += 2;
  }
  if (ritualKind === 'duo_task') {
    delta += 8;
  }
  if (ritualKind === 'memory_lane' || ritualKind === 'memorial') {
    delta += 5;
  }
  if (voteResolved) {
    delta += 3;
  }
  return delta;
}

export function buildRelationshipSnapshot({ contact, warmthScore, previousSummary, latestInteraction }) {
  const level = deriveRelationshipLevelFromWarmth(warmthScore);
  const latestSummary = uniqueStrings([
    previousSummary,
    latestInteraction
  ])
    .filter(Boolean)
    .join(' ')
    .trim();

  return {
    contactId: contact.id,
    level,
    warmthScore: clampScore(warmthScore),
    latestSummary:
      latestSummary ||
      `${contact.displayName} 的互动以 ${contact.defaultMask.signature.toLowerCase()} 为主。`
  };
}

export function buildRitualRecord({ contact, relationship, kind, scheduledFor, note, nowIso = isoNow() }) {
  const title = buildRitualTitle(kind, contact.displayName);
  const summary =
    kind === 'duo_task'
      ? `围绕“${sanitizeText(note) || '一起推进一个小目标'}”安排了双人任务，计划时间为 ${scheduledFor ?? '待定'}。`
      : kind === 'memory_lane'
        ? `把这段互动写进回忆线：${sanitizeText(note) || '记住最近一次彼此接住的时刻'}。`
        : kind === 'memorial'
          ? `生成纪念卡，记录这次关系推进：${sanitizeText(note) || '一次值得留下的共同瞬间'}。`
          : `安排一次轻量报到，计划时间为 ${scheduledFor ?? '待定'}。`;

  return {
    ritualId: stableId('companion-ritual', relationship.contactId, kind, scheduledFor ?? nowIso, note ?? ''),
    relationshipId: relationship.id,
    conversationId: relationship.conversationId,
    ritualKind: kind,
    title,
    summary,
    status: 'scheduled',
    scheduledFor: scheduledFor ?? null,
    memorialCard: {
      title,
      summary: clipText(summary, 72),
      createdAt: nowIso
    },
    memoryLaneSummary: clipText(
      `${contact.displayName} 的关系温度来到 ${Math.round(relationship.warmthScore)} 分，这次重点是 ${sanitizeText(note) || '稳住节奏'}`,
      92
    )
  };
}

export function scoreMessageSignal(content) {
  const normalized = sanitizeText(content);
  if (!normalized) {
    return 0;
  }
  let score = Math.min(60, normalized.length * 1.3);
  if (normalized.length <= 8) {
    score -= 22;
  }
  if (/哈哈|冲冲冲|666|？？？|!!!/i.test(normalized)) {
    score -= 18;
  }
  if (/周六|周末|投票|安排|需求|总结|Demo|复盘|时间/.test(normalized)) {
    score += 18;
  }
  if (/因为|所以|建议|先|然后|如果/.test(normalized)) {
    score += 8;
  }
  return clampScore(score);
}

export function buildGroupVote({ groupId, question, options, createdBy, nowIso = isoNow() }) {
  return {
    id: stableId('companion-vote', groupId, question, nowIso),
    groupId,
    question,
    status: 'open',
    options: uniqueStrings(options).map((option, index) => ({
      optionId: stableId('companion-vote-option', groupId, question, option, index),
      label: option
    })),
    route: buildGroupVoteRoute(stableId('companion-vote', groupId, question, nowIso)),
    createdBy,
    createdAt: nowIso,
    updatedAt: nowIso
  };
}

export function tallyGroupVote({ vote, ballots = [] }) {
  const counts = new Map((vote?.options ?? []).map((option) => [option.optionId, 0]));
  for (const ballot of ballots) {
    counts.set(ballot.optionId, (counts.get(ballot.optionId) ?? 0) + 1);
  }
  const ranked = (vote?.options ?? [])
    .map((option) => ({
      ...option,
      count: counts.get(option.optionId) ?? 0
    }))
    .sort((left, right) => right.count - left.count || left.label.localeCompare(right.label));
  return {
    winningOption: ranked[0] ?? null,
    rankedOptions: ranked
  };
}

export function buildGroupSummary({ group, messages = [], vote = null, ballots = [] }) {
  const meaningfulMessages = messages.filter((message) => !message.suppressed);
  const suppressedCount = messages.length - meaningfulMessages.length;
  const recentTopics = uniqueStrings(
    meaningfulMessages.slice(-4).flatMap((message) => sanitizeText(message.content).split(/[、，,。.!？?\s]+/))
  ).slice(0, 6);
  const voteResult = vote ? tallyGroupVote({ vote, ballots }) : null;
  const headline = voteResult?.winningOption
    ? `群里当前更倾向 “${voteResult.winningOption.label}”。`
    : '群里还在收敛本轮重点。';
  const detail = recentTopics.length
    ? `高信号词集中在：${recentTopics.join(' / ')}。`
    : '当前还缺少足够高信号内容。';
  const noiseLine =
    suppressedCount > 0 ? `已压低 ${suppressedCount} 条低信号噪音消息。` : '本轮没有触发噪音抑制。';
  return {
    summary: `${headline}${detail}${noiseLine}`,
    suppressedCount,
    winningOption: voteResult?.winningOption ?? null,
    rankedOptions: voteResult?.rankedOptions ?? []
  };
}

export function buildRecentChatCards({
  conversations,
  contactsById,
  groupsById,
  relationshipsByContactId,
  memoriesByConversationId
}) {
  return (conversations ?? []).map((conversation) => {
    const contact = conversation.contactId ? contactsById.get(conversation.contactId) : null;
    const group = conversation.groupId ? groupsById.get(conversation.groupId) : null;
    const relationship = contact ? relationshipsByContactId.get(contact.id) : null;
    const memoryCards = collapseMemoryLayers(memoriesByConversationId.get(conversation.id) ?? []);
    return {
      conversationId: conversation.id,
      title: contact?.displayName ?? group?.title ?? conversation.title,
      kind: conversation.kind,
      subtitle:
        contact?.personaSummary ??
        group?.summary ??
        conversation.lastMessagePreview ??
        '最近暂无摘要',
      unreadCount: conversation.unreadCount,
      lastMessagePreview: conversation.lastMessagePreview,
      lastMessageAt: conversation.lastMessageAt,
      route: conversation.route,
      warmthScore: relationship?.warmthScore ?? null,
      relationshipLevel: relationship?.level ?? null,
      latestMemorySummary: memoryCards[0]?.summary ?? null
    };
  });
}

export function buildConversationContext({
  conversation,
  contact = null,
  group = null,
  relationship = null,
  mask = null,
  rituals = [],
  memories = []
}) {
  return {
    conversation,
    contextCards: [
      contact
        ? {
            cardType: 'mask',
            title: '对人面具',
            route: buildMaskRoute(contact.id),
            payload: mask
          }
        : null,
      contact
        ? {
            cardType: 'relationship',
            title: '关系温度',
            route: buildRelationshipRoute(contact.id),
            payload: relationship
          }
        : null,
      {
        cardType: 'memory',
        title: group ? '群上下文摘要' : '跨会话记忆',
        route: conversation.route,
        payload: collapseMemoryLayers(memories)
      },
      rituals.length
        ? {
            cardType: 'rituals',
            title: '关系养成',
            route: conversation.route,
            payload: rituals
          }
        : null
    ].filter(Boolean),
    homeRoute: buildMessagesHomeRoute()
  };
}
