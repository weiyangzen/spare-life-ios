import { createHash } from 'node:crypto';

import {
  isoNow,
  keywordOverlap,
  sanitizeText,
  stableId,
  uniqueStrings
} from './sceneContracts.mjs';

export const MASTER_MEMORY_SCOPES = new Set(['session_only', 'master_only', 'cross_master']);
export const MASTER_CONSULT_SHARE_MODES = new Set(['master_only', 'cross_master']);
export const MASTER_CTA_EFFECTS = new Set(['messages', 'earn_social', 'profile', 'masters']);

export function sha1(value) {
  return createHash('sha1').update(value).digest('hex');
}

export function tokenizeText(value) {
  const normalized = sanitizeText(value).toLowerCase();
  if (!normalized) {
    return [];
  }

  const latinTokens = normalized.match(/[a-z0-9]+/g) ?? [];
  const hanRuns = normalized.match(/[\p{Script=Han}]{2,}/gu) ?? [];
  const hanTokens = hanRuns.flatMap((run) => {
    const tokens = [run];
    for (const size of [2, 3, 4]) {
      if (run.length < size) {
        continue;
      }
      for (let index = 0; index <= run.length - size; index += 1) {
        tokens.push(run.slice(index, index + size));
      }
    }
    return tokens;
  });

  return uniqueStrings([...latinTokens, ...hanTokens]);
}

export function scoreTextMatch(text, candidateTerms) {
  const haystack = tokenizeText(text);
  const needles = Array.isArray(candidateTerms)
    ? uniqueStrings(candidateTerms.flatMap((item) => tokenizeText(item)))
    : tokenizeText(candidateTerms);

  if (!haystack.length || !needles.length) {
    return 0;
  }

  const overlap = keywordOverlap(haystack, needles);
  const loweredText = sanitizeText(text).toLowerCase();
  const substringHits = needles.filter((needle) => loweredText.includes(needle)).length;
  const substringScore = substringHits / needles.length;
  return overlap * 0.65 + substringScore * 0.35;
}

export function resolveMemoryScope(value, fallback = 'master_only') {
  if (!value) {
    return fallback;
  }
  if (!MASTER_MEMORY_SCOPES.has(value)) {
    throw new Error(`Unsupported master memory scope: ${value}`);
  }
  return value;
}

export function resolveConsultShareMode(value, fallback = 'cross_master') {
  if (!value) {
    return fallback;
  }
  if (!MASTER_CONSULT_SHARE_MODES.has(value)) {
    throw new Error(`Unsupported consultation share mode: ${value}`);
  }
  return value;
}

export function buildMasterHomeRoute({ domainKey = null, query = '' } = {}) {
  const params = new URLSearchParams();
  if (sanitizeText(domainKey)) {
    params.set('domain', sanitizeText(domainKey));
  }
  if (sanitizeText(query)) {
    params.set('query', sanitizeText(query));
  }
  const suffix = params.toString();
  return `sparelife://masters/home${suffix ? `?${suffix}` : ''}`;
}

export function buildMasterChatRoute(masterId, sessionId = null) {
  const params = new URLSearchParams({
    master_id: sanitizeText(masterId)
  });
  if (sanitizeText(sessionId)) {
    params.set('session_id', sanitizeText(sessionId));
  }
  return `sparelife://masters/chat?${params.toString()}`;
}

export function buildMasterConsultRoute(consultationId) {
  return `sparelife://masters/consultation?consultation_id=${encodeURIComponent(
    sanitizeText(consultationId)
  )}`;
}

export function buildPromptPreview(template) {
  return sanitizeText(template).slice(0, 120);
}

export function combineTags(...lists) {
  return uniqueStrings(lists.flatMap((list) => list ?? []).map((item) => sanitizeText(item)));
}

export function clipText(value, maxLength = 180) {
  const normalized = sanitizeText(value);
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, maxLength - 1)}…`;
}

export function deriveStanceLabel(character = {}) {
  switch (character.decisionStyle) {
    case 'act_then_reflect':
      return '先行动后校准';
    case 'small_bets_profit':
      return '先算账再放大';
    case 'resilient_expression':
      return '先稳情绪再表达';
    case 'steady_execution':
    default:
      return '先立边界再推进';
  }
}

export function buildEffectRoute(effectKind, payload = {}) {
  const safeEffect = MASTER_CTA_EFFECTS.has(effectKind) ? effectKind : 'masters';
  switch (safeEffect) {
    case 'messages': {
      const params = new URLSearchParams();
      if (sanitizeText(payload.draft)) {
        params.set('draft', sanitizeText(payload.draft));
      }
      if (sanitizeText(payload.sessionId)) {
        params.set('session_id', sanitizeText(payload.sessionId));
      }
      return `sparelife://messages/self?${params.toString()}`;
    }
    case 'earn_social': {
      const params = new URLSearchParams();
      if (sanitizeText(payload.lane)) {
        params.set('lane', sanitizeText(payload.lane));
      }
      if (sanitizeText(payload.topic)) {
        params.set('topic', sanitizeText(payload.topic));
      }
      return `sparelife://earn-social/market?${params.toString()}`;
    }
    case 'profile':
      return 'sparelife://my/profile?highlight=memory';
    case 'masters':
    default:
      return buildMasterHomeRoute({
        domainKey: payload.domainKey,
        query: payload.query
      });
  }
}

export function buildTrackedActionId(prefix, ...parts) {
  return stableId(prefix, ...parts, isoNow());
}

export { stableId };
