import {
  isoNow,
  sanitizeText
} from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';

function baseEnvelope({ normalizedEnvelope, status }) {
  return {
    eventType: 'openclaw_channel_response',
    requestId: normalizedEnvelope.requestId,
    envelopeVersion: normalizedEnvelope.envelopeVersion,
    channel: normalizedEnvelope.channel,
    routeKey: normalizedEnvelope.routeKey,
    action: normalizedEnvelope.action,
    status,
    handledAt: isoNow()
  };
}

export function buildUnifiedChannelSuccess({ normalizedEnvelope, result, guard, memory = null }) {
  return {
    ...baseEnvelope({
      normalizedEnvelope,
      status: guard?.requiresReview ? 'review' : 'ok'
    }),
    guard,
    memory,
    result
  };
}

export function buildUnifiedChannelIntercept({ normalizedEnvelope, guard }) {
  return {
    ...baseEnvelope({
      normalizedEnvelope,
      status: 'intercepted'
    }),
    guard,
    message: sanitizeText(guard?.risk?.reason) || 'request_intercepted'
  };
}

export function buildUnifiedChannelFailure({ normalizedEnvelope, error }) {
  return {
    ...baseEnvelope({
      normalizedEnvelope,
      status: 'error'
    }),
    error: {
      name: sanitizeText(error?.name) || 'Error',
      message: sanitizeText(error?.message) || 'Unknown channel runtime error.'
    }
  };
}
