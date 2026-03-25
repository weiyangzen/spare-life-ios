import { sanitizeText, uniqueStrings } from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';

function requireString(value, fieldName) {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    throw new Error(`${fieldName} is required.`);
  }
  return safeValue;
}

function sanitizeObject(input = {}) {
  return Object.fromEntries(
    Object.entries(input)
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => [key, typeof value === 'string' ? sanitizeText(value) : value])
  );
}

export function normalizeEarnSocialHomeInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    laneId: sanitizeText(input.laneId) || null,
    viewerTags: uniqueStrings(input.viewerTags ?? [])
  };
}

export function normalizeIntentPostInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    laneId: requireString(input.laneId, 'laneId'),
    templateId: requireString(input.templateId, 'templateId'),
    mode: sanitizeText(input.mode) || 'public',
    targetAgentId: sanitizeText(input.targetAgentId) || null,
    viewerTags: uniqueStrings(input.viewerTags ?? []),
    formPayload: sanitizeObject(input.formPayload ?? {})
  };
}

export function normalizeBrowsePersonaInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    laneId: requireString(input.laneId, 'laneId'),
    intentId: sanitizeText(input.intentId) || null,
    viewerTags: uniqueStrings(input.viewerTags ?? []),
    limit: Number.isFinite(Number(input.limit)) ? Number(input.limit) : 6
  };
}

export function normalizePersonaFeedbackInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    laneId: requireString(input.laneId, 'laneId'),
    agentId: requireString(input.agentId, 'agentId'),
    feedback: requireString(input.feedback, 'feedback'),
    reason: sanitizeText(input.reason) || null
  };
}

export function normalizeIcebreakStartInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    intentId: requireString(input.intentId, 'intentId'),
    targetAgentId: requireString(input.targetAgentId, 'targetAgentId'),
    mode: sanitizeText(input.mode) || 'dual_agent_first'
  };
}

export function normalizeConsentInput(input) {
  return {
    sessionId: requireString(input.sessionId, 'sessionId'),
    side: requireString(input.side, 'side'),
    granted: Boolean(input.granted)
  };
}

export function normalizeTrendInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    claimLaneId: sanitizeText(input.claimLaneId) || null
  };
}

export function normalizeArenaCreateInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    laneId: requireString(input.laneId, 'laneId'),
    theme: requireString(input.theme, 'theme'),
    challengerAgentId: requireString(input.challengerAgentId, 'challengerAgentId'),
    opponentAgentId: requireString(input.opponentAgentId, 'opponentAgentId')
  };
}

export function normalizeArenaVoteInput(input) {
  return {
    matchId: requireString(input.matchId, 'matchId'),
    voterUserId: requireString(input.voterUserId, 'voterUserId'),
    preferredSide: requireString(input.preferredSide, 'preferredSide'),
    weight: Number.isFinite(Number(input.weight)) ? Number(input.weight) : 1
  };
}

export function normalizeArenaResolveInput(input) {
  return {
    matchId: requireString(input.matchId, 'matchId'),
    userId: requireString(input.userId, 'userId')
  };
}

export function normalizeBondTaskInput(input) {
  return {
    userId: requireString(input.userId, 'userId'),
    taskId: requireString(input.taskId, 'taskId'),
    increment: Number.isFinite(Number(input.increment)) ? Number(input.increment) : 1
  };
}
