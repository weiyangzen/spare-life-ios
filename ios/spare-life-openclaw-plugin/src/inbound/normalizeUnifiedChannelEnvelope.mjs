import {
  isoNow,
  sanitizeText,
  stableId
} from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';
import { assertUnifiedChannelEnvelope } from '../schemas/unifiedChannelContracts.mjs';

export function normalizeUnifiedChannelEnvelope(payload) {
  const input = assertUnifiedChannelEnvelope(payload);
  const body = input.body ?? {};
  const userId = sanitizeText(body.userId || input.userId) || 'guest-user';

  return {
    requestId: sanitizeText(input.requestId) || stableId('openclaw-request', isoNow()),
    envelopeVersion: sanitizeText(input.envelopeVersion) || '2026-03-26',
    channel: sanitizeText(input.channel) || 'openclaw',
    routeKey: sanitizeText(input.routeKey),
    action: sanitizeText(input.action),
    userId,
    body: {
      ...body,
      userId
    },
    trace: {
      source: sanitizeText(input.trace?.source) || 'plugin',
      worker: sanitizeText(input.trace?.worker) || 'codex-func-lane',
      receivedAt: sanitizeText(input.trace?.receivedAt) || isoNow()
    }
  };
}
