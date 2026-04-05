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

export function normalizeWaterfallHomeInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    homeKey: requireString(input.homeKey, 'homeKey'),
    query: `${input.query ?? ''}`.trim() || null,
    domainKey: `${input.domainKey ?? ''}`.trim() || null,
    laneId: `${input.laneId ?? ''}`.trim() || null,
    viewerTags: sanitizeArray(input.viewerTags),
    principalKey: `${input.principalKey ?? ''}`.trim() || null,
    principalRole: `${input.principalRole ?? ''}`.trim() || null,
    vaultSecret: `${input.vaultSecret ?? ''}`.trim() || null,
    memoryLimit: Number(input.memoryLimit ?? 4),
    limit: Number(input.limit ?? 6)
  };
}

export function normalizeConversationHubInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeConversationDetailInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireString(input.conversationId, 'conversationId'),
    markRead: input.markRead !== false,
    limit: Number(input.limit ?? 40)
  };
}

export function normalizeScrollStateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    surfaceKey: requireString(input.surfaceKey, 'surfaceKey'),
    anchorCardId: `${input.anchorCardId ?? ''}`.trim() || null,
    anchorOffset: Number(input.anchorOffset ?? 0),
    lastVisibleCardId: `${input.lastVisibleCardId ?? ''}`.trim() || null,
    metadata: input.metadata && typeof input.metadata === 'object' ? input.metadata : {}
  };
}

export function normalizeCardEventInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    surfaceKey: requireString(input.surfaceKey, 'surfaceKey'),
    cardId: requireString(input.cardId, 'cardId'),
    cardType: `${input.cardType ?? ''}`.trim() || null,
    referenceId: `${input.referenceId ?? ''}`.trim() || null,
    eventType: `${input.eventType ?? ''}`.trim() || null,
    route: `${input.route ?? ''}`.trim() || null,
    detail: input.detail && typeof input.detail === 'object' ? input.detail : {}
  };
}

export function normalizeUnifiedInspectInput(input) {
  return {
    userId: requireString(input.userId, 'userId')
  };
}
