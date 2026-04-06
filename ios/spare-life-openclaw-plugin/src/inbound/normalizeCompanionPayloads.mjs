import {
  buildMessagesHomeRoute,
  normalizeIMCardEnvelope,
  normalizeIMConversationLocator,
  resolveMessagesHomeTab
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';

function requireString(value, fieldName) {
  const normalized = `${value ?? ''}`.trim();
  if (!normalized) {
    throw new Error(`Missing required field: ${fieldName}`);
  }
  return normalized;
}

function sanitizeArray(values = []) {
  return Array.isArray(values)
    ? values.map((value) => `${value ?? ''}`.trim()).filter(Boolean)
    : [];
}

function normalizeConversationLocatorInput(input) {
  if (input.locator && typeof input.locator === 'object') {
    return normalizeIMConversationLocator(input.locator);
  }

  return normalizeIMConversationLocator({
    conversationId: `${input.conversationId ?? input.conversation_id ?? ''}`.trim(),
    channelId: `${input.channelId ?? input.channel_id ?? ''}`.trim(),
    groupId: `${input.groupId ?? input.group_id ?? ''}`.trim(),
    peerId: `${input.peerId ?? input.peer_id ?? input.dmPeerId ?? input.dm_peer_id ?? input.contactId ?? input.contact_id ?? ''}`.trim()
  });
}

function normalizeCardEnvelopeInput(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return null;
  }
  return normalizeIMCardEnvelope(input);
}

export function normalizeMessagesHomeInput(input) {
  const tab = resolveMessagesHomeTab(input.tab ?? input.homeTab ?? 'recent');
  return {
    userId: requireString(input.userId, 'userId'),
    limit: Number(input.limit ?? 12),
    sourceSurface: `${input.sourceSurface ?? input.source_surface ?? ''}`.trim() || 'messages',
    tab,
    route: buildMessagesHomeRoute(tab)
  };
}

export function normalizeConversationOpenInput(input) {
  const envelope = normalizeCardEnvelopeInput(
    input.envelope ?? input.cardEnvelope ?? input.card_envelope ?? input.openAction?.cardEnvelope
  );
  const sourceSurface =
    `${input.sourceSurface ?? input.source_surface ?? input.openAction?.handoff?.sourceSurface ?? input.cardEnvelope?.handoff?.sourceSurface ?? input.envelope?.handoff?.sourceSurface ?? ''}`.trim() ||
    'messages';
  const locator = input.openAction?.locator
    ? normalizeIMConversationLocator(input.openAction.locator)
    : envelope?.locator ?? normalizeConversationLocatorInput(input);
  const conversationId =
    `${input.conversationId ?? input.conversation_id ?? input.openAction?.conversationId ?? ''}`.trim() ||
    envelope?.conversationId ||
    (locator.kind === 'conversation' ? locator.conversationID : null);

  return {
    userId: requireString(input.userId, 'userId'),
    conversationId,
    locator,
    envelope,
    sourceSurface,
    markRead: input.markRead !== false,
    limit: Number(input.limit ?? 40)
  };
}

export function normalizeConversationSearchInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireString(input.conversationId, 'conversationId'),
    query: requireString(input.query, 'query'),
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeDirectMessageInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireString(input.contactId, 'contactId'),
    text: requireString(input.text, 'text')
  };
}

export function normalizeMaskUpdateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireString(input.contactId, 'contactId'),
    tone: `${input.tone ?? ''}`.trim() || null,
    openness: `${input.openness ?? ''}`.trim() || null,
    boundaryTags: sanitizeArray(input.boundaryTags),
    signature: `${input.signature ?? ''}`.trim() || null,
    overrideRules: sanitizeArray(input.overrideRules),
    changeSummary: `${input.changeSummary ?? ''}`.trim() || null
  };
}

export function normalizeSharedStageDraftInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireString(input.contactId, 'contactId'),
    text: requireString(input.text, 'text')
  };
}

export function normalizeStageAccessInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireString(input.conversationId, 'conversationId'),
    participantKey: requireString(input.participantKey, 'participantKey'),
    granted: input.granted !== false
  };
}

export function normalizeStageMessageInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireString(input.conversationId, 'conversationId'),
    participantKey: requireString(input.participantKey, 'participantKey'),
    content: requireString(input.content, 'content'),
    channelKind: `${input.channelKind ?? ''}`.trim() || null
  };
}

export function normalizeRitualScheduleInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireString(input.contactId, 'contactId'),
    kind: requireString(input.kind, 'kind'),
    scheduledFor: `${input.scheduledFor ?? ''}`.trim() || null,
    note: `${input.note ?? ''}`.trim() || null
  };
}

export function normalizeRitualCompletionInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    ritualId: requireString(input.ritualId, 'ritualId'),
    note: `${input.note ?? ''}`.trim() || null
  };
}

export function normalizeGroupConversationInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireString(input.groupId, 'groupId'),
    limit: Number(input.limit ?? 40)
  };
}

export function normalizeGroupMessageInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireString(input.groupId, 'groupId'),
    actorKey: requireString(input.actorKey, 'actorKey'),
    content: requireString(input.content, 'content'),
    channelKind: `${input.channelKind ?? ''}`.trim() || null
  };
}

export function normalizeGroupVoteLaunchInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireString(input.groupId, 'groupId'),
    question: requireString(input.question, 'question'),
    options: sanitizeArray(input.options)
  };
}

export function normalizeGroupVoteBallotInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    voteId: requireString(input.voteId, 'voteId'),
    voterKey: requireString(input.voterKey, 'voterKey'),
    optionId: requireString(input.optionId, 'optionId'),
    rationale: `${input.rationale ?? ''}`.trim() || null
  };
}

export function normalizeGroupSummaryInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireString(input.groupId, 'groupId'),
    voteId: `${input.voteId ?? ''}`.trim() || null
  };
}

export function normalizeCompanionInspectInput(input) {
  return {
    userId: requireString(input.userId, 'userId')
  };
}
