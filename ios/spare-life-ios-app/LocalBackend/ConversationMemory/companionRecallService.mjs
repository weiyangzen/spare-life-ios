import {
  clipText,
  scoreTextMatch,
  tokenizeText
} from '../../Domain/Models/masterContracts.mjs';
import {
  COMPANION_MEMORY_LAYERS,
  deriveRelationshipLevelFromWarmth
} from '../../Domain/Models/companionContracts.mjs';
import {
  clampScore,
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const EMOTION_RULES = [
  {
    label: '被压力顶住',
    keywords: ['焦虑', '压力', '赶', '来不及', '担心', '撑不住', '卡住']
  },
  {
    label: '期待推进',
    keywords: ['想', '一起', '推进', '安排', '约', '做完', '收尾']
  },
  {
    label: '需要被接住',
    keywords: ['累', '委屈', '想聊', '失落', '低落', '烦']
  },
  {
    label: '轻松连接',
    keywords: ['散步', '咖啡', '跑步', '周末', '轻松', '开心']
  }
];

export function detectEmotionLabel(text) {
  const normalized = sanitizeText(text).toLowerCase();
  if (!normalized) {
    return '平稳过渡';
  }

  let winner = {
    label: '平稳过渡',
    score: 0
  };

  for (const rule of EMOTION_RULES) {
    const score = rule.keywords.filter((keyword) => normalized.includes(keyword)).length;
    if (score > winner.score) {
      winner = {
        label: rule.label,
        score
      };
    }
  }

  return winner.label;
}

function buildLatestStateSummary({ userMessage, counterpartMessage }) {
  const left = clipText(userMessage, 42);
  const right = clipText(counterpartMessage, 42);
  if (left && right) {
    return `上一段停在“${left}”，对方回到了“${right}”。`;
  }
  if (left) {
    return `上一段你主动提到了“${left}”。`;
  }
  return '上一段对话留下了新的互动线索。';
}

function buildEmotionSummary({ emotionLabel, relationship }) {
  return `上次情绪快照是“${emotionLabel}”，关系温度约 ${Math.round(
    clampScore(relationship?.warmthScore ?? 40)
  )} 分。`;
}

function buildRelationshipSummary({ relationship, counterpartName }) {
  const warmth = clampScore(relationship?.warmthScore ?? 40);
  const level = deriveRelationshipLevelFromWarmth(warmth);
  const recentSummary = sanitizeText(relationship?.latestSummary);
  return recentSummary
    ? `${counterpartName} 当前处于 ${level} 关系层，最近摘要：${clipText(recentSummary, 72)}`
    : `${counterpartName} 当前处于 ${level} 关系层，温度约 ${Math.round(warmth)} 分。`;
}

export function buildLayeredMemorySnapshots({
  userId,
  contactId,
  counterpartName,
  conversationId,
  userMessage,
  counterpartMessage,
  relationship,
  sourceMessageIds = [],
  nowIso = isoNow()
}) {
  const combined = `${sanitizeText(userMessage)} ${sanitizeText(counterpartMessage)}`.trim();
  const emotionLabel = detectEmotionLabel(combined);
  const keywords = uniqueStrings([
    ...tokenizeText(userMessage),
    ...tokenizeText(counterpartMessage),
    relationship?.level,
    emotionLabel
  ]);

  const summaries = {
    latest_state: buildLatestStateSummary({
      userMessage,
      counterpartMessage
    }),
    emotion_snapshot: buildEmotionSummary({
      emotionLabel,
      relationship
    }),
    relationship_summary: buildRelationshipSummary({
      relationship,
      counterpartName
    })
  };

  return [...COMPANION_MEMORY_LAYERS].map((layer) => ({
    id: stableId('companion-memory', conversationId, contactId, layer, nowIso),
    userId,
    contactId,
    conversationId,
    layer,
    summary: summaries[layer],
    keywords,
    emotionLabel,
    warmthScore: clampScore(relationship?.warmthScore ?? 40),
    sourceMessageIds,
    createdAt: nowIso
  }));
}

export function recallRelevantMemorySnapshots({ snapshots, message, limit = 3 }) {
  const normalized = sanitizeText(message);
  return (snapshots ?? [])
    .map((snapshot) => ({
      ...snapshot,
      relevance: scoreTextMatch(
        `${snapshot.summary} ${(snapshot.keywords ?? []).join(' ')}`,
        normalized
      )
    }))
    .filter((snapshot) => snapshot.relevance > 0)
    .sort((left, right) => right.relevance - left.relevance || right.createdAt.localeCompare(left.createdAt))
    .slice(0, limit);
}

export function collapseMemoryLayers(snapshots) {
  const latestByLayer = new Map();
  for (const snapshot of (snapshots ?? []).sort((left, right) => right.createdAt.localeCompare(left.createdAt))) {
    if (!latestByLayer.has(snapshot.layer)) {
      latestByLayer.set(snapshot.layer, snapshot);
    }
  }
  return [...latestByLayer.values()].sort((left, right) => left.layer.localeCompare(right.layer));
}
