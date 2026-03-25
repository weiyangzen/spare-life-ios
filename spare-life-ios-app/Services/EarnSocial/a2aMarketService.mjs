import {
  A2A_LANES,
  buildArenaRoute,
  buildBondRoute,
  buildDedupeKey,
  buildEarnSocialHomeRoute,
  buildFeedCardId,
  buildIcebreakRoute,
  buildIntentDetailRoute,
  buildIntentMarketRoute,
  buildLeadRoute,
  buildMessagesThreadRoute,
  buildPersonaDeckRoute,
  buildTrendRoute,
  extractIntentTags,
  getLeadStageDefinition,
  inferIntentTitle,
  listLaneTemplates,
  requireIntentTemplate,
  requireLane,
  scoreFormCompleteness,
  summarizeFormPayload
} from '../../Domain/Models/a2aContracts.mjs';
import {
  clampScore,
  isoNow,
  keywordOverlap,
  sanitizeText,
  stableId,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

export const DEFAULT_PUBLIC_AGENT_CARDS = [
  {
    agentId: 'agent-idle-luna',
    userId: 'seed-user-luna',
    laneId: 'idle_goods',
    displayName: 'Luna 省心卖家分身',
    personaTags: ['守时', '验货清晰', '议价克制'],
    expertiseTags: ['数码', '成色判断', '同城交易'],
    openHours: ['工作日晚间', '周末下午'],
    expectedPartner: ['同城', '讲清楚需求', '不反复砍价'],
    allowsAgentIntro: true,
    publicBio: '帮主人先聊价格、成色和取货方式，确认靠谱再拉真人。',
    explanationTags: ['为什么推给你：同城 + 预算明确', '愿意先让分身聊'],
    trustScore: 88
  },
  {
    agentId: 'agent-idle-yu',
    userId: 'seed-user-yu',
    laneId: 'idle_goods',
    displayName: '阿宇 捡漏买家分身',
    personaTags: ['会验货', '回复快', '预算明确'],
    expertiseTags: ['耳机', '键盘', '同城面交'],
    openHours: ['午休', '晚饭后'],
    expectedPartner: ['成色真实', '可提供照片'],
    allowsAgentIntro: true,
    publicBio: '不浪费对话，先由分身确认是否值得见面验货。',
    explanationTags: ['为什么推给你：预算相近', '同城交易高响应'],
    trustScore: 83
  },
  {
    agentId: 'agent-skill-yan',
    userId: 'seed-user-yan',
    laneId: 'skill_qa',
    displayName: '言舟 AI 产品答疑分身',
    personaTags: ['结构化', '边界清楚', '能给行动单'],
    expertiseTags: ['AI 产品', '需求拆解', '作品集'],
    openHours: ['晚间', '周末全天'],
    expectedPartner: ['问题具体', '愿意补充背景'],
    allowsAgentIntro: true,
    publicBio: '先帮你拆问题，再决定是否值得继续深聊和付费。',
    explanationTags: ['为什么推给你：问题主题匹配', '擅长明确交付边界'],
    trustScore: 92
  },
  {
    agentId: 'agent-skill-min',
    userId: 'seed-user-min',
    laneId: 'skill_qa',
    displayName: '小敏 内容策略分身',
    personaTags: ['共创型', '反馈具体', '节奏稳定'],
    expertiseTags: ['内容增长', '短视频', '账号诊断'],
    openHours: ['工作日下午', '周末'],
    expectedPartner: ['给到样本', '能接受迭代'],
    allowsAgentIntro: true,
    publicBio: '先由分身判断问题边界，再确定要不要真人细聊。',
    explanationTags: ['为什么推给你：交付方式接近', '对预算敏感度高'],
    trustScore: 86
  },
  {
    agentId: 'agent-romance-chen',
    userId: 'seed-user-chen',
    laneId: 'romance',
    displayName: '晨序 认真相处分身',
    personaTags: ['边界明确', '慢热', '重价值观'],
    expertiseTags: ['长期关系', '线下见面节奏', '安全感'],
    openHours: ['晚上 8 点后', '周末下午'],
    expectedPartner: ['尊重边界', '愿意稳定沟通'],
    allowsAgentIntro: true,
    publicBio: '先看价值观和节奏是否匹配，再决定要不要真人见面。',
    explanationTags: ['为什么推给你：节奏相近', '关系期待一致'],
    trustScore: 90
  },
  {
    agentId: 'agent-romance-lin',
    userId: 'seed-user-lin',
    laneId: 'romance',
    displayName: '林野 轻见面分身',
    personaTags: ['坦诚', '会表达', '不拖延'],
    expertiseTags: ['城市漫步', '咖啡约见', '风险感知'],
    openHours: ['工作日晚上', '周末'],
    expectedPartner: ['聊得清楚', '见面节奏自然'],
    allowsAgentIntro: true,
    publicBio: '先让分身过滤错配，减少无效暧昧和见面风险。',
    explanationTags: ['为什么推给你：城市相同', '见面节奏一致'],
    trustScore: 84
  },
  {
    agentId: 'agent-friend-ora',
    userId: 'seed-user-ora',
    laneId: 'friendship',
    displayName: 'Ora 城市搭子分身',
    personaTags: ['情绪稳定', '不鸽', '有趣但不吵'],
    expertiseTags: ['展览', 'citywalk', '播客'],
    openHours: ['周五晚', '周末'],
    expectedPartner: ['有共同兴趣', '不强社交'],
    allowsAgentIntro: true,
    publicBio: '先判断兴趣和相处氛围，减少尬聊。',
    explanationTags: ['为什么推给你：兴趣标签重合', '活跃时间一致'],
    trustScore: 87
  },
  {
    agentId: 'agent-friend-neo',
    userId: 'seed-user-neo',
    laneId: 'friendship',
    displayName: 'Neo 陪伴聊天分身',
    personaTags: ['有耐心', '节奏慢', '回复柔和'],
    expertiseTags: ['夜聊', '情绪接住', '线上陪伴'],
    openHours: ['深夜', '雨天'],
    expectedPartner: ['不冒犯边界', '愿意真诚表达'],
    allowsAgentIntro: true,
    publicBio: '先由分身确认是否适合长期陪伴，而不是一次性浅聊。',
    explanationTags: ['为什么推给你：情绪频率接近', '愿意先分身摸底'],
    trustScore: 81
  },
  {
    agentId: 'agent-job-jia',
    userId: 'seed-user-jia',
    laneId: 'job_hiring',
    displayName: '嘉禾 招聘方分身',
    personaTags: ['反馈快', '职位理解强', '不画饼'],
    expertiseTags: ['AI 产品', '增长', '远程协作'],
    openHours: ['工作日白天', '周二晚上'],
    expectedPartner: ['经历真实', '动机明确', '沟通直接'],
    allowsAgentIntro: true,
    publicBio: '先由分身确认岗位理解和履历匹配，再约真人沟通。',
    explanationTags: ['为什么推给你：岗位标签重合', '响应速度高'],
    trustScore: 94
  },
  {
    agentId: 'agent-job-luo',
    userId: 'seed-user-luo',
    laneId: 'job_hiring',
    displayName: '洛可 候选人分身',
    personaTags: ['履历解释强', '行动快', '善于复盘'],
    expertiseTags: ['B 端产品', 'AI 工具', '项目落地'],
    openHours: ['工作日晚上', '周末上午'],
    expectedPartner: ['JD 明确', '愿意看作品集'],
    allowsAgentIntro: true,
    publicBio: '先让分身解释过往经历，筛掉不合适岗位。',
    explanationTags: ['为什么推给你：求职意图相近', '愿意先分身筛选'],
    trustScore: 89
  },
  {
    agentId: 'agent-errand-qi',
    userId: 'seed-user-qi',
    laneId: 'errand_help',
    displayName: '七木 同城应答分身',
    personaTags: ['守时', '会回报进度', '路径熟'],
    expertiseTags: ['同城代买', '文件递送', '地铁熟路'],
    openHours: ['午间', '晚高峰前'],
    expectedPartner: ['时间要求清楚', '预算直接'],
    allowsAgentIntro: true,
    publicBio: '先确认任务和预算，避免临时加码和无效沟通。',
    explanationTags: ['为什么推给你：同城覆盖', '预算匹配'],
    trustScore: 85
  },
  {
    agentId: 'agent-errand-jing',
    userId: 'seed-user-jing',
    laneId: 'errand_help',
    displayName: '静海 紧急求助分身',
    personaTags: ['说需求清楚', '预算诚实', '会及时确认'],
    expertiseTags: ['材料代取', '临时帮忙', '跨区跑腿'],
    openHours: ['工作日全天'],
    expectedPartner: ['路线熟', '可按时反馈'],
    allowsAgentIntro: true,
    publicBio: '把任务细节先说清楚，再判断谁来接最稳。',
    explanationTags: ['为什么推给你：时间窗重合', '任务类型相近'],
    trustScore: 82
  }
];

export const DEFAULT_LANE_EVENTS = [
  {
    eventId: 'lane-event-idle-gadget-week',
    laneId: 'idle_goods',
    title: '二手数码热卖周',
    summary: '本周耳机、键盘和显示器问价明显升温。',
    heatDelta: 9,
    rewardAmount: 3
  },
  {
    eventId: 'lane-event-skill-ai-week',
    laneId: 'skill_qa',
    title: 'AI 产品问答榜',
    summary: 'AI 产品、作品集和 prompt 协作问题集中爆发。',
    heatDelta: 12,
    rewardAmount: 4
  },
  {
    eventId: 'lane-event-romance-weekend',
    laneId: 'romance',
    title: '周末轻见面窗口',
    summary: '认真匹配前的价值观预沟通需求上升。',
    heatDelta: 6,
    rewardAmount: 2
  },
  {
    eventId: 'lane-event-friend-citywalk',
    laneId: 'friendship',
    title: '春日 citywalk 搭子潮',
    summary: '展览、citywalk 和播客搭子需求上升。',
    heatDelta: 7,
    rewardAmount: 3
  },
  {
    eventId: 'lane-event-job-hiring-season',
    laneId: 'job_hiring',
    title: '求职季岗位热度峰值',
    summary: 'AI 产品、增长和运营转岗类岗位沟通最密集。',
    heatDelta: 14,
    rewardAmount: 4
  },
  {
    eventId: 'lane-event-errand-rush-hour',
    laneId: 'errand_help',
    title: '晚高峰跑腿高峰',
    summary: '文件递送和临时代买的响应速度要求更高。',
    heatDelta: 8,
    rewardAmount: 3
  }
];

export const DEFAULT_MARKET_INTENTS = [
  {
    userId: 'seed-user-luna',
    laneId: 'idle_goods',
    templateId: 'sell_idle',
    mode: 'public',
    status: 'open',
    formPayload: {
      category: '降噪耳机',
      condition: '9 成新',
      budget: 780,
      meetupArea: '徐汇'
    }
  },
  {
    userId: 'seed-user-yan',
    laneId: 'skill_qa',
    templateId: 'offer_skill',
    mode: 'public',
    status: 'open',
    formPayload: {
      topic: 'AI 产品作品集诊断',
      experience: '做过 3 次转岗辅导',
      delivery: '30 分钟语音 + 行动清单',
      budget: 199
    }
  },
  {
    userId: 'seed-user-chen',
    laneId: 'romance',
    templateId: 'serious_match',
    mode: 'semi_public',
    status: 'open',
    formPayload: {
      expectation: '认真关系，不急着见面',
      boundary: '不接受突然失联',
      city: '上海',
      pace: '先稳定聊两周'
    }
  },
  {
    userId: 'seed-user-ora',
    laneId: 'friendship',
    templateId: 'interest_friend',
    mode: 'public',
    status: 'open',
    formPayload: {
      interest: '看展 + citywalk',
      city: '上海',
      availability: '周六下午',
      vibe: '轻松、少自拍'
    }
  },
  {
    userId: 'seed-user-jia',
    laneId: 'job_hiring',
    templateId: 'hire_now',
    mode: 'public',
    status: 'open',
    formPayload: {
      role: 'AI 产品经理',
      mustHave: '做过工具或效率类产品',
      city: '上海 / 远程',
      salary: 40000
    }
  },
  {
    userId: 'seed-user-jing',
    laneId: 'errand_help',
    templateId: 'post_errand',
    mode: 'public',
    status: 'open',
    formPayload: {
      task: '代取体检报告并顺路送到静安',
      deadline: '今天 18:30 前',
      location: '黄浦',
      budget: 120
    }
  }
];

function summarizeCard(card) {
  return uniqueStrings([...card.personaTags, ...card.expertiseTags]).slice(0, 5).join(' · ');
}

function templateWeight(mode) {
  switch (mode) {
    case 'direct':
      return 1;
    case 'semi_public':
      return 0.82;
    case 'public':
    default:
      return 0.72;
  }
}

export function createSeedIntentCandidate(seed) {
  const lane = requireLane(seed.laneId);
  const template = requireIntentTemplate(seed.templateId, seed.laneId);
  const normalizedForm = {};
  for (const field of template.formTemplate) {
    normalizedForm[field.key] = seed.formPayload[field.key] ?? null;
  }
  return {
    intentId: stableId('seed-intent', seed.userId, seed.templateId, summarizeFormPayload(normalizedForm)),
    lane,
    template,
    normalizedForm,
    title: inferIntentTitle({
      template,
      formPayload: normalizedForm
    }),
    summary: summarizeFormPayload(normalizedForm),
    tags: extractIntentTags(template, normalizedForm),
    route: buildIntentDetailRoute(stableId('seed-intent', seed.userId, seed.templateId, summarizeFormPayload(normalizedForm))),
    rankingScore: scoreIntentCandidate({
      lane,
      template,
      formPayload: normalizedForm,
      mode: seed.mode
    }),
    ...seed
  };
}

export function scoreIntentCandidate({ lane, template, formPayload, mode = 'public', targetCard = null }) {
  const completeness = scoreFormCompleteness(template, formPayload);
  const laneBonus = 52 + lane.defaultSort / 3;
  const targetBonus = targetCard ? targetCard.trustScore / 6 : 0;
  const visibilityBonus = templateWeight(mode) * 20;
  return clampScore(laneBonus + completeness * 0.35 + targetBonus + visibilityBonus);
}

export function scorePersonaCard({ laneId, card, intentTags = [], viewerTags = [], feedback = [] }) {
  const laneBonus = card.laneId === laneId ? 40 : 0;
  const tagBonus = keywordOverlap([...intentTags, ...viewerTags], [...card.personaTags, ...card.expertiseTags]) * 35;
  const trustBonus = card.trustScore * 0.25;
  const negativeFeedback = feedback.filter((item) => item.agentId === card.agentId && ['skip', 'block', 'report'].includes(item.feedback)).length;
  const positiveFeedback = feedback.filter((item) => item.agentId === card.agentId && item.feedback === 'like').length;
  return clampScore(laneBonus + tagBonus + trustBonus + positiveFeedback * 8 - negativeFeedback * 18);
}

export function buildRecommendedPersonaDeck({ laneId, cards, intentTags = [], viewerTags = [], feedback = [], limit = 6 }) {
  return cards
    .map((card) => ({
      ...card,
      matchScore: scorePersonaCard({
        laneId,
        card,
        intentTags,
        viewerTags,
        feedback
      }),
      reason: uniqueStrings([
        ...card.explanationTags,
        intentTags.length ? `与你当前意图标签重合 ${Math.round(keywordOverlap(intentTags, card.expertiseTags) * 100)}%` : null
      ])[0]
    }))
    .sort((left, right) => right.matchScore - left.matchScore || right.trustScore - left.trustScore)
    .slice(0, limit)
    .map((card) => ({
      ...card,
      route: buildPersonaDeckRoute(card.laneId, card.agentId),
      summary: summarizeCard(card)
    }));
}

export function auditAgentMessage({ content }) {
  const issues = [];
  let safeContent = sanitizeText(content);
  const rules = [
    {
      key: 'no_absolute_promise',
      test: /(保证|包过|100%|绝对)/u,
      redact: '我会先帮你判断匹配度和风险边界'
    },
    {
      key: 'no_private_contact',
      test: /(微信|vx|手机号|电话|加我)/iu,
      redact: '先在当前线程完成规则内沟通，再决定是否进入真人阶段'
    },
    {
      key: 'no_privacy_leak',
      test: /(住址|身份证|家庭住址|公司机密)/u,
      redact: '先只交换完成匹配所需的最小信息'
    }
  ];

  for (const rule of rules) {
    if (rule.test.test(safeContent)) {
      issues.push(rule.key);
      safeContent = rule.redact;
    }
  }

  return {
    status: issues.length ? 'redacted' : 'passed',
    issues,
    content: safeContent
  };
}

export function runDualAgentIcebreak({ lane, intent, counterpartCard, nowIso = isoNow() }) {
  const intentText = `${intent.title} ${intent.summary}`.trim();
  const initiatorDraft = `我先替主人确认关键边界：${intentText}。只聊必要信息，不越权承诺。`;
  const counterpartDraft = `${counterpartCard.displayName} 这边可先说明 ${counterpartCard.expertiseTags.slice(0, 2).join(' / ')}，如果匹配再授权真人接手。`;

  const introAudit = auditAgentMessage({ content: initiatorDraft });
  const replyAudit = auditAgentMessage({ content: counterpartDraft });
  const compatibilityScore = clampScore(
    55 +
      keywordOverlap(intent.tags, [...counterpartCard.personaTags, ...counterpartCard.expertiseTags]) * 35 +
      counterpartCard.trustScore * 0.1
  );
  const handoffRule = {
    minimumCompatibility: 70,
    requiresMutualConsent: true,
    blocks: ['privacy_leak', 'over_promise', 'contact_exchange'],
    auditPassed: introAudit.status !== 'blocked' && replyAudit.status !== 'blocked'
  };
  const summary = compatibilityScore >= handoffRule.minimumCompatibility
    ? '双方分身已完成摸底，可以进入真人接手授权。'
    : '双方分身还需要继续筛选，暂不建议真人接手。';

  return {
    sessionId: stableId('icebreak-session', intent.id, counterpartCard.agentId, nowIso),
    route: buildIcebreakRoute(stableId('icebreak-session', intent.id, counterpartCard.agentId, nowIso)),
    mode: 'dual_agent_first',
    status: compatibilityScore >= handoffRule.minimumCompatibility ? 'consent_pending' : 'screening',
    compatibilityScore,
    handoffRule,
    summary,
    consent: {
      initiator: false,
      counterpart: false
    },
    messages: [
      {
        messageId: stableId('icebreak-message', intent.id, 'initiator-agent', nowIso),
        actorKind: 'initiator_agent',
        stage: 'agent_intro',
        content: introAudit.content,
        audit: introAudit,
        createdAt: nowIso
      },
      {
        messageId: stableId('icebreak-message', intent.id, 'counterpart-agent', nowIso),
        actorKind: 'counterpart_agent',
        stage: 'agent_screening',
        content: replyAudit.content,
        audit: replyAudit,
        createdAt: nowIso
      }
    ]
  };
}

export function buildLaneHeatSnapshot({ lane, openIntents, activeIcebreaks, activePersonas, activeArenaMatches, eventHeat, averageResponseMinutes = 18, energyPayout = 0, recentLikes = 0 }) {
  const responseSpeedScore = clampScore(100 - averageResponseMinutes * 3.5);
  const profitScore = clampScore(45 + energyPayout * 6);
  const supplyGapScore = clampScore(35 + Math.max(0, openIntents - activePersonas) * 9);
  const engagementScore = clampScore(40 + openIntents * 6 + activeIcebreaks * 8 + recentLikes * 5);
  const heatScore = clampScore(
    engagementScore * 0.35 +
      responseSpeedScore * 0.2 +
      profitScore * 0.2 +
      supplyGapScore * 0.15 +
      clampScore(activeArenaMatches * 16 + eventHeat * 3) * 0.1
  );
  return {
    laneId: lane.id,
    openIntents,
    activeIcebreaks,
    activePersonas,
    activeArenaMatches,
    eventHeat,
    engagementScore,
    profitScore,
    supplyGapScore,
    responseSpeedScore,
    heatScore,
    route: buildTrendRoute(lane.id)
  };
}

export function rankLaneTrends(snapshots, events = []) {
  const eventMap = new Map(events.map((event) => [event.laneId, event]));
  return snapshots
    .map((snapshot) => {
      const lane = requireLane(snapshot.laneId);
      const event = eventMap.get(snapshot.laneId) ?? null;
      return {
        laneId: snapshot.laneId,
        laneTitle: lane.title,
        heatScore: snapshot.heatScore,
        responseSpeedScore: snapshot.responseSpeedScore,
        profitScore: snapshot.profitScore,
        supplyGapScore: snapshot.supplyGapScore,
        event,
        route: buildTrendRoute(snapshot.laneId)
      };
    })
    .sort((left, right) => right.heatScore - left.heatScore || right.profitScore - left.profitScore);
}

function cardPriority(type) {
  switch (type) {
    case 'lane_opportunity':
      return 100;
    case 'public_persona':
      return 88;
    case 'dual_agent':
      return 78;
    case 'lead_result':
      return 74;
    case 'arena_activity':
      return 68;
    case 'trend_snapshot':
      return 58;
    case 'bond_task':
      return 52;
    default:
      return 30;
  }
}

export function buildMixedFeed({ laneId, opportunityCards = [], personaCards = [], icebreakCards = [], leadCards = [], arenaCards = [], trendCards = [], bondCards = [] }) {
  return [
    ...opportunityCards.map((card) => ({
      cardType: 'lane_opportunity',
      cardId: buildFeedCardId('lane_opportunity', card.intentId),
      laneId: card.laneId,
      priority: cardPriority('lane_opportunity'),
      weight: card.rankingScore,
      route: card.route,
      payload: card
    })),
    ...personaCards.map((card) => ({
      cardType: 'public_persona',
      cardId: buildFeedCardId('public_persona', card.agentId),
      laneId: card.laneId,
      priority: cardPriority('public_persona'),
      weight: card.matchScore,
      route: card.route,
      payload: card
    })),
    ...icebreakCards.map((card) => ({
      cardType: 'dual_agent',
      cardId: buildFeedCardId('dual_agent', card.sessionId),
      laneId: card.laneId,
      priority: cardPriority('dual_agent'),
      weight: card.compatibilityScore,
      route: card.route,
      payload: card
    })),
    ...leadCards.map((card) => ({
      cardType: 'lead_result',
      cardId: buildFeedCardId('lead_result', card.leadId),
      laneId: card.laneId,
      priority: cardPriority('lead_result'),
      weight: card.stageWeight,
      route: card.route,
      payload: card
    })),
    ...arenaCards.map((card) => ({
      cardType: 'arena_activity',
      cardId: buildFeedCardId('arena_activity', card.matchId),
      laneId: card.laneId,
      priority: cardPriority('arena_activity'),
      weight: card.arenaScore,
      route: card.route,
      payload: card
    })),
    ...trendCards.map((card) => ({
      cardType: 'trend_snapshot',
      cardId: buildFeedCardId('trend_snapshot', card.laneId),
      laneId: card.laneId,
      priority: cardPriority('trend_snapshot'),
      weight: card.heatScore,
      route: card.route,
      payload: card
    })),
    ...bondCards.map((card) => ({
      cardType: 'bond_task',
      cardId: buildFeedCardId('bond_task', card.taskId),
      laneId: card.laneId,
      priority: cardPriority('bond_task'),
      weight: card.strengthScore,
      route: card.route,
      payload: card
    }))
  ]
    .filter((card) => !laneId || card.laneId === laneId)
    .sort((left, right) => right.priority - left.priority || right.weight - left.weight);
}

export function buildLaneChips({ selectedLaneId = null, laneStats = [] }) {
  const statsMap = new Map(laneStats.map((entry) => [entry.laneId, entry]));
  return A2A_LANES.map((lane) => {
    const stat = statsMap.get(lane.id) ?? {};
    return {
      laneId: lane.id,
      title: lane.title,
      selected: lane.id === selectedLaneId,
      shortcutLabel: lane.shortcutLabel,
      openIntentCount: stat.openIntents ?? 0,
      heatScore: stat.heatScore ?? 0,
      route: buildEarnSocialHomeRoute(lane.id)
    };
  });
}

export function buildIntentCard(intent) {
  const lane = requireLane(intent.laneId);
  return {
    intentId: intent.id,
    laneId: intent.laneId,
    laneTitle: lane.title,
    templateId: intent.templateId,
    title: intent.title,
    summary: intent.summary,
    mode: intent.mode,
    status: intent.status,
    rankingScore: intent.rankingScore,
    route: buildIntentDetailRoute(intent.id),
    reason: `这条赛道省掉了 ${lane.summary}`,
    tags: intent.tags
  };
}

export function buildArenaBlueprint({ laneId, theme, challengerCard, opponentCard }) {
  const lane = requireLane(laneId);
  const prompts = [
    `第 1 回合：围绕“${theme}”做立场陈述，说明为什么你更适合代表 ${lane.title} 赛道。`,
    `第 2 回合：针对对方弱点做追问，但不能越权承诺。`,
    `第 3 回合：给出收尾主张，并说明真人什么时候适合接手。`
  ];

  return prompts.map((prompt, index) => ({
    roundIndex: index + 1,
    prompt,
    challengerReply: `${challengerCard.displayName}：我会先把 ${challengerCard.expertiseTags.slice(0, 2).join('、')} 说清楚，避免真人一上来就浪费时间。`,
    opponentReply: `${opponentCard.displayName}：我会先用 ${opponentCard.personaTags.slice(0, 2).join('、')} 的方式筛掉不匹配请求，再决定是否升级。`
  }));
}

export function scoreArenaMatch({ rounds, votes = [] }) {
  const roundScores = rounds.map((round) => {
    const challengerScore = clampScore(55 + sanitizeText(round.challengerReply).length * 0.12 + round.roundIndex * 6);
    const opponentScore = clampScore(52 + sanitizeText(round.opponentReply).length * 0.12 + round.roundIndex * 5);
    return {
      roundIndex: round.roundIndex,
      challengerScore,
      opponentScore,
      summary:
        challengerScore >= opponentScore
          ? '挑战方在信息密度和接手边界上更清楚。'
          : '应战方在稳定性和节奏控制上更占优。'
    };
  });

  const audience = votes.reduce(
    (accumulator, vote) => {
      if (vote.preferredSide === 'challenger') {
        accumulator.challenger += vote.weight;
      } else {
        accumulator.opponent += vote.weight;
      }
      return accumulator;
    },
    { challenger: 0, opponent: 0 }
  );

  const judgeTotals = roundScores.reduce(
    (accumulator, score) => {
      accumulator.challenger += score.challengerScore;
      accumulator.opponent += score.opponentScore;
      return accumulator;
    },
    { challenger: 0, opponent: 0 }
  );

  const finalScore = {
    challenger: judgeTotals.challenger + audience.challenger * 8,
    opponent: judgeTotals.opponent + audience.opponent * 8
  };
  const winnerSide = finalScore.challenger >= finalScore.opponent ? 'challenger' : 'opponent';

  return {
    roundScores,
    audience,
    finalScore,
    winnerSide,
    recap:
      winnerSide === 'challenger'
        ? '挑战方赢下对战，原因是对问题边界和真人接手时机表述更完整。'
        : '应战方赢下对战，原因是节奏控制更稳，围观投票也更高。'
  };
}

export function buildBondBlueprint({ laneId, counterpartCard, icebreakSessionId }) {
  const nowIso = isoNow();
  const memorialCard = {
    title: `${counterpartCard.displayName} 初遇纪念卡`,
    summary: `通过 ${requireLane(laneId).title} 赛道完成第一次互相授权，开始从陌生过渡到熟人。`,
    createdAt: nowIso
  };
  const bondId = stableId('bond', laneId, counterpartCard.agentId, icebreakSessionId);
  const tasks = [
    {
      taskId: stableId('bond-task', bondId, 'checkin'),
      title: '连续 2 天轻量报到',
      summary: '用两次低负担互动确认节奏和回应稳定性。',
      targetCount: 2,
      rewardAmount: 4,
      milestoneKey: 'first_rhythm'
    },
    {
      taskId: stableId('bond-task', bondId, 'shared_goal'),
      title: '共完成 1 个小目标',
      summary: '一起完成一件小事，验证执行和协同感。',
      targetCount: 1,
      rewardAmount: 6,
      milestoneKey: 'shared_goal'
    },
    {
      taskId: stableId('bond-task', bondId, 'reflection'),
      title: '交换 1 次关系回顾',
      summary: '说清楚彼此舒服的互动方式，避免降温误伤。',
      targetCount: 1,
      rewardAmount: 5,
      milestoneKey: 'reflection'
    }
  ];

  return {
    bondId,
    level: 'spark',
    strengthScore: 42,
    memorialCard,
    threadRoute: buildMessagesThreadRoute({
      bondId,
      sessionId: icebreakSessionId
    }),
    tasks
  };
}

export function buildLeadPipelineBlueprint({ intent, session, bond, counterpartCard = null }) {
  const leadId = stableId('lead-pipeline', intent.id, session.id, bond.id);
  const counterpartName = counterpartCard?.displayName ?? session.targetAgentId;
  const stages = ['agent_screened', 'mutual_confirmation', 'human_takeover'].map((stageKey, index) => ({
    stageIndex: index + 1,
    stageKey,
    stageLabel: getLeadStageDefinition(stageKey)?.label ?? stageKey,
    actorKind: 'system',
    detail:
      stageKey === 'agent_screened'
        ? {
            sourceSessionId: session.id,
            targetAgentId: session.targetAgentId,
            compatibilityScore: session.compatibilityScore
          }
        : stageKey === 'mutual_confirmation'
          ? {
              initiatorConfirmed: true,
              counterpartConfirmed: true
            }
          : {
              bondId: bond.id,
              humanThreadRoute: bond.threadRoute
            }
  }));

  const recommendationChain = {
    recommendedFromIntentId: intent.id,
    recommendedToUserId: session.initiatorUserId,
    recommendedAgentId: session.targetAgentId,
    recommendedCounterpartUserId: session.counterpartUserId,
    counterpartName
  };

  return {
    leadId,
    laneId: session.laneId,
    intentId: intent.id,
    sourceSessionId: session.id,
    bondId: bond.id,
    initiatorUserId: session.initiatorUserId,
    counterpartUserId: session.counterpartUserId,
    targetAgentId: session.targetAgentId,
    humanTakeover: true,
    sourceRoute: intent.route,
    route: buildLeadRoute(leadId),
    currentStageKey: 'human_takeover',
    currentStageLabel: getLeadStageDefinition('human_takeover')?.label ?? '真人已接手',
    confirmations: {
      initiator: true,
      counterpart: true
    },
    stages,
    auditEvents: [
      {
        eventType: 'source_linked',
        actorKind: 'system',
        actorId: session.targetAgentId,
        detail: {
          recommendationChain,
          sourceSessionId: session.id,
          sourceRoute: intent.route,
          humanTakeover: true
        }
      },
      {
        eventType: 'confirmation_recorded',
        actorKind: 'initiator_user',
        actorId: session.initiatorUserId,
        detail: {
          confirmed: true,
          side: 'initiator'
        }
      },
      {
        eventType: 'confirmation_recorded',
        actorKind: 'counterpart_user',
        actorId: session.counterpartUserId,
        detail: {
          confirmed: true,
          side: 'counterpart'
        }
      },
      {
        eventType: 'recommended_match',
        actorKind: 'system',
        actorId: session.targetAgentId,
        detail: {
          recommendationChain
        }
      }
    ]
  };
}

export function assertLeadStageTransition({ currentStageKey, nextStageKey }) {
  const transitionMap = new Map([
    ['agent_screened', new Set(['mutual_confirmation', 'cancelled'])],
    ['mutual_confirmation', new Set(['human_takeover', 'cancelled'])],
    ['human_takeover', new Set(['active_delivery', 'cancelled'])],
    ['active_delivery', new Set(['result_recorded', 'cancelled'])],
    ['result_recorded', new Set(['settled', 'cancelled'])],
    ['settled', new Set()],
    ['cancelled', new Set()]
  ]);
  const allowedTransitions = transitionMap.get(currentStageKey);
  if (!allowedTransitions) {
    throw new Error(`Unknown current lead stage: ${currentStageKey}`);
  }
  if (!allowedTransitions.has(nextStageKey)) {
    throw new Error(`Lead stage cannot transition from ${currentStageKey} to ${nextStageKey}.`);
  }
}

export function buildLeadSettlementRule({ leadId, laneId, beneficiaryUserId, settlementType }) {
  return {
    ruleKey: `lead_${settlementType}_settlement`,
    dedupeKey: buildDedupeKey(`lead_${settlementType}_settlement:${leadId}`, beneficiaryUserId),
    detail: {
      leadId,
      laneId,
      settlementType
    }
  };
}

export function buildLeadResultCard(lead) {
  const lane = requireLane(lead.laneId);
  const stageOrder = getLeadStageDefinition(lead.currentStageKey)?.order ?? 0;
  return {
    leadId: lead.id,
    laneId: lead.laneId,
    laneTitle: lane.title,
    stageKey: lead.currentStageKey,
    stageLabel: lead.currentStageLabel,
    latestOutcomeCode: lead.latestOutcomeCode,
    latestOutcomeLabel: lead.latestOutcomeLabel,
    latestOutcomeStatus: lead.latestOutcomeStatus,
    humanTakeover: lead.humanTakeover,
    summary:
      lead.latestOutcomeLabel
        ? `${lane.title}结果：${lead.latestOutcomeLabel}`
        : `${lane.title}流程当前处于“${lead.currentStageLabel}”`,
    stageWeight: stageOrder + (lead.latestOutcomeStatus === 'successful' ? 20 : lead.latestOutcomeStatus === 'milestone' ? 12 : 0),
    route: lead.route
  };
}

export function advanceBondProgress({ bond, tasks }) {
  const completedTasks = tasks.filter((task) => task.status === 'completed').length;
  const totalTasks = tasks.length || 1;
  const strengthScore = clampScore(42 + completedTasks * 24);
  let nextLevel = 'spark';
  if (completedTasks >= totalTasks) {
    nextLevel = 'trusted';
  } else if (completedTasks >= 1) {
    nextLevel = 'warming';
  }
  return {
    level: nextLevel,
    strengthScore,
    milestoneReady: completedTasks >= 1
  };
}

export function buildHomeSnapshot({ selectedLaneId = null, laneStats = [], opportunityCards = [], personaCards = [], icebreakCards = [], leadCards = [], arenaCards = [], trendCards = [], bondCards = [], wallet }) {
  const feed = buildMixedFeed({
    laneId: selectedLaneId,
    opportunityCards,
    personaCards,
    icebreakCards,
    leadCards,
    arenaCards,
    trendCards,
    bondCards
  });

  return {
    route: buildEarnSocialHomeRoute(selectedLaneId),
    wallet,
    laneChips: buildLaneChips({
      selectedLaneId,
      laneStats
    }),
    quickFilters: [
      { key: 'opportunities', title: '机会最多', route: buildEarnSocialHomeRoute(selectedLaneId) },
      { key: 'best_match', title: '最匹配分身', route: buildPersonaDeckRoute(selectedLaneId ?? 'job_hiring') },
      { key: 'trends', title: '热度趋势', route: buildTrendRoute(selectedLaneId) },
      { key: 'arena', title: '竞技场', route: buildArenaRoute() }
    ],
    feed
  };
}

export function buildTrendRewardRule(event, userId) {
  return {
    ruleKey: 'trend_explore_reward',
    dedupeKey: buildDedupeKey(`trend_explore_reward:${event.eventId}`, userId),
    amount: event.rewardAmount,
    detail: {
      eventId: event.eventId,
      laneId: event.laneId,
      title: event.title
    }
  };
}

export function buildDailyOpenRule(userId) {
  return {
    ruleKey: 'daily_home_open',
    dedupeKey: buildDedupeKey('daily_home_open', userId),
    amount: 10,
    detail: {
      reason: '首次进入赚闲能首页'
    }
  };
}

export function buildIcebreakRewardRule(sessionId, laneId) {
  return {
    ruleKey: 'complete_dual_agent_icebreak',
    dedupeKey: buildDedupeKey(`complete_dual_agent_icebreak:${sessionId}`, laneId),
    amount: 12,
    detail: {
      sessionId,
      laneId
    }
  };
}

export function buildBondTaskRewardRule(taskId, laneId) {
  return {
    ruleKey: 'bond_task_completion',
    dedupeKey: buildDedupeKey(`bond_task_completion:${taskId}`, laneId),
    amount: 4,
    detail: {
      taskId,
      laneId
    }
  };
}

export function buildArenaEntryRule(matchId, laneId) {
  return {
    ruleKey: 'arena_entry_fee',
    dedupeKey: buildDedupeKey(`arena_entry_fee:${matchId}`, laneId),
    amount: 5,
    detail: {
      matchId,
      laneId
    }
  };
}

export function buildArenaSettlementRule(matchId, laneId, winnerSide) {
  return {
    ruleKey: 'arena_settlement_reward',
    dedupeKey: buildDedupeKey(`arena_settlement_reward:${matchId}:${winnerSide}`, laneId),
    amount: winnerSide === 'challenger' ? 14 : 6,
    detail: {
      matchId,
      laneId,
      winnerSide
    }
  };
}

export function buildIntentMarketSnapshot({ laneId, templates, recentIntents, recommendedCards, history }) {
  return {
    route: buildIntentMarketRoute(laneId),
    laneId,
    templates: templates.map((template) => ({
      ...template,
      route: buildIntentMarketRoute(laneId, template.id)
    })),
    recentIntents,
    recommendedCards,
    history
  };
}

export function bootstrapCatalogSeed() {
  return {
    lanes: A2A_LANES,
    templatesByLane: A2A_LANES.map((lane) => ({
      laneId: lane.id,
      templates: listLaneTemplates(lane.id)
    })),
    publicCards: DEFAULT_PUBLIC_AGENT_CARDS,
    laneEvents: DEFAULT_LANE_EVENTS,
    marketIntents: DEFAULT_MARKET_INTENTS.map((seed) => createSeedIntentCandidate(seed))
  };
}
