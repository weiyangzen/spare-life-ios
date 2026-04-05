import { existsSync, rmSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { createMyDashboardRuntime } from '../handlers/myDashboardHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    'backup-dir': { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-my-dashboard.sqlite'));
const backupDir = resolve(args.values['backup-dir'] ?? join(tmpdir(), 'spare-life-my-dashboard-backups'));

if (args.values.reset && existsSync(dbPath)) {
  unlinkSync(dbPath);
}
if (args.values.reset && existsSync(backupDir)) {
  rmSync(backupDir, { recursive: true, force: true });
}

const runtime = createMyDashboardRuntime({
  dbPath,
  backupDir
});
const userId = 'demo-user';
const vaultSecret = 'demo-vault-secret';

try {
  const initialHome = runtime.openMyHome({
    userId,
    principalKey: 'self_human',
    principalRole: 'owner',
    vaultSecret
  });
  const initialSyncScore = initialHome.sync.score;

  const profileUpdate = runtime.updateProfile({
    userId,
    displayName: '林闻',
    agentDisplayName: '闻闻分身',
    headline: '把焦虑拆成计划，把记忆炼成可信分身',
    growthFocus: '让分身先学会识别边界，再学会替我出面',
    city: '上海',
    occupation: 'AI 产品探索者',
    personaTags: ['稳', '会复盘', '会接住情绪'],
    visibility: {
      displayName: 'public',
      agentDisplayName: 'public',
      headline: 'public',
      growthFocus: 'public',
      personaTags: 'public',
      bio: 'private',
      city: 'trusted_circle'
    }
  });

  const firstTask = initialHome.sync.trainingTasks[0];
  const secondTask = initialHome.sync.trainingTasks[1];
  const firstReplay = initialHome.sync.errorReplays[0];

  const completedVoice = runtime.completeTrainingTask({
    userId,
    taskId: firstTask.id
  });
  const completedBoundary = runtime.completeTrainingTask({
    userId,
    taskId: secondTask.id
  });
  const resolvedReplay = runtime.resolveErrorReplay({
    userId,
    replayId: firstReplay.id,
    resolvedNote: '统一改成先给安全替代方案，再请求人工确认。'
  });

  const personaUpdate = runtime.updatePersonaConfig({
    userId,
    growthMode: 'resonant',
    awakeningSeed: 58,
    activeMaskId: 'career_mask',
    dna: {
      warmth: 68,
      curiosity: 86,
      directness: 74,
      playfulness: 52,
      steadiness: 88
    },
    values: ['真实', '边界', '长期主义', '对齐后再承诺'],
    masks: [
      {
        id: 'career_mask',
        label: '职业出面',
        scenarioKey: 'career_mode',
        tone: 'calm_confident',
        openness: 'medium',
        boundaryTags: ['不夸大经历', '先确认交付边界'],
        styleTags: ['利落', '有温度', '不画饼'],
        isDefault: true
      },
      {
        label: '熟人深聊',
        scenarioKey: 'trusted_circle',
        tone: 'soft_direct',
        openness: 'high',
        boundaryTags: ['先接住情绪', '避免替对方做决定'],
        styleTags: ['会追问', '不装懂', '有陪伴感']
      }
    ]
  });

  const privateMemory = runtime.saveMemoryEntry({
    userId,
    vaultSecret,
    title: '现金流底线',
    summary: '接下来 90 天不能做高风险决定。',
    content: '当前现金流只够 90 天，所以任何转岗动作都要先保留兜底方案。',
    memoryKind: 'constraint',
    permissionScope: 'private',
    emotion: 'anxious',
    source: 'weekly_review',
    tags: ['现金流', '转岗', '约束']
  });

  const sharedMemory = runtime.saveMemoryEntry({
    userId,
    vaultSecret,
    title: 'AI side project 首战复盘',
    summary: '第一次把假设写成可验证实验。',
    content: '第一次把假设写成可验证实验，并留下了失败条件、数据口径和下一轮迭代触发器。',
    memoryKind: 'story',
    permissionScope: 'agent_shared',
    emotion: 'grounded',
    source: 'project_retro',
    tags: ['AI 产品', '实验', '复盘'],
    grants: ['self_agent']
  });

  const editedSharedMemory = runtime.saveMemoryEntry({
    userId,
    memoryId: sharedMemory.memory.id,
    vaultSecret,
    title: 'AI side project 首战复盘',
    summary: '第一次把假设写成可验证实验，并沉淀了模板。',
    content: '第一次把假设写成可验证实验，并沉淀了模板：先写用户信号，再写失败阈值，最后写复盘问题。',
    memoryKind: 'story',
    permissionScope: 'agent_shared',
    emotion: 'grounded',
    source: 'project_retro',
    tags: ['AI 产品', '实验', '模板'],
    grants: ['self_agent']
  });

  const ownerMemories = runtime.listMemoryPalace({
    userId,
    vaultSecret,
    principalKey: 'self_human',
    principalRole: 'owner'
  });
  const agentMemories = runtime.listMemoryPalace({
    userId,
    vaultSecret,
    principalKey: 'self_agent',
    principalRole: 'agent'
  });
  const publicMemories = runtime.listMemoryPalace({
    userId,
    vaultSecret,
    principalKey: 'public_guest',
    principalRole: 'public'
  });

  const growthJournal = runtime.recordGrowthJournal({
    userId,
    title: '第一次完整自我训练闭环',
    body: '资料、训练、人格和记忆都已经连成一条线，接下来要继续压缩错误回放。',
    mood: 'hopeful'
  });
  const growthReview = runtime.openGrowthReview({
    userId,
    limit: 16
  });

  const updatedAuthorization = runtime.updateAuthorization({
    userId,
    resourceKey: 'contacts',
    status: 'authorized',
    detail: '允许分身读取熟人关系与面具上下文'
  });
  const backupOne = runtime.createLocalBackup({
    userId,
    label: 'after-persona-tuning'
  });
  const backupTwo = runtime.createLocalBackup({
    userId,
    label: 'after-memory-palace'
  });
  const backupCleanup = runtime.cleanupLocalBackups({
    userId,
    keepLatest: 1
  });
  const privacyCenter = runtime.openPrivacyCenter({
    userId
  });

  const finalHome = runtime.openMyHome({
    userId,
    principalKey: 'self_human',
    principalRole: 'owner',
    vaultSecret
  });
  const state = runtime.inspectMyState({
    userId
  });

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          backupDir,
          publicProfileFields: Object.keys(profileUpdate.publicProfile.profile),
          publicProfileHidesBio: !Object.prototype.hasOwnProperty.call(profileUpdate.publicProfile.profile, 'bio'),
          syncScoreBefore: initialSyncScore,
          syncScoreAfter: finalHome.sync.score,
          syncScoreImproved: finalHome.sync.score > initialSyncScore,
          completedTrainingCount: finalHome.sync.trainingTasks.filter((task) => task.status === 'completed').length,
          resolvedReplayCount: finalHome.sync.errorReplays.filter((replay) => replay.status === 'resolved').length,
          awakeningStage: finalHome.persona.awakening.stage,
          awakeningScore: finalHome.persona.awakening.score,
          activeMask: finalHome.persona.awakening.activeMask?.label ?? null,
          ownerMemoryCount: ownerMemories.memories.length,
          agentMemoryCount: agentMemories.memories.length,
          publicMemoryCount: publicMemories.memories.length,
          editedSharedMemoryTags: editedSharedMemory.memory.tags,
          encryptedStorageOpaque: !state.rawMemoryStorage.some((entry) =>
            entry.cipherTextPreview.includes('现金流') || entry.cipherTextPreview.includes('side project')
          ),
          growthChartPoints: growthReview.review.chart.length,
          journalCount: growthReview.review.journal.length,
          latestIdleEnergy: growthReview.review.latest?.idleEnergy ?? null,
          latestSocialScore: growthReview.review.latest?.socialScore ?? null,
          contactsAuthorization: privacyCenter.privacy.authorizations.find((item) => item.resourceKey === 'contacts')?.status ?? null,
          activeBackupCount: privacyCenter.privacy.backups.active.length,
          purgedBackupCount: privacyCenter.privacy.backups.purged.length,
          latestBackupLabel: privacyCenter.privacy.backups.active[0]?.label ?? null,
          dbTableCount: privacyCenter.privacy.database.tableCount,
          dbPageCount: privacyCenter.privacy.database.pageCount,
          profileRoute: finalHome.profile.route,
          syncRoute: finalHome.sync.route,
          memoryRoute: ownerMemories.route,
          growthRoute: growthReview.review.route,
          privacyRoute: privacyCenter.privacy.route
        },
        initialHome,
        profileUpdate,
        completedVoice,
        completedBoundary,
        resolvedReplay,
        personaUpdate,
        privateMemory,
        sharedMemory,
        editedSharedMemory,
        ownerMemories,
        agentMemories,
        publicMemories,
        growthJournal,
        growthReview,
        updatedAuthorization,
        backupOne,
        backupTwo,
        backupCleanup,
        privacyCenter,
        finalHome,
        state
      },
      null,
      2
    )
  );
} finally {
  runtime.close();
}
