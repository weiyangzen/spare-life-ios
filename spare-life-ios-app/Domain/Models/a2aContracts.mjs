import {
  clampScore,
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from './sceneContracts.mjs';

export const A2A_LANES = [
  {
    id: 'idle_goods',
    title: '闲置物品',
    tone: 'efficient',
    summary: '买家 Agent 和卖家 Agent 先问价、验货、议价。',
    shortcutLabel: '捡漏买卖',
    keywords: ['闲置', '买卖', '议价', '验货', '转手'],
    defaultSort: 10
  },
  {
    id: 'skill_qa',
    title: '技能问答',
    tone: 'expert',
    summary: '提问者和技能方先对齐问题范围、交付边界和价值。',
    shortcutLabel: '问答撮合',
    keywords: ['技能', '问答', '咨询', '交付', '方案'],
    defaultSort: 20
  },
  {
    id: 'romance',
    title: '婚恋',
    tone: 'warm',
    summary: '双方 Agent 先筛价值观、期待和节奏，再决定是否见面。',
    shortcutLabel: '认真匹配',
    keywords: ['婚恋', '相亲', '价值观', '见面', '边界'],
    defaultSort: 30
  },
  {
    id: 'friendship',
    title: '交友',
    tone: 'playful',
    summary: '先看兴趣、情绪和氛围，再拉真人加入。',
    shortcutLabel: '找搭子',
    keywords: ['交友', '搭子', '兴趣', '情绪', '陪伴'],
    defaultSort: 40
  },
  {
    id: 'job_hiring',
    title: '求职招人',
    tone: 'professional',
    summary: '候选人和招聘方 Agent 先对齐岗位理解、履历解释和意向。',
    shortcutLabel: '工作机会',
    keywords: ['求职', '招聘', '岗位', '面试', '履历'],
    defaultSort: 50
  },
  {
    id: 'errand_help',
    title: '跑腿求助',
    tone: 'practical',
    summary: '需求发布者和应答者先确认任务内容、时间、预算和可靠性。',
    shortcutLabel: '任务应答',
    keywords: ['跑腿', '求助', '任务', '预算', '时间'],
    defaultSort: 60
  }
];

export const A2A_LANE_IDS = new Set(A2A_LANES.map((lane) => lane.id));
export const INTENT_VISIBILITY_MODES = new Set(['public', 'semi_public', 'direct']);
export const INTENT_STATUSES = new Set(['draft', 'open', 'icebreaking', 'bonded', 'closed', 'cancelled']);
export const ICEBREAK_MODES = new Set(['human_only', 'agent_first', 'dual_agent_first', 'human_takeover']);
export const ICEBREAK_STATUSES = new Set(['screening', 'consent_pending', 'human_takeover', 'archived', 'blocked']);
export const EXPOSURE_FEEDBACK_TYPES = new Set(['shown', 'like', 'skip', 'block', 'report', 'match']);
export const ENERGY_ENTRY_TYPES = new Set(['income', 'expense', 'freeze', 'settlement', 'rollback']);
export const ENERGY_ENTRY_STATUSES = new Set(['posted', 'frozen', 'settled', 'rolled_back', 'blocked']);
export const ARENA_STATUSES = new Set(['scheduled', 'active', 'resolved', 'cancelled']);
export const BOND_LEVELS = new Set(['spark', 'warming', 'trusted']);

export const A2A_INTENT_TEMPLATES = [
  {
    id: 'sell_idle',
    laneId: 'idle_goods',
    title: '出售闲置',
    summary: '想快速找到靠谱买家，先让分身帮你过一轮问价和成色确认。',
    modeHints: ['public', 'semi_public', 'direct'],
    tags: ['出售', '议价', '成色'],
    formTemplate: [
      { key: 'category', label: '品类', type: 'text', required: true },
      { key: 'condition', label: '成色', type: 'text', required: true },
      { key: 'budget', label: '期望价格', type: 'number', required: true },
      { key: 'meetupArea', label: '交付区域', type: 'text', required: true }
    ]
  },
  {
    id: 'buy_idle',
    laneId: 'idle_goods',
    title: '求购闲置',
    summary: '让 Agent 先帮你问价格、验来源、筛低质量沟通。',
    modeHints: ['public', 'semi_public'],
    tags: ['求购', '预算', '筛选'],
    formTemplate: [
      { key: 'category', label: '品类', type: 'text', required: true },
      { key: 'budget', label: '预算', type: 'number', required: true },
      { key: 'condition', label: '最低成色', type: 'text', required: false },
      { key: 'delivery', label: '交付方式', type: 'text', required: false }
    ]
  },
  {
    id: 'ask_expert',
    laneId: 'skill_qa',
    title: '技能问答',
    summary: '先确认问题范围、交付边界和是否值得继续聊。',
    modeHints: ['public', 'semi_public', 'direct'],
    tags: ['咨询', '问答', '技能'],
    formTemplate: [
      { key: 'topic', label: '问题主题', type: 'text', required: true },
      { key: 'delivery', label: '希望交付', type: 'text', required: true },
      { key: 'budget', label: '预算', type: 'number', required: true },
      { key: 'deadline', label: '截止时间', type: 'text', required: false }
    ]
  },
  {
    id: 'offer_skill',
    laneId: 'skill_qa',
    title: '提供技能',
    summary: '发布自己能回答什么，让 Agent 先过滤不匹配问题。',
    modeHints: ['public', 'semi_public'],
    tags: ['答疑', '能力', '服务'],
    formTemplate: [
      { key: 'topic', label: '擅长主题', type: 'text', required: true },
      { key: 'experience', label: '经验说明', type: 'text', required: true },
      { key: 'delivery', label: '交付形式', type: 'text', required: true },
      { key: 'budget', label: '参考报价', type: 'number', required: false }
    ]
  },
  {
    id: 'serious_match',
    laneId: 'romance',
    title: '认真匹配',
    summary: '让双方 Agent 先确认价值观、界限和见面节奏。',
    modeHints: ['semi_public', 'direct'],
    tags: ['认真关系', '价值观', '边界'],
    formTemplate: [
      { key: 'expectation', label: '关系期待', type: 'text', required: true },
      { key: 'boundary', label: '明确边界', type: 'text', required: true },
      { key: 'city', label: '所在城市', type: 'text', required: true },
      { key: 'pace', label: '相处节奏', type: 'text', required: false }
    ]
  },
  {
    id: 'coffee_first',
    laneId: 'romance',
    title: '轻见面前预沟通',
    summary: '先用分身判断是不是值得真人见面。',
    modeHints: ['semi_public', 'direct'],
    tags: ['见面', '预沟通', '节奏'],
    formTemplate: [
      { key: 'expectation', label: '这次想先了解什么', type: 'text', required: true },
      { key: 'boundary', label: '边界感', type: 'text', required: true },
      { key: 'city', label: '活动范围', type: 'text', required: true },
      { key: 'availability', label: '空闲时间', type: 'text', required: false }
    ]
  },
  {
    id: 'interest_friend',
    laneId: 'friendship',
    title: '兴趣搭子',
    summary: '找同频搭子，先让 Agent 判断兴趣和相处氛围。',
    modeHints: ['public', 'semi_public'],
    tags: ['兴趣', '搭子', '氛围'],
    formTemplate: [
      { key: 'interest', label: '兴趣主题', type: 'text', required: true },
      { key: 'city', label: '所在城市', type: 'text', required: true },
      { key: 'availability', label: '常见空档', type: 'text', required: true },
      { key: 'vibe', label: '希望的氛围', type: 'text', required: false }
    ]
  },
  {
    id: 'healing_chat',
    laneId: 'friendship',
    title: '陪伴聊天',
    summary: '先让分身判断情绪频率和陪伴方式是否合适。',
    modeHints: ['semi_public', 'direct'],
    tags: ['陪伴', '聊天', '情绪'],
    formTemplate: [
      { key: 'topic', label: '最想聊的话题', type: 'text', required: true },
      { key: 'availability', label: '一般什么时候在线', type: 'text', required: true },
      { key: 'boundary', label: '不想触碰的话题', type: 'text', required: true },
      { key: 'city', label: '所在城市', type: 'text', required: false }
    ]
  },
  {
    id: 'job_seek',
    laneId: 'job_hiring',
    title: '求职机会',
    summary: '候选人 Agent 先解释履历、匹配岗位，再拉真人进来。',
    modeHints: ['public', 'semi_public', 'direct'],
    tags: ['求职', '岗位', '履历'],
    formTemplate: [
      { key: 'role', label: '目标岗位', type: 'text', required: true },
      { key: 'experience', label: '相关经历', type: 'text', required: true },
      { key: 'city', label: '工作城市', type: 'text', required: true },
      { key: 'salary', label: '薪资期待', type: 'number', required: false }
    ]
  },
  {
    id: 'hire_now',
    laneId: 'job_hiring',
    title: '招人中',
    summary: '招聘方 Agent 先过滤岗位理解、履历匹配和响应速度。',
    modeHints: ['public', 'semi_public', 'direct'],
    tags: ['招聘', '岗位', '需求'],
    formTemplate: [
      { key: 'role', label: '招聘岗位', type: 'text', required: true },
      { key: 'mustHave', label: '必须满足', type: 'text', required: true },
      { key: 'city', label: '工作地点', type: 'text', required: true },
      { key: 'salary', label: '薪资范围', type: 'number', required: false }
    ]
  },
  {
    id: 'post_errand',
    laneId: 'errand_help',
    title: '发布跑腿',
    summary: '先确认时间、地点、预算和可靠性，再真人接手。',
    modeHints: ['public', 'semi_public', 'direct'],
    tags: ['跑腿', '预算', '时间'],
    formTemplate: [
      { key: 'task', label: '任务内容', type: 'text', required: true },
      { key: 'deadline', label: '最晚完成时间', type: 'text', required: true },
      { key: 'location', label: '地点', type: 'text', required: true },
      { key: 'budget', label: '预算', type: 'number', required: true }
    ]
  },
  {
    id: 'respond_errand',
    laneId: 'errand_help',
    title: '应答跑腿',
    summary: '先声明可服务时间、可覆盖范围和可靠性。',
    modeHints: ['public', 'semi_public'],
    tags: ['应答', '覆盖', '可靠'],
    formTemplate: [
      { key: 'task', label: '擅长处理的任务', type: 'text', required: true },
      { key: 'coverage', label: '服务范围', type: 'text', required: true },
      { key: 'availability', label: '可接单时间', type: 'text', required: true },
      { key: 'budget', label: '参考报价', type: 'number', required: false }
    ]
  }
];

export function listLaneTemplates(laneId = null) {
  return A2A_INTENT_TEMPLATES.filter((template) => !laneId || template.laneId === laneId);
}

export function getLane(laneId) {
  if (!laneId) {
    return null;
  }
  return A2A_LANES.find((lane) => lane.id === laneId) ?? null;
}

export function requireLane(laneId) {
  const lane = getLane(laneId);
  if (!lane) {
    throw new Error(`Unknown A2A lane: ${laneId}`);
  }
  return lane;
}

export function getIntentTemplate(templateId) {
  if (!templateId) {
    return null;
  }
  return A2A_INTENT_TEMPLATES.find((template) => template.id === templateId) ?? null;
}

export function requireIntentTemplate(templateId, laneId = null) {
  const template = getIntentTemplate(templateId);
  if (!template) {
    throw new Error(`Unknown A2A intent template: ${templateId}`);
  }
  if (laneId && template.laneId !== laneId) {
    throw new Error(`Intent template ${templateId} does not belong to lane ${laneId}`);
  }
  return template;
}

export function resolveVisibilityMode(value, fallback = 'public') {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    return fallback;
  }
  if (!INTENT_VISIBILITY_MODES.has(safeValue)) {
    throw new Error(`Unsupported intent visibility mode: ${safeValue}`);
  }
  return safeValue;
}

export function resolveIcebreakMode(value, fallback = 'dual_agent_first') {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    return fallback;
  }
  if (!ICEBREAK_MODES.has(safeValue)) {
    throw new Error(`Unsupported icebreak mode: ${safeValue}`);
  }
  return safeValue;
}

export function resolveArenaStatus(value, fallback = 'active') {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    return fallback;
  }
  if (!ARENA_STATUSES.has(safeValue)) {
    throw new Error(`Unsupported arena status: ${safeValue}`);
  }
  return safeValue;
}

export function resolveBondLevel(value, fallback = 'spark') {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    return fallback;
  }
  if (!BOND_LEVELS.has(safeValue)) {
    throw new Error(`Unsupported bond level: ${safeValue}`);
  }
  return safeValue;
}

export function buildEarnSocialHomeRoute(laneId = null) {
  const params = new URLSearchParams();
  if (sanitizeText(laneId)) {
    params.set('lane', sanitizeText(laneId));
  }
  const suffix = params.toString();
  return `sparelife://earn-social/home${suffix ? `?${suffix}` : ''}`;
}

export function buildIntentMarketRoute(laneId, templateId = null) {
  const params = new URLSearchParams({
    lane: requireLane(laneId).id
  });
  if (sanitizeText(templateId)) {
    params.set('template', sanitizeText(templateId));
  }
  return `sparelife://earn-social/market?${params.toString()}`;
}

export function buildIntentDetailRoute(intentId) {
  return `sparelife://earn-social/intent?intent_id=${encodeURIComponent(sanitizeText(intentId))}`;
}

export function buildPersonaDeckRoute(laneId, agentId = null) {
  const params = new URLSearchParams({
    lane: requireLane(laneId).id
  });
  if (sanitizeText(agentId)) {
    params.set('agent_id', sanitizeText(agentId));
  }
  return `sparelife://earn-social/personas?${params.toString()}`;
}

export function buildIcebreakRoute(sessionId) {
  return `sparelife://earn-social/icebreak?session_id=${encodeURIComponent(sanitizeText(sessionId))}`;
}

export function buildTrendRoute(laneId = null) {
  const params = new URLSearchParams();
  if (sanitizeText(laneId)) {
    params.set('lane', sanitizeText(laneId));
  }
  const suffix = params.toString();
  return `sparelife://earn-social/trends${suffix ? `?${suffix}` : ''}`;
}

export function buildArenaRoute(matchId = null) {
  const params = new URLSearchParams();
  if (sanitizeText(matchId)) {
    params.set('match_id', sanitizeText(matchId));
  }
  const suffix = params.toString();
  return `sparelife://earn-social/arena${suffix ? `?${suffix}` : ''}`;
}

export function buildBondRoute(bondId) {
  return `sparelife://earn-social/bond?bond_id=${encodeURIComponent(sanitizeText(bondId))}`;
}

export function buildMessagesThreadRoute({ bondId, sessionId }) {
  const params = new URLSearchParams();
  if (sanitizeText(bondId)) {
    params.set('bond_id', sanitizeText(bondId));
  }
  if (sanitizeText(sessionId)) {
    params.set('icebreak_session_id', sanitizeText(sessionId));
  }
  return `sparelife://messages/thread?${params.toString()}`;
}

export function inferIntentTitle({ template, formPayload }) {
  const subject =
    sanitizeText(formPayload.role) ||
    sanitizeText(formPayload.category) ||
    sanitizeText(formPayload.topic) ||
    sanitizeText(formPayload.task) ||
    sanitizeText(formPayload.expectation) ||
    template.title;
  return `${template.title} · ${subject}`;
}

export function normalizeFormPayload(template, formPayload) {
  const payload = {};
  for (const field of template.formTemplate) {
    const rawValue = formPayload?.[field.key];
    const safeValue =
      field.type === 'number' ? Number(rawValue ?? 0) : sanitizeText(rawValue);
    if (field.required) {
      if (field.type === 'number') {
        if (!Number.isFinite(safeValue) || safeValue <= 0) {
          throw new Error(`Field ${field.key} is required for template ${template.id}`);
        }
      } else if (!safeValue) {
        throw new Error(`Field ${field.key} is required for template ${template.id}`);
      }
    }
    if (field.type === 'number') {
      payload[field.key] = Number.isFinite(safeValue) && safeValue > 0 ? safeValue : null;
    } else {
      payload[field.key] = safeValue || null;
    }
  }
  return payload;
}

export function extractIntentTags(template, formPayload) {
  return uniqueStrings([
    template.title,
    template.summary,
    ...(template.tags ?? []),
    ...Object.values(formPayload ?? {}).flatMap((value) =>
      typeof value === 'number' ? [] : sanitizeText(value).split(/[、,，/ ]+/)
    )
  ]);
}

export function scoreFormCompleteness(template, formPayload) {
  const total = template.formTemplate.length || 1;
  let filled = 0;
  for (const field of template.formTemplate) {
    const value = formPayload?.[field.key];
    if (field.type === 'number') {
      if (Number.isFinite(Number(value)) && Number(value) > 0) {
        filled += 1;
      }
      continue;
    }
    if (sanitizeText(value)) {
      filled += 1;
    }
  }
  return clampScore((filled / total) * 100);
}

export function buildDedupeKey(ruleKey, referenceId = null, dayKey = isoNow().slice(0, 10)) {
  return stableId('energy-rule', ruleKey, referenceId ?? '', dayKey);
}

export function buildFeedCardId(type, referenceId) {
  return stableId('a2a-feed-card', type, referenceId);
}

export function summarizeFormPayload(formPayload) {
  return uniqueStrings(
    Object.entries(formPayload ?? {})
      .filter(([, value]) => value !== null && value !== undefined && `${value}` !== '')
      .map(([key, value]) => `${key}:${value}`)
  ).join(' / ');
}
