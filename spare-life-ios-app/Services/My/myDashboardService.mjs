import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
  scryptSync
} from 'node:crypto';

import {
  buildBackupRoute,
  buildGrowthRoute,
  buildMemoryRoute,
  buildPersonaRoute,
  buildProfileRoute,
  buildPrivacyRoute,
  buildReplayRoute,
  buildSyncRoute,
  buildTrainingRoute,
  defaultMemoryTitleHint,
  normalizePersonaDNA,
  normalizePrincipalGrants,
  normalizeVisibilityRules,
  rankTopTraits,
  resolveGrowthMode,
  resolveMemoryKind,
  resolveMemoryScope,
  resolveAuthorizationStatus,
  resolvePrincipalRole,
  resolveReplaySeverity,
} from '../../Domain/Models/myContracts.mjs';
import {
  clampScore,
  isoNow,
  sanitizeText,
  stableId,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const PROFILE_FIELDS = [
  'displayName',
  'agentDisplayName',
  'headline',
  'bio',
  'city',
  'occupation',
  'growthFocus',
  'availabilityNote'
];

const REPLAY_SEVERITY_WEIGHTS = {
  low: 1,
  medium: 2,
  high: 3,
  critical: 4
};

function sha1(value) {
  return createHash('sha1').update(value).digest('hex');
}

function describeTrait(trait) {
  switch (trait) {
    case 'warmth':
      return '温度';
    case 'curiosity':
      return '好奇';
    case 'directness':
      return '直率';
    case 'playfulness':
      return '轻盈';
    case 'steadiness':
    default:
      return '稳定';
  }
}

function awakeningStageLabel(score) {
  if (score >= 85) {
    return 'resonant';
  }
  if (score >= 70) {
    return 'awakened';
  }
  if (score >= 55) {
    return 'stirring';
  }
  return 'latent';
}

function summarizeVisibility(visibilityRules) {
  return Object.entries(normalizeVisibilityRules(visibilityRules))
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([fieldKey, value]) => ({
      fieldKey,
      visibility: value
    }));
}

function countProfileCompleteness(profile) {
  const score = PROFILE_FIELDS.filter((field) => sanitizeText(profile?.[field])).length;
  const tags = uniqueStrings(profile?.personaTags ?? []).length > 0 ? 1 : 0;
  return (score + tags) / (PROFILE_FIELDS.length + 1);
}

function countPublicFields(visibilityRules) {
  return Object.values(normalizeVisibilityRules(visibilityRules)).filter((value) => value === 'public').length;
}

function unresolvedReplayWeight(replays) {
  return (replays ?? [])
    .filter((replay) => replay.status === 'open')
    .reduce((total, replay) => total + (REPLAY_SEVERITY_WEIGHTS[resolveReplaySeverity(replay.severity)] ?? 1), 0);
}

function activeMaskSummary(masks = [], activeMaskId = null) {
  const activeMask =
    masks.find((mask) => mask.id === activeMaskId) ??
    masks.find((mask) => mask.isDefault) ??
    masks[0] ??
    null;
  if (!activeMask) {
    return null;
  }
  return {
    id: activeMask.id,
    label: activeMask.label,
    scenarioKey: activeMask.scenarioKey,
    tone: activeMask.tone,
    openness: activeMask.openness,
    boundaryTags: activeMask.boundaryTags
  };
}

export function buildMyBootstrapSeed(userId, nowIso = isoNow()) {
  const visibility = normalizeVisibilityRules();
  const profile = {
    userId,
    displayName: '林闻',
    agentDisplayName: '闻闻分身',
    headline: '把焦虑拆成可执行动作的 AI 产品搭子',
    bio: '正在转向 AI 产品与本地优先应用，希望把节奏、边界和长期记忆训练成可信分身。',
    city: '上海',
    occupation: 'AI 产品转岗中',
    growthFocus: '让分身先学会复盘，再学会替我表达',
    personaTags: ['稳', '会复盘', '边界清楚'],
    interests: ['AI 产品', '本地优先', '关系经营'],
    availabilityNote: '晚上 20:00 之后适合进入深聊模式',
    createdAt: nowIso,
    updatedAt: nowIso
  };

  const trainingTasks = [
    {
      id: stableId('my-training', userId, 'voice-alignment'),
      userId,
      title: '口吻校准',
      focusArea: 'voice_alignment',
      targetBehavior: '让分身在拒绝请求时既坚定又不伤人',
      difficulty: 3,
      status: 'in_progress',
      progress: 0.45,
      dueAt: '2026-03-28T20:00:00+08:00',
      completedAt: null,
      route: buildTrainingRoute(stableId('my-training', userId, 'voice-alignment')),
      createdAt: nowIso,
      updatedAt: nowIso
    },
    {
      id: stableId('my-training', userId, 'boundary-guard'),
      userId,
      title: '边界守卫',
      focusArea: 'boundary_guard',
      targetBehavior: '遇到催促和情绪勒索时保持边界，不直接泄露隐私',
      difficulty: 4,
      status: 'todo',
      progress: 0,
      dueAt: '2026-03-29T20:00:00+08:00',
      completedAt: null,
      route: buildTrainingRoute(stableId('my-training', userId, 'boundary-guard')),
      createdAt: nowIso,
      updatedAt: nowIso
    },
    {
      id: stableId('my-training', userId, 'memory-recall'),
      userId,
      title: '记忆召回',
      focusArea: 'memory_recall',
      targetBehavior: '在跨会话时准确带回目标、约束和情绪背景',
      difficulty: 2,
      status: 'todo',
      progress: 0,
      dueAt: '2026-03-30T20:00:00+08:00',
      completedAt: null,
      route: buildTrainingRoute(stableId('my-training', userId, 'memory-recall')),
      createdAt: nowIso,
      updatedAt: nowIso
    }
  ];

  const errorReplays = [
    {
      id: stableId('my-replay', userId, 'over-share'),
      userId,
      sourceChannel: 'messages',
      mismatchType: 'privacy_leak',
      severity: 'high',
      transcript: [
        { role: 'user', content: '帮我直接把手机号发给对方吧。' },
        { role: 'agent', content: '好的，我把完整联系方式发过去。' }
      ],
      diagnosis: '分身跳过了联系信息保护规则，错误地越过了人工确认。',
      repairBrief: '改成先给出可公开的下一步，再请求人工确认。',
      status: 'open',
      resolvedNote: null,
      route: buildReplayRoute(stableId('my-replay', userId, 'over-share')),
      createdAt: nowIso,
      updatedAt: nowIso
    },
    {
      id: stableId('my-replay', userId, 'too-cold'),
      userId,
      sourceChannel: 'public_profile',
      mismatchType: 'tone_drift',
      severity: 'medium',
      transcript: [
        { role: 'visitor', content: '你的分身看起来很厉害，可以聊聊合作吗？' },
        { role: 'agent', content: '请提交标准化表单后再说。' }
      ],
      diagnosis: '回复过于硬，缺少先接住对方意图的缓冲句。',
      repairBrief: '先确认合作意图，再给结构化下一步。',
      status: 'open',
      resolvedNote: null,
      route: buildReplayRoute(stableId('my-replay', userId, 'too-cold')),
      createdAt: nowIso,
      updatedAt: nowIso
    }
  ];

  const personaConfig = {
    userId,
    awakeningSeed: 46,
    growthMode: 'steady',
    dna: normalizePersonaDNA({
      warmth: 58,
      curiosity: 72,
      directness: 60,
      playfulness: 38,
      steadiness: 82
    }),
    values: ['真实', '边界', '长期主义'],
    activeMaskId: stableId('my-mask', userId, 'public'),
    createdAt: nowIso,
    updatedAt: nowIso
  };

  const masks = [
    {
      id: stableId('my-mask', userId, 'public'),
      userId,
      label: '公开场合',
      scenarioKey: 'public_intro',
      tone: 'warm_clear',
      openness: 'measured',
      boundaryTags: ['不直接交换隐私', '先说明合作边界'],
      styleTags: ['结构化', '可信', '留余地'],
      isDefault: true,
      createdAt: nowIso,
      updatedAt: nowIso
    },
    {
      id: stableId('my-mask', userId, 'friends'),
      userId,
      label: '熟人深聊',
      scenarioKey: 'trusted_circle',
      tone: 'soft_direct',
      openness: 'high',
      boundaryTags: ['先确认情绪状态', '避免替对方做决定'],
      styleTags: ['有温度', '会追问', '不敷衍'],
      isDefault: false,
      createdAt: nowIso,
      updatedAt: nowIso
    },
    {
      id: stableId('my-mask', userId, 'career'),
      userId,
      label: '求职合作',
      scenarioKey: 'career_mode',
      tone: 'confident',
      openness: 'medium',
      boundaryTags: ['不夸大经历', '结果导向'],
      styleTags: ['利落', '不画饼', '重交付'],
      isDefault: false,
      createdAt: nowIso,
      updatedAt: nowIso
    }
  ];

  const authorizations = [
    {
      userId,
      resourceKey: 'contacts',
      status: 'prompt',
      detail: '允许分身识别熟人关系与面具上下文',
      lastPromptedAt: nowIso,
      updatedAt: nowIso
    },
    {
      userId,
      resourceKey: 'notifications',
      status: 'authorized',
      detail: '允许提醒训练任务、记忆回顾与同步异常',
      lastPromptedAt: nowIso,
      updatedAt: nowIso
    },
    {
      userId,
      resourceKey: 'photo_library',
      status: 'denied',
      detail: '公开资料暂不读取相册，仅使用本地导入头像',
      lastPromptedAt: nowIso,
      updatedAt: nowIso
    },
    {
      userId,
      resourceKey: 'microphone',
      status: 'restricted',
      detail: '当前设备限制语音训练，只开放文本训练',
      lastPromptedAt: nowIso,
      updatedAt: nowIso
    }
  ];

  return {
    profile,
    visibility,
    trainingTasks,
    errorReplays,
    personaConfig,
    masks,
    authorizations
  };
}

export function buildPublicProfile({
  profile,
  visibilityRules,
  syncSnapshot,
  awakeningSnapshot,
  activeMask
}) {
  const rules = normalizeVisibilityRules(visibilityRules);
  const visibleProfile = {};
  const copyField = (fieldKey, value) => {
    if (rules[fieldKey] === 'public') {
      visibleProfile[fieldKey] = value;
    }
  };

  copyField('displayName', profile.displayName);
  copyField('agentDisplayName', profile.agentDisplayName);
  copyField('headline', profile.headline);
  copyField('city', profile.city);
  copyField('occupation', profile.occupation);
  copyField('growthFocus', profile.growthFocus);
  copyField('availabilityNote', profile.availabilityNote);
  if (rules.personaTags === 'public') {
    visibleProfile.personaTags = uniqueStrings(profile.personaTags ?? []);
  }

  return {
    cardId: stableId('my-public-card', profile.userId),
    route: buildProfileRoute(profile.userId),
    visibilitySummary: summarizeVisibility(rules),
    profile: visibleProfile,
    syncBadge: {
      score: syncSnapshot.score,
      band: syncSnapshot.band
    },
    awakeningBadge: {
      stage: awakeningSnapshot.stage,
      label: awakeningSnapshot.label
    },
    activeMask: activeMask
      ? {
          label: activeMask.label,
          tone: activeMask.tone
        }
      : null
  };
}

export function evaluateSyncState({
  profile,
  visibilityRules,
  trainingTasks = [],
  errorReplays = [],
  personaConfig,
  masks = [],
  memoryCount = 0,
  previousScore = null
}) {
  const totalTasks = Math.max(trainingTasks.length, 1);
  const completedTasks = trainingTasks.filter((task) => task.status === 'completed').length;
  const inProgressTasks = trainingTasks.filter((task) => task.status === 'in_progress').length;
  const resolvedReplays = errorReplays.filter((replay) => replay.status === 'resolved').length;
  const openReplayWeight = unresolvedReplayWeight(errorReplays);
  const profileCompleteness = countProfileCompleteness(profile);
  const publicFields = countPublicFields(visibilityRules);
  const personaAverage =
    Object.values(normalizePersonaDNA(personaConfig?.dna ?? {})).reduce((sum, value) => sum + value, 0) / 5;

  const trainingComponent = Math.round((completedTasks / totalTasks) * 28 + (inProgressTasks / totalTasks) * 8);
  const replayComponent = Math.max(0, 24 - openReplayWeight * 5 + resolvedReplays * 4);
  const profileComponent = Math.round(profileCompleteness * 18 + publicFields * 1.5);
  const personaComponent = Math.round(masks.length * 2 + personaAverage * 0.12);
  const memoryComponent = Math.min(12, memoryCount * 3);

  const score = clampScore(
    20 + trainingComponent + replayComponent + profileComponent + personaComponent + memoryComponent,
    0,
    100
  );
  const delta = previousScore === null ? 0 : score - previousScore;

  let band = 'fragile';
  if (score >= 82) {
    band = 'high_fidelity';
  } else if (score >= 68) {
    band = 'usable';
  } else if (score >= 55) {
    band = 'warming_up';
  }

  const confidence = clampScore(
    25 + completedTasks * 10 + resolvedReplays * 8 + memoryCount * 6 + publicFields * 3,
    0,
    100
  );

  const nextActions = [
    ...trainingTasks
      .filter((task) => task.status !== 'completed')
      .sort((left, right) => right.difficulty - left.difficulty || left.title.localeCompare(right.title))
      .slice(0, 3)
      .map((task) => ({
        kind: 'training_task',
        id: task.id,
        title: task.title,
        detail: task.targetBehavior,
        route: task.route
      })),
    ...errorReplays
      .filter((replay) => replay.status === 'open')
      .sort(
        (left, right) =>
          (REPLAY_SEVERITY_WEIGHTS[resolveReplaySeverity(right.severity)] ?? 0) -
            (REPLAY_SEVERITY_WEIGHTS[resolveReplaySeverity(left.severity)] ?? 0) ||
          left.createdAt.localeCompare(right.createdAt)
      )
      .slice(0, 2)
      .map((replay) => ({
        kind: 'error_replay',
        id: replay.id,
        title: replay.mismatchType,
        detail: replay.repairBrief,
        route: replay.route
      }))
  ];

  return {
    score,
    delta,
    band,
    confidence,
    breakdown: {
      training: trainingComponent,
      replay: replayComponent,
      profile: profileComponent,
      persona: personaComponent,
      memory: memoryComponent
    },
    trainingTasks,
    errorReplays,
    nextActions,
    route: buildSyncRoute(profile.userId)
  };
}

export function evaluateAwakeningState({
  profile,
  personaConfig,
  masks = [],
  syncSnapshot,
  trainingTasks = [],
  errorReplays = [],
  memoryCount = 0
}) {
  const dna = normalizePersonaDNA(personaConfig?.dna ?? {});
  const completedTasks = trainingTasks.filter((task) => task.status === 'completed').length;
  const resolvedReplays = errorReplays.filter((replay) => replay.status === 'resolved').length;
  const dnaAverage = Object.values(dna).reduce((sum, value) => sum + value, 0) / 5;
  const score = clampScore(
    (personaConfig?.awakeningSeed ?? 40) +
      dnaAverage * 0.18 +
      syncSnapshot.score * 0.22 +
      completedTasks * 6 +
      resolvedReplays * 4 +
      memoryCount * 3,
    0,
    100
  );
  const stage = awakeningStageLabel(score);
  const topTraits = rankTopTraits(dna).map((item) => ({
    ...item,
    label: describeTrait(item.key)
  }));
  const activeMask = activeMaskSummary(masks, personaConfig?.activeMaskId);

  return {
    score,
    stage,
    label:
      stage === 'resonant'
        ? '共振中'
        : stage === 'awakened'
          ? '已觉醒'
          : stage === 'stirring'
            ? '正在苏醒'
            : '待唤醒',
    growthMode: resolveGrowthMode(personaConfig?.growthMode, 'steady'),
    dna,
    topTraits,
    values: uniqueStrings(personaConfig?.values ?? []),
    activeMask,
    masks: masks.map((mask) => ({
      ...mask,
      route: buildPersonaRoute(profile.userId)
    })),
    route: buildPersonaRoute(profile.userId)
  };
}

export function encryptMemoryDocument({ userId, vaultSecret, document }) {
  const normalizedSecret = sanitizeText(vaultSecret);
  if (!normalizedSecret) {
    throw new Error('vaultSecret is required to encrypt memory content.');
  }

  const payload = JSON.stringify(document);
  const salt = createHash('sha256').update(`spare-life-memory::${userId}`).digest().subarray(0, 16);
  const key = scryptSync(normalizedSecret, salt, 32);
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const cipherText = Buffer.concat([cipher.update(payload, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return {
    algorithm: 'aes-256-gcm',
    iv: iv.toString('base64'),
    cipherText: cipherText.toString('base64'),
    authTag: authTag.toString('base64'),
    checksum: sha1(payload)
  };
}

export function decryptMemoryDocument({ userId, vaultSecret, entry }) {
  const normalizedSecret = sanitizeText(vaultSecret);
  if (!normalizedSecret) {
    throw new Error('vaultSecret is required to decrypt memory content.');
  }

  const salt = createHash('sha256').update(`spare-life-memory::${userId}`).digest().subarray(0, 16);
  const key = scryptSync(normalizedSecret, salt, 32);
  const decipher = createDecipheriv(
    entry.algorithm,
    key,
    Buffer.from(entry.iv, 'base64')
  );
  decipher.setAuthTag(Buffer.from(entry.authTag, 'base64'));
  const clearText = Buffer.concat([
    decipher.update(Buffer.from(entry.cipherText, 'base64')),
    decipher.final()
  ]).toString('utf8');
  return JSON.parse(clearText);
}

export function normalizeMemoryDocument(input, fallback = {}) {
  const memoryKind = resolveMemoryKind(input.memoryKind ?? fallback.memoryKind ?? 'reflection');
  return {
    title: sanitizeText(input.title ?? fallback.title),
    summary: sanitizeText(input.summary ?? fallback.summary),
    content: sanitizeText(input.content ?? fallback.content),
    tags: uniqueStrings(input.tags ?? fallback.tags ?? []),
    emotion: sanitizeText(input.emotion ?? fallback.emotion) || 'steady',
    source: sanitizeText(input.source ?? fallback.source) || 'manual_entry',
    memoryKind
  };
}

export function presentMemoryEntry({ userId, entry, document }) {
  return {
    id: entry.id,
    route: buildMemoryRoute(userId, entry.id),
    title: document.title,
    summary: document.summary,
    content: document.content,
    tags: uniqueStrings(document.tags ?? []),
    emotion: document.emotion,
    source: document.source,
    memoryKind: resolveMemoryKind(entry.memoryKind),
    permissionScope: resolveMemoryScope(entry.permissionScope),
    grants: normalizePrincipalGrants(entry.grants ?? []),
    updatedAt: entry.updatedAt,
    createdAt: entry.createdAt
  };
}

export function canPrincipalAccessMemory(entry, principalKey, principalRole) {
  const role = resolvePrincipalRole(principalRole, 'owner');
  const grants = new Set(normalizePrincipalGrants(entry.grants ?? []));
  if (role === 'owner') {
    return true;
  }
  if (grants.has(sanitizeText(principalKey)) || grants.has(role)) {
    return true;
  }

  switch (resolveMemoryScope(entry.permissionScope, 'private')) {
    case 'public':
      return true;
    case 'trusted_circle':
      return role === 'trusted_circle';
    case 'agent_shared':
      return role === 'agent';
    case 'private':
    default:
      return false;
  }
}

export function buildMemoryPalaceSnapshot({
  userId,
  principalKey,
  principalRole,
  entries,
  vaultSecret,
  query = '',
  limit = 12
}) {
  const normalizedQuery = sanitizeText(query).toLowerCase();
  const visible = [];
  let deniedCount = 0;

  for (const entry of entries) {
    if (!canPrincipalAccessMemory(entry, principalKey, principalRole)) {
      deniedCount += 1;
      continue;
    }
    const document = decryptMemoryDocument({
      userId,
      vaultSecret,
      entry
    });
    const presented = presentMemoryEntry({
      userId,
      entry,
      document
    });
    const searchText = `${presented.title} ${presented.summary} ${presented.content} ${presented.tags.join(' ')}`.toLowerCase();
    if (!normalizedQuery || searchText.includes(normalizedQuery)) {
      visible.push(presented);
    }
  }

  return {
    route: buildMemoryRoute(userId),
    memories: visible
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
      .slice(0, Math.max(1, Number(limit ?? 12))),
    deniedCount,
    totalStored: entries.length
  };
}

export function computeGrowthSnapshot({
  userId,
  syncSnapshot,
  awakeningSnapshot,
  visibilityRules,
  authorizations = [],
  memories = [],
  backups = [],
  trainingTasks = [],
  note = ''
}) {
  const completedTasks = trainingTasks.filter((task) => task.status === 'completed').length;
  const publicFields = countPublicFields(visibilityRules);
  const authorizedCount = authorizations.filter((item) => item.status === 'authorized').length;
  const sharedMemories = memories.filter((entry) => entry.permissionScope !== 'private').length;

  return {
    id: stableId('my-growth-snapshot', userId, note, isoNow()),
    userId,
    idleEnergy: clampScore(18 + completedTasks * 14 + backups.length * 4, 0, 100),
    socialScore: clampScore(12 + publicFields * 10 + authorizedCount * 8 + sharedMemories * 6, 0, 100),
    syncScore: syncSnapshot.score,
    awakeningScore: awakeningSnapshot.score,
    memoryCount: memories.length,
    activeBackups: backups.length,
    note: sanitizeText(note) || '状态已刷新',
    createdAt: isoNow()
  };
}

export function diffGrowthSnapshot(current, previous = null) {
  if (!previous) {
    return {
      idleEnergy: 0,
      socialScore: 0,
      syncScore: 0,
      awakeningScore: 0,
      memoryCount: 0
    };
  }
  return {
    idleEnergy: current.idleEnergy - previous.idleEnergy,
    socialScore: current.socialScore - previous.socialScore,
    syncScore: current.syncScore - previous.syncScore,
    awakeningScore: current.awakeningScore - previous.awakeningScore,
    memoryCount: current.memoryCount - previous.memoryCount
  };
}

export function buildGrowthReview({ userId, snapshots = [], journal = [] }) {
  const orderedSnapshots = [...snapshots].sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  const latest = orderedSnapshots.at(-1) ?? null;

  return {
    route: buildGrowthRoute(userId),
    latest,
    chart: orderedSnapshots.map((snapshot) => ({
      createdAt: snapshot.createdAt,
      idleEnergy: snapshot.idleEnergy,
      socialScore: snapshot.socialScore,
      syncScore: snapshot.syncScore,
      awakeningScore: snapshot.awakeningScore
    })),
    journal: [...journal]
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt))
      .slice(0, 12)
  };
}

export function buildPrivacyPanel({
  userId,
  databaseStatus,
  authorizations = [],
  backups = [],
  counts
}) {
  return {
    route: buildPrivacyRoute(userId),
    database: databaseStatus,
    dataFootprint: counts,
    authorizations: [...authorizations].sort((left, right) => left.resourceKey.localeCompare(right.resourceKey)),
    backups: {
      active: backups.filter((backup) => backup.status === 'active').map((backup) => ({
        ...backup,
        route: buildBackupRoute(backup.id)
      })),
      purged: backups.filter((backup) => backup.status === 'purged').map((backup) => ({
        ...backup,
        route: buildBackupRoute(backup.id)
      }))
    }
  };
}

export function buildProfileRecord(input, currentProfile = {}, nowIso = isoNow()) {
  const merged = {
    ...currentProfile,
    displayName: sanitizeText(input.displayName ?? currentProfile.displayName),
    agentDisplayName: sanitizeText(input.agentDisplayName ?? currentProfile.agentDisplayName),
    headline: sanitizeText(input.headline ?? currentProfile.headline),
    bio: sanitizeText(input.bio ?? currentProfile.bio),
    city: sanitizeText(input.city ?? currentProfile.city),
    occupation: sanitizeText(input.occupation ?? currentProfile.occupation),
    growthFocus: sanitizeText(input.growthFocus ?? currentProfile.growthFocus),
    personaTags:
      Array.isArray(input.personaTags) && input.personaTags.length > 0
        ? uniqueStrings(input.personaTags)
        : uniqueStrings(currentProfile.personaTags ?? []),
    interests:
      Array.isArray(input.interests) && input.interests.length > 0
        ? uniqueStrings(input.interests)
        : uniqueStrings(currentProfile.interests ?? []),
    availabilityNote: sanitizeText(input.availabilityNote ?? currentProfile.availabilityNote),
    updatedAt: nowIso
  };

  for (const fieldKey of ['displayName', 'agentDisplayName', 'headline', 'bio', 'city', 'occupation', 'growthFocus']) {
    if (!sanitizeText(merged[fieldKey])) {
      throw new Error(`Profile field ${fieldKey} is required.`);
    }
  }

  return merged;
}

export function buildPersonaConfigRecord(input, currentConfig = {}, nowIso = isoNow()) {
  return {
    ...currentConfig,
    awakeningSeed: clampScore(input.awakeningSeed ?? currentConfig.awakeningSeed ?? 40, 0, 100),
    growthMode: resolveGrowthMode(input.growthMode ?? currentConfig.growthMode ?? 'steady'),
    dna: normalizePersonaDNA(input.dna ?? {}, currentConfig.dna ?? {}),
    values:
      Array.isArray(input.values) && input.values.length > 0
        ? uniqueStrings(input.values).slice(0, 6)
        : uniqueStrings(currentConfig.values ?? []).slice(0, 6),
    activeMaskId: sanitizeText(input.activeMaskId ?? currentConfig.activeMaskId) || null,
    updatedAt: nowIso
  };
}

export function buildPersonaMasks(userId, masks = [], nowIso = isoNow()) {
  return masks.map((mask, index) => ({
    id: sanitizeText(mask.id) || stableId('my-mask', userId, mask.scenarioKey ?? mask.label ?? `${index}`),
    userId,
    label: sanitizeText(mask.label) || `面具 ${index + 1}`,
    scenarioKey: sanitizeText(mask.scenarioKey) || `scenario_${index + 1}`,
    tone: sanitizeText(mask.tone) || 'steady',
    openness: sanitizeText(mask.openness) || 'medium',
    boundaryTags: uniqueStrings(mask.boundaryTags ?? []),
    styleTags: uniqueStrings(mask.styleTags ?? []),
    isDefault: index === 0 ? mask.isDefault !== false : Boolean(mask.isDefault),
    createdAt: mask.createdAt ?? nowIso,
    updatedAt: nowIso
  }));
}

export function buildMemoryRecord({
  userId,
  memoryId = null,
  existingEntry = null,
  input,
  vaultSecret,
  nowIso = isoNow()
}) {
  const document = normalizeMemoryDocument(input, existingEntry?.document ?? {});
  if (!document.title || !document.content) {
    throw new Error('Memory title and content are required.');
  }

  const id = sanitizeText(memoryId ?? existingEntry?.id) || stableId('my-memory', userId, document.title, nowIso);
  const encrypted = encryptMemoryDocument({
    userId,
    vaultSecret,
    document
  });
  const grants = normalizePrincipalGrants(input.grants ?? existingEntry?.grants ?? []);
  const permissionScope = resolveMemoryScope(input.permissionScope ?? existingEntry?.permissionScope ?? 'private');

  return {
    id,
    userId,
    titleHint: sanitizeText(input.titleHint ?? existingEntry?.titleHint) || defaultMemoryTitleHint(document.memoryKind, id),
    memoryKind: resolveMemoryKind(document.memoryKind),
    permissionScope,
    grants,
    algorithm: encrypted.algorithm,
    iv: encrypted.iv,
    cipherText: encrypted.cipherText,
    authTag: encrypted.authTag,
    checksum: encrypted.checksum,
    createdAt: existingEntry?.createdAt ?? nowIso,
    updatedAt: nowIso,
    lastOpenedAt: existingEntry?.lastOpenedAt ?? null,
    document
  };
}

export function buildAuthorizationRecord({ userId, resourceKey, status, detail, lastPromptedAt = null }, nowIso = isoNow()) {
  const normalizedResource = sanitizeText(resourceKey);
  if (!normalizedResource) {
    throw new Error('resourceKey is required.');
  }
  return {
    userId,
    resourceKey: normalizedResource,
    status: resolveAuthorizationStatus(status, 'prompt'),
    detail: sanitizeText(detail) || '未填写说明',
    lastPromptedAt: sanitizeText(lastPromptedAt) || nowIso,
    updatedAt: nowIso
  };
}
