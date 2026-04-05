import {
  clampScore,
  keywordOverlap,
  maskLocation,
  minutesSince,
  sentimentLabel,
  stableId,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const POSITIVE_KEYWORDS = [
  '合作',
  '有趣',
  '靠谱',
  '喜欢',
  '机会',
  '开心',
  '想认识',
  '不错',
  '专业'
];

const NEGATIVE_KEYWORDS = [
  '忽悠',
  '麻烦',
  '崩',
  '失望',
  '太装',
  '带节奏',
  '翻车',
  '拉踩',
  '画饼'
];

const DIVISIVE_KEYWORDS = [
  '有人觉得',
  '也有人说',
  '争议',
  '分歧',
  '两极',
  '吵',
  '不一定'
];

const SENSITIVE_KEYWORDS = [
  '傻子',
  '废物',
  '滚',
  '约炮',
  '骚扰',
  '开房',
  '加微信不回就'
];

const TOPIC_DICTIONARY = [
  { label: 'AI', keywords: ['AI', 'agent', '模型', '智能体'] },
  { label: '合作', keywords: ['合作', '联名', '共创', '一起做'] },
  { label: '招聘', keywords: ['招人', '招聘', '求职', '缺人', '内推'] },
  { label: '交友', keywords: ['认识', '交朋友', '夜宵', '一起吃饭'] },
  { label: '风控', keywords: ['骗局', '忽悠', '带节奏', '画饼'] },
  { label: '产品', keywords: ['产品', '增长', '用户', '转化'] },
  { label: 'iOS', keywords: ['iOS', 'Swift', '客户端'] }
];

function includesKeyword(text, keywords) {
  return keywords.some((keyword) => text.includes(keyword.toLowerCase()));
}

function summarizeSentiment(counts) {
  const ordered = Object.entries(counts).sort((left, right) => right[1] - left[1]);
  return ordered[0]?.[0] ?? 'neutral';
}

function inferTags(text, providedTags) {
  if (providedTags?.length) {
    return uniqueStrings(providedTags);
  }
  const lowered = text.toLowerCase();
  const inferred = TOPIC_DICTIONARY.filter((entry) => includesKeyword(lowered, entry.keywords)).map(
    (entry) => entry.label
  );
  return uniqueStrings(inferred.length ? inferred : ['现场观察']);
}

export function analyzeSentiment(text) {
  const lowered = text.toLowerCase();
  const positiveHits = POSITIVE_KEYWORDS.filter((keyword) => lowered.includes(keyword.toLowerCase())).length;
  const negativeHits = NEGATIVE_KEYWORDS.filter((keyword) => lowered.includes(keyword.toLowerCase())).length;
  const divisiveHits = DIVISIVE_KEYWORDS.filter((keyword) => lowered.includes(keyword.toLowerCase())).length;

  if (divisiveHits > 0 || (positiveHits > 0 && negativeHits > 0)) {
    return 'divisive';
  }
  if (negativeHits > positiveHits) {
    return 'negative';
  }
  if (positiveHits > 0) {
    return 'positive';
  }
  return 'neutral';
}

export function moderatePosts(posts) {
  const approvedPosts = [];
  const flaggedPosts = [];

  for (const post of posts) {
    const lowered = post.text.toLowerCase();
    const tags = inferTags(post.text, post.topicTags);
    const sentiment = analyzeSentiment(post.text);
    const normalized = {
      ...post,
      topicTags: tags,
      sentiment
    };

    const flaggedKeyword = SENSITIVE_KEYWORDS.find((keyword) => lowered.includes(keyword.toLowerCase()));
    if (flaggedKeyword) {
      flaggedPosts.push({
        ...normalized,
        flagReason: `filtered:${flaggedKeyword}`
      });
      continue;
    }

    approvedPosts.push(normalized);
  }

  return {
    approvedPosts,
    flaggedPosts,
    moderationSummary: {
      approvedCount: approvedPosts.length,
      flaggedCount: flaggedPosts.length
    }
  };
}

export function clusterPosts(posts) {
  const clusters = new Map();

  for (const post of posts) {
    const primaryTag = post.topicTags[0] ?? '现场观察';
    const cluster = clusters.get(primaryTag) ?? {
      clusterKey: primaryTag,
      label: primaryTag,
      keywords: new Set(),
      postIds: [],
      posts: [],
      sentimentCounts: {
        positive: 0,
        negative: 0,
        divisive: 0,
        neutral: 0
      },
      totalEngagement: 0
    };

    for (const tag of post.topicTags) {
      cluster.keywords.add(tag);
    }
    cluster.postIds.push(post.id);
    cluster.posts.push(post);
    cluster.sentimentCounts[post.sentiment] += 1;
    cluster.totalEngagement += post.engagement;
    clusters.set(primaryTag, cluster);
  }

  return [...clusters.values()]
    .map((cluster) => ({
      clusterKey: cluster.clusterKey,
      label: cluster.label,
      postIds: cluster.postIds,
      posts: cluster.posts.sort((left, right) => right.engagement - left.engagement),
      keywords: [...cluster.keywords],
      totalEngagement: cluster.totalEngagement,
      dominantSentiment: summarizeSentiment(cluster.sentimentCounts),
      sentimentCounts: cluster.sentimentCounts
    }))
    .sort((left, right) => right.totalEngagement - left.totalEngagement);
}

export function buildSceneCards({ scene, approvedPosts, flaggedPosts, clusters }) {
  const topClusters = clusters.slice(0, 3);
  const topClusterLabels = topClusters.map((cluster) => cluster.label);
  const overallSentiment = summarizeSentiment(
    approvedPosts.reduce(
      (counts, post) => {
        counts[post.sentiment] += 1;
        return counts;
      },
      { positive: 0, negative: 0, divisive: 0, neutral: 0 }
    )
  );

  const summaryCard = {
    cardType: 'summary_card',
    title: '大家都在说什么',
    summary: `${scene.title} 现在主要在聊 ${topClusterLabels.join('、') || '现场观察'}，整体氛围${sentimentLabel(
      overallSentiment
    )}。${topClusters[0] ? `最热的是“${topClusters[0].label}”话题。` : '现场还在积累可总结内容。'}`,
    sentiment: overallSentiment,
    sourcePostIds: topClusters.flatMap((cluster) => cluster.postIds.slice(0, 2)),
    traceability: topClusters.map((cluster) => ({
      cardType: 'summary_card',
      clusterKey: cluster.clusterKey,
      sourcePostIds: cluster.postIds.slice(0, 3)
    }))
  };

  const hotTakeCards = topClusters.map((cluster) => {
    const sourcePosts = cluster.posts.slice(0, 2);
    const leadPost = sourcePosts[0];
    return {
      cardType: 'hot_take_card',
      title: `${cluster.label} 热观点`,
      summary: leadPost
        ? `${leadPost.authorName}：${leadPost.text}`
        : `${cluster.label} 话题正在升温。`,
      sentiment: cluster.dominantSentiment,
      clusterKey: cluster.clusterKey,
      sourcePostIds: sourcePosts.map((post) => post.id),
      keywords: cluster.keywords.slice(0, 4)
    };
  });

  const riskCards = [];
  if (flaggedPosts.length) {
    riskCards.push({
      cardType: 'risk_card',
      title: '审核拦截提醒',
      summary: `本场景已拦截 ${flaggedPosts.length} 条含有人身攻击或骚扰风险的内容，默认不进入公开摘要。`,
      sourcePostIds: flaggedPosts.map((post) => post.id),
      keywords: ['moderation', 'safety']
    });
  }

  const negativeCluster = clusters.find((cluster) => cluster.dominantSentiment === 'negative');
  if (negativeCluster) {
    riskCards.push({
      cardType: 'risk_card',
      title: `${negativeCluster.label} 风险提醒`,
      summary: `围绕“${negativeCluster.label}”的话题出现了负向反馈，建议回看原始观点再判断。`,
      sourcePostIds: negativeCluster.postIds.slice(0, 3),
      keywords: negativeCluster.keywords.slice(0, 4)
    });
  }

  const traceability = [
    ...summaryCard.traceability,
    ...hotTakeCards.map((card) => ({
      cardType: card.cardType,
      clusterKey: card.clusterKey,
      sourcePostIds: card.sourcePostIds
    })),
    ...riskCards.map((card) => ({
      cardType: card.cardType,
      clusterKey: card.title,
      sourcePostIds: card.sourcePostIds
    }))
  ];

  return {
    summaryCard,
    hotTakeCards,
    riskCards,
    traceability,
    overallSentiment
  };
}

export function rankActiveAgents({ approvedPosts, agentPublicCards, viewerContext, sortBy, sceneLocation }) {
  const activityByAgent = new Map();

  for (const post of approvedPosts) {
    if (!post.agentId) {
      continue;
    }
    const current = activityByAgent.get(post.agentId) ?? {
      postCount: 0,
      engagement: 0,
      tags: new Set(),
      newestTimestamp: post.createdAt
    };
    current.postCount += 1;
    current.engagement += post.engagement;
    for (const tag of post.topicTags) {
      current.tags.add(tag);
    }
    if (new Date(post.createdAt) > new Date(current.newestTimestamp)) {
      current.newestTimestamp = post.createdAt;
    }
    activityByAgent.set(post.agentId, current);
  }

  const ranked = agentPublicCards
    .filter((card) => card.visibilityScope !== 'trusted_only')
    .map((card) => {
      const activity = activityByAgent.get(card.agentId) ?? {
        postCount: 0,
        engagement: 0,
        tags: new Set(card.intentTags),
        newestTimestamp: null
      };
      const combinedTags = uniqueStrings([
        ...card.identityTags,
        ...card.intentTags,
        ...card.expertiseTags,
        ...activity.tags
      ]);
      const activityScore = clampScore(activity.postCount * 18 + activity.engagement * 1.2, 0, 100);
      const freshnessScore = clampScore(
        100 - minutesSince(activity.newestTimestamp ?? new Date(), new Date()) * 4,
        0,
        100
      );
      const matchScore = clampScore(
        keywordOverlap(viewerContext.profileTags, combinedTags) * 100 + (card.allowsAgentIntro ? 6 : 0),
        0,
        100
      );
      const trustScore = clampScore(Number(card.trustScore ?? 0) * 100, 0, 100);
      const heatScore = clampScore(activityScore * 0.55 + trustScore * 0.2 + freshnessScore * 0.25, 0, 100);
      return {
        id: stableId('scene-presence', card.agentId, card.userId),
        agentId: card.agentId,
        userId: card.userId,
        displayName: card.displayName,
        identityTags: card.identityTags,
        intentTags: card.intentTags,
        expertiseTags: card.expertiseTags,
        publicBio: card.publicBio,
        allowsAgentIntro: card.allowsAgentIntro,
        visibilityScope: card.visibilityScope,
        privacyRadius: card.privacyRadius,
        maskedLocationLabel: maskLocation(card.privacyRadius, card.locationLabel || sceneLocation),
        activityScore,
        freshnessScore,
        matchScore,
        trustScore,
        heatScore,
        combinedTags,
        contactHint: card.allowsAgentIntro ? '可先让分身破冰' : '需要真人先开口'
      };
    });

  const sorters = {
    hottest: (left, right) => right.heatScore - left.heatScore || right.trustScore - left.trustScore,
    newest: (left, right) =>
      right.freshnessScore - left.freshnessScore || right.activityScore - left.activityScore,
    best_match: (left, right) => right.matchScore - left.matchScore || right.trustScore - left.trustScore,
    most_trusted: (left, right) => right.trustScore - left.trustScore || right.heatScore - left.heatScore
  };

  return ranked.sort(sorters[sortBy] ?? sorters.best_match);
}
