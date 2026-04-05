import { buildEarnSocialHomeRoute } from './a2aContracts.mjs';
import { buildMessagesHomeRoute } from './companionContracts.mjs';
import { buildMasterHomeRoute } from './masterContracts.mjs';
import { buildMyRoute } from './myContracts.mjs';
import {
  clampScore,
  isoNow,
  minutesSince,
  sanitizeText,
  stableId
} from './sceneContracts.mjs';

export const UNIFIED_HOME_KEYS = new Set([
  'xianxia',
  'masters',
  'earn_social',
  'my'
]);

export const FEED_CARD_TYPES = new Set([
  'summary',
  'person',
  'action',
  'status'
]);

export const CARD_EVENT_TYPES = new Set([
  'impression',
  'open',
  'continue',
  'like',
  'skip',
  'hide'
]);

const CARD_TYPE_PRIORITY = {
  summary: 74,
  person: 70,
  action: 78,
  status: 82
};

export function resolveUnifiedHomeKey(value, fallback = 'xianxia') {
  const normalized = sanitizeText(value) || fallback;
  if (!UNIFIED_HOME_KEYS.has(normalized)) {
    throw new Error(`Unsupported unified home key: ${normalized}`);
  }
  return normalized;
}

export function resolveFeedCardType(value, fallback = 'summary') {
  const normalized = sanitizeText(value) || fallback;
  if (!FEED_CARD_TYPES.has(normalized)) {
    throw new Error(`Unsupported feed card type: ${normalized}`);
  }
  return normalized;
}

export function resolveCardEventType(value, fallback = 'impression') {
  const normalized = sanitizeText(value) || fallback;
  if (!CARD_EVENT_TYPES.has(normalized)) {
    throw new Error(`Unsupported card event type: ${normalized}`);
  }
  return normalized;
}

export function buildSurfaceKey(surfaceKind, referenceId = null) {
  const normalizedSurface = sanitizeText(surfaceKind);
  if (!normalizedSurface) {
    throw new Error('surfaceKind is required.');
  }
  const normalizedReference = sanitizeText(referenceId);
  return normalizedReference ? `${normalizedSurface}:${normalizedReference}` : normalizedSurface;
}

export function buildUnifiedHomeRoute(homeKey, userId = null) {
  switch (resolveUnifiedHomeKey(homeKey)) {
    case 'masters':
      return buildMasterHomeRoute();
    case 'earn_social':
      return buildEarnSocialHomeRoute();
    case 'my':
      return buildMyRoute('home', {
        user_id: sanitizeText(userId)
      });
    case 'xianxia':
    default:
      return 'sparelife://xianxia/home';
  }
}

export function scoreFreshness(timestamp, nowIso = isoNow()) {
  const minutes = minutesSince(timestamp, nowIso);
  return clampScore(100 - minutes * 1.8);
}

export function estimateCardHeight({
  cardType,
  title = '',
  summary = '',
  metricCount = 0,
  actionCount = 0
}) {
  const typeBase = {
    summary: 208,
    person: 228,
    action: 214,
    status: 196
  }[resolveFeedCardType(cardType)] ?? 204;

  const textWeight = Math.min(76, Math.ceil((sanitizeText(title).length + sanitizeText(summary).length) * 0.38));
  return typeBase + textWeight + metricCount * 12 + actionCount * 16;
}

export function computeCardRanking({
  cardType,
  relevance = 0,
  freshness = 0,
  socialValue = 0,
  stateValue = 0
}) {
  const resolvedType = resolveFeedCardType(cardType);
  const scores = {
    relevance: clampScore(relevance),
    freshness: clampScore(freshness),
    socialValue: clampScore(socialValue),
    stateValue: clampScore(stateValue)
  };
  const total = clampScore(
    scores.relevance * 0.35 +
      scores.freshness * 0.25 +
      scores.socialValue * 0.2 +
      scores.stateValue * 0.2 +
      (CARD_TYPE_PRIORITY[resolvedType] - 70) * 0.25
  );
  return {
    ...scores,
    total
  };
}

export function buildFeedCardId(surfaceKey, sourceKind, referenceId) {
  return stableId('unified-feed-card', surfaceKey, sourceKind, referenceId);
}

export function buildUnifiedFeedCard({
  surfaceKey,
  sourceKind,
  referenceId,
  cardType,
  route,
  title,
  summary,
  badge = null,
  freshnessAt = null,
  relevanceScore = 0,
  socialValueScore = 0,
  stateScore = 0,
  metrics = [],
  quickActions = [],
  payload = {}
}) {
  const resolvedType = resolveFeedCardType(cardType);
  const normalizedSurface = sanitizeText(surfaceKey);
  const normalizedSource = sanitizeText(sourceKind);
  const normalizedReference = sanitizeText(referenceId) || normalizedSource;
  if (!normalizedSurface || !normalizedSource) {
    throw new Error('surfaceKey and sourceKind are required to build a feed card.');
  }

  const normalizedTitle = sanitizeText(title);
  const normalizedSummary = sanitizeText(summary);
  const ranking = computeCardRanking({
    cardType: resolvedType,
    relevance: relevanceScore,
    freshness: freshnessAt ? scoreFreshness(freshnessAt) : 56,
    socialValue: socialValueScore,
    stateValue: stateScore
  });

  return {
    cardId: buildFeedCardId(normalizedSurface, normalizedSource, normalizedReference),
    surfaceKey: normalizedSurface,
    sourceKind: normalizedSource,
    referenceId: normalizedReference,
    cardType: resolvedType,
    route: sanitizeText(route) || null,
    title: normalizedTitle,
    summary: normalizedSummary,
    badge: sanitizeText(badge) || null,
    freshnessAt: freshnessAt ? new Date(freshnessAt).toISOString() : null,
    ranking,
    metrics: Array.isArray(metrics) ? metrics.filter(Boolean) : [],
    quickActions: Array.isArray(quickActions) ? quickActions.filter(Boolean) : [],
    layout: {
      columns: 2,
      estimatedHeight: estimateCardHeight({
        cardType: resolvedType,
        title: normalizedTitle,
        summary: normalizedSummary,
        metricCount: Array.isArray(metrics) ? metrics.filter(Boolean).length : 0,
        actionCount: Array.isArray(quickActions) ? quickActions.filter(Boolean).length : 0
      }),
      emphasis: ranking.total >= 84 ? 'primary' : 'standard'
    },
    payload
  };
}

export function sortFeedCards(cards = []) {
  return [...cards].sort((left, right) => {
    if (right.ranking.total !== left.ranking.total) {
      return right.ranking.total - left.ranking.total;
    }
    if (right.ranking.stateValue !== left.ranking.stateValue) {
      return right.ranking.stateValue - left.ranking.stateValue;
    }
    if (right.ranking.freshness !== left.ranking.freshness) {
      return right.ranking.freshness - left.ranking.freshness;
    }
    return left.cardId.localeCompare(right.cardId);
  });
}

export function buildFeedSurface({
  surfaceKey,
  route,
  title,
  subtitle = null,
  cards = [],
  scrollState = null,
  metadata = {}
}) {
  return {
    surfaceKey: sanitizeText(surfaceKey),
    route: sanitizeText(route) || null,
    title: sanitizeText(title),
    subtitle: sanitizeText(subtitle) || null,
    layout: {
      kind: 'waterfall',
      columns: 2
    },
    scrollState,
    cardCount: cards.length,
    cards: sortFeedCards(cards),
    metadata
  };
}
