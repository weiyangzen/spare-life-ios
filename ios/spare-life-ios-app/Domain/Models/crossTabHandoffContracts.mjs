import {
  isoNow,
  sanitizeText,
  stableId
} from './sceneContracts.mjs';

export const APP_SURFACE_IDS = new Set([
  'xianxia',
  'masters',
  'earn_social',
  'messages',
  'my_profile'
]);

export const CROSS_TAB_ROUTE_KINDS = new Set([
  'home',
  'thread',
  'compose_draft',
  'memory'
]);

export const CROSS_TAB_HANDOFF_VERSION = 1;

export function resolveAppSurfaceID(value, fallback = null) {
  const normalized = sanitizeText(value) || sanitizeText(fallback);
  if (!normalized) {
    throw new Error('App surface ID is required.');
  }
  if (!APP_SURFACE_IDS.has(normalized)) {
    throw new Error(`Unsupported app surface ID: ${normalized}`);
  }
  return normalized;
}

export function resolveCrossTabRouteKind(value, fallback = 'home') {
  const normalized = sanitizeText(value) || fallback;
  if (!CROSS_TAB_ROUTE_KINDS.has(normalized)) {
    throw new Error(`Unsupported cross-tab route kind: ${normalized}`);
  }
  return normalized;
}

function sanitizeRouteParams(params = {}) {
  if (!params || typeof params !== 'object' || Array.isArray(params)) {
    return {};
  }
  return Object.fromEntries(
    Object.entries(params)
      .map(([key, value]) => [sanitizeText(key), sanitizeText(value)])
      .filter(([key, value]) => key && value)
  );
}

function normalizeMessagesLocator(locator) {
  if (!locator || typeof locator !== 'object' || Array.isArray(locator)) {
    throw new Error('Messages thread locator is required.');
  }

  const kind = sanitizeText(locator.kind);
  switch (kind) {
    case 'conversation': {
      const conversationID = sanitizeText(locator.conversationID ?? locator.conversationId);
      if (!conversationID) {
        throw new Error('Messages conversation locator requires conversationID.');
      }
      return {
        kind: 'conversation',
        conversationID
      };
    }
    case 'group': {
      const channelID = sanitizeText(locator.channelID ?? locator.channelId);
      const groupID = sanitizeText(locator.groupID ?? locator.groupId);
      if (!channelID || !groupID) {
        throw new Error('Messages group locator requires channelID and groupID.');
      }
      return {
        kind: 'group',
        channelID,
        groupID
      };
    }
    case 'dm': {
      const channelID = sanitizeText(locator.channelID ?? locator.channelId);
      const peerID = sanitizeText(locator.peerID ?? locator.peerId);
      if (!channelID || !peerID) {
        throw new Error('Messages dm locator requires channelID and peerID.');
      }
      return {
        kind: 'dm',
        channelID,
        peerID
      };
    }
    default:
      throw new Error(`Unsupported messages locator kind: ${kind || 'unknown'}`);
  }
}

export function normalizeCrossTabRoute(route, targetSurface) {
  if (!route || typeof route !== 'object' || Array.isArray(route)) {
    throw new Error('Cross-tab route payload is required.');
  }

  const surface = resolveAppSurfaceID(route.surface ?? targetSurface, targetSurface);
  const kind = resolveCrossTabRouteKind(route.kind, 'home');

  if (surface === 'messages' && kind === 'home') {
    return {
      surface,
      kind,
      tab: sanitizeText(route.tab) || 'recent'
    };
  }

  if (surface === 'messages' && kind === 'thread') {
    return {
      surface,
      kind,
      locator: normalizeMessagesLocator(route.locator),
      sourceSurface: resolveAppSurfaceID(route.sourceSurface, 'messages'),
      hint: sanitizeRouteParams(route.hint)
    };
  }

  return {
    surface,
    kind,
    params: sanitizeRouteParams(route.params)
  };
}

export function buildMessagesHomeRoutePayload({ tab = 'recent' } = {}) {
  return normalizeCrossTabRoute({
    surface: 'messages',
    kind: 'home',
    tab
  }, 'messages');
}

export function buildMessagesThreadRoutePayload({
  locator,
  sourceSurface = 'messages',
  hint = {}
}) {
  return normalizeCrossTabRoute({
    surface: 'messages',
    kind: 'thread',
    locator,
    sourceSurface,
    hint
  }, 'messages');
}

export function buildCrossTabHandoff({
  id = null,
  sourceSurface,
  targetSurface,
  createdAt = isoNow(),
  payloadVersion = CROSS_TAB_HANDOFF_VERSION,
  route
}) {
  const normalizedSource = resolveAppSurfaceID(sourceSurface);
  const normalizedTarget = resolveAppSurfaceID(targetSurface);
  const normalizedRoute = normalizeCrossTabRoute(route, normalizedTarget);
  const normalizedCreatedAt = new Date(createdAt).toISOString();
  const normalizedVersion = Number.isFinite(Number(payloadVersion)) && Number(payloadVersion) > 0
    ? Number(payloadVersion)
    : CROSS_TAB_HANDOFF_VERSION;

  return {
    id:
      sanitizeText(id) ||
      stableId(
        'cross-tab-handoff',
        normalizedSource,
        normalizedTarget,
        normalizedRoute.kind,
        JSON.stringify(normalizedRoute),
        normalizedCreatedAt
      ),
    sourceSurface: normalizedSource,
    targetSurface: normalizedTarget,
    createdAt: normalizedCreatedAt,
    payloadVersion: normalizedVersion,
    route: normalizedRoute
  };
}
