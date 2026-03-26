import { clipText } from '../../Domain/Models/masterContracts.mjs';
import {
  buildFeedSurface,
  buildSurfaceKey,
  buildUnifiedFeedCard,
  buildUnifiedHomeRoute
} from '../../Domain/Models/unifiedUIContracts.mjs';
import {
  clampScore,
  sanitizeText,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

function numberMetric(label, value) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return null;
  }
  return {
    label,
    value: Number(value)
  };
}

function textMetric(label, value) {
  const normalized = sanitizeText(value);
  if (!normalized) {
    return null;
  }
  return {
    label,
    value: normalized
  };
}

function flattenMasterMatches(domains = []) {
  return domains.flatMap((domain, domainIndex) =>
    (domain.masters ?? []).map((master, masterIndex) => ({
      ...master,
      domainTitle: domain.title,
      domainIndex,
      matchIndex: masterIndex
    }))
  );
}

function topSceneAction(entry) {
  if (entry.latestIntent) {
    return {
      label: entry.latestIntent.riskStatus === 'allow' ? '继续破冰' : '查看风险',
      route: entry.latestIntent.route
    };
  }
  return {
    label: '发起社交',
    route: `sparelife://earn-social/compose?scene_key=${encodeURIComponent(entry.sceneKey)}`
  };
}

function buildSceneCards(entries = [], surfaceKey) {
  return entries.flatMap((entry) => {
    const topHotTake = entry.hotTakeCards?.[0] ?? null;
    const topAgent = entry.topAgent ?? null;
    const action = topSceneAction(entry);
    const moderationBlocked = Number(entry.riskCards?.length ?? 0);
    const sceneMood = sanitizeText(entry.summaryCard?.sentiment) || 'neutral';

    return [
      buildUnifiedFeedCard({
        surfaceKey,
        sourceKind: 'scene_summary',
        referenceId: `${entry.sceneKey}:summary`,
        cardType: 'summary',
        route: entry.route,
        title: entry.title,
        summary: clipText(
          entry.summaryCard?.summary ??
            topHotTake?.summary ??
            `${entry.title} 的场景摘要正在更新中。`,
          140
        ),
        badge: sceneMood,
        freshnessAt: entry.lastScannedAt,
        relevanceScore: clampScore(62 + entry.scanCount * 8 + entry.intentCount * 6),
        socialValueScore: clampScore(50 + entry.activeAgentCount * 12),
        stateScore: clampScore(42 + moderationBlocked * 10),
        metrics: [
          numberMetric('扫描', entry.scanCount),
          numberMetric('活跃分身', entry.activeAgentCount)
        ],
        quickActions: [
          {
            actionId: 'open_scene',
            title: '继续看',
            route: entry.route
          }
        ],
        payload: entry
      }),
      topAgent
        ? buildUnifiedFeedCard({
            surfaceKey,
            sourceKind: 'scene_persona',
            referenceId: topAgent.agentId,
            cardType: 'person',
            route: entry.route,
            title: topAgent.displayName,
            summary: clipText(
              `${topAgent.publicBio} · ${topAgent.contactHint} · ${topAgent.maskedLocationLabel}`,
              140
            ),
            badge: entry.title,
            freshnessAt: entry.lastScannedAt,
            relevanceScore: clampScore(54 + topAgent.matchScore * 0.42),
            socialValueScore: clampScore(56 + topAgent.heatScore * 0.35),
            stateScore: clampScore(40 + topAgent.trustScore * 0.3),
            metrics: [
              numberMetric('匹配', topAgent.matchScore),
              numberMetric('热度', topAgent.heatScore)
            ],
            quickActions: [
              {
                actionId: 'scene_social',
                title: '让分身先聊',
                route: action.route
              }
            ],
            payload: topAgent
          })
        : null,
      buildUnifiedFeedCard({
        surfaceKey,
        sourceKind: 'scene_action',
        referenceId: entry.latestIntent?.id ?? `${entry.sceneKey}:compose`,
        cardType: 'action',
        route: action.route,
        title: entry.latestIntent ? entry.latestIntent.title : `${entry.title} 立刻发起社交`,
        summary: clipText(
          entry.latestIntent
            ? `${entry.latestIntent.message} · 风险状态 ${entry.latestIntent.riskStatus}`
            : `把 ${entry.title} 里最值得接触的人和观点，直接推进成一次真实破冰。`,
          132
        ),
        badge: entry.latestIntent?.riskStatus ?? 'ready',
        freshnessAt: entry.latestIntent?.updatedAt ?? entry.lastScannedAt,
        relevanceScore: clampScore(60 + entry.intentCount * 9),
        socialValueScore: clampScore(50 + entry.activeAgentCount * 10),
        stateScore: entry.latestIntent?.riskStatus === 'allow' ? 86 : 66,
        metrics: [
          numberMetric('意图', entry.intentCount),
          textMetric('模式', entry.latestIntent?.chatMode ?? 'dual_agent')
        ],
        quickActions: [
          {
            actionId: 'continue_scene_social',
            title: action.label,
            route: action.route
          }
        ],
        payload: entry.latestIntent ?? {
          sceneKey: entry.sceneKey,
          route: action.route
        }
      }),
      buildUnifiedFeedCard({
        surfaceKey,
        sourceKind: 'scene_status',
        referenceId: `${entry.sceneKey}:status`,
        cardType: 'status',
        route: entry.route,
        title: `${entry.title} 场景状态`,
        summary: clipText(
          moderationBlocked > 0
            ? `已拦截 ${moderationBlocked} 条风险内容，当前仍有 ${entry.activeAgentCount} 个分身值得继续观察。`
            : `当前场景已沉淀 ${entry.scanCount} 次扫描与 ${entry.intentCount} 个社交推进入口。`,
          132
        ),
        badge: moderationBlocked > 0 ? 'watch' : 'stable',
        freshnessAt: entry.updatedAt ?? entry.lastScannedAt,
        relevanceScore: clampScore(48 + entry.scanCount * 7),
        socialValueScore: clampScore(45 + entry.activeAgentCount * 11),
        stateScore: clampScore(58 + moderationBlocked * 14 + entry.intentCount * 5),
        metrics: [
          numberMetric('风险卡', moderationBlocked),
          numberMetric('摘要簇', entry.hotTakeCards?.length ?? 0)
        ],
        payload: {
          sceneKey: entry.sceneKey,
          riskCards: entry.riskCards,
          moderation: entry.moderation
        }
      })
    ].filter(Boolean);
  });
}

function buildMasterCards(home, surfaceKey) {
  const masterMatches = flattenMasterMatches(home.domains);
  const primaryDomain = home.domains[0] ?? null;

  return [
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'master_summary',
      referenceId: primaryDomain?.domainKey ?? 'overview',
      cardType: 'summary',
      route: home.appRoute,
      title: home.query ? `“${home.query}” 的大师匹配` : '大师馆今日入口',
      summary: clipText(
        primaryDomain
          ? `${primaryDomain.title} 当前最先浮出，馆内共命中 ${home.totalMatches} 位大师，先决定该找谁聊，再进入具体上下文。`
          : '当前还没有大师命中，先换个关键词或领域再刷一轮。',
        136
      ),
      badge: home.catalogReadOnly ? 'read_only' : null,
      freshnessAt: null,
      relevanceScore: clampScore(64 + masterMatches.length * 4),
      socialValueScore: clampScore(58 + home.recentChats.length * 8),
      stateScore: home.catalogReadOnly ? 82 : 54,
      metrics: [
        numberMetric('命中', home.totalMatches),
        numberMetric('最近聊天', home.recentChats.length)
      ],
      payload: {
        domains: home.domains,
        query: home.query
      }
    }),
    ...masterMatches.slice(0, 6).map((master, index) =>
      buildUnifiedFeedCard({
        surfaceKey,
        sourceKind: 'master_profile',
        referenceId: master.masterId,
        cardType: 'person',
        route: master.chatRoute,
        title: `${master.displayName} · ${master.title}`,
        summary: clipText(
          `${master.tagline} · ${master.domainTitle} · ${uniqueStrings(master.profileTags ?? []).slice(0, 4).join(' / ')}`,
          140
        ),
        badge: master.domainTitle,
        relevanceScore: clampScore(78 - index * 4),
        socialValueScore: clampScore(54 + (master.profileTags?.length ?? 0) * 5),
        stateScore: clampScore(46 + index * 3),
        metrics: [
          textMetric('领域', master.domainTitle),
          numberMetric('标签', master.profileTags?.length ?? 0)
        ],
        quickActions: [
          {
            actionId: 'chat_with_master',
            title: '继续聊',
            route: master.chatRoute
          }
        ],
        payload: master
      })
    ),
    ...home.recentChats.slice(0, 3).map((chat, index) =>
      buildUnifiedFeedCard({
        surfaceKey,
        sourceKind: 'master_resume',
        referenceId: chat.sessionId,
        cardType: 'action',
        route: chat.restoreRoute,
        title: `恢复 ${chat.displayName}`,
        summary: clipText(chat.preview, 132),
        badge: chat.unreadCount > 0 ? 'unread' : 'resume',
        freshnessAt: chat.lastMessageAt,
        relevanceScore: clampScore(72 - index * 5 + chat.unreadCount * 6),
        socialValueScore: clampScore(56 + chat.unreadCount * 8),
        stateScore: clampScore(62 + chat.unreadCount * 10),
        metrics: [
          numberMetric('未读', chat.unreadCount)
        ],
        quickActions: [
          {
            actionId: 'resume_master',
            title: '恢复上下文',
            route: chat.restoreRoute
          }
        ],
        payload: chat
      })
    ),
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'master_status',
      referenceId: 'catalog_mode',
      cardType: 'status',
      route: home.appRoute,
      title: '大师目录约束',
      summary: home.catalogReadOnly
        ? '当前目录只读，端侧不允许增删改大师，只允许导入、筛选与恢复最近上下文。'
        : '当前目录允许编辑。',
      badge: home.catalogReadOnly ? 'locked' : 'editable',
      relevanceScore: 52,
      socialValueScore: 40,
      stateScore: home.catalogReadOnly ? 80 : 48,
      metrics: [
        numberMetric('领域', home.domains.length)
      ],
      payload: {
        catalogReadOnly: home.catalogReadOnly
      }
    })
  ].filter(Boolean);
}

function mapEarnCardType(cardType) {
  switch (cardType) {
    case 'trend_snapshot':
      return 'summary';
    case 'public_persona':
      return 'person';
    case 'lane_opportunity':
    case 'dual_agent':
      return 'action';
    case 'lead_result':
    case 'arena_activity':
    case 'bond_task':
    default:
      return 'status';
  }
}

function describeEarnCard(card) {
  const payload = card.payload ?? {};
  switch (card.cardType) {
    case 'public_persona':
      return {
        title: payload.displayName,
        summary: clipText(`${payload.publicBio} · ${payload.expertiseTags?.slice(0, 3).join(' / ')}`, 136),
        badge: payload.laneTitle ?? null,
        metrics: [
          numberMetric('匹配', payload.matchScore),
          numberMetric('信任', payload.trustScore)
        ]
      };
    case 'trend_snapshot':
      return {
        title: payload.event?.title ?? `${payload.laneTitle} 热度`,
        summary: clipText(
          payload.event?.summary ??
            `${payload.laneTitle} 当前热度 ${payload.heatScore}，回复速度 ${payload.responseSpeedScore}。`,
          136
        ),
        badge: payload.laneTitle,
        metrics: [
          numberMetric('热度', payload.heatScore),
          numberMetric('奖励', payload.event?.rewardAmount ?? 0)
        ]
      };
    case 'dual_agent':
      return {
        title: '双 Agent 破冰进行中',
        summary: clipText(payload.summary, 136),
        badge: payload.laneTitle ?? payload.laneId,
        metrics: [
          numberMetric('兼容度', payload.compatibilityScore)
        ]
      };
    case 'lead_result':
      return {
        title: payload.title ?? '赛道结果卡',
        summary: clipText(payload.summary ?? '线索已进入结果追踪。', 136),
        badge: payload.statusLabel ?? payload.currentStageLabel ?? payload.outcome?.outcomeCode ?? null,
        metrics: [
          numberMetric('阶段权重', payload.stageWeight)
        ]
      };
    case 'arena_activity':
      return {
        title: 'A2A 竞技场',
        summary: clipText(payload.summary, 136),
        badge: payload.laneTitle ?? payload.laneId,
        metrics: [
          numberMetric('对战值', payload.arenaScore)
        ]
      };
    case 'bond_task':
      return {
        title: payload.title,
        summary: clipText(payload.summary, 136),
        badge: payload.level ?? payload.laneTitle ?? null,
        metrics: [
          numberMetric('关系强度', payload.strengthScore),
          numberMetric('奖励', payload.rewardAmount ?? 0)
        ]
      };
    case 'lane_opportunity':
    default:
      return {
        title: payload.title,
        summary: clipText(payload.summary, 136),
        badge: payload.laneTitle ?? null,
        metrics: [
          numberMetric('排序分', payload.rankingScore)
        ]
      };
  }
}

function buildEarnCards(home, surfaceKey) {
  return (home.feed ?? []).map((card) => {
    const detail = describeEarnCard(card);
    return buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: card.cardType,
      referenceId: card.cardId,
      cardType: mapEarnCardType(card.cardType),
      route: card.route,
      title: detail.title,
      summary: detail.summary,
      badge: detail.badge,
      relevanceScore: clampScore(card.priority ?? 40),
      socialValueScore: clampScore(card.weight ?? 40),
      stateScore:
        card.cardType === 'lead_result'
          ? 88
          : card.cardType === 'bond_task'
            ? 80
            : card.cardType === 'dual_agent'
              ? 76
              : 64,
      metrics: detail.metrics,
      quickActions: [
        {
          actionId: 'open_earn_card',
          title: '继续',
          route: card.route
        }
      ],
      payload: card.payload
    });
  });
}

function buildMyCards(home, surfaceKey) {
  const syncNextActions = home.sync.nextActions ?? [];
  const publicProfile = home.profile.publicProfile?.profile ?? {};
  const latestMemory = home.memory.memories?.[0] ?? null;
  const latestGrowth = home.growth.latest ?? null;
  const openReplayCount = home.sync.errorReplays?.filter((item) => item.status === 'open').length ?? 0;
  const activeBackups = home.privacy.backups?.active?.length ?? 0;
  const authorizedCount = home.privacy.authorizations?.filter((item) => item.status === 'authorized').length ?? 0;

  return [
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'my_sync',
      referenceId: 'sync',
      cardType: 'status',
      route: home.sync.route,
      title: `同步度 ${home.sync.score} · ${home.sync.band}`,
      summary: clipText(
        `${openReplayCount > 0 ? `还有 ${openReplayCount} 条错误回放待修复。` : '当前错误回放已被压低。'} ${syncNextActions
          .slice(0, 2)
          .join('；')}`,
        140
      ),
      badge: home.sync.band,
      freshnessAt: home.sync.createdAt,
      relevanceScore: clampScore(74 + Math.max(home.sync.delta, 0)),
      socialValueScore: clampScore(48 + (home.sync.trainingTasks?.length ?? 0) * 7),
      stateScore: clampScore(64 + openReplayCount * 12 + Math.max(0, -home.sync.delta) * 4),
      metrics: [
        numberMetric('变化', home.sync.delta),
        numberMetric('训练任务', home.sync.trainingTasks?.length ?? 0)
      ],
      payload: home.sync
    }),
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'my_persona',
      referenceId: 'persona',
      cardType: 'person',
      route: home.persona.route,
      title: `${home.profile.privateProfile.agentDisplayName} · ${home.persona.awakening.label}`,
      summary: clipText(
        `${home.persona.awakening.activeMask?.label ?? '未设主面具'} / ${home.persona.awakening.topTraits
          ?.map((trait) => `${trait.label}${trait.score}`)
          .join(' / ')} / ${home.persona.awakening.values?.slice(0, 3).join(' / ')}`,
        140
      ),
      badge: home.persona.awakening.stage,
      relevanceScore: clampScore(70 + home.persona.awakening.score * 0.2),
      socialValueScore: clampScore(44 + (home.persona.awakening.values?.length ?? 0) * 8),
      stateScore: clampScore(56 + home.persona.awakening.score * 0.25),
      metrics: [
        numberMetric('觉醒', home.persona.awakening.score),
        numberMetric('面具', home.persona.awakening.masks?.length ?? 0)
      ],
      payload: home.persona
    }),
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'my_profile',
      referenceId: 'profile',
      cardType: 'summary',
      route: home.profile.route,
      title: publicProfile.displayName ?? home.profile.privateProfile.displayName,
      summary: clipText(
        `${publicProfile.headline ?? home.profile.privateProfile.headline} · ${publicProfile.growthFocus ?? home.profile.privateProfile.growthFocus}`,
        140
      ),
      badge: publicProfile.city ?? null,
      relevanceScore: 60,
      socialValueScore: clampScore(50 + Object.keys(publicProfile).length * 4),
      stateScore: 52,
      metrics: [
        numberMetric('公开字段', Object.keys(publicProfile).length)
      ],
      payload: home.profile
    }),
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'my_memory',
      referenceId: latestMemory?.id ?? 'memory',
      cardType: 'summary',
      route: home.memory.route,
      title: latestMemory?.title ?? '记忆宫殿',
      summary: clipText(
        latestMemory?.summary ??
          `当前已存 ${home.memory.totalStored} 条记忆，${home.memory.deniedCount} 条在当前权限下不可见。`,
        140
      ),
      badge: latestMemory?.permissionScope ?? null,
      freshnessAt: latestMemory?.updatedAt,
      relevanceScore: clampScore(58 + home.memory.totalStored * 6),
      socialValueScore: clampScore(42 + home.memory.memories.length * 10),
      stateScore: clampScore(50 + home.memory.deniedCount * 12),
      metrics: [
        numberMetric('可见记忆', home.memory.memories.length),
        numberMetric('总数', home.memory.totalStored)
      ],
      payload: home.memory
    }),
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'my_growth',
      referenceId: latestGrowth?.id ?? 'growth',
      cardType: 'summary',
      route: home.growth.route,
      title: '成长统计与回顾',
      summary: clipText(
        latestGrowth
          ? `闲能 ${latestGrowth.idleEnergy} / 社交 ${latestGrowth.socialScore} / 同步 ${latestGrowth.syncScore} / 觉醒 ${latestGrowth.awakeningScore}`
          : '成长曲线还在积累中。',
        140
      ),
      badge: home.growth.journal?.[0]?.mood ?? null,
      freshnessAt: latestGrowth?.createdAt,
      relevanceScore: clampScore(54 + (home.growth.chart?.length ?? 0) * 5),
      socialValueScore: clampScore(44 + (home.growth.journal?.length ?? 0) * 6),
      stateScore: clampScore(52 + (latestGrowth?.syncScore ?? 0) * 0.2),
      metrics: [
        numberMetric('曲线点', home.growth.chart?.length ?? 0),
        numberMetric('日记', home.growth.journal?.length ?? 0)
      ],
      payload: home.growth
    }),
    buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: 'my_privacy',
      referenceId: 'privacy',
      cardType: 'status',
      route: home.privacy.route,
      title: '隐私与本地后端',
      summary: clipText(
        `SQLite 当前 ${home.privacy.database.tableCount} 张表 / ${home.privacy.database.pageCount} 页，活跃备份 ${activeBackups} 份，已授权资源 ${authorizedCount} 项。`,
        140
      ),
      badge: activeBackups > 0 ? 'backed_up' : 'attention',
      relevanceScore: clampScore(52 + activeBackups * 8),
      socialValueScore: clampScore(36 + authorizedCount * 8),
      stateScore: clampScore(68 + (activeBackups === 0 ? 12 : 0)),
      metrics: [
        numberMetric('备份', activeBackups),
        numberMetric('授权', authorizedCount)
      ],
      payload: home.privacy
    })
  ];
}

function conversationScore(chat, index) {
  return clampScore(
    Number(chat.unreadCount ?? 0) * 18 +
      Number(chat.warmthScore ?? 50) * 0.4 +
      (chat.latestMemorySummary ? 8 : 0) +
      Math.max(0, 40 - index * 2)
  );
}

function buildConversationRows(recentChats = []) {
  return [...recentChats]
    .map((chat, index) => ({
      ...chat,
      hubScore: conversationScore(chat, index)
    }))
    .sort((left, right) => right.hubScore - left.hubScore || right.unreadCount - left.unreadCount);
}

function summarizeContextPayload(card) {
  switch (card.cardType) {
    case 'relationship':
      return {
        title: '关系温度',
        summary: clipText(
          `${card.payload?.latestSummary ?? '关系摘要待生成。'} · 当前温度 ${card.payload?.warmthScore ?? 0}`,
          136
        ),
        metrics: [
          numberMetric('温度', card.payload?.warmthScore ?? 0),
          textMetric('关系', card.payload?.level ?? null)
        ],
        cardType: 'status',
        stateScore: clampScore(56 + Number(card.payload?.warmthScore ?? 0) * 0.35)
      };
    case 'mask':
      return {
        title: '对人面具',
        summary: clipText(
          `${card.payload?.signature ?? '当前面具未写签名。'} · ${card.payload?.boundaryTags?.slice(0, 3).join(' / ') ?? ''}`,
          136
        ),
        metrics: [
          textMetric('语气', card.payload?.tone),
          textMetric('开放度', card.payload?.openness)
        ],
        cardType: 'person',
        stateScore: 68
      };
    case 'memory':
      return {
        title: card.title,
        summary: clipText(
          (card.payload ?? [])
            .slice(0, 2)
            .map((item) => `${item.layer} · ${item.summary}`)
            .join('；') || '暂时还没有可展示的跨会话记忆。',
          136
        ),
        metrics: [
          numberMetric('记忆层', card.payload?.length ?? 0)
        ],
        cardType: 'summary',
        stateScore: clampScore(54 + (card.payload?.length ?? 0) * 8)
      };
    case 'agent_summary':
      return {
        title: 'Agent 摘要',
        summary: clipText(card.payload?.summary, 136),
        metrics: [
          numberMetric('未读', card.payload?.unreadCount ?? 0)
        ],
        cardType: 'summary',
        stateScore: 74
      };
    case 'rituals':
      return {
        title: '关系事件',
        summary: clipText(
          (card.payload ?? [])
            .slice(0, 2)
            .map((item) => `${item.title} · ${item.status}`)
            .join('；') || '还没有可展示的关系事件。',
          136
        ),
        metrics: [
          numberMetric('事件', card.payload?.length ?? 0)
        ],
        cardType: 'action',
        stateScore: 72
      };
    default:
      return {
        title: sanitizeText(card.title),
        summary: clipText(JSON.stringify(card.payload ?? {}), 136),
        metrics: [],
        cardType: 'summary',
        stateScore: 50
      };
  }
}

function buildTimelineGroups(messages = []) {
  const groups = [];
  const byDay = new Map();
  for (const message of messages) {
    const day = sanitizeText(message.createdAt).slice(0, 10) || 'unknown';
    if (!byDay.has(day)) {
      byDay.set(day, []);
      groups.push({
        day,
        items: byDay.get(day)
      });
    }
    byDay.get(day).push({
      messageId: message.id,
      actorRole: message.actorRole,
      actorKey: message.actorKey,
      channelKind: message.channelKind,
      content: message.content,
      unreadForOwner: Boolean(message.unreadForOwner),
      suppressed: Boolean(message.suppressed),
      createdAt: message.createdAt
    });
  }
  return groups;
}

export function buildSceneWaterfallFeed({ entries = [], scrollState = null }) {
  const surfaceKey = buildSurfaceKey('xianxia_home');
  return buildFeedSurface({
    surfaceKey,
    route: buildUnifiedHomeRoute('xianxia'),
    title: '咸虾',
    subtitle: '场景摘要、人物、行动、状态混排成一条可刷的双列卡片流。',
    cards: buildSceneCards(entries, surfaceKey),
    scrollState,
    metadata: {
      recentScenes: entries.map((entry) => ({
        sceneKey: entry.sceneKey,
        title: entry.title,
        route: entry.route,
        lastScannedAt: entry.lastScannedAt
      }))
    }
  });
}

export function buildMasterWaterfallFeed({ home, scrollState = null }) {
  const surfaceKey = buildSurfaceKey('masters_home');
  return buildFeedSurface({
    surfaceKey,
    route: home.appRoute ?? buildUnifiedHomeRoute('masters'),
    title: '大师',
    subtitle: '人物卡、恢复上下文卡和目录状态卡统一混排。',
    cards: buildMasterCards(home, surfaceKey),
    scrollState,
    metadata: {
      totalMatches: home.totalMatches,
      selectedDomain: home.selectedDomain
    }
  });
}

export function buildEarnSocialWaterfallFeed({ home, selectedLaneId = null, scrollState = null }) {
  const surfaceKey = buildSurfaceKey('earn_social_home', selectedLaneId ?? 'all');
  return buildFeedSurface({
    surfaceKey,
    route: home.route ?? buildUnifiedHomeRoute('earn_social'),
    title: '赚闲能',
    subtitle: '机会卡、分身卡、结果卡与状态卡统一排序。',
    cards: buildEarnCards(home, surfaceKey),
    scrollState,
    metadata: {
      selectedLaneId,
      quickFilters: home.quickFilters
    }
  });
}

export function buildMyWaterfallFeed({ home, scrollState = null }) {
  const surfaceKey = buildSurfaceKey('my_home');
  return buildFeedSurface({
    surfaceKey,
    route: buildUnifiedHomeRoute('my', home.profile.privateProfile.userId),
    title: '我的',
    subtitle: '同步度、人格、记忆、成长和隐私都以卡片流组织，而不是设置列表。',
    cards: buildMyCards(home, surfaceKey),
    scrollState,
    metadata: {
      userId: home.profile.privateProfile.userId
    }
  });
}

export function buildConversationHubList({ home, scrollState = null }) {
  const surfaceKey = buildSurfaceKey('messages_home');
  const rows = buildConversationRows(home.recentChats ?? []);
  return {
    surfaceKey,
    route: home.route,
    layout: {
      kind: 'conversation_hub_list'
    },
    scrollState,
    unreadTotal: home.unreadTotal,
    highlights: rows.slice(0, 3).map((row) => ({
      conversationId: row.conversationId,
      title: row.title,
      subtitle: row.latestMemorySummary ?? row.subtitle,
      unreadCount: row.unreadCount,
      warmthScore: row.warmthScore,
      route: row.route
    })),
    hubList: rows.map((row) => ({
      conversationId: row.conversationId,
      title: row.title,
      subtitle: row.subtitle,
      unreadCount: row.unreadCount,
      lastMessagePreview: row.lastMessagePreview,
      lastMessageAt: row.lastMessageAt,
      warmthScore: row.warmthScore,
      relationshipLevel: row.relationshipLevel,
      latestMemorySummary: row.latestMemorySummary,
      route: row.route,
      rankScore: row.hubScore
    }))
  };
}

export function buildMessageDetailSurface({ detail, scrollState = null }) {
  const surfaceKey = buildSurfaceKey('messages_detail', detail.conversation.id);
  const contextCards = (detail.contextCards ?? []).map((card) => {
    const presentation = summarizeContextPayload(card);
    return buildUnifiedFeedCard({
      surfaceKey,
      sourceKind: `message_${card.cardType}`,
      referenceId: `${detail.conversation.id}:${card.cardType}`,
      cardType: presentation.cardType,
      route: card.route ?? detail.conversation.route,
      title: presentation.title,
      summary: presentation.summary,
      badge: sanitizeText(card.cardType),
      relevanceScore: 70,
      socialValueScore: 56,
      stateScore: presentation.stateScore,
      metrics: presentation.metrics,
      payload: card.payload
    });
  });

  return {
    surfaceKey,
    route: detail.conversation.route,
    title: detail.conversation.title,
    subtitle: detail.conversation.kind === 'group' ? '群里先看上下文，再进时间线。' : '先看关系与面具，再进时间线。',
    layout: {
      kind: 'context_cards_plus_timeline',
      contextColumns: 2
    },
    scrollState,
    conversation: detail.conversation,
    contextArea: {
      cardCount: contextCards.length,
      cards: contextCards
    },
    timeline: {
      totalMessages: detail.messages.length,
      groups: buildTimelineGroups(detail.messages),
      participants: detail.participants,
      votes: detail.votes,
      groupSummaries: detail.groupSummaries
    },
    homeRoute: detail.homeRoute
  };
}
