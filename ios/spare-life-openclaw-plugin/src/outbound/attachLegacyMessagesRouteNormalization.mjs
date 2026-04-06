import { normalizeLegacyMessagesRoute } from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';

export function attachLegacyMessagesRouteNormalization(payload, route = payload?.route) {
  if (!route || typeof route !== 'string') {
    return payload;
  }

  try {
    const normalized = normalizeLegacyMessagesRoute(route);
    if (!normalized) {
      return payload;
    }
    return {
      ...payload,
      legacyMessagesRouteNormalization: normalized
    };
  } catch {
    return payload;
  }
}
