import { createHash } from 'node:crypto';

export const SCAN_TARGET_KINDS = new Set([
  'restaurant',
  'event',
  'brand',
  'group',
  'product',
  'person_card'
]);

export const SORT_MODES = new Set([
  'hottest',
  'newest',
  'best_match',
  'most_trusted'
]);

export const CHAT_MODES = new Set([
  'human_first',
  'agent_first',
  'dual_agent'
]);

export function stableId(prefix, ...parts) {
  const hash = createHash('sha1')
    .update(parts.filter(Boolean).join('::'))
    .digest('hex')
    .slice(0, 16);
  return `${prefix}_${hash}`;
}

export function fingerprint(value) {
  return createHash('sha1').update(JSON.stringify(value)).digest('hex');
}

export function isoNow(now = new Date()) {
  return new Date(now).toISOString();
}

export function sanitizeText(value) {
  return `${value ?? ''}`.trim().replace(/\s+/g, ' ');
}

export function uniqueStrings(values) {
  return [...new Set((values ?? []).map(sanitizeText).filter(Boolean))];
}

export function clampScore(value, minimum = 0, maximum = 100) {
  if (Number.isNaN(Number(value))) {
    return minimum;
  }
  return Math.min(maximum, Math.max(minimum, Number(value)));
}

export function minutesSince(timestamp, now = new Date()) {
  const then = new Date(timestamp);
  if (Number.isNaN(then.getTime())) {
    return 999;
  }
  return Math.max(0, (new Date(now).getTime() - then.getTime()) / 60_000);
}

export function keywordOverlap(left, right) {
  const a = new Set(uniqueStrings(left).map((item) => item.toLowerCase()));
  const b = new Set(uniqueStrings(right).map((item) => item.toLowerCase()));
  if (!a.size || !b.size) {
    return 0;
  }
  let hits = 0;
  for (const item of a) {
    if (b.has(item)) {
      hits += 1;
    }
  }
  return hits / Math.max(a.size, b.size);
}

export function toJson(value) {
  return JSON.stringify(value ?? null);
}

export function fromJson(value, fallback = null) {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

export function buildSceneRoute(sceneKey, scanTargetId) {
  const params = new URLSearchParams({
    scene_key: sceneKey,
    scan_target_id: scanTargetId
  });
  return `sparelife://scene/discussion?${params.toString()}`;
}

export function buildSocialRoute(intentId, sceneKey) {
  const params = new URLSearchParams({
    intent_id: intentId,
    scene_key: sceneKey
  });
  return `sparelife://earn-social/match?${params.toString()}`;
}

export function maskLocation(privacyRadius, locationLabel) {
  const safeLabel = sanitizeText(locationLabel);
  if (!safeLabel) {
    return 'scene only';
  }
  switch (privacyRadius) {
    case 'scene_only':
      return 'scene only';
    case 'city':
      return safeLabel.split(/[\s,-]+/).slice(0, 1).join(' ');
    case 'district':
    default:
      return safeLabel.split(/[\s,-]+/).slice(0, 2).join(' ');
  }
}

export function requireEnum(value, allowedValues, fallback, fieldName) {
  if (!value) {
    return fallback;
  }
  if (!allowedValues.has(value)) {
    throw new Error(`Invalid ${fieldName}: ${value}`);
  }
  return value;
}

export function sentimentLabel(sentiment) {
  switch (sentiment) {
    case 'positive':
      return '偏正向';
    case 'negative':
      return '偏负向';
    case 'divisive':
      return '存在明显分歧';
    default:
      return '相对中性';
  }
}
