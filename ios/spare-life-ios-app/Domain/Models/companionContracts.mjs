import {
  clampScore,
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from './sceneContracts.mjs';

export const COMPANION_CONVERSATION_KINDS = new Set(['direct', 'group']);
export const COMPANION_PARTICIPANT_ROLES = new Set([
  'self_human',
  'self_agent',
  'counterpart_human',
  'counterpart_agent',
  'group_human',
  'tool_agent'
]);
export const COMPANION_CHANNEL_KINDS = new Set(['timeline', 'assistant', 'summary', 'vote']);
export const COMPANION_MASK_TONES = new Set(['gentle', 'steady', 'playful', 'direct']);
export const COMPANION_MASK_OPENNESS = new Set(['guarded', 'balanced', 'open']);
export const COMPANION_RELATIONSHIP_LEVELS = new Set(['new', 'warm', 'close']);
export const COMPANION_RITUAL_KINDS = new Set(['checkin', 'duo_task', 'memory_lane', 'memorial']);
export const COMPANION_RITUAL_STATUSES = new Set(['scheduled', 'completed', 'cancelled']);
export const COMPANION_MEMORY_LAYERS = new Set([
  'latest_state',
  'emotion_snapshot',
  'relationship_summary'
]);
export const COMPANION_GROUP_VOTE_STATUSES = new Set(['open', 'closed']);

export const COMPANION_CONTACT_SEEDS = [
  {
    id: 'lin-zhou',
    displayName: '周琳',
    personaSummary: '熟悉 AI 产品和 side project 节奏，遇到压力时会先找确定性，再给建议。',
    tags: ['AI 产品', 'side project', '作品集', '节奏感'],
    defaultMask: {
      tone: 'gentle',
      openness: 'balanced',
      boundaryTags: ['先共情', '别抢结论', '把邀请说具体'],
      signature: '先接住情绪，再一起拆行动。'
    }
  },
  {
    id: 'chen-miao',
    displayName: '陈淼',
    personaSummary: '偏活泼，适合把大问题拆成轻量邀约和有趣的下一步。',
    tags: ['播客', '跑步', '周末计划', '陪伴聊天'],
    defaultMask: {
      tone: 'playful',
      openness: 'open',
      boundaryTags: ['允许吐槽', '鼓励举例', '行动要低负担'],
      signature: '让对话先轻起来，再自然推进。'
    }
  },
  {
    id: 'he-qi',
    displayName: '何栖',
    personaSummary: '偏理性，需要边界清晰和时间安排明确，适合做复盘与计划。',
    tags: ['设计复盘', '时间管理', '任务共创', '边界感'],
    defaultMask: {
      tone: 'steady',
      openness: 'guarded',
      boundaryTags: ['先说需求', '避免情绪归因', '确认时间窗口'],
      signature: '先把边界说明白，再往下走。'
    }
  }
];

export const COMPANION_GROUP_SEEDS = [
  {
    id: 'weekend-makers',
    title: '周末项目局',
    summary: '一个围绕 AI side project、复盘和 Demo day 的熟人小群。',
    memberContactIds: ['lin-zhou', 'chen-miao', 'he-qi'],
    toolAgentName: '局内 Agent',
    noiseThreshold: 42
  }
];

export function requireCompanionEnum(value, allowedValues, fallback, fieldName) {
  if (!value) {
    return fallback;
  }
  if (!allowedValues.has(value)) {
    throw new Error(`Unsupported ${fieldName}: ${value}`);
  }
  return value;
}

export function resolveConversationKind(value, fallback = 'direct') {
  return requireCompanionEnum(value, COMPANION_CONVERSATION_KINDS, fallback, 'conversation kind');
}

export function resolveMaskTone(value, fallback = 'gentle') {
  return requireCompanionEnum(value, COMPANION_MASK_TONES, fallback, 'mask tone');
}

export function resolveMaskOpenness(value, fallback = 'balanced') {
  return requireCompanionEnum(value, COMPANION_MASK_OPENNESS, fallback, 'mask openness');
}

export function resolveRitualKind(value, fallback = 'checkin') {
  return requireCompanionEnum(value, COMPANION_RITUAL_KINDS, fallback, 'ritual kind');
}

export function resolveRelationshipLevel(value, fallback = 'new') {
  return requireCompanionEnum(value, COMPANION_RELATIONSHIP_LEVELS, fallback, 'relationship level');
}

export function resolveGroupVoteStatus(value, fallback = 'open') {
  return requireCompanionEnum(value, COMPANION_GROUP_VOTE_STATUSES, fallback, 'group vote status');
}

export function buildMessagesHomeRoute(tab = 'recent') {
  const params = new URLSearchParams({
    tab: sanitizeText(tab) || 'recent'
  });
  return `sparelife://messages/home?${params.toString()}`;
}

export function buildConversationRoute({ conversationId, kind = 'direct', contactId = null, groupId = null }) {
  const params = new URLSearchParams({
    conversation_id: sanitizeText(conversationId),
    kind: resolveConversationKind(kind)
  });
  if (sanitizeText(contactId)) {
    params.set('contact_id', sanitizeText(contactId));
  }
  if (sanitizeText(groupId)) {
    params.set('group_id', sanitizeText(groupId));
  }
  return `sparelife://messages/thread?${params.toString()}`;
}

export function buildMaskRoute(contactId) {
  return `sparelife://messages/mask?contact_id=${encodeURIComponent(sanitizeText(contactId))}`;
}

export function buildRelationshipRoute(contactId) {
  return `sparelife://messages/relationship?contact_id=${encodeURIComponent(sanitizeText(contactId))}`;
}

export function buildGroupVoteRoute(voteId) {
  return `sparelife://messages/group-vote?vote_id=${encodeURIComponent(sanitizeText(voteId))}`;
}

export function buildSelfParticipantKey(kind = 'human') {
  return kind === 'agent' ? 'self_agent' : 'self_human';
}

export function buildCounterpartParticipantKey(contactId, kind = 'human') {
  return `contact:${sanitizeText(contactId)}:${kind === 'agent' ? 'agent' : 'human'}`;
}

export function buildGroupParticipantKey(memberId, role = 'human') {
  return role === 'tool_agent'
    ? `group:${sanitizeText(memberId)}:tool_agent`
    : `group:${sanitizeText(memberId)}:${role === 'agent' ? 'agent' : 'human'}`;
}

export function participantLabel(role) {
  switch (role) {
    case 'self_agent':
      return '我方分身';
    case 'counterpart_human':
      return '对方真人';
    case 'counterpart_agent':
      return '对方分身';
    case 'tool_agent':
      return '工具 Agent';
    case 'group_human':
      return '群成员';
    case 'self_human':
    default:
      return '我';
  }
}

export function buildDefaultDirectParticipants(contact) {
  return [
    {
      participantKey: buildSelfParticipantKey('human'),
      role: 'self_human',
      displayName: '我',
      permissions: {
        canPost: true,
        canModerate: true
      }
    },
    {
      participantKey: buildSelfParticipantKey('agent'),
      role: 'self_agent',
      displayName: '我方分身',
      permissions: {
        canPost: false,
        requiresGrant: true,
        canSuggest: true
      }
    },
    {
      participantKey: buildCounterpartParticipantKey(contact.id, 'human'),
      role: 'counterpart_human',
      displayName: contact.displayName,
      permissions: {
        canPost: true
      }
    },
    {
      participantKey: buildCounterpartParticipantKey(contact.id, 'agent'),
      role: 'counterpart_agent',
      displayName: `${contact.displayName} 的分身`,
      permissions: {
        canPost: false,
        requiresGrant: true,
        canSuggest: true
      }
    }
  ];
}

export function buildDefaultGroupParticipants(group, contacts) {
  const participants = contacts.map((contact) => ({
    participantKey: buildGroupParticipantKey(contact.id, 'human'),
    role: 'group_human',
    displayName: contact.displayName,
    permissions: {
      canPost: true
    }
  }));
  participants.push({
    participantKey: buildGroupParticipantKey(group.id, 'tool_agent'),
    role: 'tool_agent',
    displayName: group.toolAgentName,
    permissions: {
      canPost: true,
      canSummarize: true,
      canLaunchVote: true
    }
  });
  return participants;
}

export function deriveRelationshipLevelFromWarmth(warmthScore) {
  const normalized = clampScore(warmthScore);
  if (normalized >= 72) {
    return 'close';
  }
  if (normalized >= 45) {
    return 'warm';
  }
  return 'new';
}

export function buildCompanionId(prefix, ...parts) {
  return stableId(prefix, ...parts, isoNow());
}

export function collectMaskTerms(mask) {
  return uniqueStrings([
    mask?.tone,
    mask?.openness,
    ...(mask?.boundaryTags ?? []),
    mask?.signature
  ]);
}

export function buildRitualTitle(kind, contactName) {
  switch (resolveRitualKind(kind)) {
    case 'duo_task':
      return `和 ${contactName} 的双人任务`;
    case 'memory_lane':
      return `${contactName} 的回忆线更新`;
    case 'memorial':
      return `${contactName} 的纪念卡`;
    case 'checkin':
    default:
      return `和 ${contactName} 的轻量报到`;
  }
}
