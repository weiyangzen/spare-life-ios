import {
  clipText,
  scoreTextMatch,
  tokenizeText
} from '../../Domain/Models/masterContracts.mjs';
import {
  clampScore,
  isoNow,
  minutesSince,
  sanitizeText,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const INTENT_RULES = [
  {
    label: 'relationship_support',
    keywords: ['关系', '陪', '沟通', '记住', '情绪', '聊天', '对方', '群聊']
  },
  {
    label: 'career_growth',
    keywords: ['求职', '转岗', '作品集', '面试', '职业', '学习', '成长']
  },
  {
    label: 'a2a_matchmaking',
    keywords: ['撮合', '匹配', '赛道', '合作', '意图', '市场', '破冰']
  },
  {
    label: 'risk_and_privacy',
    keywords: ['风险', '安全', '审计', '举报', '权限', '隐私', '拦截']
  }
];

export function resolveIntentLabel(inputText, fallback = 'general_chat') {
  const normalized = sanitizeText(inputText).toLowerCase();
  if (!normalized) {
    return fallback;
  }

  let winner = {
    label: fallback,
    score: 0
  };

  for (const rule of INTENT_RULES) {
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

export function buildMemoryPrompt({ routeKey, action, intentLabel, text, context = {} }) {
  const contextParts = uniqueStrings([
    context.channel,
    context.userId,
    context.sourceRef,
    context.intentHint
  ]);
  return [
    `你是 Spare Life 的本地记忆总结器。`,
    `任务: 把这次 ${sanitizeText(routeKey)}/${sanitizeText(action)} 交互压缩成可检索摘要。`,
    `意图标签: ${sanitizeText(intentLabel)}。`,
    contextParts.length ? `上下文: ${contextParts.join(' | ')}。` : null,
    `原始输入: ${sanitizeText(text)}`
  ]
    .filter(Boolean)
    .join('\n');
}

export function summarizeInteraction({ text, intentLabel }) {
  const normalized = sanitizeText(text);
  if (!normalized) {
    return '空输入，未生成可检索摘要。';
  }

  const sentences = normalized
    .split(/[。！？!?]/)
    .map((segment) => sanitizeText(segment))
    .filter(Boolean);
  const lead = sentences[0] ?? normalized;
  const second = sentences[1] ?? '';
  const summary = second
    ? `${lead}；补充：${clipText(second, 52)}`
    : clipText(lead, 90);

  return `[${sanitizeText(intentLabel)}] ${clipText(summary, 118)}`;
}

export function extractMemoryKeywords({ text, intentLabel, extraKeywords = [] }) {
  const tokens = tokenizeText(text);
  const topical = tokens.filter((token) => token.length >= 2).slice(0, 24);
  return uniqueStrings([
    intentLabel,
    ...extraKeywords,
    ...topical
  ]);
}

function recencyBoost(createdAt, nowIso = isoNow()) {
  const ageMinutes = minutesSince(createdAt, nowIso);
  if (ageMinutes <= 10) {
    return 0.18;
  }
  if (ageMinutes <= 60) {
    return 0.12;
  }
  if (ageMinutes <= 24 * 60) {
    return 0.06;
  }
  return 0;
}

export function recallMemories({ records, queryText, limit = 5, nowIso = isoNow() }) {
  const normalizedQuery = sanitizeText(queryText);

  return (records ?? [])
    .map((record) => {
      const lexical = scoreTextMatch(
        `${record.summary} ${(record.keywords ?? []).join(' ')}`,
        normalizedQuery
      );
      const intentAffinity = record.intentLabel === resolveIntentLabel(normalizedQuery, record.intentLabel)
        ? 0.12
        : 0;
      const relevance = lexical + recencyBoost(record.createdAt, nowIso) + intentAffinity;
      return {
        ...record,
        relevance: clampScore(relevance * 100, 0, 100)
      };
    })
    .filter((record) => record.relevance > 0)
    .sort((left, right) => right.relevance - left.relevance || right.createdAt.localeCompare(left.createdAt))
    .slice(0, limit);
}

export function rankIntentCandidates({
  candidates,
  recalledMemories,
  intentLabel,
  queryText,
  limit = 5
}) {
  const normalizedQuery = sanitizeText(queryText);
  const memoryContext = (recalledMemories ?? [])
    .map((item) => `${item.summary} ${(item.keywords ?? []).join(' ')}`)
    .join(' ');

  return (candidates ?? [])
    .map((candidate, index) => {
      const candidateText = sanitizeText(candidate.summary || candidate.title || candidate.id || `candidate-${index}`);
      const candidateTags = uniqueStrings(candidate.tags ?? []);
      const semanticScore = scoreTextMatch(
        `${candidateText} ${candidateTags.join(' ')}`,
        [normalizedQuery, memoryContext, intentLabel]
      );
      const memoryBoost = (recalledMemories ?? []).some((memory) =>
        (memory.keywords ?? []).some((keyword) => candidateTags.includes(keyword))
      )
        ? 0.1
        : 0;
      const finalScore = clampScore((semanticScore + memoryBoost) * 100, 0, 100);
      return {
        candidateId: sanitizeText(candidate.id) || `candidate-${index + 1}`,
        summary: candidateText,
        tags: candidateTags,
        score: finalScore,
        reason:
          memoryBoost > 0
            ? '命中历史记忆关键词，并与当前意图一致。'
            : '与当前查询和意图语义匹配。'
      };
    })
    .sort((left, right) => right.score - left.score || left.candidateId.localeCompare(right.candidateId, 'en'))
    .slice(0, limit);
}
