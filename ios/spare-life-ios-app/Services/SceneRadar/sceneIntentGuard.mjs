import { randomUUID } from 'node:crypto';

import {
  CHAT_MODES,
  buildSocialRoute,
  requireEnum,
  sanitizeText,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const HARASSMENT_KEYWORDS = [
  '约炮',
  '开房',
  '裸照',
  '滚',
  '别装了',
  '快点加我'
];

function containsHarassment(text) {
  const lowered = text.toLowerCase();
  return HARASSMENT_KEYWORDS.find((keyword) => lowered.includes(keyword.toLowerCase())) ?? null;
}

export function evaluateIntentRisk({ intentRequest, recentIntentCount, targetAgent }) {
  const mode = requireEnum(intentRequest.mode, CHAT_MODES, 'agent_first', 'intent mode');
  const message = sanitizeText(intentRequest.message);
  if (!message) {
    return {
      status: 'blocked',
      reason: 'empty_message',
      mode
    };
  }

  const harassmentKeyword = containsHarassment(message);
  if (harassmentKeyword) {
    return {
      status: 'blocked',
      reason: `harassment_keyword:${harassmentKeyword}`,
      mode
    };
  }

  if (recentIntentCount > 0) {
    return {
      status: 'blocked',
      reason: 'rate_limited_recent_duplicate',
      mode
    };
  }

  if (targetAgent && !targetAgent.allowsAgentIntro && mode !== 'human_first') {
    return {
      status: 'blocked',
      reason: 'target_requires_human_first',
      mode
    };
  }

  return {
    status: 'allowed',
    reason: 'ok',
    mode
  };
}

export function buildIntentDraft({ scene, viewerContext, intentRequest, risk, targetAgent, now }) {
  const createdAt = new Date(now).toISOString();
  const intentId = `intent_${randomUUID().replace(/-/g, '').slice(0, 16)}`;

  return {
    id: intentId,
    sceneKey: scene.sceneKey,
    initiatorUserId: viewerContext.userId,
    targetAgentId: targetAgent?.agentId ?? null,
    title: `${scene.title} · ${intentRequest.intentType ?? 'scene_social'}`,
    message: sanitizeText(intentRequest.message),
    chatMode: risk.mode,
    sceneTags: uniqueStrings([...scene.tags, ...(intentRequest.extraTags ?? [])]),
    route: buildSocialRoute(intentId, scene.sceneKey),
    riskStatus: risk.status,
    riskReason: risk.reason,
    createdAt
  };
}
