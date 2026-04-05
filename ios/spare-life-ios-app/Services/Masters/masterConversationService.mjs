import {
  MASTER_CTA_EFFECTS,
  buildEffectRoute,
  buildPromptPreview,
  clipText,
  combineTags,
  deriveStanceLabel,
  scoreTextMatch,
  stableId
} from '../../Domain/Models/masterContracts.mjs';
import { sanitizeText, uniqueStrings } from '../../Domain/Models/sceneContracts.mjs';

function buildStoryExcerpt(story, query) {
  const scoredBeats = story.beats
    .map((beat) => ({
      beat,
      score: scoreTextMatch(beat, query)
    }))
    .sort((left, right) => right.score - left.score);

  return uniqueStrings(scoredBeats.slice(0, 2).map((entry) => entry.beat));
}

function selectPrimaryLane(text, master) {
  const lowered = sanitizeText(text).toLowerCase();
  if (
    ['求职', '转岗', '简历', '面试', '现金流', '合作', '副业'].some((keyword) => lowered.includes(keyword))
  ) {
    return 'earn_social';
  }
  if (['关系', '沟通', '朋友', '婚恋', '相处', '表达'].some((keyword) => lowered.includes(keyword))) {
    return 'messages';
  }
  if (master.domainKey === 'career') {
    return 'earn_social';
  }
  return 'messages';
}

export function recallRelevantMemories({ memories, masterId, shareMode, message, limit = 3 }) {
  const filtered = memories.filter((memory) => {
    if (memory.masterId === masterId) {
      return true;
    }
    return shareMode === 'cross_master' && memory.scope === 'cross_master';
  });

  return filtered
    .map((memory) => ({
      ...memory,
      relevanceScore: scoreTextMatch(
        `${memory.summary} ${memory.tags.join(' ')} ${JSON.stringify(memory.detail ?? {})}`,
        message
      )
    }))
    .sort(
      (left, right) =>
        right.relevanceScore - left.relevanceScore ||
        new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime()
    )
    .slice(0, limit);
}

export function rankRelevantStories({ stories, message, memories, master, limit = 2 }) {
  const query = [message, memories.map((memory) => memory.summary).join(' '), master.searchTags.join(' ')].join(' ');

  return stories
    .map((story) => ({
      ...story,
      relevanceScore:
        scoreTextMatch(
          `${story.title} ${story.summary} ${story.fullText} ${story.tags.join(' ')} ${story.beats.join(' ')}`,
          query
        ) +
        scoreTextMatch(story.tags.join(' '), query) * 0.5,
      clippedBeats: buildStoryExcerpt(story, query)
    }))
    .sort((left, right) => right.relevanceScore - left.relevanceScore || left.title.localeCompare(right.title))
    .slice(0, limit);
}

function memorySummaryLabel(kind, segment) {
  switch (kind) {
    case 'goal':
      return `目标：${segment}`;
    case 'history':
      return `经历：${segment}`;
    case 'constraint':
      return `约束：${segment}`;
    default:
      return `背景：${segment}`;
  }
}

export function extractAuthorizedMemories({ userId, masterId, sessionId, message, consentScope, nowIso }) {
  if (consentScope === 'session_only') {
    return [];
  }

  const segments = sanitizeText(message)
    .split(/[。！？!?]/)
    .map((segment) => sanitizeText(segment))
    .filter(Boolean);

  const detectors = [
    { kind: 'goal', test: /(目标|想|希望|计划|准备|需要|转岗|求职|创业|拿到|完成)/ },
    { kind: 'history', test: /(之前|过去|以前|去年|曾经|做过|经历|履历|一直在)/ },
    { kind: 'constraint', test: /(担心|焦虑|预算|时间|压力|风险|家里|现金流)/ }
  ];

  const memories = [];
  for (const segment of segments) {
    const detector = detectors.find((item) => item.test.test(segment));
    if (!detector) {
      continue;
    }

    memories.push({
      id: stableId('master-memory', userId, masterId, consentScope, detector.kind, segment.slice(0, 48)),
      userId,
      masterId,
      sessionId,
      scope: consentScope,
      memoryKind: detector.kind,
      summary: memorySummaryLabel(detector.kind, segment),
      detail: {
        rawSegment: segment
      },
      tags: uniqueStrings(segment.match(/[A-Za-z0-9]+|[\p{Script=Han}]{2,}/gu) ?? []),
      authorizedAt: nowIso,
      updatedAt: nowIso
    });
  }

  if (!memories.length && segments[0]) {
    memories.push({
      id: stableId('master-memory', userId, masterId, consentScope, 'context', segments[0].slice(0, 48)),
      userId,
      masterId,
      sessionId,
      scope: consentScope,
      memoryKind: 'context',
      summary: memorySummaryLabel('context', segments[0]),
      detail: {
        rawSegment: segments[0]
      },
      tags: uniqueStrings(segments[0].match(/[A-Za-z0-9]+|[\p{Script=Han}]{2,}/gu) ?? []),
      authorizedAt: nowIso,
      updatedAt: nowIso
    });
  }

  return memories.slice(0, 3);
}

function buildSessionCTAs({ master, text, sessionId, consultationId = null }) {
  const primaryLane = selectPrimaryLane(text, master);
  const ctas = [
    {
      id: stableId('cta', sessionId ?? consultationId ?? master.id, primaryLane, '行动清单'),
      label: primaryLane === 'earn_social' ? '去赚闲能页落一个行动' : '去消息页给自己发行动清单',
      effectKind: primaryLane,
      route: buildEffectRoute(primaryLane, {
        sessionId,
        lane: primaryLane === 'earn_social' ? 'jobSeek' : null,
        draft: clipText(text, 40),
        topic: master.displayName
      })
    },
    {
      id: stableId('cta', sessionId ?? consultationId ?? master.id, 'profile', '写入记忆'),
      label: '去我的页检查长期记忆授权',
      effectKind: 'profile',
      route: buildEffectRoute('profile')
    }
  ];

  return ctas.filter((cta) => MASTER_CTA_EFFECTS.has(cta.effectKind));
}

function renderPrompt(template, variables) {
  return Object.entries(variables).reduce(
    (output, [key, value]) => output.replaceAll(`{{${key}}}`, sanitizeText(value)),
    template
  );
}

export function composeMasterReply({
  master,
  userMessage,
  recentMessages,
  memories,
  stories,
  sessionId = null,
  consultationId = null,
  mode = 'chat'
}) {
  const leadStory = stories[0];
  const leadMemory = memories[0];
  const stance = deriveStanceLabel(master.character);
  const memoryLine = leadMemory ? `我会沿用你已经授权我记住的内容: ${leadMemory.summary}。` : '';
  const storyLine = leadStory
    ? `这让我想到“${leadStory.title}”: ${leadStory.clippedBeats.join('；')}。`
    : `${master.displayName}会先按你的现状拆出一段能立刻执行的节奏。`;
  const recentLine =
    recentMessages.length > 0
      ? `你们最近一次上下文里最重要的是“${clipText(recentMessages.at(-1)?.content ?? '', 42)}”。`
      : '';
  const actionLine =
    master.character.decisionStyle === 'small_bets_profit'
      ? '先做一个 7 天可验证、且不会伤现金流的小实验，再决定是否扩大。'
      : master.character.decisionStyle === 'act_then_reflect'
        ? '先做一个今天就能开始的小动作，用结果校准下一步，而不是继续空转。'
        : master.character.decisionStyle === 'resilient_expression'
          ? '先稳住情绪和表达，再决定向谁求助、向谁展示你的新计划。'
          : '先定一条底线、一个周目标、一个今天动作，别同时开太多口子。';
  const boundaryLine = master.character.boundaries.length
    ? `不要做的是: ${master.character.boundaries[0]}。`
    : '';

  const replyText = [
    `${master.displayName}会按“${master.character.adviceStyle}”来回应。`,
    recentLine,
    memoryLine,
    storyLine,
    `就这轮问题“${clipText(userMessage, 48)}”，我的立场是${stance}。`,
    actionLine,
    boundaryLine
  ]
    .filter(Boolean)
    .join(' ');

  const ctas = buildSessionCTAs({
    master,
    text: userMessage,
    sessionId,
    consultationId
  });
  const promptPacket = {
    promptPreview: buildPromptPreview(master.promptTemplate),
    renderedPrompt: renderPrompt(master.promptTemplate, {
      master_name: master.displayName,
      advice_style: master.character.adviceStyle,
      user_goal: leadMemory?.summary ?? '待澄清目标',
      memory_context: memories.map((memory) => memory.summary).join(' / ') || '暂无长期记忆',
      story_context:
        stories.map((story) => `${story.title}:${story.clippedBeats.join(' / ')}`).join(' || ') || '暂无故事引用',
      user_message: userMessage,
      recent_context: recentMessages.map((message) => message.content).join(' / ') || '首次会话'
    }),
    referencedStoryIds: stories.map((story) => story.id),
    referencedMemoryIds: memories.map((memory) => memory.id)
  };

  return {
    text: replyText,
    stance,
    ctas,
    promptPacket,
    referencedStories: stories.map((story) => ({
      id: story.id,
      title: story.title,
      clippedBeats: story.clippedBeats
    })),
    referencedMemories: memories.map((memory) => ({
      id: memory.id,
      summary: memory.summary,
      scope: memory.scope
    })),
    mode
  };
}

export function mergeConsultationAdvice({ issue, memberReplies, consultationId }) {
  const uniqueStances = uniqueStrings(memberReplies.map((member) => member.reply.stance));
  const conflicts =
    uniqueStances.length > 1
      ? [
          {
            type: 'approach_conflict',
            summary: `不同大师给出了 ${uniqueStances.join(' / ')} 的推进节奏。`
          }
        ]
      : [];

  const mergedSummary = [
    `围绕“${issue}”，${memberReplies.map((member) => member.master.displayName).join('、')}的共同建议是先把目标写实，再用一个可验证动作换取反馈。`,
    conflicts[0]?.summary ?? '目前几位大师的节奏判断基本一致。'
  ].join(' ');

  const ctas = uniqueStrings(
    memberReplies.flatMap((member) => member.reply.ctas.map((cta) => JSON.stringify(cta)))
  )
    .map((value) => JSON.parse(value))
    .slice(0, 3)
    .map((cta) => ({
      ...cta,
      id: stableId('consult-cta', consultationId, cta.label, cta.route)
    }));

  return {
    mergedSummary,
    conflicts,
    ctas
  };
}
