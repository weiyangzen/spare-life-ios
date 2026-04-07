import {
  clampScore,
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from './sceneContracts.mjs';
import {
  buildCrossTabHandoff,
  buildMessagesComposeDraftRoutePayload,
  buildMessagesHomeRoutePayload,
  buildMessagesThreadRoutePayload
} from './crossTabHandoffContracts.mjs';

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
export const COMPANION_CHANNEL_ID = 'companion';
export const IM_CARD_SURFACE_KINDS = new Set(['dm', 'group']);
export const IM_HOME_TABS = new Set(['recent']);
export const OPENCLAW_IM_CAPABILITY_SURFACE_SCOPES = new Set([
  'shared',
  'direct_only',
  'group_only'
]);
export const OPENCLAW_IM_ERROR_KINDS = new Set([
  'unsupported',
  'not_ready',
  'invalid_locator',
  'temporarily_unavailable',
  'permission_denied'
]);

const OPENCLAW_IM_CAPABILITY_DEFINITIONS = Object.freeze([
  Object.freeze({
    actionKey: 'open_messages_home',
    label: 'messages home',
    stage3Item: 'S3-035',
    flagKey: 'canOpenMessagesHome',
    surfaceScope: 'shared',
    normalizeInput: 'normalizeMessagesHomeInput',
    handlerMethod: 'openMessagesHome',
    entrySurface: 'messages_home',
    runtimeGate: 'not_required'
  }),
  Object.freeze({
    actionKey: 'open_conversation',
    label: 'conversation open',
    stage3Item: 'S3-036',
    flagKey: 'canOpenConversation',
    surfaceScope: 'shared',
    normalizeInput: 'normalizeConversationOpenInput',
    handlerMethod: 'openConversation',
    entrySurface: 'messages_thread',
    runtimeGate: 'not_required'
  }),
  Object.freeze({
    actionKey: 'search_conversation',
    label: 'conversation search',
    stage3Item: 'S3-037',
    flagKey: 'canSearchConversation',
    surfaceScope: 'shared',
    normalizeInput: 'normalizeConversationSearchInput',
    handlerMethod: 'searchConversation',
    entrySurface: 'messages_thread_search',
    runtimeGate: 'not_required'
  }),
  Object.freeze({
    actionKey: 'send_direct_message',
    label: 'direct message',
    stage3Item: 'S3-038',
    flagKey: 'canSendDirectMessage',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeDirectMessageInput',
    handlerMethod: 'sendDirectMessage',
    entrySurface: 'direct_thread',
    runtimeGate: 'handler_surface_gate'
  }),
  Object.freeze({
    actionKey: 'update_contact_mask',
    label: 'mask update',
    stage3Item: 'S3-041',
    flagKey: 'canUpdateMask',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeMaskUpdateInput',
    handlerMethod: 'updateContactMask',
    entrySurface: 'direct_thread_context',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'draft_shared_stage',
    label: 'shared stage draft',
    stage3Item: 'S3-041',
    flagKey: 'canDraftSharedStage',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeSharedStageDraftInput',
    handlerMethod: 'draftSharedStage',
    entrySurface: 'direct_thread_context',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'grant_stage_access',
    label: 'stage access',
    stage3Item: 'S3-041',
    flagKey: 'canManageStageAccess',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeStageAccessInput',
    handlerMethod: 'grantStageAccess',
    entrySurface: 'direct_thread_context',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'post_stage_message',
    label: 'stage message',
    stage3Item: 'S3-041',
    flagKey: 'canPostStageMessage',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeStageMessageInput',
    handlerMethod: 'postStageMessage',
    entrySurface: 'direct_thread_context',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'schedule_relationship_ritual',
    label: 'ritual schedule',
    stage3Item: 'S3-041',
    flagKey: 'canScheduleRelationshipRitual',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeRitualScheduleInput',
    handlerMethod: 'scheduleRelationshipRitual',
    entrySurface: 'direct_thread_context',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'complete_relationship_ritual',
    label: 'ritual completion',
    stage3Item: 'S3-041',
    flagKey: 'canCompleteRelationshipRitual',
    surfaceScope: 'direct_only',
    normalizeInput: 'normalizeRitualCompletionInput',
    handlerMethod: 'completeRelationshipRitual',
    entrySurface: 'direct_thread_context',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'open_group_conversation',
    label: 'group conversation',
    stage3Item: 'S3-039',
    flagKey: 'canOpenGroupConversation',
    surfaceScope: 'group_only',
    normalizeInput: 'normalizeGroupConversationInput',
    handlerMethod: 'openGroupConversation',
    entrySurface: 'group_thread',
    runtimeGate: 'handler_surface_gate'
  }),
  Object.freeze({
    actionKey: 'post_group_message',
    label: 'group message',
    stage3Item: 'S3-040',
    flagKey: 'canPostGroupMessage',
    surfaceScope: 'group_only',
    normalizeInput: 'normalizeGroupMessageInput',
    handlerMethod: 'postGroupMessage',
    entrySurface: 'group_thread',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'launch_group_vote',
    label: 'group vote launch',
    stage3Item: 'S3-040',
    flagKey: 'canLaunchGroupVote',
    surfaceScope: 'group_only',
    normalizeInput: 'normalizeGroupVoteLaunchInput',
    handlerMethod: 'launchGroupVote',
    entrySurface: 'group_thread_vote_lane',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'cast_group_vote',
    label: 'group vote ballot',
    stage3Item: 'S3-040',
    flagKey: 'canCastGroupVote',
    surfaceScope: 'group_only',
    normalizeInput: 'normalizeGroupVoteBallotInput',
    handlerMethod: 'castGroupVote',
    entrySurface: 'group_thread_vote_lane',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'summarize_group',
    label: 'group summary',
    stage3Item: 'S3-040',
    flagKey: 'canSummarizeGroup',
    surfaceScope: 'group_only',
    normalizeInput: 'normalizeGroupSummaryInput',
    handlerMethod: 'summarizeGroup',
    entrySurface: 'group_thread_summary_lane',
    runtimeGate: 'capability_flag_only'
  }),
  Object.freeze({
    actionKey: 'inspect_companion',
    label: 'companion inspect',
    stage3Item: 'S3-042',
    flagKey: 'canInspectCompanion',
    surfaceScope: 'shared',
    normalizeInput: 'normalizeCompanionInspectInput',
    handlerMethod: 'inspectCompanionState',
    entrySurface: 'diagnostics',
    runtimeGate: 'not_required'
  })
]);

const OPENCLAW_IM_ACTION_RUNTIME_CONTRACTS = Object.freeze({
  open_messages_home: Object.freeze({
    uiTitle: '打开消息首页',
    uiStatus: 'ready',
    uiUnavailableCopy: '消息首页暂时不可用，请稍后重试。',
    requiredIDs: ['user_id'],
    fallbackIDs: [],
    optionalHints: ['tab', 'source_surface'],
    supportedErrorKinds: ['temporarily_unavailable']
  }),
  open_conversation: Object.freeze({
    uiTitle: '打开会话',
    uiStatus: 'ready',
    uiUnavailableCopy: '当前会话入口不可用，请先从消息卡片或线程主路由重新进入。',
    requiredIDs: ['user_id', 'conversation_id | locator'],
    fallbackIDs: [
      'locator.conversation_id',
      'locator.group_id + channel_id',
      'locator.dm_peer_id + channel_id',
      'card_envelope.locator'
    ],
    optionalHints: ['source_surface', 'location_primary_key', 'location_turn_index'],
    supportedErrorKinds: ['invalid_locator', 'temporarily_unavailable']
  }),
  search_conversation: Object.freeze({
    uiTitle: '搜索会话',
    uiStatus: 'ready',
    uiUnavailableCopy: '当前会话搜索入口不可用，请先回到线程主路由后再试。',
    requiredIDs: ['user_id', 'conversation_id | locator'],
    fallbackIDs: [
      'locator.conversation_id',
      'locator.group_id + channel_id',
      'locator.dm_peer_id + channel_id',
      'card_envelope.locator'
    ],
    optionalHints: ['query', 'source_surface', 'result_limit'],
    supportedErrorKinds: ['invalid_locator', 'temporarily_unavailable']
  }),
  send_direct_message: Object.freeze({
    uiTitle: '发送私聊消息',
    uiStatus: 'ready',
    uiUnavailableCopy: '只有私聊线程可以发消息；若当前是群聊卡片，请先切回私聊。',
    requiredIDs: ['user_id', 'contact_id'],
    fallbackIDs: ['locator.peer_id', 'card_envelope.locator.peer_id'],
    optionalHints: ['conversation_id', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'invalid_locator', 'temporarily_unavailable']
  }),
  update_contact_mask: Object.freeze({
    uiTitle: '更新对人面具',
    uiStatus: 'not_ready',
    uiUnavailableCopy: '对人面具的 OpenClaw IM 入口仍在消息线程收口中，暂不作为独立卡片入口开放。',
    requiredIDs: ['user_id', 'contact_id'],
    fallbackIDs: ['locator.peer_id', 'card_envelope.locator.peer_id'],
    optionalHints: ['tone', 'openness', 'boundary_tags', 'signature'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable']
  }),
  draft_shared_stage: Object.freeze({
    uiTitle: '生成共享舞台草稿',
    uiStatus: 'not_ready',
    uiUnavailableCopy: '共享舞台草稿仍在 direct thread 内部收口中，暂不作为独立 OpenClaw IM 入口开放。',
    requiredIDs: ['user_id', 'contact_id'],
    fallbackIDs: ['locator.peer_id', 'card_envelope.locator.peer_id'],
    optionalHints: ['conversation_id', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable']
  }),
  grant_stage_access: Object.freeze({
    uiTitle: '管理舞台访问',
    uiStatus: 'not_ready',
    uiUnavailableCopy: '共享舞台授权入口还未收口成稳定的 OpenClaw IM route。',
    requiredIDs: ['user_id', 'conversation_id', 'participant_key'],
    fallbackIDs: ['card_envelope.conversation_id', 'locator.conversation_id'],
    optionalHints: ['granted', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable']
  }),
  post_stage_message: Object.freeze({
    uiTitle: '发送舞台消息',
    uiStatus: 'not_ready',
    uiUnavailableCopy: '共享舞台消息入口还在 direct thread 内部整理中，暂不作为独立 OpenClaw IM route。',
    requiredIDs: ['user_id', 'conversation_id', 'participant_key'],
    fallbackIDs: ['card_envelope.conversation_id', 'locator.conversation_id'],
    optionalHints: ['channel_kind', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable']
  }),
  schedule_relationship_ritual: Object.freeze({
    uiTitle: '安排关系仪式',
    uiStatus: 'not_ready',
    uiUnavailableCopy: '关系仪式入口仍在消息线程上下文卡里收口，暂不开放独立 OpenClaw IM 入口。',
    requiredIDs: ['user_id', 'contact_id'],
    fallbackIDs: ['locator.peer_id', 'card_envelope.locator.peer_id'],
    optionalHints: ['ritual_kind', 'scheduled_for', 'note'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable']
  }),
  complete_relationship_ritual: Object.freeze({
    uiTitle: '完成关系仪式',
    uiStatus: 'not_ready',
    uiUnavailableCopy: '关系仪式完成入口还未冻结成稳定 OpenClaw IM route。',
    requiredIDs: ['user_id', 'ritual_id'],
    fallbackIDs: [],
    optionalHints: ['note'],
    supportedErrorKinds: ['not_ready', 'invalid_locator', 'temporarily_unavailable']
  }),
  open_group_conversation: Object.freeze({
    uiTitle: '打开群聊线程',
    uiStatus: 'ready',
    uiUnavailableCopy: '只有群聊卡片和群线程入口可以打开群聊主路由。',
    requiredIDs: ['user_id', 'group_id'],
    fallbackIDs: ['locator.group_id', 'card_envelope.locator.group_id'],
    optionalHints: ['conversation_id', 'source_surface', 'message_limit'],
    supportedErrorKinds: ['unsupported', 'invalid_locator', 'temporarily_unavailable']
  }),
  post_group_message: Object.freeze({
    uiTitle: '发送群聊消息',
    uiStatus: 'ready',
    uiUnavailableCopy: '只有群聊线程可以发送群消息；若当前还在私聊或首页卡片，请先进入群聊主路由。',
    requiredIDs: ['user_id', 'group_id', 'actor_key'],
    fallbackIDs: [
      'locator.group_id',
      'card_envelope.locator.group_id',
      'actor_key -> self_human'
    ],
    optionalHints: ['conversation_id', 'channel_kind', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'permission_denied', 'invalid_locator', 'temporarily_unavailable']
  }),
  launch_group_vote: Object.freeze({
    uiTitle: '发起群投票',
    uiLaneKey: 'group_vote_launch',
    uiStatus: 'ready',
    uiUnavailableCopy: '只有群聊 vote lane 可以发起投票；若当前不在群聊线程，请先从群卡片进入。',
    requiredIDs: ['user_id', 'group_id'],
    fallbackIDs: ['locator.group_id', 'card_envelope.locator.group_id'],
    optionalHints: ['conversation_id', 'question_seed', 'options', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable', 'permission_denied']
  }),
  cast_group_vote: Object.freeze({
    uiTitle: '参与群投票',
    uiLaneKey: 'group_vote_ballot',
    uiStatus: 'ready',
    uiUnavailableCopy: '当前没有可参与的开放投票，请先进入群聊 vote lane 再操作。',
    requiredIDs: ['user_id', 'vote_id', 'option_id'],
    fallbackIDs: [
      'group_id -> latest_open_vote',
      'locator.group_id -> latest_open_vote',
      'option_label -> vote_option_id',
      'voter_key -> self_human'
    ],
    optionalHints: ['conversation_id', 'source_surface', 'rationale'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable', 'permission_denied']
  }),
  summarize_group: Object.freeze({
    uiTitle: '生成群总结',
    uiLaneKey: 'group_summary',
    uiStatus: 'ready',
    uiUnavailableCopy: '群总结只在群聊 summary lane 提供；若当前不在群聊线程，请先进入群聊主路由。',
    requiredIDs: ['user_id', 'group_id'],
    fallbackIDs: [
      'vote_id -> vote.group_id',
      'locator.group_id',
      'card_envelope.locator.group_id'
    ],
    optionalHints: ['latest_vote_id', 'summary_focus', 'conversation_id', 'source_surface'],
    supportedErrorKinds: ['unsupported', 'not_ready', 'invalid_locator', 'temporarily_unavailable', 'permission_denied']
  }),
  inspect_companion: Object.freeze({
    uiTitle: '检查 companion 状态',
    uiStatus: 'not_ready',
    uiUnavailableCopy: 'companion inspect 仍是内部诊断入口，当前还没有稳定的 client-facing IM 承接位。',
    requiredIDs: ['user_id'],
    fallbackIDs: [],
    optionalHints: ['diagnostics_scope'],
    supportedErrorKinds: ['not_ready', 'temporarily_unavailable']
  })
});

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

export function resolveIMCardSurfaceKind(value, fallback = 'dm') {
  const normalized = sanitizeText(value) || fallback;
  if (!IM_CARD_SURFACE_KINDS.has(normalized)) {
    throw new Error(`Unsupported IM card surface kind: ${normalized}`);
  }
  return normalized;
}

function getOpenClawIMCapabilityDefinition(actionKey) {
  const normalizedActionKey = sanitizeText(actionKey);
  const definition = OPENCLAW_IM_CAPABILITY_DEFINITIONS.find(
    (candidate) => candidate.actionKey === normalizedActionKey
  );
  if (!definition) {
    throw new Error(`Unsupported OpenClaw IM capability action: ${normalizedActionKey || 'unknown'}`);
  }
  const runtimeContract = OPENCLAW_IM_ACTION_RUNTIME_CONTRACTS[normalizedActionKey] ?? null;
  return {
    ...definition,
    uiTitle: sanitizeText(runtimeContract?.uiTitle) || definition.label,
    uiLaneKey: sanitizeText(runtimeContract?.uiLaneKey) || null,
    uiStatus: sanitizeText(runtimeContract?.uiStatus) === 'not_ready' ? 'not_ready' : 'ready',
    uiUnavailableCopy: sanitizeText(runtimeContract?.uiUnavailableCopy) || null,
    requiredIDs: Array.isArray(runtimeContract?.requiredIDs) ? [...runtimeContract.requiredIDs] : [],
    fallbackIDs: Array.isArray(runtimeContract?.fallbackIDs) ? [...runtimeContract.fallbackIDs] : [],
    optionalHints: Array.isArray(runtimeContract?.optionalHints) ? [...runtimeContract.optionalHints] : [],
    supportedErrorKinds:
      Array.isArray(runtimeContract?.supportedErrorKinds) && runtimeContract.supportedErrorKinds.length
        ? runtimeContract.supportedErrorKinds.filter((kind) => OPENCLAW_IM_ERROR_KINDS.has(kind))
        : [...OPENCLAW_IM_ERROR_KINDS]
  };
}

function capabilityAvailableOnSurface(definition, surfaceKind) {
  if (definition.surfaceScope === 'shared') {
    return true;
  }
  if (definition.surfaceScope === 'direct_only') {
    return surfaceKind === 'dm';
  }
  return surfaceKind === 'group';
}

function normalizeOpenClawIMErrorKind(value, fallback = 'temporarily_unavailable') {
  const normalized = sanitizeText(value);
  if (OPENCLAW_IM_ERROR_KINDS.has(normalized)) {
    return normalized;
  }
  return OPENCLAW_IM_ERROR_KINDS.has(fallback) ? fallback : 'temporarily_unavailable';
}

function surfaceKindLabel(surfaceKind) {
  return sanitizeText(surfaceKind) === 'group' ? '群聊' : '私聊';
}

function uniqueErrorIDs(values = []) {
  return uniqueStrings(
    (Array.isArray(values) ? values : [values])
      .map((value) => sanitizeText(value))
      .filter(Boolean)
  );
}

export function buildOpenClawIMActionContract(actionKey, context = {}) {
  const definition = getOpenClawIMCapabilityDefinition(actionKey);
  const surfaceFallback = definition.surfaceScope === 'group_only' ? 'group' : 'dm';
  const resolvedSurfaceKind = resolveIMCapabilitySurfaceKind(context, surfaceFallback);
  const availableOnSurface = capabilityAvailableOnSurface(definition, resolvedSurfaceKind);
  const blockedBySurface = definition.surfaceScope === 'shared'
    ? null
    : definition.surfaceScope === 'direct_only'
      ? 'group'
      : 'dm';
  const uiReady = availableOnSurface && definition.uiStatus === 'ready';
  const uiUnavailableErrorKind = !availableOnSurface
    ? 'unsupported'
    : definition.uiStatus === 'ready'
      ? null
      : 'not_ready';

  return {
    ...definition,
    surfaceKind: resolvedSurfaceKind,
    availableOnSurface,
    blockedBySurface,
    uiReady,
    uiUnavailableErrorKind
  };
}

export function buildOpenClawIMErrorSurface({
  kind,
  actionKey = null,
  surfaceKind = null,
  allowedSurfaceKind = null,
  missingIDs = [],
  detail = null
} = {}) {
  const resolvedKind = normalizeOpenClawIMErrorKind(kind);
  const definition = actionKey ? getOpenClawIMCapabilityDefinition(actionKey) : null;
  const actionTitle = definition?.uiTitle ?? definition?.label ?? '当前操作';
  const normalizedDetail = sanitizeText(detail) || null;
  const normalizedMissingIDs = uniqueErrorIDs(missingIDs);
  const requiredIDs = definition?.requiredIDs ?? [];
  const fallbackIDs = definition?.fallbackIDs ?? [];
  const optionalHints = definition?.optionalHints ?? [];

  let title = '暂时不可用';
  let message = normalizedDetail || `${actionTitle} 暂时不可用，请稍后重试。`;
  let recoveryHint = '请稍后再试。';

  switch (resolvedKind) {
    case 'unsupported':
      title = '当前入口不支持';
      message = allowedSurfaceKind
        ? `${actionTitle} 仅支持${surfaceKindLabel(allowedSurfaceKind)}入口。`
        : definition?.uiUnavailableCopy || `${actionTitle} 当前不在这个入口开放。`;
      recoveryHint = allowedSurfaceKind
        ? `请切换到${surfaceKindLabel(allowedSurfaceKind)}线程后再试。`
        : definition?.uiUnavailableCopy || '请从对应消息主路由重新进入。';
      break;
    case 'not_ready':
      title = '入口还没准备好';
      message =
        normalizedDetail ||
        definition?.uiUnavailableCopy ||
        `${actionTitle} 还没有接线到当前运行态，请先完成前置流程。`;
      recoveryHint = '请先完成前置流程或稍后重试。';
      break;
    case 'invalid_locator':
      title = '定位信息不完整';
      message = normalizedMissingIDs.length
        ? `${actionTitle} 需要稳定主键才能继续，当前缺少：${normalizedMissingIDs.join(' / ')}。`
        : normalizedDetail || `${actionTitle} 的 locator 或主键无效。`;
      recoveryHint = '请从消息首页卡片或线程主路由重新进入，再触发当前动作。';
      break;
    case 'permission_denied':
      title = '当前身份没有权限';
      message = normalizedDetail || `${actionTitle} 当前身份没有权限执行。`;
      recoveryHint = '请切换到有权限的参与者，或等待授权后再试。';
      break;
    case 'temporarily_unavailable':
    default:
      title = '暂时不可用';
      message = normalizedDetail || `${actionTitle} 暂时不可用，请稍后重试。`;
      recoveryHint = '若问题持续，请回到消息主路由重新打开。';
      break;
  }

  return {
    kind: resolvedKind,
    title,
    message,
    recoveryHint,
    actionKey: definition?.actionKey ?? (sanitizeText(actionKey) || null),
    stage3Item: definition?.stage3Item ?? null,
    label: definition?.label ?? null,
    uiTitle: definition?.uiTitle ?? null,
    surfaceKind: sanitizeText(surfaceKind) || null,
    allowedSurfaceKind: sanitizeText(allowedSurfaceKind) || null,
    requiredIDs,
    fallbackIDs,
    optionalHints,
    missingIDs: normalizedMissingIDs,
    uiUnavailableCopy: definition?.uiUnavailableCopy ?? null,
    detail: normalizedDetail
  };
}

export function createOpenClawIMActionError({
  kind,
  actionKey = null,
  surfaceKind = null,
  allowedSurfaceKind = null,
  missingIDs = [],
  detail = null,
  code = null,
  extra = {}
} = {}) {
  const errorSurface = buildOpenClawIMErrorSurface({
    kind,
    actionKey,
    surfaceKind,
    allowedSurfaceKind,
    missingIDs,
    detail
  });
  const error = new Error(errorSurface.message);
  error.name = 'OpenClawIMActionError';
  error.code = sanitizeText(code) || errorSurface.kind;
  error.errorKind = errorSurface.kind;
  error.errorSurface = errorSurface;
  error.actionKey = errorSurface.actionKey;
  error.stage3Item = errorSurface.stage3Item;
  error.surfaceKind = errorSurface.surfaceKind;
  error.allowedSurfaceKind = errorSurface.allowedSurfaceKind;
  error.missingIDs = errorSurface.missingIDs;
  error.uiUnavailableCopy = errorSurface.uiUnavailableCopy;
  Object.assign(error, extra);
  return error;
}

export function normalizeOpenClawIMActionError(error, context = {}) {
  if (!error) {
    return createOpenClawIMActionError({
      kind: 'temporarily_unavailable',
      actionKey: context.actionKey ?? null,
      surfaceKind: context.surfaceKind ?? null
    });
  }
  if (error.errorSurface) {
    return error;
  }

  const rawMessage = sanitizeText(error.message) || 'Unknown companion runtime error.';
  const normalizedCode = sanitizeText(error.code) || null;
  const missingFieldMatch = rawMessage.match(/Missing required field:\s*(.+)$/i);
  const detectedMissingField = missingFieldMatch ? sanitizeText(missingFieldMatch[1]) : null;
  const identityLikeField =
    detectedMissingField &&
    /(^|\.|_)(id|key)$|locator|conversationId|contactId|groupId|peerId|voteId|optionId|ritualId|participantKey|actorKey/i.test(
      detectedMissingField
    );
  const missingIDs = uniqueErrorIDs([
    ...(Array.isArray(context.missingIDs) ? context.missingIDs : []),
    identityLikeField ? detectedMissingField : null
  ]);

  let kind = null;
  const explicitKind = sanitizeText(context.kind ?? error.errorKind ?? normalizedCode);
  if (OPENCLAW_IM_ERROR_KINDS.has(explicitKind)) {
    kind = explicitKind;
  } else if (/_capability_gate$/.test(normalizedCode ?? '') || /cannot run from .* surface/i.test(rawMessage)) {
    kind = 'unsupported';
  } else if (/already closed|no open vote|not ready/i.test(rawMessage)) {
    kind = 'not_ready';
  } else if (/cannot post|permission denied|forbidden|unauthorized/i.test(rawMessage)) {
    kind = 'permission_denied';
  } else if (
    /unknown group|unknown contact|unknown conversation|unknown vote|locator|requires conversationID|requires groupID|requires peerID/i.test(
      rawMessage
    ) ||
    identityLikeField
  ) {
    kind = 'invalid_locator';
  } else {
    kind = 'temporarily_unavailable';
  }

  return createOpenClawIMActionError({
    kind,
    actionKey: context.actionKey ?? error.actionKey ?? null,
    surfaceKind: context.surfaceKind ?? error.surfaceKind ?? null,
    allowedSurfaceKind: context.allowedSurfaceKind ?? error.allowedSurfaceKind ?? null,
    missingIDs,
    detail: rawMessage,
    code: kind,
    extra: {
      legacyCode: normalizedCode
    }
  });
}

export function resolveIMCapabilitySurfaceKind(context = {}, fallback = 'dm') {
  const normalizedFallback = sanitizeText(fallback) === 'group' ? 'group' : 'dm';
  const explicitSurfaceKind = sanitizeText(
    context.surfaceKind ??
      context.envelope?.surfaceKind ??
      context.cardEnvelope?.surfaceKind ??
      context.conversation?.surfaceKind ??
      context.conversation?.kind
  );
  if (explicitSurfaceKind === 'direct') {
    return 'dm';
  }
  if (IM_CARD_SURFACE_KINDS.has(explicitSurfaceKind)) {
    return resolveIMCardSurfaceKind(explicitSurfaceKind, normalizedFallback);
  }

  const rawLocator = context.locator ?? context.envelope?.locator ?? context.cardEnvelope?.locator ?? null;
  if (rawLocator && typeof rawLocator === 'object' && !Array.isArray(rawLocator)) {
    const normalizedLocator = normalizeIMConversationLocator(rawLocator);
    return normalizedLocator.kind === 'group' ? 'group' : 'dm';
  }

  const groupID = sanitizeText(context.groupId ?? context.groupID ?? context.conversation?.groupId);
  if (groupID) {
    return 'group';
  }

  const peerID = sanitizeText(
    context.peerId ??
      context.peerID ??
      context.contactId ??
      context.contactID ??
      context.conversation?.contactId
  );
  if (peerID) {
    return 'dm';
  }

  return resolveIMCardSurfaceKind(normalizedFallback, 'dm');
}

export function buildOpenClawIMCapabilityChecklist(surfaceKind) {
  return OPENCLAW_IM_CAPABILITY_DEFINITIONS.map((definition) =>
    buildOpenClawIMActionContract(definition.actionKey, {
      surfaceKind
    })
  );
}

export function assertOpenClawIMCapabilityAllowed({
  actionKey,
  surfaceKind = null,
  locator = null,
  envelope = null,
  groupId = null,
  peerId = null,
  contactId = null
} = {}) {
  const contract = buildOpenClawIMActionContract(actionKey, {
    surfaceKind,
    locator,
    envelope,
    groupId,
    peerId,
    contactId
  });
  if (contract.availableOnSurface) {
    return {
      actionKey: contract.actionKey,
      stage3Item: contract.stage3Item,
      flagKey: contract.flagKey,
      surfaceKind: contract.surfaceKind
    };
  }
  const allowedSurfaceKind = contract.surfaceScope === 'group_only' ? 'group' : 'dm';
  throw createOpenClawIMActionError({
    kind: 'unsupported',
    actionKey: contract.actionKey,
    surfaceKind: contract.surfaceKind,
    allowedSurfaceKind,
    detail: `OpenClaw IM action ${contract.actionKey} is ${contract.surfaceScope} and cannot run from ${contract.surfaceKind} surface.`,
    code: 'unsupported',
    extra: {
      legacyCode: `${contract.surfaceScope}_capability_gate`
    }
  });
}

export function resolveMessagesHomeTab(value, fallback = 'recent') {
  const normalized = sanitizeText(value) || fallback;
  if (!IM_HOME_TABS.has(normalized)) {
    throw new Error(`Unsupported messages home tab: ${normalized}`);
  }
  return normalized;
}

export function buildMessagesHomeRoute(tab = 'recent') {
  const params = new URLSearchParams({
    tab: resolveMessagesHomeTab(tab)
  });
  return `sparelife://messages/home?${params.toString()}`;
}

export function normalizeIMConversationLocator(locator) {
  if (!locator || typeof locator !== 'object' || Array.isArray(locator)) {
    throw new Error('IM conversation locator is required.');
  }

  const kind = sanitizeText(locator.kind);
  if (kind === 'conversation') {
    const conversationID = sanitizeText(locator.conversationID ?? locator.conversationId);
    if (!conversationID) {
      throw new Error('conversation locator requires conversationID.');
    }
    return {
      kind: 'conversation',
      conversationID
    };
  }
  if (kind === 'group') {
    const channelID = sanitizeText(locator.channelID ?? locator.channelId) || COMPANION_CHANNEL_ID;
    const groupID = sanitizeText(locator.groupID ?? locator.groupId);
    if (!groupID) {
      throw new Error('group locator requires groupID.');
    }
    return {
      kind: 'group',
      channelID,
      groupID
    };
  }
  if (kind === 'dm') {
    const channelID = sanitizeText(locator.channelID ?? locator.channelId) || COMPANION_CHANNEL_ID;
    const peerID =
      sanitizeText(locator.peerID ?? locator.peerId) ||
      sanitizeText(locator.dmPeerID ?? locator.dmPeerId) ||
      sanitizeText(locator.contactId);
    if (!peerID) {
      throw new Error('dm locator requires peerID.');
    }
    return {
      kind: 'dm',
      channelID,
      peerID
    };
  }

  const conversationID = sanitizeText(locator.conversationID ?? locator.conversationId);
  if (conversationID) {
    return {
      kind: 'conversation',
      conversationID
    };
  }

  const channelID = sanitizeText(locator.channelID ?? locator.channelId) || COMPANION_CHANNEL_ID;
  const groupID = sanitizeText(locator.groupID ?? locator.groupId);
  if (groupID) {
    return {
      kind: 'group',
      channelID,
      groupID
    };
  }

  const peerID =
    sanitizeText(locator.peerID ?? locator.peerId) ||
    sanitizeText(locator.dmPeerID ?? locator.dmPeerId) ||
    sanitizeText(locator.contactId);
  if (peerID) {
    return {
      kind: 'dm',
      channelID,
      peerID
    };
  }

  throw new Error('IM conversation locator requires conversationID, groupID, or peerID.');
}

export function buildIMConversationLocator({
  conversationId = null,
  channelId = COMPANION_CHANNEL_ID,
  groupId = null,
  peerId = null,
  contactId = null
}) {
  return normalizeIMConversationLocator({
    conversationId,
    channelId,
    groupId,
    peerId: peerId ?? contactId
  });
}

export function buildCanonicalIMCardID({
  conversationId = null,
  channelId = COMPANION_CHANNEL_ID,
  groupId = null,
  peerId = null,
  contactId = null
}) {
  const locator = buildIMConversationLocator({
    conversationId,
    channelId,
    groupId,
    peerId,
    contactId
  });

  switch (locator.kind) {
    case 'conversation':
      return `conversation:${locator.conversationID}`;
    case 'group':
      return `group:${locator.channelID}:${locator.groupID}`;
    case 'dm':
      return `dm:${locator.channelID}:${locator.peerID}`;
    default:
      throw new Error(`Unsupported IM locator kind: ${locator.kind}`);
  }
}

export function buildIMCapabilityFlags(surfaceKind) {
  const checklist = buildOpenClawIMCapabilityChecklist(surfaceKind);
  return checklist.reduce((flags, item) => {
    if (item.flagKey) {
      flags[item.flagKey] = item.availableOnSurface;
    }
    return flags;
  }, {});
}

function normalizeIMBadge(badge, unreadCount) {
  if (badge && typeof badge === 'object' && !Array.isArray(badge)) {
    const kind = sanitizeText(badge.kind) || 'status';
    const label = sanitizeText(badge.label);
    const count = Number.isFinite(Number(badge.count)) ? Math.max(0, Number(badge.count)) : null;
    if (!label && count === null) {
      return null;
    }
    return {
      kind,
      label: label || (count === null ? null : `${count} unread`),
      count
    };
  }

  const normalizedBadge = sanitizeText(badge);
  if (normalizedBadge) {
    return {
      kind: 'status',
      label: normalizedBadge,
      count: null
    };
  }

  const normalizedUnreadCount = Math.max(0, Number(unreadCount) || 0);
  if (normalizedUnreadCount <= 0) {
    return null;
  }
  return {
    kind: 'unread_count',
    label: `${normalizedUnreadCount} unread`,
    count: normalizedUnreadCount
  };
}

function normalizeIsoTimestamp(value) {
  const normalized = sanitizeText(value);
  if (!normalized) {
    return null;
  }
  const timestamp = new Date(normalized);
  return Number.isNaN(timestamp.getTime()) ? null : timestamp.toISOString();
}

function normalizeParticipantPermissions(permissions = {}) {
  const normalized = permissions && typeof permissions === 'object' && !Array.isArray(permissions)
    ? permissions
    : {};
  return {
    canPost: normalized.canPost === true,
    canSuggest: normalized.canSuggest === true,
    canModerate: normalized.canModerate === true,
    canLaunchVote: normalized.canLaunchVote === true,
    canSummarize: normalized.canSummarize === true,
    requiresGrant: normalized.requiresGrant === true
  };
}

function buildConversationLocatorFallback(conversation = {}, locator = null) {
  if (locator) {
    return normalizeIMConversationLocator(locator);
  }
  return buildIMConversationLocator({
    conversationId: conversation.id ?? conversation.conversationId ?? null,
    groupId: conversation.groupId ?? null,
    contactId: conversation.contactId ?? null
  });
}

function normalizeConversationSurfaceKind(value, fallback = 'dm') {
  const normalized = sanitizeText(value);
  if (normalized === 'direct') {
    return 'dm';
  }
  if (normalized === 'group') {
    return 'group';
  }
  return resolveIMCardSurfaceKind(normalized, fallback);
}

export function buildIMRenderFields({
  surfaceKind,
  primaryTitle,
  secondaryTitle = null,
  preview = null,
  badge = null,
  avatarHint = null,
  unreadCount = 0,
  lastMessageAt = null,
  sourceChannelID = COMPANION_CHANNEL_ID,
  capabilityFlags = null
}) {
  const resolvedSurfaceKind = resolveIMCardSurfaceKind(surfaceKind);
  const normalizedUnreadCount = Math.max(0, Number(unreadCount) || 0);
  const normalizedLastMessageAt = sanitizeText(lastMessageAt)
    ? new Date(lastMessageAt).toISOString()
    : null;

  return {
    surfaceKind: resolvedSurfaceKind,
    primaryTitle: sanitizeText(primaryTitle) || '未命名会话',
    secondaryTitle: sanitizeText(secondaryTitle) || null,
    preview: sanitizeText(preview) || null,
    badge: normalizeIMBadge(badge, normalizedUnreadCount),
    avatarHint: sanitizeText(avatarHint) || (resolvedSurfaceKind === 'group' ? 'group' : 'person'),
    unreadCount: normalizedUnreadCount,
    lastMessageAt: normalizedLastMessageAt,
    sourceChannelID: sanitizeText(sourceChannelID) || COMPANION_CHANNEL_ID,
    capabilityFlags: capabilityFlags ?? buildIMCapabilityFlags(resolvedSurfaceKind)
  };
}

export function normalizeIMCardEnvelope(envelope) {
  if (!envelope || typeof envelope !== 'object' || Array.isArray(envelope)) {
    throw new Error('IM card envelope is required.');
  }

  const locator = normalizeIMConversationLocator(
    envelope.locator ??
      envelope.cardEnvelope?.locator ??
      envelope.openAction?.locator ??
      envelope.handoff?.route?.locator
  );
  const conversationId =
    sanitizeText(
      envelope.conversationId ??
        envelope.conversationID ??
        envelope.cardEnvelope?.conversationId ??
        envelope.openAction?.conversationId
    ) || (locator.kind === 'conversation' ? locator.conversationID : null);
  const sourceChannelID =
    sanitizeText(
      envelope.sourceChannelID ??
        envelope.sourceChannelId ??
        envelope.cardEnvelope?.sourceChannelID ??
        locator.channelID
    ) || COMPANION_CHANNEL_ID;
  const surfaceKind = resolveIMCardSurfaceKind(
    envelope.surfaceKind ?? envelope.cardEnvelope?.surfaceKind,
    locator.kind === 'group' ? 'group' : 'dm'
  );

  return {
    canonicalCardID:
      sanitizeText(
        envelope.canonicalCardID ??
          envelope.canonicalCardId ??
          envelope.cardEnvelope?.canonicalCardID
      ) ||
      buildCanonicalIMCardID({
        conversationId,
        channelId: sourceChannelID,
        groupId: locator.groupID ?? null,
        peerId: locator.peerID ?? null
      }),
    conversationId,
    locator,
    surfaceKind,
    sourceChannelID,
    capabilityChecklist: buildOpenClawIMCapabilityChecklist(surfaceKind)
  };
}

export function buildMessagesHomeHandoff({ sourceSurface = 'messages', tab = 'recent' } = {}) {
  return buildCrossTabHandoff({
    sourceSurface,
    targetSurface: 'messages',
    route: buildMessagesHomeRoutePayload({
      tab
    })
  });
}

export function buildMessagesComposeDraftHandoff({
  sourceSurface = 'messages',
  draft = null,
  context = {}
} = {}) {
  return buildCrossTabHandoff({
    sourceSurface,
    targetSurface: 'messages',
    route: buildMessagesComposeDraftRoutePayload({
      draft,
      sourceSurface,
      context
    })
  });
}

export function buildMessagesThreadHandoff({
  sourceSurface = 'messages',
  conversationId = null,
  channelId = COMPANION_CHANNEL_ID,
  groupId = null,
  peerId = null,
  contactId = null,
  hint = {}
}) {
  const locator = buildIMConversationLocator({
    conversationId,
    channelId,
    groupId,
    peerId,
    contactId
  });
  return buildCrossTabHandoff({
    sourceSurface,
    targetSurface: 'messages',
    route: buildMessagesThreadRoutePayload({
      locator,
      sourceSurface,
      hint
    })
  });
}

export function buildConversationOpenAction({
  sourceSurface = 'messages',
  conversationId = null,
  locator,
  route = null
}) {
  const normalizedLocator = normalizeIMConversationLocator(locator);
  const normalizedConversationId =
    sanitizeText(conversationId) ||
    (normalizedLocator.kind === 'conversation' ? normalizedLocator.conversationID : null);

  return {
    actionKind: 'open_conversation',
    conversationId: normalizedConversationId,
    locator: normalizedLocator,
    route:
      sanitizeText(route) ||
      buildConversationRoute({
        conversationId: normalizedConversationId,
        kind: normalizedLocator.kind === 'group' ? 'group' : 'direct',
        channelId: normalizedLocator.channelID ?? COMPANION_CHANNEL_ID,
        groupId: normalizedLocator.groupID ?? null,
        peerId: normalizedLocator.peerID ?? null
      }),
    handoff: buildMessagesThreadHandoff({
      sourceSurface,
      conversationId: normalizedConversationId,
      channelId: normalizedLocator.channelID ?? COMPANION_CHANNEL_ID,
      groupId: normalizedLocator.groupID ?? null,
      peerId: normalizedLocator.peerID ?? null
    })
  };
}

export function buildIMCardEnvelope({
  canonicalCardID,
  conversationId = null,
  locator,
  surfaceKind,
  route = null,
  sourceChannelID = COMPANION_CHANNEL_ID,
  renderFields,
  fieldSources = {},
  handoff = null,
  openAction = null
}) {
  const normalizedLocator = normalizeIMConversationLocator(locator);
  const normalizedConversationId =
    sanitizeText(conversationId) ||
    (normalizedLocator.kind === 'conversation' ? normalizedLocator.conversationID : null);
  const normalizedSurfaceKind = resolveIMCardSurfaceKind(
    surfaceKind,
    normalizedLocator.kind === 'group' ? 'group' : 'dm'
  );
  const normalizedSourceChannelID =
    sanitizeText(sourceChannelID) || normalizedLocator.channelID || COMPANION_CHANNEL_ID;
  const normalizedRenderFields = buildIMRenderFields({
    ...renderFields,
    surfaceKind: normalizedSurfaceKind,
    sourceChannelID: normalizedSourceChannelID
  });
  const summary = {
    canonicalCardID:
      sanitizeText(canonicalCardID) ||
      buildCanonicalIMCardID({
        conversationId: normalizedConversationId,
        channelId: normalizedSourceChannelID,
        groupId: normalizedLocator.groupID ?? null,
        peerId: normalizedLocator.peerID ?? null
      }),
    conversationId: normalizedConversationId,
    locator: normalizedLocator,
    surfaceKind: normalizedSurfaceKind,
    sourceChannelID: normalizedSourceChannelID
  };
  const normalizedHandoff = handoff
    ? {
        ...handoff,
        cardEnvelope: summary
      }
    : null;
  const normalizedOpenAction = openAction
    ? {
        ...openAction,
        cardEnvelope: summary,
        handoff: openAction.handoff
          ? {
              ...openAction.handoff,
              cardEnvelope: summary
            }
          : null
      }
    : null;

  return {
    ...summary,
    route: sanitizeText(route) || null,
    renderFields: normalizedRenderFields,
    fieldSources: {
      title: sanitizeText(fieldSources.title) || null,
      subtitle: sanitizeText(fieldSources.subtitle) || null,
      preview: sanitizeText(fieldSources.preview) || null,
      badge: sanitizeText(fieldSources.badge) || null,
      locator: sanitizeText(fieldSources.locator) || null,
      capability: sanitizeText(fieldSources.capability) || 'openclaw_stage3_capability_checklist'
    },
    capabilityChecklist: buildOpenClawIMCapabilityChecklist(normalizedSurfaceKind),
    capabilityFlags: normalizedRenderFields.capabilityFlags,
    title: normalizedRenderFields.primaryTitle,
    subtitle: normalizedRenderFields.secondaryTitle,
    preview: normalizedRenderFields.preview,
    badge: normalizedRenderFields.badge,
    unreadCount: normalizedRenderFields.unreadCount,
    lastMessagePreview: normalizedRenderFields.preview,
    lastMessageAt: normalizedRenderFields.lastMessageAt,
    handoff: normalizedHandoff,
    openAction: normalizedOpenAction
  };
}

export function buildMessagesHomeInputModel({
  userId,
  limit = 12,
  sourceSurface = 'messages',
  tab = 'recent'
}) {
  return {
    kind: 'messages_home_input',
    userId: sanitizeText(userId) || null,
    limit: Math.max(1, Number(limit) || 12),
    sourceSurface: sanitizeText(sourceSurface) || 'messages',
    tab: resolveMessagesHomeTab(tab),
    route: buildMessagesHomeRoute(tab)
  };
}

export function buildMessagesHomeOutputModel({
  route = null,
  handoff = null,
  sourceChannelID = COMPANION_CHANNEL_ID,
  unreadTotal = 0,
  cards = [],
  tab = 'recent'
}) {
  const normalizedTab = resolveMessagesHomeTab(tab);
  const cardEnvelopes = Array.isArray(cards) ? cards.filter(Boolean) : [];
  return {
    kind: 'messages_home_output',
    tab: normalizedTab,
    route: sanitizeText(route) || buildMessagesHomeRoute(normalizedTab),
    handoff:
      handoff ??
      buildMessagesHomeHandoff({
        sourceSurface: 'messages',
        tab: normalizedTab
      }),
    sourceChannelID: sanitizeText(sourceChannelID) || COMPANION_CHANNEL_ID,
    unreadTotal: Math.max(0, Number(unreadTotal) || 0),
    cardCount: cardEnvelopes.length,
    cardEnvelopes
  };
}

export function buildConversationSummaryModel({
  conversation = {},
  cardEnvelope = null
} = {}) {
  const normalizedLocator = buildConversationLocatorFallback(
    conversation,
    cardEnvelope?.locator ?? conversation.locator ?? null
  );
  const normalizedConversationId =
    sanitizeText(
      cardEnvelope?.conversationId ??
        conversation.id ??
        conversation.conversationId
    ) || (normalizedLocator.kind === 'conversation' ? normalizedLocator.conversationID : null);
  const normalizedSurfaceKind = resolveIMCardSurfaceKind(
    normalizeConversationSurfaceKind(
      cardEnvelope?.surfaceKind ??
        conversation.surfaceKind ??
        conversation.kind,
      normalizedLocator.kind === 'group' ? 'group' : 'dm'
    ),
    normalizedLocator.kind === 'group' ? 'group' : 'dm'
  );
  const normalizedSourceChannelID =
    sanitizeText(
      cardEnvelope?.sourceChannelID ??
        conversation.sourceChannelID ??
        conversation.channelId ??
        normalizedLocator.channelID
    ) || COMPANION_CHANNEL_ID;
  const renderFields = cardEnvelope?.renderFields ?? {};

  return {
    kind: 'conversation_summary',
    conversationId: normalizedConversationId,
    canonicalCardID:
      sanitizeText(cardEnvelope?.canonicalCardID ?? conversation.canonicalCardID) ||
      buildCanonicalIMCardID({
        conversationId: normalizedConversationId,
        channelId: normalizedSourceChannelID,
        groupId: normalizedLocator.groupID ?? conversation.groupId ?? null,
        peerId: normalizedLocator.peerID ?? conversation.contactId ?? null
      }),
    locator: normalizedLocator,
    surfaceKind: normalizedSurfaceKind,
    sourceChannelID: normalizedSourceChannelID,
    route:
      sanitizeText(cardEnvelope?.route ?? conversation.route) ||
      buildConversationRoute({
        conversationId: normalizedConversationId,
        kind: normalizedSurfaceKind === 'group' ? 'group' : 'direct',
        channelId: normalizedSourceChannelID,
        groupId: normalizedLocator.groupID ?? conversation.groupId ?? null,
        peerId: normalizedLocator.peerID ?? conversation.contactId ?? null
      }),
    title:
      sanitizeText(renderFields.primaryTitle ?? cardEnvelope?.title ?? conversation.title) ||
      '未命名会话',
    subtitle:
      sanitizeText(renderFields.secondaryTitle ?? cardEnvelope?.subtitle) ||
      null,
    preview:
      sanitizeText(
        renderFields.preview ??
          cardEnvelope?.preview ??
          conversation.lastMessagePreview
      ) || null,
    unreadCount: Math.max(
      0,
      Number(renderFields.unreadCount ?? cardEnvelope?.unreadCount ?? conversation.unreadCount) || 0
    ),
    lastMessageAt: normalizeIsoTimestamp(
      renderFields.lastMessageAt ?? cardEnvelope?.lastMessageAt ?? conversation.lastMessageAt
    ),
    capabilityChecklist:
      cardEnvelope?.capabilityChecklist ?? buildOpenClawIMCapabilityChecklist(normalizedSurfaceKind),
    capabilityFlags:
      renderFields.capabilityFlags ??
      cardEnvelope?.capabilityFlags ??
      buildIMCapabilityFlags(normalizedSurfaceKind)
  };
}

export function buildConversationOpenInputModel({
  userId,
  conversationId = null,
  locator = null,
  sourceSurface = 'messages',
  markRead = true,
  limit = 40,
  envelope = null
} = {}) {
  const normalizedLocator = buildConversationLocatorFallback(
    {
      id: conversationId ?? null
    },
    locator ?? envelope?.locator ?? null
  );
  const normalizedConversationId =
    sanitizeText(conversationId) ||
    sanitizeText(envelope?.conversationId) ||
    (normalizedLocator.kind === 'conversation' ? normalizedLocator.conversationID : null);

  return {
    kind: 'conversation_open_input',
    userId: sanitizeText(userId) || null,
    conversationId: normalizedConversationId,
    locator: normalizedLocator,
    sourceSurface: sanitizeText(sourceSurface) || 'messages',
    markRead: markRead !== false,
    limit: Math.max(1, Number(limit) || 40),
    route: buildConversationRoute({
      conversationId: normalizedConversationId,
      kind: normalizedLocator.kind === 'group' ? 'group' : 'direct',
      channelId: normalizedLocator.channelID ?? COMPANION_CHANNEL_ID,
      groupId: normalizedLocator.groupID ?? null,
      peerId: normalizedLocator.peerID ?? null
    }),
    cardEnvelope: envelope ? normalizeIMCardEnvelope(envelope) : null
  };
}

export function buildConversationParticipantModel(participant = {}) {
  const role = requireCompanionEnum(
    sanitizeText(participant.role),
    COMPANION_PARTICIPANT_ROLES,
    'self_human',
    'participant role'
  );
  return {
    kind: 'conversation_participant',
    participantKey: sanitizeText(participant.participantKey) || null,
    role,
    displayName: sanitizeText(participant.displayName) || participantLabel(role),
    permissions: normalizeParticipantPermissions(participant.permissions),
    isOwnerActor: [buildSelfParticipantKey('human'), buildSelfParticipantKey('agent')].includes(
      sanitizeText(participant.participantKey)
    ),
    createdAt: normalizeIsoTimestamp(participant.createdAt),
    updatedAt: normalizeIsoTimestamp(participant.updatedAt)
  };
}

export function buildConversationMessageModel(message = {}, participant = null) {
  const actorRole = requireCompanionEnum(
    sanitizeText(message.actorRole),
    COMPANION_PARTICIPANT_ROLES,
    'self_human',
    'participant role'
  );
  const channelKind = requireCompanionEnum(
    sanitizeText(message.channelKind),
    COMPANION_CHANNEL_KINDS,
    'timeline',
    'channel kind'
  );
  const metadata =
    message.metadata && typeof message.metadata === 'object' && !Array.isArray(message.metadata)
      ? message.metadata
      : {};

  return {
    kind: 'conversation_message',
    messageId: sanitizeText(message.id) || null,
    conversationId: sanitizeText(message.conversationId) || null,
    turnIndex: Math.max(0, Number(message.turnIndex) || 0),
    actorKey: sanitizeText(message.actorKey) || null,
    actorRole,
    actorDisplayName:
      sanitizeText(participant?.displayName) || participantLabel(actorRole),
    channelKind,
    content: sanitizeText(message.content) || '',
    createdAt: normalizeIsoTimestamp(message.createdAt),
    unreadForOwner: Boolean(message.unreadForOwner),
    suppressed: Boolean(message.suppressed),
    signalScore: Number.isFinite(Number(message.signalScore)) ? Number(message.signalScore) : null,
    stageMode: sanitizeText(metadata.stageMode) || null,
    metadata
  };
}

export function buildConversationTimelineItemModel(messageModel = {}) {
  const messageId = sanitizeText(messageModel.messageId);
  return {
    kind: 'conversation_timeline_item',
    timelineItemID:
      messageId ||
      stableId(
        'conversation-timeline-item',
        messageModel.conversationId ?? 'unknown',
        messageModel.turnIndex ?? 0,
        messageModel.actorKey ?? 'unknown'
      ),
    locationPrimaryKey: {
      kind: 'message_id',
      value: messageId,
      turnIndex: Math.max(0, Number(messageModel.turnIndex) || 0)
    },
    messageId,
    turnIndex: Math.max(0, Number(messageModel.turnIndex) || 0),
    actorKey: sanitizeText(messageModel.actorKey) || null,
    actorRole: sanitizeText(messageModel.actorRole) || 'self_human',
    actorDisplayName: sanitizeText(messageModel.actorDisplayName) || null,
    channelKind: sanitizeText(messageModel.channelKind) || 'timeline',
    createdAt: normalizeIsoTimestamp(messageModel.createdAt),
    stageMode: sanitizeText(messageModel.stageMode) || null,
    suppressed: Boolean(messageModel.suppressed),
    unreadForOwner: Boolean(messageModel.unreadForOwner)
  };
}

export function buildConversationStageContextModel({
  conversation = {},
  participants = [],
  messages = []
} = {}) {
  const summary = buildConversationSummaryModel({ conversation });
  if (summary.surfaceKind === 'group') {
    return null;
  }

  const stageParticipants = participants.filter((participant) =>
    ['self_human', 'self_agent', 'counterpart_human', 'counterpart_agent'].includes(participant.role)
  );
  const stageMessages = messages.filter((message) => sanitizeText(message.stageMode) === 'shared_stage');
  const latestStageMessage = stageMessages.at(-1) ?? null;

  return {
    kind: 'conversation_stage_context',
    conversationId: summary.conversationId,
    locator: summary.locator,
    participantKeys: stageParticipants.map((participant) => participant.participantKey),
    grantedParticipantKeys: stageParticipants
      .filter((participant) => participant.permissions.canPost)
      .map((participant) => participant.participantKey),
    pendingGrantParticipantKeys: stageParticipants
      .filter((participant) => participant.permissions.requiresGrant && !participant.permissions.canPost)
      .map((participant) => participant.participantKey),
    messageCount: stageMessages.length,
    latestMessageId: latestStageMessage?.messageId ?? null,
    latestMessageAt: latestStageMessage?.createdAt ?? null
  };
}

function buildGroupThreadActionLane({
  actionKey,
  title,
  conversation = {},
  groupId,
  sourceSurface = 'messages',
  latestVote = null,
  latestSummary = null,
  availableOverride = null,
  unavailableKind = null,
  unavailableDetail = null
} = {}) {
  const normalizedGroupId = sanitizeText(groupId ?? conversation.groupId) || null;
  if (!normalizedGroupId) {
    return null;
  }

  const locator = buildIMConversationLocator({
    conversationId: conversation.id ?? null,
    groupId: normalizedGroupId
  });
  const actionContract = buildOpenClawIMActionContract(actionKey, {
    surfaceKind: 'group',
    locator,
    groupId: normalizedGroupId
  });
  const route =
    sanitizeText(conversation.route) ||
    buildConversationRoute({
      conversationId: sanitizeText(conversation.id) || null,
      kind: 'group',
      groupId: normalizedGroupId
    });
  const handoff = buildMessagesThreadHandoff({
    sourceSurface,
    conversationId: sanitizeText(conversation.id) || null,
    groupId: normalizedGroupId,
    hint: {
      groupLaneKey: actionContract.uiLaneKey ?? actionContract.actionKey,
      actionKey: actionContract.actionKey,
      voteId: sanitizeText(latestVote?.id) || null,
      summaryId: sanitizeText(latestSummary?.id) || null
    }
  });
  const baseAvailable = actionContract.availableOnSurface && actionContract.uiStatus === 'ready';
  const uiReady = typeof availableOverride === 'boolean'
    ? baseAvailable && availableOverride
    : baseAvailable;
  const resolvedUnavailableKind = uiReady
    ? null
    : normalizeOpenClawIMErrorKind(unavailableKind ?? actionContract.uiUnavailableErrorKind ?? 'not_ready');

  return {
    laneKey: actionContract.uiLaneKey ?? actionContract.actionKey,
    actionKey: actionContract.actionKey,
    stage3Item: actionContract.stage3Item,
    title: sanitizeText(title) || actionContract.uiTitle || actionContract.label,
    surfaceKind: 'group',
    entrySurface: actionContract.entrySurface,
    route,
    handoff,
    targetID:
      sanitizeText(latestVote?.id) ||
      sanitizeText(latestSummary?.id) ||
      normalizedGroupId,
    requiredIDs: actionContract.requiredIDs,
    fallbackIDs: actionContract.fallbackIDs,
    optionalHints: actionContract.optionalHints,
    supportedErrorKinds: actionContract.supportedErrorKinds,
    uiReady,
    uiStatus: uiReady ? 'ready' : resolvedUnavailableKind,
    uiUnavailableCopy: actionContract.uiUnavailableCopy,
    surfaceGate: {
      allowedSurfaceKind: 'group',
      blockedBySurface: actionContract.blockedBySurface
    },
    errorSurface: uiReady
      ? null
      : buildOpenClawIMErrorSurface({
          kind: resolvedUnavailableKind,
          actionKey: actionContract.actionKey,
          surfaceKind: 'group',
          allowedSurfaceKind: 'group',
          detail: unavailableDetail
        }),
    payload: {
      groupId: normalizedGroupId,
      conversationId: sanitizeText(conversation.id) || null,
      voteId: sanitizeText(latestVote?.id) || null,
      summaryId: sanitizeText(latestSummary?.id) || null
    }
  };
}

export function buildGroupThreadActionLanes({
  conversation = {},
  votes = [],
  groupSummaries = [],
  sourceSurface = 'messages',
  messageCount = 0
} = {}) {
  const normalizedGroupId = sanitizeText(conversation.groupId) || null;
  if (!normalizedGroupId) {
    return [];
  }

  const latestVote = Array.isArray(votes) ? votes[0] ?? null : null;
  const latestOpenVote = Array.isArray(votes)
    ? votes.find((vote) => resolveGroupVoteStatus(vote.status, 'open') === 'open') ?? null
    : null;
  const latestSummary = Array.isArray(groupSummaries) ? groupSummaries[0] ?? null : null;

  return [
    buildGroupThreadActionLane({
      actionKey: 'launch_group_vote',
      title: '发起群投票',
      conversation,
      groupId: normalizedGroupId,
      sourceSurface
    }),
    buildGroupThreadActionLane({
      actionKey: 'cast_group_vote',
      title: '参与群投票',
      conversation,
      groupId: normalizedGroupId,
      sourceSurface,
      latestVote: latestOpenVote ?? latestVote,
      availableOverride: Boolean(latestOpenVote),
      unavailableKind: 'not_ready',
      unavailableDetail: latestVote && resolveGroupVoteStatus(latestVote.status, 'open') === 'closed'
        ? '上一轮投票已经关闭，当前没有开放中的 ballot。'
        : '当前群聊还没有开放中的投票。'
    }),
    buildGroupThreadActionLane({
      actionKey: 'summarize_group',
      title: '生成群总结',
      conversation,
      groupId: normalizedGroupId,
      sourceSurface,
      latestVote,
      latestSummary,
      availableOverride: Math.max(0, Number(messageCount) || 0) > 0,
      unavailableKind: 'not_ready',
      unavailableDetail: '群聊还没有可总结的消息上下文。'
    })
  ].filter(Boolean);
}

export function buildConversationGroupContextModel({
  conversation = {},
  participants = [],
  messages = [],
  votes = [],
  groupSummaries = [],
  sourceSurface = 'messages'
} = {}) {
  const summary = buildConversationSummaryModel({ conversation });
  if (summary.surfaceKind !== 'group') {
    return null;
  }

  const latestVote = Array.isArray(votes) ? votes[0] ?? null : null;
  const latestSummary = Array.isArray(groupSummaries) ? groupSummaries[0] ?? null : null;
  const toolAgent = participants.find((participant) => participant.role === 'tool_agent') ?? null;
  const actionLanes = buildGroupThreadActionLanes({
    conversation: {
      ...conversation,
      ...summary
    },
    votes,
    groupSummaries,
    sourceSurface,
    messageCount: messages.length
  });
  const ballotLane = actionLanes.find((lane) => lane.actionKey === 'cast_group_vote') ?? null;
  const summaryLane = actionLanes.find((lane) => lane.actionKey === 'summarize_group') ?? null;

  return {
    kind: 'conversation_group_context',
    conversationId: summary.conversationId,
    locator: summary.locator,
    groupId: summary.locator.groupID || sanitizeText(conversation.groupId) || null,
    channelId: summary.locator.channelID ?? summary.sourceChannelID,
    participantCount: participants.length,
    messageCount: messages.length,
    toolAgentParticipantKey: toolAgent?.participantKey ?? null,
    voteCount: Array.isArray(votes) ? votes.length : 0,
    latestVote: latestVote
      ? {
          voteId: sanitizeText(latestVote.id) || null,
          status: resolveGroupVoteStatus(latestVote.status),
          question: sanitizeText(latestVote.question) || null,
          resultSummary: sanitizeText(latestVote.resultSummary) || null,
          route: sanitizeText(latestVote.route) || ballotLane?.route || null,
          handoff: ballotLane?.handoff ?? null,
          updatedAt: normalizeIsoTimestamp(latestVote.updatedAt)
        }
      : null,
    summaryCount: Array.isArray(groupSummaries) ? groupSummaries.length : 0,
    latestSummary: latestSummary
      ? {
          summaryId: sanitizeText(latestSummary.id) || null,
          suppressedCount: Math.max(0, Number(latestSummary.suppressedCount) || 0),
          route: summaryLane?.route ?? null,
          handoff: summaryLane?.handoff ?? null,
          createdAt: normalizeIsoTimestamp(latestSummary.createdAt)
        }
      : null,
    actionLanes
  };
}

export function buildConversationOpenOutputModel({
  conversation = {},
  cardEnvelope = null,
  participants = [],
  messages = [],
  contextCards = [],
  votes = [],
  groupSummaries = [],
  sourceSurface = 'messages',
  homeRoute = null,
  homeHandoff = null
} = {}) {
  const conversationSummary = buildConversationSummaryModel({
    conversation,
    cardEnvelope
  });
  const participantModels = participants.map((participant) => buildConversationParticipantModel(participant));
  const participantByKey = new Map(
    participantModels
      .filter((participant) => participant.participantKey)
      .map((participant) => [participant.participantKey, participant])
  );
  const messageModels = messages.map((message) =>
    buildConversationMessageModel(message, participantByKey.get(sanitizeText(message.actorKey)))
  );
  const timelineItems = messageModels.map((messageModel) => buildConversationTimelineItemModel(messageModel));

  return {
    kind: 'conversation_open_output',
    conversation: conversationSummary,
    homeRoute: sanitizeText(homeRoute) || buildMessagesHomeRoute(),
    homeHandoff:
      homeHandoff ??
      buildMessagesHomeHandoff({
        sourceSurface: 'messages'
      }),
    participantCount: participantModels.length,
    participants: participantModels,
    messageCount: messageModels.length,
    messages: messageModels,
    timeline: {
      kind: 'conversation_timeline',
      itemCount: timelineItems.length,
      latestTimelineItemID: timelineItems.at(-1)?.timelineItemID ?? null,
      items: timelineItems
    },
    stageContext: buildConversationStageContextModel({
      conversation: {
        ...conversation,
        ...conversationSummary
      },
      participants: participantModels,
      messages: messageModels
    }),
    groupContext: buildConversationGroupContextModel({
      conversation: {
        ...conversation,
        ...conversationSummary
      },
      participants: participantModels,
      messages: messageModels,
      votes,
      groupSummaries,
      sourceSurface
    }),
    contextCards: Array.isArray(contextCards) ? contextCards.filter(Boolean) : []
  };
}

export function buildConversationSearchQueryModel({
  query,
  conversationId = null,
  locator = null,
  limit = 12
} = {}) {
  const text = sanitizeText(query) || '';
  const normalizedLocator = buildConversationLocatorFallback(
    {
      id: conversationId ?? null
    },
    locator ?? null
  );

  return {
    kind: 'conversation_search_query',
    text,
    normalizedText: text.toLowerCase(),
    conversationId:
      sanitizeText(conversationId) ||
      (normalizedLocator.kind === 'conversation' ? normalizedLocator.conversationID : null),
    locator: normalizedLocator,
    limit: Math.max(1, Number(limit) || 12)
  };
}

export function buildConversationSearchInputModel({
  userId,
  conversationId = null,
  locator = null,
  query,
  sourceSurface = 'messages',
  limit = 12
} = {}) {
  const queryModel = buildConversationSearchQueryModel({
    query,
    conversationId,
    locator,
    limit
  });

  return {
    kind: 'conversation_search_input',
    userId: sanitizeText(userId) || null,
    conversationId: queryModel.conversationId,
    locator: queryModel.locator,
    sourceSurface: sanitizeText(sourceSurface) || 'messages',
    limit: queryModel.limit,
    query: queryModel
  };
}

export function buildConversationSearchResultItem({
  conversation = {},
  message = {},
  participant = null,
  sourceSurface = 'messages'
} = {}) {
  const conversationSummary = buildConversationSummaryModel({ conversation });
  const messageModel = buildConversationMessageModel(message, participant);
  const locationPrimaryKey = {
    kind: 'message_id',
    value: messageModel.messageId,
    turnIndex: messageModel.turnIndex
  };

  return {
    kind: 'conversation_search_result_item',
    resultID:
      messageModel.messageId ||
      stableId(
        'conversation-search-result',
        conversationSummary.conversationId ?? 'unknown',
        messageModel.turnIndex ?? 0
      ),
    conversationId: conversationSummary.conversationId,
    locator: conversationSummary.locator,
    route: conversationSummary.route,
    handoff: buildMessagesThreadHandoff({
      sourceSurface,
      conversationId: conversationSummary.conversationId,
      channelId: conversationSummary.locator.channelID ?? conversationSummary.sourceChannelID,
      groupId: conversationSummary.locator.groupID ?? null,
      peerId: conversationSummary.locator.peerID ?? null,
      hint: {
        locationPrimaryKeyKind: locationPrimaryKey.kind,
        locationPrimaryKeyValue: locationPrimaryKey.value,
        locationTurnIndex: locationPrimaryKey.turnIndex
      }
    }),
    locationPrimaryKey,
    messageId: messageModel.messageId,
    turnIndex: messageModel.turnIndex,
    actorKey: messageModel.actorKey,
    actorRole: messageModel.actorRole,
    actorDisplayName: messageModel.actorDisplayName,
    channelKind: messageModel.channelKind,
    excerpt: messageModel.content,
    createdAt: messageModel.createdAt,
    suppressed: messageModel.suppressed,
    unreadForOwner: messageModel.unreadForOwner
  };
}

export function buildConversationSearchOutputModel({
  conversation = {},
  query,
  limit = 12,
  participants = [],
  hits = [],
  sourceSurface = 'messages'
} = {}) {
  const conversationSummary = buildConversationSummaryModel({ conversation });
  const queryModel = buildConversationSearchQueryModel({
    query,
    conversationId: conversationSummary.conversationId,
    locator: conversationSummary.locator,
    limit
  });
  const participantModels = participants.map((participant) => buildConversationParticipantModel(participant));
  const participantByKey = new Map(
    participantModels
      .filter((participant) => participant.participantKey)
      .map((participant) => [participant.participantKey, participant])
  );
  const resultItems = hits.map((message) =>
    buildConversationSearchResultItem({
      conversation,
      message,
      participant: participantByKey.get(sanitizeText(message.actorKey)),
      sourceSurface
    })
  );

  return {
    kind: 'conversation_search_output',
    conversation: conversationSummary,
    locator: conversationSummary.locator,
    query: queryModel,
    resultCount: resultItems.length,
    resultItems,
    emptyState: resultItems.length
      ? null
      : {
          kind: 'conversation_search_empty_state',
          reason: 'no_match',
          conversationId: conversationSummary.conversationId,
          locator: conversationSummary.locator,
          queryText: queryModel.text,
          resultCount: 0
        }
  };
}

function parseLegacyMessagesRoute(rawRoute) {
  const trimmed = sanitizeText(rawRoute);
  if (!trimmed) {
    throw new Error('Legacy messages route is required.');
  }

  let url = null;
  try {
    url = new URL(trimmed);
  } catch {
    throw new Error(`Invalid legacy messages route: ${trimmed}`);
  }

  if (url.protocol !== 'sparelife:' || sanitizeText(url.host) !== 'messages') {
    return null;
  }

  return {
    rawRoute: trimmed,
    path: sanitizeText(url.pathname.replace(/^\/+/, '')),
    searchParams: url.searchParams
  };
}

export function normalizeLegacyMessagesRoute(rawRoute, { sourceSurface = null, homeTab = 'recent' } = {}) {
  const parsed = parseLegacyMessagesRoute(rawRoute);
  if (!parsed) {
    return null;
  }

  const { rawRoute: normalizedRoute, path, searchParams } = parsed;

  if (path === 'self') {
    const draft = sanitizeText(searchParams.get('draft')) || null;
    const sessionId = sanitizeText(searchParams.get('session_id')) || null;
    if (!draft && !sessionId) {
      return null;
    }
    const context = sessionId ? { session_id: sessionId } : {};
    const handoff = buildMessagesComposeDraftHandoff({
      sourceSurface: sourceSurface ?? 'masters',
      draft,
      context
    });
    return {
      matchedKind: 'messages_self_draft',
      rawRoute: normalizedRoute,
      sourceSurface: handoff.sourceSurface,
      targetSurface: handoff.targetSurface,
      canonicalRoute: handoff.route,
      handoff,
      fallbackRoute: null,
      pendingThread: null,
      legacyContext: {
        draft,
        sessionId
      }
    };
  }

  if (path === 'thread') {
    const bondId = sanitizeText(searchParams.get('bond_id')) || null;
    if (bondId) {
      const icebreakSessionId = sanitizeText(searchParams.get('icebreak_session_id')) || null;
      const handoff = buildMessagesHomeHandoff({
        sourceSurface: sourceSurface ?? 'earn_social',
        tab: homeTab
      });
      return {
        matchedKind: 'messages_thread_bond_bridge',
        rawRoute: normalizedRoute,
        sourceSurface: handoff.sourceSurface,
        targetSurface: handoff.targetSurface,
        canonicalRoute: handoff.route,
        handoff,
        fallbackRoute: buildMessagesHomeRoute(homeTab),
        pendingThread: {
          kind: 'bond_bridge',
          bondId,
          icebreakSessionId
        },
        legacyContext: {
          bondId,
          icebreakSessionId
        }
      };
    }

    const laneId = sanitizeText(searchParams.get('lane')) || null;
    const counterpartName = sanitizeText(searchParams.get('counterpart')) || null;
    if (laneId && counterpartName) {
      const handoff = buildMessagesHomeHandoff({
        sourceSurface: sourceSurface ?? 'earn_social',
        tab: homeTab
      });
      return {
        matchedKind: 'messages_thread_lane_counterpart',
        rawRoute: normalizedRoute,
        sourceSurface: handoff.sourceSurface,
        targetSurface: handoff.targetSurface,
        canonicalRoute: handoff.route,
        handoff,
        fallbackRoute: buildMessagesHomeRoute(homeTab),
        pendingThread: {
          kind: 'lane_counterpart',
          laneId,
          counterpartName
        },
        legacyContext: {
          laneId,
          counterpartName
        }
      };
    }
  }

  return null;
}

export function buildConversationRoute({
  conversationId = null,
  kind = 'direct',
  contactId = null,
  groupId = null,
  channelId = COMPANION_CHANNEL_ID,
  peerId = null
}) {
  const locator = buildIMConversationLocator({
    conversationId,
    channelId,
    groupId,
    peerId,
    contactId
  });

  const params = new URLSearchParams();
  if (locator.kind === 'conversation') {
    params.set('conversation_id', locator.conversationID);
  } else if (locator.kind === 'group') {
    params.set('channel_id', locator.channelID);
    params.set('group_id', locator.groupID);
  } else {
    params.set('channel_id', locator.channelID);
    params.set('dm_peer_id', locator.peerID);
  }

  if (!conversationId) {
    params.set('kind', resolveConversationKind(kind));
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
