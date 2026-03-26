import { dirname, resolve } from 'node:path';

import {
  buildAuthorizationRecord,
  buildGrowthReview,
  buildMemoryPalaceSnapshot,
  buildMemoryRecord,
  buildMyBootstrapSeed,
  buildPersonaConfigRecord,
  buildPersonaMasks,
  buildPrivacyPanel,
  buildProfileRecord,
  buildPublicProfile,
  computeGrowthSnapshot,
  decryptMemoryDocument,
  diffGrowthSnapshot,
  evaluateAwakeningState,
  evaluateSyncState
} from '../../Services/My/myDashboardService.mjs';
import {
  buildMemoryRoute,
  buildProfileRoute,
  buildSyncRoute,
  normalizeVisibilityRules,
  resolveAuthorizationStatus,
  resolvePrincipalRole
} from '../Models/myContracts.mjs';
import {
  isoNow,
  sanitizeText,
  stableId
} from '../Models/sceneContracts.mjs';

function buildJournalEntry({ userId, title, body, mood = 'steady', statDelta = {}, nowIso = isoNow() }) {
  return {
    id: stableId('my-journal', userId, title, nowIso),
    userId,
    title,
    body,
    mood,
    statDelta,
    createdAt: nowIso
  };
}

export class MyDashboardExperienceUseCase {
  constructor({ repository, backupDir = null }) {
    this.repository = repository;
    this.backupDir = backupDir ?? resolve(dirname(repository.dbPath), 'my-backups');
  }

  bootstrap(userId) {
    if (this.repository.getProfile(userId)) {
      return;
    }

    const nowIso = isoNow();
    const seed = buildMyBootstrapSeed(userId, nowIso);

    this.repository.upsertProfile(seed.profile, seed.visibility);
    this.repository.upsertTrainingTasks(seed.trainingTasks);
    this.repository.upsertErrorReplays(seed.errorReplays);
    this.repository.upsertPersonaConfig(seed.personaConfig);
    this.repository.replacePersonaMasks(userId, seed.masks);
    for (const authorization of seed.authorizations) {
      this.repository.upsertAuthorization(authorization);
    }

    this.refreshDerivedState(userId, {
      nowIso,
      journalTitle: '初始化我的主页',
      journalBody: '已生成个人资料、同步训练、人格 DNA、记忆权限和本地后端控制基线。'
    });
  }

  collectState(userId) {
    return {
      profile: this.repository.getProfile(userId),
      visibilityRules: this.repository.getVisibilityRules(userId),
      trainingTasks: this.repository.listTrainingTasks(userId),
      errorReplays: this.repository.listErrorReplays(userId),
      personaConfig: this.repository.getPersonaConfig(userId),
      masks: this.repository.listPersonaMasks(userId),
      memories: this.repository.listMemoryEntries(userId),
      authorizations: this.repository.listAuthorizations(userId),
      backups: this.repository.listBackups(userId),
      latestSync: this.repository.latestSyncSnapshot(userId),
      latestGrowth: this.repository.latestGrowthSnapshot(userId)
    };
  }

  refreshDerivedState(
    userId,
    {
      nowIso = isoNow(),
      journalTitle = null,
      journalBody = null,
      journalMood = 'steady'
    } = {}
  ) {
    const state = this.collectState(userId);
    const syncSnapshot = evaluateSyncState({
      profile: state.profile,
      visibilityRules: state.visibilityRules,
      trainingTasks: state.trainingTasks,
      errorReplays: state.errorReplays,
      personaConfig: state.personaConfig,
      masks: state.masks,
      memoryCount: state.memories.length,
      previousScore: state.latestSync?.score ?? null
    });
    const persistedSync = this.repository.insertSyncSnapshot({
      id: stableId('my-sync-snapshot', userId, nowIso, syncSnapshot.score),
      userId,
      score: syncSnapshot.score,
      delta: syncSnapshot.delta,
      band: syncSnapshot.band,
      confidence: syncSnapshot.confidence,
      breakdown: syncSnapshot.breakdown,
      nextActions: syncSnapshot.nextActions,
      createdAt: nowIso
    });

    const awakeningSnapshot = evaluateAwakeningState({
      profile: state.profile,
      personaConfig: state.personaConfig,
      masks: state.masks,
      syncSnapshot: persistedSync,
      trainingTasks: state.trainingTasks,
      errorReplays: state.errorReplays,
      memoryCount: state.memories.length
    });

    const growthSnapshot = computeGrowthSnapshot({
      userId,
      syncSnapshot: persistedSync,
      awakeningSnapshot,
      visibilityRules: state.visibilityRules,
      authorizations: state.authorizations,
      memories: state.memories,
      backups: state.backups.filter((backup) => backup.status === 'active'),
      trainingTasks: state.trainingTasks,
      note: journalTitle ?? '状态刷新'
    });

    const previousGrowth = state.latestGrowth;
    const persistedGrowth = this.repository.insertGrowthSnapshot({
      ...growthSnapshot,
      id: stableId('my-growth-snapshot', userId, nowIso, growthSnapshot.note)
    });

    if (journalTitle && journalBody) {
      this.repository.insertGrowthJournal(
        buildJournalEntry({
          userId,
          title: journalTitle,
          body: journalBody,
          mood: journalMood,
          statDelta: diffGrowthSnapshot(persistedGrowth, previousGrowth),
          nowIso
        })
      );
    }

    return {
      sync: {
        ...syncSnapshot,
        score: persistedSync.score,
        delta: persistedSync.delta,
        confidence: persistedSync.confidence,
        createdAt: persistedSync.createdAt
      },
      awakening: awakeningSnapshot,
      growth: persistedGrowth
    };
  }

  buildHomePayload({
    userId,
    principalKey = 'self_human',
    principalRole = 'owner',
    vaultSecret = null,
    memoryLimit = 4
  }) {
    const state = this.collectState(userId);
    const syncSnapshot = state.latestSync
      ? {
          ...state.latestSync,
          trainingTasks: state.trainingTasks,
          errorReplays: state.errorReplays,
          route: buildSyncRoute(userId)
        }
      : this.refreshDerivedState(userId).sync;

    const awakening = evaluateAwakeningState({
      profile: state.profile,
      personaConfig: state.personaConfig,
      masks: state.masks,
      syncSnapshot,
      trainingTasks: state.trainingTasks,
      errorReplays: state.errorReplays,
      memoryCount: state.memories.length
    });

    const publicProfile = buildPublicProfile({
      profile: state.profile,
      visibilityRules: state.visibilityRules,
      syncSnapshot,
      awakeningSnapshot: awakening,
      activeMask: awakening.activeMask
    });

    const memoryPreview = vaultSecret
      ? buildMemoryPalaceSnapshot({
          userId,
          principalKey,
          principalRole,
          entries: state.memories,
          vaultSecret,
          limit: memoryLimit
        })
      : {
          route: buildMemoryRoute(userId),
          memories: [],
          deniedCount: 0,
          totalStored: state.memories.length
        };

    const privacy = buildPrivacyPanel({
      userId,
      databaseStatus: this.repository.inspectDatabaseStatus(),
      authorizations: state.authorizations,
      backups: state.backups,
      counts: this.repository.inspectMyState(userId).counts
    });

    const growth = buildGrowthReview({
      userId,
      snapshots: this.repository.listGrowthSnapshots(userId, 12),
      journal: this.repository.listGrowthJournal(userId, 8)
    });

    return {
      eventType: 'my_home_ready',
      profile: {
        route: buildProfileRoute(userId),
        privateProfile: state.profile,
        visibilityRules: normalizeVisibilityRules(state.visibilityRules),
        publicProfile
      },
      sync: {
        ...syncSnapshot,
        route: buildSyncRoute(userId)
      },
      persona: {
        route: awakening.route,
        config: state.personaConfig,
        awakening
      },
      memory: memoryPreview,
      growth,
      privacy
    };
  }

  openMyHome(input) {
    this.bootstrap(input.userId);
    return this.buildHomePayload(input);
  }

  updateProfile(input) {
    this.bootstrap(input.userId);
    const currentProfile = this.repository.getProfile(input.userId);
    const profile = buildProfileRecord(
      {
        ...input,
        userId: input.userId
      },
      currentProfile,
      isoNow()
    );
    const visibilityRules = normalizeVisibilityRules({
      ...this.repository.getVisibilityRules(input.userId),
      ...(input.visibility ?? {})
    });
    this.repository.upsertProfile(profile, visibilityRules);
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: '更新个人资料',
      journalBody: '个人资料和分身公开资料已同步更新，可见性控制也已落库。'
    });
    const state = this.collectState(input.userId);
    return {
      eventType: 'my_profile_updated',
      profile: state.profile,
      visibilityRules,
      publicProfile: buildPublicProfile({
        profile: state.profile,
        visibilityRules,
        syncSnapshot: {
          ...derived.sync,
          trainingTasks: state.trainingTasks,
          errorReplays: state.errorReplays
        },
        awakeningSnapshot: derived.awakening,
        activeMask: derived.awakening.activeMask
      }),
      sync: derived.sync
    };
  }

  completeTrainingTask(input) {
    this.bootstrap(input.userId);
    const task = this.repository.findTrainingTask(input.taskId);
    if (!task || task.userId !== input.userId) {
      throw new Error(`Unknown training task: ${input.taskId}`);
    }
    const completed = this.repository.completeTrainingTask(input.taskId, isoNow());
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: `完成训练任务 · ${completed.title}`,
      journalBody: `训练任务“${completed.title}”已闭环，新的同步评分和成长统计已更新。`,
      journalMood: 'focused'
    });
    return {
      eventType: 'my_training_completed',
      task: completed,
      sync: derived.sync,
      awakening: derived.awakening,
      growth: derived.growth
    };
  }

  resolveErrorReplay(input) {
    this.bootstrap(input.userId);
    const replay = this.repository.findErrorReplay(input.replayId);
    if (!replay || replay.userId !== input.userId) {
      throw new Error(`Unknown replay: ${input.replayId}`);
    }
    const resolved = this.repository.resolveErrorReplay(
      input.replayId,
      sanitizeText(input.resolvedNote) || '已完成修复规则确认。',
      isoNow()
    );
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: `修复错误回放 · ${resolved.mismatchType}`,
      journalBody: `错误回放“${resolved.mismatchType}”已经修复并记录结果，新的同步得分已回补。`,
      journalMood: 'relieved'
    });
    return {
      eventType: 'my_replay_resolved',
      replay: resolved,
      sync: derived.sync,
      awakening: derived.awakening,
      growth: derived.growth
    };
  }

  updatePersonaConfig(input) {
    this.bootstrap(input.userId);
    const currentConfig = this.repository.getPersonaConfig(input.userId);
    const currentMasks = this.repository.listPersonaMasks(input.userId);
    const nowIso = isoNow();
    const nextMasks = input.masks?.length ? buildPersonaMasks(input.userId, input.masks, nowIso) : currentMasks;
    const nextConfig = buildPersonaConfigRecord(
      {
        ...input,
        activeMaskId:
          sanitizeText(input.activeMaskId) ||
          currentConfig.activeMaskId ||
          nextMasks.find((mask) => mask.isDefault)?.id ||
          nextMasks[0]?.id ||
          null
      },
      {
        ...currentConfig,
        userId: input.userId
      },
      nowIso
    );
    if (nextMasks.length && !nextMasks.some((mask) => mask.id === nextConfig.activeMaskId)) {
      nextConfig.activeMaskId = nextMasks.find((mask) => mask.isDefault)?.id ?? nextMasks[0].id;
    }

    this.repository.upsertPersonaConfig({
      ...nextConfig,
      userId: input.userId,
      createdAt: currentConfig.createdAt ?? nowIso
    });
    this.repository.replacePersonaMasks(input.userId, nextMasks);
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: '更新人格 DNA',
      journalBody: '觉醒度、人格 DNA 和面具配置已经刷新并回写到成长统计。',
      journalMood: 'energized'
    });
    const state = this.collectState(input.userId);
    return {
      eventType: 'my_persona_updated',
      personaConfig: state.personaConfig,
      masks: state.masks,
      awakening: derived.awakening,
      sync: derived.sync
    };
  }

  saveMemoryEntry(input) {
    this.bootstrap(input.userId);
    const nowIso = isoNow();
    const existing = sanitizeText(input.memoryId) ? this.repository.getMemoryEntry(input.memoryId) : null;
    if (existing && existing.userId !== input.userId) {
      throw new Error(`Unknown memory entry: ${input.memoryId}`);
    }

    const existingWithDocument = existing
      ? {
          ...existing,
          document: decryptMemoryDocument({
            userId: input.userId,
            vaultSecret: input.vaultSecret,
            entry: existing
          })
        }
      : null;
    const record = buildMemoryRecord({
      userId: input.userId,
      memoryId: input.memoryId,
      existingEntry: existingWithDocument,
      input,
      vaultSecret: input.vaultSecret,
      nowIso
    });
    const saved = this.repository.saveMemoryEntry(record);
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: existing ? '编辑记忆宫殿' : '新增记忆宫殿',
      journalBody: existing
        ? '已有记忆已完成修订，权限与加密内容都已更新。'
        : '新的分身记忆已加密写入本地宫殿，并同步进入成长统计。',
      journalMood: 'reflective'
    });
    return {
      eventType: existing ? 'my_memory_updated' : 'my_memory_saved',
      memory: buildMemoryPalaceSnapshot({
        userId: input.userId,
        principalKey: 'self_human',
        principalRole: 'owner',
        entries: [saved],
        vaultSecret: input.vaultSecret,
        limit: 1
      }).memories[0],
      sync: derived.sync,
      growth: derived.growth
    };
  }

  listMemoryPalace(input) {
    this.bootstrap(input.userId);
    const principalRole = resolvePrincipalRole(input.principalRole, 'owner');
    const snapshot = buildMemoryPalaceSnapshot({
      userId: input.userId,
      principalKey: input.principalKey ?? input.userId,
      principalRole,
      entries: this.repository.listMemoryEntries(input.userId),
      vaultSecret: input.vaultSecret,
      query: input.query,
      limit: input.limit
    });

    for (const memory of snapshot.memories) {
      this.repository.touchMemory(memory.id, isoNow());
    }

    return {
      eventType: 'my_memory_palace_ready',
      ...snapshot
    };
  }

  recordGrowthJournal(input) {
    this.bootstrap(input.userId);
    const latest = this.repository.latestGrowthSnapshot(input.userId);
    const previous = this.repository.listGrowthSnapshots(input.userId, 2)[1] ?? null;
    const entry = buildJournalEntry({
      userId: input.userId,
      title: input.title,
      body: input.body,
      mood: sanitizeText(input.mood) || 'steady',
      statDelta:
        input.statDelta && Object.keys(input.statDelta).length > 0
          ? input.statDelta
          : diffGrowthSnapshot(latest, previous)
    });
    this.repository.insertGrowthJournal(entry);
    return {
      eventType: 'my_growth_journal_recorded',
      entry,
      review: buildGrowthReview({
        userId: input.userId,
        snapshots: this.repository.listGrowthSnapshots(input.userId, input.limit ?? 12),
        journal: this.repository.listGrowthJournal(input.userId, 12)
      })
    };
  }

  openGrowthReview(input) {
    this.bootstrap(input.userId);
    return {
      eventType: 'my_growth_review_ready',
      review: buildGrowthReview({
        userId: input.userId,
        snapshots: this.repository.listGrowthSnapshots(input.userId, input.limit ?? 12),
        journal: this.repository.listGrowthJournal(input.userId, 12)
      })
    };
  }

  updateAuthorization(input) {
    this.bootstrap(input.userId);
    const record = buildAuthorizationRecord(
      {
        userId: input.userId,
        resourceKey: input.resourceKey,
        status: resolveAuthorizationStatus(input.status, 'prompt'),
        detail: input.detail,
        lastPromptedAt: input.lastPromptedAt
      },
      isoNow()
    );
    const updated = this.repository.upsertAuthorization(record);
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: `更新授权 · ${updated.resourceKey}`,
      journalBody: `权限“${updated.resourceKey}”已更新为 ${updated.status}，隐私控制面板已同步刷新。`,
      journalMood: 'cautious'
    });
    return {
      eventType: 'my_authorization_updated',
      authorization: updated,
      privacy: this.openPrivacyCenter({ userId: input.userId }).privacy,
      growth: derived.growth
    };
  }

  createLocalBackup(input) {
    this.bootstrap(input.userId);
    const backup = this.repository.createBackup({
      userId: input.userId,
      label: sanitizeText(input.label) || 'manual',
      backupDir: this.backupDir,
      nowIso: isoNow()
    });
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: '创建本地备份',
      journalBody: `SQLite 已通过 VACUUM INTO 生成本地备份“${backup.label}”。`,
      journalMood: 'careful'
    });
    return {
      eventType: 'my_backup_created',
      backup,
      privacy: this.openPrivacyCenter({ userId: input.userId }).privacy,
      growth: derived.growth
    };
  }

  cleanupLocalBackups(input) {
    this.bootstrap(input.userId);
    const cleanup = this.repository.cleanupBackups({
      userId: input.userId,
      keepLatest: input.keepLatest,
      nowIso: isoNow()
    });
    const derived = this.refreshDerivedState(input.userId, {
      journalTitle: '清理本地备份',
      journalBody: `已保留最近 ${Math.max(0, Number(input.keepLatest ?? 1))} 份备份，并清理过期备份文件。`,
      journalMood: 'tidy'
    });
    return {
      eventType: 'my_backup_cleanup_completed',
      cleanup,
      privacy: this.openPrivacyCenter({ userId: input.userId }).privacy,
      growth: derived.growth
    };
  }

  openPrivacyCenter(input) {
    this.bootstrap(input.userId);
    return {
      eventType: 'my_privacy_center_ready',
      privacy: buildPrivacyPanel({
        userId: input.userId,
        databaseStatus: this.repository.inspectDatabaseStatus(),
        authorizations: this.repository.listAuthorizations(input.userId),
        backups: this.repository.listBackups(input.userId),
        counts: this.repository.inspectMyState(input.userId).counts
      })
    };
  }

  inspectMyState(input) {
    this.bootstrap(input.userId);
    return this.repository.inspectMyState(input.userId);
  }
}
