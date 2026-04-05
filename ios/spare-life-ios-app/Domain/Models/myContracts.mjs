import {
  clampScore,
  sanitizeText,
  stableId,
  uniqueStrings
} from './sceneContracts.mjs';

export const PROFILE_VISIBILITY_LEVELS = new Set([
  'private',
  'trusted_circle',
  'public'
]);

export const TRAINING_STATUSES = new Set([
  'todo',
  'in_progress',
  'completed',
  'blocked'
]);

export const REPLAY_STATUSES = new Set([
  'open',
  'resolved',
  'ignored'
]);

export const REPLAY_SEVERITIES = new Set([
  'low',
  'medium',
  'high',
  'critical'
]);

export const GROWTH_MODES = new Set([
  'reflective',
  'steady',
  'resonant'
]);

export const MEMORY_SCOPES = new Set([
  'private',
  'agent_shared',
  'trusted_circle',
  'public'
]);

export const MEMORY_KINDS = new Set([
  'story',
  'constraint',
  'belief',
  'ritual',
  'goal',
  'reflection'
]);

export const AUTHORIZATION_STATUSES = new Set([
  'prompt',
  'authorized',
  'denied',
  'restricted'
]);

export const PRINCIPAL_ROLES = new Set([
  'owner',
  'agent',
  'trusted_circle',
  'public'
]);

export const DNA_TRAITS = [
  'warmth',
  'curiosity',
  'directness',
  'playfulness',
  'steadiness'
];

export function requireMyEnum(value, allowedValues, fallback, fieldName) {
  if (value === null || value === undefined || `${value}`.trim() === '') {
    return fallback;
  }

  const normalized = sanitizeText(value);
  if (!allowedValues.has(normalized)) {
    throw new Error(`Invalid ${fieldName}: ${value}`);
  }
  return normalized;
}

export function resolveVisibilityLevel(value, fallback = 'private') {
  return requireMyEnum(value, PROFILE_VISIBILITY_LEVELS, fallback, 'visibility level');
}

export function resolveTrainingStatus(value, fallback = 'todo') {
  return requireMyEnum(value, TRAINING_STATUSES, fallback, 'training status');
}

export function resolveReplayStatus(value, fallback = 'open') {
  return requireMyEnum(value, REPLAY_STATUSES, fallback, 'replay status');
}

export function resolveReplaySeverity(value, fallback = 'medium') {
  return requireMyEnum(value, REPLAY_SEVERITIES, fallback, 'replay severity');
}

export function resolveGrowthMode(value, fallback = 'steady') {
  return requireMyEnum(value, GROWTH_MODES, fallback, 'growth mode');
}

export function resolveMemoryScope(value, fallback = 'private') {
  return requireMyEnum(value, MEMORY_SCOPES, fallback, 'memory scope');
}

export function resolveMemoryKind(value, fallback = 'reflection') {
  return requireMyEnum(value, MEMORY_KINDS, fallback, 'memory kind');
}

export function resolveAuthorizationStatus(value, fallback = 'prompt') {
  return requireMyEnum(value, AUTHORIZATION_STATUSES, fallback, 'authorization status');
}

export function resolvePrincipalRole(value, fallback = 'owner') {
  return requireMyEnum(value, PRINCIPAL_ROLES, fallback, 'principal role');
}

export function normalizeVisibilityRules(visibility = {}) {
  const defaults = {
    displayName: 'public',
    agentDisplayName: 'public',
    headline: 'public',
    bio: 'private',
    city: 'trusted_circle',
    occupation: 'trusted_circle',
    growthFocus: 'public',
    personaTags: 'public',
    availabilityNote: 'trusted_circle'
  };

  return Object.fromEntries(
    Object.entries({
      ...defaults,
      ...(visibility ?? {})
    }).map(([fieldKey, value]) => [fieldKey, resolveVisibilityLevel(value, defaults[fieldKey] ?? 'private')])
  );
}

export function normalizePersonaDNA(dna = {}, fallback = {}) {
  return Object.fromEntries(
    DNA_TRAITS.map((trait) => [
      trait,
      clampScore(dna[trait] ?? fallback[trait] ?? 50, 0, 100)
    ])
  );
}

export function normalizePrincipalGrants(grants = []) {
  return uniqueStrings(grants).slice(0, 12);
}

export function buildMyRoute(section, params = {}) {
  const normalizedSection = sanitizeText(section) || 'home';
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    const normalized = sanitizeText(value);
    if (normalized) {
      query.set(key, normalized);
    }
  }
  const suffix = query.toString();
  return `sparelife://me/${normalizedSection}${suffix ? `?${suffix}` : ''}`;
}

export function buildProfileRoute(userId) {
  return buildMyRoute('profile', { user_id: userId });
}

export function buildSyncRoute(userId) {
  return buildMyRoute('sync', { user_id: userId });
}

export function buildPersonaRoute(userId) {
  return buildMyRoute('persona', { user_id: userId });
}

export function buildMemoryRoute(userId, memoryId = null) {
  return buildMyRoute('memory', {
    user_id: userId,
    memory_id: memoryId
  });
}

export function buildGrowthRoute(userId) {
  return buildMyRoute('growth', { user_id: userId });
}

export function buildPrivacyRoute(userId) {
  return buildMyRoute('privacy', { user_id: userId });
}

export function buildTrainingRoute(taskId) {
  return buildMyRoute('sync-training', { task_id: taskId });
}

export function buildReplayRoute(replayId) {
  return buildMyRoute('sync-replay', { replay_id: replayId });
}

export function buildBackupRoute(backupId) {
  return buildMyRoute('privacy-backup', { backup_id: backupId });
}

export function defaultMemoryTitleHint(memoryKind, memoryId) {
  const suffix = sanitizeText(memoryId).split('_').at(-1) ?? stableId('memory-hint', memoryKind).slice(-6);
  return `${resolveMemoryKind(memoryKind)}-${suffix}`;
}

export function rankTopTraits(dna = {}) {
  return DNA_TRAITS.map((trait) => ({
    key: trait,
    score: clampScore(dna[trait] ?? 0, 0, 100)
  }))
    .sort((left, right) => right.score - left.score || left.key.localeCompare(right.key))
    .slice(0, 3);
}
