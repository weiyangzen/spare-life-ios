import { sanitizeText } from '../Models/sceneContracts.mjs';
import {
  buildMemoryPrompt,
  extractMemoryKeywords,
  rankIntentCandidates,
  recallMemories,
  resolveIntentLabel,
  summarizeInteraction
} from '../../Services/LLMBridge/aiMemoryMatchingService.mjs';

function requireUserId(userId) {
  const normalized = sanitizeText(userId);
  if (!normalized) {
    throw new Error('userId is required.');
  }
  return normalized;
}

function toSourceText(payload) {
  const text = sanitizeText(payload.text);
  if (text) {
    return text;
  }
  if (Array.isArray(payload.messages)) {
    return payload.messages.map((item) => sanitizeText(item)).filter(Boolean).join(' ');
  }
  if (Array.isArray(payload.fragments)) {
    return payload.fragments.map((item) => sanitizeText(item)).filter(Boolean).join(' ');
  }
  return '';
}

export class AIMemoryMatchingUseCase {
  constructor({ repository }) {
    this.repository = repository;
  }

  rememberInteraction(payload) {
    const userId = requireUserId(payload.userId);
    const routeKey = sanitizeText(payload.routeKey) || 'ai_memory';
    const action = sanitizeText(payload.action) || 'remember';
    const sourceText = toSourceText(payload);
    if (!sourceText) {
      throw new Error('Memory source text is required.');
    }

    const intentLabel = resolveIntentLabel(payload.intentHint || sourceText);
    const prompt = buildMemoryPrompt({
      routeKey,
      action,
      intentLabel,
      text: sourceText,
      context: {
        userId,
        channel: sanitizeText(payload.channel) || 'openclaw',
        sourceRef: sanitizeText(payload.sourceRef) || null,
        intentHint: sanitizeText(payload.intentHint) || null
      }
    });
    const summary = summarizeInteraction({
      text: sourceText,
      intentLabel
    });
    const keywords = extractMemoryKeywords({
      text: sourceText,
      intentLabel,
      extraKeywords: payload.tags ?? []
    });

    const memory = this.repository.saveMemoryRecord({
      userId,
      channel: sanitizeText(payload.channel) || 'openclaw',
      routeKey,
      action,
      intentLabel,
      summary,
      promptPreview: prompt,
      keywords,
      sourceRef: sanitizeText(payload.sourceRef) || null,
      metadata: payload.metadata ?? {}
    });

    return {
      eventType: 'ai_memory_saved',
      intentLabel,
      memory
    };
  }

  recallMemories(payload) {
    const userId = requireUserId(payload.userId);
    const queryText = sanitizeText(payload.query || payload.text);
    if (!queryText) {
      throw new Error('query is required.');
    }

    const routeKey = sanitizeText(payload.routeKey) || 'ai_memory';
    const action = sanitizeText(payload.action) || 'recall';
    const intentLabel = resolveIntentLabel(payload.intentHint || queryText);
    const sourceRecords = this.repository.listMemoryRecords(userId, payload.sourceLimit ?? 120);
    const memories = recallMemories({
      records: sourceRecords,
      queryText,
      limit: payload.limit ?? 5
    });

    const queryLog = this.repository.recordMemoryQuery({
      userId,
      routeKey,
      action,
      queryText,
      intentLabel,
      recalledMemoryIds: memories.map((memory) => memory.id)
    });

    return {
      eventType: 'ai_memory_recalled',
      intentLabel,
      query: queryText,
      memories,
      queryLog
    };
  }

  matchIntentCandidates(payload) {
    const userId = requireUserId(payload.userId);
    const queryText = sanitizeText(payload.query || payload.text);
    if (!queryText) {
      throw new Error('query is required.');
    }

    if (!Array.isArray(payload.candidates) || payload.candidates.length === 0) {
      throw new Error('candidates are required for intent matching.');
    }

    const routeKey = sanitizeText(payload.routeKey) || 'ai_memory';
    const action = sanitizeText(payload.action) || 'match';
    const intentLabel = resolveIntentLabel(payload.intentHint || queryText);
    const sourceRecords = this.repository.listMemoryRecords(userId, payload.sourceLimit ?? 160);
    const recalled = recallMemories({
      records: sourceRecords,
      queryText,
      limit: payload.memoryLimit ?? 8
    });

    const rankedCandidates = rankIntentCandidates({
      candidates: payload.candidates,
      recalledMemories: recalled,
      intentLabel,
      queryText,
      limit: payload.limit ?? 5
    });

    const queryLog = this.repository.recordMemoryQuery({
      userId,
      routeKey,
      action,
      queryText,
      intentLabel,
      recalledMemoryIds: recalled.map((memory) => memory.id),
      candidateRanking: rankedCandidates
    });

    return {
      eventType: 'ai_match_ranked',
      intentLabel,
      query: queryText,
      recalled,
      rankedCandidates,
      queryLog
    };
  }

  inspectMemoryState(payload) {
    const userId = requireUserId(payload.userId);
    const baseState = this.repository.inspectFoundationState(userId);
    return {
      eventType: 'ai_memory_state',
      userId,
      counts: {
        memoryRecords: baseState.counts.memoryRecords,
        memoryQueries: baseState.counts.memoryQueries
      },
      latestMemory: baseState.latest.memory,
      latestAudit: baseState.latest.audit
    };
  }
}
