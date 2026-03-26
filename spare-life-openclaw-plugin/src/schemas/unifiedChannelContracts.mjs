import { sanitizeText } from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';

export const CHANNEL_ROUTES = new Set([
  'scene',
  'masters',
  'earn_social',
  'companion',
  'my',
  'unified_ui',
  'ai_memory',
  'security'
]);

export function assertUnifiedChannelEnvelope(payload) {
  if (!payload || typeof payload !== 'object') {
    throw new Error('Channel envelope payload must be an object.');
  }

  const requestId = sanitizeText(payload.requestId);
  if (!requestId) {
    throw new Error('requestId is required.');
  }

  const routeKey = sanitizeText(payload.routeKey);
  if (!CHANNEL_ROUTES.has(routeKey)) {
    throw new Error(`Unsupported routeKey: ${routeKey}`);
  }

  const action = sanitizeText(payload.action);
  if (!action) {
    throw new Error('action is required.');
  }

  const body = payload.body;
  if (body !== undefined && (body === null || typeof body !== 'object' || Array.isArray(body))) {
    throw new Error('body must be an object when provided.');
  }

  return payload;
}
