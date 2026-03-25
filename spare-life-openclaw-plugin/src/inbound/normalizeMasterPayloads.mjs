import {
  MASTER_CTA_EFFECTS,
  resolveConsultShareMode,
  resolveMemoryScope
} from '../../../spare-life-ios-app/Domain/Models/masterContracts.mjs';
import { sanitizeText, uniqueStrings } from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';

export function normalizeMasterAssetBundleInput(input) {
  if (!input?.bundle || typeof input.bundle !== 'object') {
    throw new Error('Master bundle input requires bundle.');
  }
  return {
    bundle: input.bundle,
    sourcePath: input.sourcePath
  };
}

export function normalizeMasterHomeInput(input) {
  return {
    userId: sanitizeText(input?.userId) || 'guest-viewer',
    query: sanitizeText(input?.query),
    domainKey: sanitizeText(input?.domainKey) || null
  };
}

export function normalizeMasterChatInput(input) {
  if (!sanitizeText(input?.masterId)) {
    throw new Error('Master chat input requires masterId.');
  }
  if (!sanitizeText(input?.message)) {
    throw new Error('Master chat input requires message.');
  }
  return {
    userId: sanitizeText(input?.userId) || 'guest-viewer',
    masterId: sanitizeText(input.masterId),
    sessionId: sanitizeText(input?.sessionId) || null,
    topic: sanitizeText(input?.topic) || sanitizeText(input.message),
    message: sanitizeText(input.message),
    memoryScope: resolveMemoryScope(input?.memoryScope, 'master_only')
  };
}

export function normalizeRestoreRecentInput(input) {
  return {
    userId: sanitizeText(input?.userId) || 'guest-viewer',
    sessionId: sanitizeText(input?.sessionId) || null
  };
}

export function normalizeCatalogMutationInput(input) {
  const operation = sanitizeText(input?.operation);
  if (!operation) {
    throw new Error('Catalog mutation input requires operation.');
  }
  return {
    operation,
    masterId: sanitizeText(input?.masterId) || null
  };
}

export function normalizeConsultationInput(input) {
  const masterIds = uniqueStrings(input?.masterIds ?? []);
  if (!masterIds.length) {
    throw new Error('Consultation input requires masterIds.');
  }
  if (!sanitizeText(input?.issue)) {
    throw new Error('Consultation input requires issue.');
  }
  return {
    userId: sanitizeText(input?.userId) || 'guest-viewer',
    issue: sanitizeText(input.issue),
    masterIds,
    shareMode: resolveConsultShareMode(input?.shareMode, 'cross_master')
  };
}

export function normalizeCTAActionInput(input) {
  if (!sanitizeText(input?.sourceKind) || !sanitizeText(input?.sourceId)) {
    throw new Error('CTA action input requires sourceKind and sourceId.');
  }
  if (!sanitizeText(input?.ctaId) || !sanitizeText(input?.route)) {
    throw new Error('CTA action input requires ctaId and route.');
  }
  const effectKind = sanitizeText(input?.effectKind) || 'masters';
  if (!MASTER_CTA_EFFECTS.has(effectKind)) {
    throw new Error(`Unsupported CTA effectKind: ${effectKind}`);
  }
  return {
    userId: sanitizeText(input?.userId) || 'guest-viewer',
    sourceKind: sanitizeText(input.sourceKind),
    sourceId: sanitizeText(input.sourceId),
    masterId: sanitizeText(input?.masterId) || null,
    ctaId: sanitizeText(input.ctaId),
    route: sanitizeText(input.route),
    effectKind
  };
}
