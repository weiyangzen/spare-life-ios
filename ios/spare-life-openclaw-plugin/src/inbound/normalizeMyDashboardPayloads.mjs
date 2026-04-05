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

function sanitizeObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function normalizeMasks(masks = []) {
  return Array.isArray(masks)
    ? masks.map((mask) => ({
        id: `${mask?.id ?? ''}`.trim() || null,
        label: `${mask?.label ?? ''}`.trim() || null,
        scenarioKey: `${mask?.scenarioKey ?? ''}`.trim() || null,
        tone: `${mask?.tone ?? ''}`.trim() || null,
        openness: `${mask?.openness ?? ''}`.trim() || null,
        boundaryTags: sanitizeArray(mask?.boundaryTags),
        styleTags: sanitizeArray(mask?.styleTags),
        isDefault: Boolean(mask?.isDefault)
      }))
    : [];
}

export function normalizeMyHomeInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    principalKey: `${input.principalKey ?? ''}`.trim() || 'self_human',
    principalRole: `${input.principalRole ?? ''}`.trim() || 'owner',
    vaultSecret: `${input.vaultSecret ?? ''}`.trim() || null,
    memoryLimit: Number(input.memoryLimit ?? 4)
  };
}

export function normalizeProfileUpdateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    displayName: `${input.displayName ?? ''}`.trim() || null,
    agentDisplayName: `${input.agentDisplayName ?? ''}`.trim() || null,
    headline: `${input.headline ?? ''}`.trim() || null,
    bio: `${input.bio ?? ''}`.trim() || null,
    city: `${input.city ?? ''}`.trim() || null,
    occupation: `${input.occupation ?? ''}`.trim() || null,
    growthFocus: `${input.growthFocus ?? ''}`.trim() || null,
    personaTags: sanitizeArray(input.personaTags),
    interests: sanitizeArray(input.interests),
    availabilityNote: `${input.availabilityNote ?? ''}`.trim() || null,
    visibility: sanitizeObject(input.visibility)
  };
}

export function normalizeTrainingCompletionInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    taskId: requireString(input.taskId, 'taskId')
  };
}

export function normalizeReplayResolveInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    replayId: requireString(input.replayId, 'replayId'),
    resolvedNote: `${input.resolvedNote ?? ''}`.trim() || null
  };
}

export function normalizePersonaUpdateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    awakeningSeed: input.awakeningSeed === undefined ? null : Number(input.awakeningSeed),
    growthMode: `${input.growthMode ?? ''}`.trim() || null,
    activeMaskId: `${input.activeMaskId ?? ''}`.trim() || null,
    dna: sanitizeObject(input.dna),
    values: sanitizeArray(input.values),
    masks: normalizeMasks(input.masks)
  };
}

export function normalizeMemorySaveInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    memoryId: `${input.memoryId ?? ''}`.trim() || null,
    vaultSecret: requireString(input.vaultSecret, 'vaultSecret'),
    title: requireString(input.title, 'title'),
    summary: `${input.summary ?? ''}`.trim() || null,
    content: requireString(input.content, 'content'),
    memoryKind: `${input.memoryKind ?? ''}`.trim() || null,
    permissionScope: `${input.permissionScope ?? ''}`.trim() || null,
    emotion: `${input.emotion ?? ''}`.trim() || null,
    source: `${input.source ?? ''}`.trim() || null,
    tags: sanitizeArray(input.tags),
    grants: sanitizeArray(input.grants)
  };
}

export function normalizeMemoryListInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    vaultSecret: requireString(input.vaultSecret, 'vaultSecret'),
    principalKey: `${input.principalKey ?? ''}`.trim() || 'self_human',
    principalRole: `${input.principalRole ?? ''}`.trim() || 'owner',
    query: `${input.query ?? ''}`.trim() || null,
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeGrowthJournalInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    title: requireString(input.title, 'title'),
    body: requireString(input.body, 'body'),
    mood: `${input.mood ?? ''}`.trim() || null,
    statDelta: sanitizeObject(input.statDelta),
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeGrowthReviewInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeAuthorizationUpdateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    resourceKey: requireString(input.resourceKey, 'resourceKey'),
    status: requireString(input.status, 'status'),
    detail: `${input.detail ?? ''}`.trim() || null,
    lastPromptedAt: `${input.lastPromptedAt ?? ''}`.trim() || null
  };
}

export function normalizeBackupCreateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    label: `${input.label ?? ''}`.trim() || null
  };
}

export function normalizeBackupCleanupInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    keepLatest: Number(input.keepLatest ?? 1)
  };
}

export function normalizeMyInspectInput(input) {
  return {
    userId: requireString(input.userId, 'userId')
  };
}
