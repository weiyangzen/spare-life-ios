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
export const LEAD_SETTLEMENT_TYPES = new Set(['reward', 'points', 'commission']);
export const MATCH_OUTCOME_STATUSES = new Set(['milestone', 'successful', 'failed']);

export const LEAD_STAGE_DEFINITIONS = [
  { key: 'agent_screened', label: '分身初筛完成', order: 10 },
  { key: 'mutual_confirmation', label: '双方确认继续', order: 20 },
  { key: 'human_takeover', label: '真人已接手', order: 30 },
  { key: 'active_delivery', label: '结果推进中', order: 40 },
  { key: 'result_recorded', label: '结果已记录', order: 50 },
  { key: 'settled', label: '结算已完成', order: 60 },
  { key: 'cancelled', label: '流程关闭', order: 99 }
];

export const LEAD_STAGE_KEYS = new Set(LEAD_STAGE_DEFINITIONS.map((stage) => stage.key));

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

export const LANE_MATCH_OUTCOME_DEFINITIONS = [
  { laneId: 'idle_goods', code: 'deal_closed', label: '买卖成交', status: 'successful' },
  { laneId: 'idle_goods', code: 'inspection_failed', label: '验货未通过', status: 'failed' },
  { laneId: 'idle_goods', code: 'seller_withdrew', label: '卖家撤回交易', status: 'failed' },
  { laneId: 'skill_qa', code: 'consult_completed', label: '问答完成', status: 'successful' },
  { laneId: 'skill_qa', code: 'service_purchased', label: '服务成交', status: 'successful' },
  { laneId: 'skill_qa', code: 'not_a_fit', label: '问题不匹配', status: 'failed' },
  { laneId: 'romance', code: 'offline_meet_scheduled', label: '进入线下见面', status: 'milestone' },
  { laneId: 'romance', code: 'steady_contact_started', label: '进入稳定接触', status: 'successful' },
  { laneId: 'romance', code: 'not_matched', label: '双方不匹配', status: 'failed' },
  { laneId: 'friendship', code: 'moved_to_private_thread', label: '转入熟人消息线程', status: 'milestone' },
  { laneId: 'friendship', code: 'buddy_routine_started', label: '形成固定搭子关系', status: 'successful' },
  { laneId: 'friendship', code: 'not_same_vibe', label: '相处氛围不合适', status: 'failed' },
  { laneId: 'job_hiring', code: 'interview_scheduled', label: '进入面试', status: 'milestone' },
  { laneId: 'job_hiring', code: 'offer_sent', label: '进入录用阶段', status: 'successful' },
  { laneId: 'job_hiring', code: 'not_selected', label: '未进入后续流程', status: 'failed' },
  { laneId: 'errand_help', code: 'task_accepted', label: '跑腿已接单', status: 'milestone' },
  { laneId: 'errand_help', code: 'task_completed', label: '跑腿完成', status: 'successful' },
  { laneId: 'errand_help', code: 'unable_to_fulfill', label: '任务未完成', status: 'failed' }
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

export function getLeadStageDefinition(stageKey) {
  if (!stageKey) {
    return null;
  }
  return LEAD_STAGE_DEFINITIONS.find((stage) => stage.key === stageKey) ?? null;
}

export function requireLeadStage(stageKey) {
  const stage = getLeadStageDefinition(stageKey);
  if (!stage) {
    throw new Error(`Unsupported lead stage: ${stageKey}`);
  }
  return stage;
}

export function resolveLeadStage(value, fallback = 'human_takeover') {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    return fallback;
  }
  if (!LEAD_STAGE_KEYS.has(safeValue)) {
    throw new Error(`Unsupported lead stage: ${safeValue}`);
  }
  return safeValue;
}

export function listLaneMatchOutcomes(laneId) {
  if (!laneId) {
    return [];
  }
  return LANE_MATCH_OUTCOME_DEFINITIONS.filter((outcome) => outcome.laneId === laneId);
}

export function requireMatchOutcome(laneId, outcomeCode) {
  const outcome = listLaneMatchOutcomes(laneId).find((item) => item.code === sanitizeText(outcomeCode));
  if (!outcome) {
    throw new Error(`Unsupported match outcome ${outcomeCode} for lane ${laneId}`);
  }
  if (!MATCH_OUTCOME_STATUSES.has(outcome.status)) {
    throw new Error(`Unsupported match outcome status: ${outcome.status}`);
  }
  return outcome;
}

export function resolveLeadSettlementType(value, fallback = 'reward') {
  const safeValue = sanitizeText(value);
  if (!safeValue) {
    return fallback;
  }
  if (!LEAD_SETTLEMENT_TYPES.has(safeValue)) {
    throw new Error(`Unsupported lead settlement type: ${safeValue}`);
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

export function buildLeadRoute(leadId) {
  return `sparelife://earn-social/lead?lead_id=${encodeURIComponent(sanitizeText(leadId))}`;
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
