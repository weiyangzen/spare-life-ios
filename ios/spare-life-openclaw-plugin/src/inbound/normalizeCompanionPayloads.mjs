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

export function normalizeMessagesHomeInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeConversationOpenInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireString(input.conversationId, 'conversationId'),
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
