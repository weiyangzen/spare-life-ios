import {
  fingerprint,
  sanitizeText,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const BLOCK_KEYWORDS = [
  '裸聊',
  '洗钱',
  '诈骗',
  '外挂',
  '爆破',
  '钓鱼',
  '仇恨',
  '约炮',
  '毒品'
];

const REVIEW_KEYWORDS = [
  '转账',
  '借钱',
  '银行卡',
  '身份证',
  '住址',
  '电话',
  '私密',
  '裸照',
  '交易'
];

function flattenPayloadText(input) {
  if (input === null || input === undefined) {
    return '';
  }
  if (typeof input === 'string' || typeof input === 'number' || typeof input === 'boolean') {
    return sanitizeText(input);
  }
  if (Array.isArray(input)) {
    return input.map((item) => flattenPayloadText(item)).filter(Boolean).join(' ');
  }
  if (typeof input === 'object') {
    return Object.values(input)
      .map((value) => flattenPayloadText(value))
      .filter(Boolean)
      .join(' ');
  }
  return '';
}

export function buildPayloadDigest(payload) {
  return fingerprint(payload ?? {});
}

export function evaluateRisk({ payload, routeKey, action }) {
  const text = flattenPayloadText(payload).toLowerCase();
  const blockHits = BLOCK_KEYWORDS.filter((keyword) => text.includes(keyword.toLowerCase()));
  const reviewHits = REVIEW_KEYWORDS.filter((keyword) => text.includes(keyword.toLowerCase()));

  if (blockHits.length > 0) {
    return {
      riskLevel: 'high',
      decision: 'block',
      reason: `命中高危词: ${blockHits.join('、')}`,
      tags: uniqueStrings(['high_risk', ...blockHits, sanitizeText(routeKey), sanitizeText(action)])
    };
  }

  if (reviewHits.length > 0) {
    return {
      riskLevel: 'medium',
      decision: 'review',
      reason: `命中敏感词: ${reviewHits.join('、')}`,
      tags: uniqueStrings(['needs_review', ...reviewHits, sanitizeText(routeKey), sanitizeText(action)])
    };
  }

  return {
    riskLevel: 'low',
    decision: 'allow',
    reason: '未命中风控规则。',
    tags: uniqueStrings([sanitizeText(routeKey), sanitizeText(action)])
  };
}

export function resolvePermissionEffect(rule, fallback = 'allow') {
  if (!rule) {
    return fallback;
  }
  return sanitizeText(rule.effect) || fallback;
}
