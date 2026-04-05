import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  unlinkSync
} from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import {
  fromJson,
  isoNow,
  stableId,
  toJson
} from '../../Domain/Models/sceneContracts.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationPath = resolve(__dirname, '../Migrations/005_my_dashboard.sql');

function sha1File(path) {
  return createHash('sha1').update(readFileSync(path)).digest('hex');
}

function escapeSqlString(value) {
  return `${value}`.replace(/'/g, "''");
}

function parseProfileRow(row) {
  if (!row) {
    return null;
  }
  return {
    userId: row.user_id,
    displayName: row.display_name,
    agentDisplayName: row.agent_display_name,
    headline: row.headline,
    bio: row.bio,
    city: row.city,
    occupation: row.occupation,
    growthFocus: row.growth_focus,
    personaTags: fromJson(row.persona_tags_json, []),
    interests: fromJson(row.interests_json, []),
    availabilityNote: row.availability_note,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseVisibilityRows(rows = []) {
  return Object.fromEntries(rows.map((row) => [row.field_key, row.visibility_level]));
}

function parseTrainingRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    focusArea: row.focus_area,
    targetBehavior: row.target_behavior,
    difficulty: Number(row.difficulty),
    status: row.status,
    progress: Number(row.progress),
    dueAt: row.due_at,
    completedAt: row.completed_at,
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseReplayRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    sourceChannel: row.source_channel,
    mismatchType: row.mismatch_type,
    severity: row.severity,
    transcript: fromJson(row.transcript_json, []),
    diagnosis: row.diagnosis,
    repairBrief: row.repair_brief,
    status: row.status,
    resolvedNote: row.resolved_note,
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parsePersonaConfigRow(row) {
  if (!row) {
    return null;
  }
  return {
    userId: row.user_id,
    awakeningSeed: Number(row.awakening_seed),
    growthMode: row.growth_mode,
    dna: fromJson(row.dna_json, {}),
    values: fromJson(row.values_json, []),
    activeMaskId: row.active_mask_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseMaskRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    label: row.label,
    scenarioKey: row.scenario_key,
    tone: row.tone,
    openness: row.openness,
    boundaryTags: fromJson(row.boundary_tags_json, []),
    styleTags: fromJson(row.style_tags_json, []),
    isDefault: Boolean(row.is_default),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseMemoryRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    titleHint: row.title_hint,
    memoryKind: row.memory_kind,
    permissionScope: row.permission_scope,
    grants: fromJson(row.grants_json, []),
    algorithm: row.cipher_algorithm,
    iv: row.cipher_iv,
    cipherText: row.cipher_text,
    authTag: row.auth_tag,
    checksum: row.checksum,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    lastOpenedAt: row.last_opened_at
  };
}

function parseSyncSnapshotRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    score: Number(row.score),
    delta: Number(row.delta),
    band: row.band,
    confidence: Number(row.confidence),
    breakdown: fromJson(row.breakdown_json, {}),
    nextActions: fromJson(row.next_actions_json, []),
    createdAt: row.created_at
  };
}

function parseGrowthSnapshotRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    idleEnergy: Number(row.idle_energy),
    socialScore: Number(row.social_score),
    syncScore: Number(row.sync_score),
    awakeningScore: Number(row.awakening_score),
    memoryCount: Number(row.memory_count),
    activeBackups: Number(row.active_backups),
    note: row.note,
    createdAt: row.created_at
  };
}

function parseJournalRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    body: row.body,
    mood: row.mood,
    statDelta: fromJson(row.stat_delta_json, {}),
    createdAt: row.created_at
  };
}

function parseAuthorizationRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    resourceKey: row.resource_key,
    status: row.status,
    detail: row.detail,
    lastPromptedAt: row.last_prompted_at,
    updatedAt: row.updated_at
  };
}

function parseBackupRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    label: row.label,
    filePath: row.file_path,
    fileSizeBytes: Number(row.file_size_bytes),
    checksum: row.checksum,
    status: row.status,
    createdAt: row.created_at,
    purgedAt: row.purged_at
  };
}

export class MyDashboardRepository {
  constructor(dbPath) {
    mkdirSync(dirname(dbPath), { recursive: true });
    this.dbPath = dbPath;
    this.db = new DatabaseSync(dbPath);
    this.schemaReady = false;
    this.ensureSchema();
  }

  ensureSchema() {
    if (this.schemaReady) {
      return;
    }
    this.db.exec(readFileSync(migrationPath, 'utf8'));
    this.schemaReady = true;
  }

  close() {
    this.db.close();
  }

  withTransaction(work) {
    this.db.exec('BEGIN');
    try {
      const result = work();
      this.db.exec('COMMIT');
      return result;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  getProfile(userId) {
    return parseProfileRow(this.db.prepare('SELECT * FROM my_profiles WHERE user_id = ?').get(userId));
  }

  upsertProfile(profile, visibilityRules) {
    this.withTransaction(() => {
      this.db
        .prepare(
          `INSERT INTO my_profiles (
            user_id, display_name, agent_display_name, headline, bio, city, occupation,
            growth_focus, persona_tags_json, interests_json, availability_note, created_at, updated_at
          ) VALUES (
            @user_id, @display_name, @agent_display_name, @headline, @bio, @city, @occupation,
            @growth_focus, @persona_tags_json, @interests_json, @availability_note, @created_at, @updated_at
          )
          ON CONFLICT(user_id) DO UPDATE SET
            display_name = excluded.display_name,
            agent_display_name = excluded.agent_display_name,
            headline = excluded.headline,
            bio = excluded.bio,
            city = excluded.city,
            occupation = excluded.occupation,
            growth_focus = excluded.growth_focus,
            persona_tags_json = excluded.persona_tags_json,
            interests_json = excluded.interests_json,
            availability_note = excluded.availability_note,
            updated_at = excluded.updated_at`
        )
        .run({
          user_id: profile.userId,
          display_name: profile.displayName,
          agent_display_name: profile.agentDisplayName,
          headline: profile.headline,
          bio: profile.bio,
          city: profile.city,
          occupation: profile.occupation,
          growth_focus: profile.growthFocus,
          persona_tags_json: toJson(profile.personaTags),
          interests_json: toJson(profile.interests),
          availability_note: profile.availabilityNote,
          created_at: profile.createdAt,
          updated_at: profile.updatedAt
        });

      const upsertVisibility = this.db.prepare(
        `INSERT INTO my_profile_visibility_rules (
          user_id, field_key, visibility_level, updated_at
        ) VALUES (
          @user_id, @field_key, @visibility_level, @updated_at
        )
        ON CONFLICT(user_id, field_key) DO UPDATE SET
          visibility_level = excluded.visibility_level,
          updated_at = excluded.updated_at`
      );

      for (const [fieldKey, visibility] of Object.entries(visibilityRules)) {
        upsertVisibility.run({
          user_id: profile.userId,
          field_key: fieldKey,
          visibility_level: visibility,
          updated_at: profile.updatedAt
        });
      }
    });

    return this.getProfile(profile.userId);
  }

  getVisibilityRules(userId) {
    return parseVisibilityRows(
      this.db
        .prepare('SELECT * FROM my_profile_visibility_rules WHERE user_id = ? ORDER BY field_key ASC')
        .all(userId)
    );
  }

  upsertTrainingTasks(tasks = []) {
    const statement = this.db.prepare(
      `INSERT INTO my_training_tasks (
        id, user_id, title, focus_area, target_behavior, difficulty, status, progress,
        due_at, completed_at, route, created_at, updated_at
      ) VALUES (
        @id, @user_id, @title, @focus_area, @target_behavior, @difficulty, @status, @progress,
        @due_at, @completed_at, @route, @created_at, @updated_at
      )
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        focus_area = excluded.focus_area,
        target_behavior = excluded.target_behavior,
        difficulty = excluded.difficulty,
        status = excluded.status,
        progress = excluded.progress,
        due_at = excluded.due_at,
        completed_at = excluded.completed_at,
        route = excluded.route,
        updated_at = excluded.updated_at`
    );

    this.withTransaction(() => {
      for (const task of tasks) {
        statement.run({
          id: task.id,
          user_id: task.userId,
          title: task.title,
          focus_area: task.focusArea,
          target_behavior: task.targetBehavior,
          difficulty: task.difficulty,
          status: task.status,
          progress: task.progress,
          due_at: task.dueAt,
          completed_at: task.completedAt,
          route: task.route,
          created_at: task.createdAt,
          updated_at: task.updatedAt
        });
      }
    });
  }

  findTrainingTask(taskId) {
    return parseTrainingRow(this.db.prepare('SELECT * FROM my_training_tasks WHERE id = ?').get(taskId));
  }

  listTrainingTasks(userId) {
    return this.db
      .prepare('SELECT * FROM my_training_tasks WHERE user_id = ? ORDER BY updated_at DESC, created_at DESC')
      .all(userId)
      .map(parseTrainingRow);
  }

  completeTrainingTask(taskId, nowIso = isoNow()) {
    this.db
      .prepare(
        `UPDATE my_training_tasks
         SET status = 'completed',
             progress = 1,
             completed_at = ?,
             updated_at = ?
         WHERE id = ?`
      )
      .run(nowIso, nowIso, taskId);
    return this.findTrainingTask(taskId);
  }

  upsertErrorReplays(replays = []) {
    const statement = this.db.prepare(
      `INSERT INTO my_error_replays (
        id, user_id, source_channel, mismatch_type, severity, transcript_json, diagnosis,
        repair_brief, status, resolved_note, route, created_at, updated_at
      ) VALUES (
        @id, @user_id, @source_channel, @mismatch_type, @severity, @transcript_json, @diagnosis,
        @repair_brief, @status, @resolved_note, @route, @created_at, @updated_at
      )
      ON CONFLICT(id) DO UPDATE SET
        source_channel = excluded.source_channel,
        mismatch_type = excluded.mismatch_type,
        severity = excluded.severity,
        transcript_json = excluded.transcript_json,
        diagnosis = excluded.diagnosis,
        repair_brief = excluded.repair_brief,
        status = excluded.status,
        resolved_note = excluded.resolved_note,
        route = excluded.route,
        updated_at = excluded.updated_at`
    );

    this.withTransaction(() => {
      for (const replay of replays) {
        statement.run({
          id: replay.id,
          user_id: replay.userId,
          source_channel: replay.sourceChannel,
          mismatch_type: replay.mismatchType,
          severity: replay.severity,
          transcript_json: toJson(replay.transcript),
          diagnosis: replay.diagnosis,
          repair_brief: replay.repairBrief,
          status: replay.status,
          resolved_note: replay.resolvedNote,
          route: replay.route,
          created_at: replay.createdAt,
          updated_at: replay.updatedAt
        });
      }
    });
  }

  findErrorReplay(replayId) {
    return parseReplayRow(this.db.prepare('SELECT * FROM my_error_replays WHERE id = ?').get(replayId));
  }

  listErrorReplays(userId) {
    return this.db
      .prepare('SELECT * FROM my_error_replays WHERE user_id = ? ORDER BY updated_at DESC, created_at DESC')
      .all(userId)
      .map(parseReplayRow);
  }

  resolveErrorReplay(replayId, resolvedNote, nowIso = isoNow()) {
    this.db
      .prepare(
        `UPDATE my_error_replays
         SET status = 'resolved',
             resolved_note = ?,
             updated_at = ?
         WHERE id = ?`
      )
      .run(resolvedNote, nowIso, replayId);
    return this.findErrorReplay(replayId);
  }

  upsertPersonaConfig(config) {
    this.db
      .prepare(
        `INSERT INTO my_persona_configs (
          user_id, awakening_seed, growth_mode, dna_json, values_json, active_mask_id, created_at, updated_at
        ) VALUES (
          @user_id, @awakening_seed, @growth_mode, @dna_json, @values_json, @active_mask_id, @created_at, @updated_at
        )
        ON CONFLICT(user_id) DO UPDATE SET
          awakening_seed = excluded.awakening_seed,
          growth_mode = excluded.growth_mode,
          dna_json = excluded.dna_json,
          values_json = excluded.values_json,
          active_mask_id = excluded.active_mask_id,
          updated_at = excluded.updated_at`
      )
      .run({
        user_id: config.userId,
        awakening_seed: config.awakeningSeed,
        growth_mode: config.growthMode,
        dna_json: toJson(config.dna),
        values_json: toJson(config.values),
        active_mask_id: config.activeMaskId,
        created_at: config.createdAt,
        updated_at: config.updatedAt
      });
    return this.getPersonaConfig(config.userId);
  }

  getPersonaConfig(userId) {
    return parsePersonaConfigRow(this.db.prepare('SELECT * FROM my_persona_configs WHERE user_id = ?').get(userId));
  }

  replacePersonaMasks(userId, masks = []) {
    this.withTransaction(() => {
      this.db.prepare('DELETE FROM my_persona_masks WHERE user_id = ?').run(userId);
      const insertMask = this.db.prepare(
        `INSERT INTO my_persona_masks (
          id, user_id, label, scenario_key, tone, openness, boundary_tags_json, style_tags_json,
          is_default, created_at, updated_at
        ) VALUES (
          @id, @user_id, @label, @scenario_key, @tone, @openness, @boundary_tags_json, @style_tags_json,
          @is_default, @created_at, @updated_at
        )`
      );
      for (const mask of masks) {
        insertMask.run({
          id: mask.id,
          user_id: mask.userId,
          label: mask.label,
          scenario_key: mask.scenarioKey,
          tone: mask.tone,
          openness: mask.openness,
          boundary_tags_json: toJson(mask.boundaryTags),
          style_tags_json: toJson(mask.styleTags),
          is_default: mask.isDefault ? 1 : 0,
          created_at: mask.createdAt,
          updated_at: mask.updatedAt
        });
      }
    });
    return this.listPersonaMasks(userId);
  }

  listPersonaMasks(userId) {
    return this.db
      .prepare('SELECT * FROM my_persona_masks WHERE user_id = ? ORDER BY is_default DESC, updated_at DESC')
      .all(userId)
      .map(parseMaskRow);
  }

  saveMemoryEntry(entry) {
    this.db
      .prepare(
        `INSERT INTO my_memory_entries (
          id, user_id, title_hint, memory_kind, permission_scope, grants_json, cipher_algorithm,
          cipher_iv, cipher_text, auth_tag, checksum, created_at, updated_at, last_opened_at
        ) VALUES (
          @id, @user_id, @title_hint, @memory_kind, @permission_scope, @grants_json, @cipher_algorithm,
          @cipher_iv, @cipher_text, @auth_tag, @checksum, @created_at, @updated_at, @last_opened_at
        )
        ON CONFLICT(id) DO UPDATE SET
          title_hint = excluded.title_hint,
          memory_kind = excluded.memory_kind,
          permission_scope = excluded.permission_scope,
          grants_json = excluded.grants_json,
          cipher_algorithm = excluded.cipher_algorithm,
          cipher_iv = excluded.cipher_iv,
          cipher_text = excluded.cipher_text,
          auth_tag = excluded.auth_tag,
          checksum = excluded.checksum,
          updated_at = excluded.updated_at,
          last_opened_at = excluded.last_opened_at`
      )
      .run({
        id: entry.id,
        user_id: entry.userId,
        title_hint: entry.titleHint,
        memory_kind: entry.memoryKind,
        permission_scope: entry.permissionScope,
        grants_json: toJson(entry.grants),
        cipher_algorithm: entry.algorithm,
        cipher_iv: entry.iv,
        cipher_text: entry.cipherText,
        auth_tag: entry.authTag,
        checksum: entry.checksum,
        created_at: entry.createdAt,
        updated_at: entry.updatedAt,
        last_opened_at: entry.lastOpenedAt
      });
    return this.getMemoryEntry(entry.id);
  }

  getMemoryEntry(memoryId) {
    return parseMemoryRow(this.db.prepare('SELECT * FROM my_memory_entries WHERE id = ?').get(memoryId));
  }

  listMemoryEntries(userId) {
    return this.db
      .prepare('SELECT * FROM my_memory_entries WHERE user_id = ? ORDER BY updated_at DESC, created_at DESC')
      .all(userId)
      .map(parseMemoryRow);
  }

  touchMemory(memoryId, nowIso = isoNow()) {
    this.db.prepare('UPDATE my_memory_entries SET last_opened_at = ? WHERE id = ?').run(nowIso, memoryId);
  }

  insertSyncSnapshot(snapshot) {
    this.db
      .prepare(
        `INSERT INTO my_sync_snapshots (
          id, user_id, score, delta, band, confidence, breakdown_json, next_actions_json, created_at
        ) VALUES (
          @id, @user_id, @score, @delta, @band, @confidence, @breakdown_json, @next_actions_json, @created_at
        )`
      )
      .run({
        id: snapshot.id,
        user_id: snapshot.userId,
        score: snapshot.score,
        delta: snapshot.delta,
        band: snapshot.band,
        confidence: snapshot.confidence,
        breakdown_json: toJson(snapshot.breakdown),
        next_actions_json: toJson(snapshot.nextActions),
        created_at: snapshot.createdAt
      });
    return this.latestSyncSnapshot(snapshot.userId);
  }

  latestSyncSnapshot(userId) {
    return parseSyncSnapshotRow(
      this.db
        .prepare('SELECT * FROM my_sync_snapshots WHERE user_id = ? ORDER BY created_at DESC LIMIT 1')
        .get(userId)
    );
  }

  insertGrowthSnapshot(snapshot) {
    this.db
      .prepare(
        `INSERT INTO my_growth_snapshots (
          id, user_id, idle_energy, social_score, sync_score, awakening_score, memory_count,
          active_backups, note, created_at
        ) VALUES (
          @id, @user_id, @idle_energy, @social_score, @sync_score, @awakening_score, @memory_count,
          @active_backups, @note, @created_at
        )`
      )
      .run({
        id: snapshot.id,
        user_id: snapshot.userId,
        idle_energy: snapshot.idleEnergy,
        social_score: snapshot.socialScore,
        sync_score: snapshot.syncScore,
        awakening_score: snapshot.awakeningScore,
        memory_count: snapshot.memoryCount,
        active_backups: snapshot.activeBackups,
        note: snapshot.note,
        created_at: snapshot.createdAt
      });
    return this.latestGrowthSnapshot(snapshot.userId);
  }

  latestGrowthSnapshot(userId) {
    return parseGrowthSnapshotRow(
      this.db
        .prepare('SELECT * FROM my_growth_snapshots WHERE user_id = ? ORDER BY created_at DESC LIMIT 1')
        .get(userId)
    );
  }

  listGrowthSnapshots(userId, limit = 24) {
    return this.db
      .prepare('SELECT * FROM my_growth_snapshots WHERE user_id = ? ORDER BY created_at DESC LIMIT ?')
      .all(userId, limit)
      .map(parseGrowthSnapshotRow);
  }

  insertGrowthJournal(entry) {
    this.db
      .prepare(
        `INSERT INTO my_growth_journal (
          id, user_id, title, body, mood, stat_delta_json, created_at
        ) VALUES (
          @id, @user_id, @title, @body, @mood, @stat_delta_json, @created_at
        )`
      )
      .run({
        id: entry.id,
        user_id: entry.userId,
        title: entry.title,
        body: entry.body,
        mood: entry.mood,
        stat_delta_json: toJson(entry.statDelta),
        created_at: entry.createdAt
      });
    return entry;
  }

  listGrowthJournal(userId, limit = 18) {
    return this.db
      .prepare('SELECT * FROM my_growth_journal WHERE user_id = ? ORDER BY created_at DESC LIMIT ?')
      .all(userId, limit)
      .map(parseJournalRow);
  }

  upsertAuthorization(record) {
    const id = stableId('my-auth', record.userId, record.resourceKey);
    this.db
      .prepare(
        `INSERT INTO my_authorizations (
          id, user_id, resource_key, status, detail, last_prompted_at, updated_at
        ) VALUES (
          @id, @user_id, @resource_key, @status, @detail, @last_prompted_at, @updated_at
        )
        ON CONFLICT(user_id, resource_key) DO UPDATE SET
          status = excluded.status,
          detail = excluded.detail,
          last_prompted_at = excluded.last_prompted_at,
          updated_at = excluded.updated_at`
      )
      .run({
        id,
        user_id: record.userId,
        resource_key: record.resourceKey,
        status: record.status,
        detail: record.detail,
        last_prompted_at: record.lastPromptedAt,
        updated_at: record.updatedAt
      });
    return this.getAuthorization(record.userId, record.resourceKey);
  }

  getAuthorization(userId, resourceKey) {
    return parseAuthorizationRow(
      this.db
        .prepare('SELECT * FROM my_authorizations WHERE user_id = ? AND resource_key = ?')
        .get(userId, resourceKey)
    );
  }

  listAuthorizations(userId) {
    return this.db
      .prepare('SELECT * FROM my_authorizations WHERE user_id = ? ORDER BY resource_key ASC')
      .all(userId)
      .map(parseAuthorizationRow);
  }

  createBackup({ userId, label = 'manual', backupDir, nowIso = isoNow() }) {
    mkdirSync(backupDir, { recursive: true });
    const backupId = stableId('my-backup', userId, label, nowIso);
    const backupPath = resolve(backupDir, `${backupId}.sqlite`);
    if (existsSync(backupPath)) {
      unlinkSync(backupPath);
    }
    this.db.exec(`VACUUM INTO '${escapeSqlString(backupPath)}'`);
    const stats = statSync(backupPath);
    const record = {
      id: backupId,
      userId,
      label,
      filePath: backupPath,
      fileSizeBytes: stats.size,
      checksum: sha1File(backupPath),
      status: 'active',
      createdAt: nowIso,
      purgedAt: null
    };

    this.db
      .prepare(
        `INSERT INTO my_local_backups (
          id, user_id, label, file_path, file_size_bytes, checksum, status, created_at, purged_at
        ) VALUES (
          @id, @user_id, @label, @file_path, @file_size_bytes, @checksum, @status, @created_at, @purged_at
        )`
      )
      .run({
        id: record.id,
        user_id: record.userId,
        label: record.label,
        file_path: record.filePath,
        file_size_bytes: record.fileSizeBytes,
        checksum: record.checksum,
        status: record.status,
        created_at: record.createdAt,
        purged_at: record.purgedAt
      });
    return record;
  }

  listBackups(userId) {
    return this.db
      .prepare('SELECT * FROM my_local_backups WHERE user_id = ? ORDER BY created_at DESC')
      .all(userId)
      .map(parseBackupRow);
  }

  cleanupBackups({ userId, keepLatest = 1, nowIso = isoNow() }) {
    const backups = this.listBackups(userId).filter((backup) => backup.status === 'active');
    const survivors = backups.slice(0, Math.max(0, Number(keepLatest ?? 1)));
    const purgeTargets = backups.slice(survivors.length);

    const update = this.db.prepare('UPDATE my_local_backups SET status = ?, purged_at = ? WHERE id = ?');
    for (const backup of purgeTargets) {
      if (existsSync(backup.filePath)) {
        unlinkSync(backup.filePath);
      }
      update.run('purged', nowIso, backup.id);
    }

    return {
      kept: survivors,
      purged: purgeTargets.map((backup) => ({
        ...backup,
        status: 'purged',
        purgedAt: nowIso
      }))
    };
  }

  inspectDatabaseStatus() {
    const pageCount = Number(this.db.prepare('PRAGMA page_count').get()?.page_count ?? 0);
    const pageSize = Number(this.db.prepare('PRAGMA page_size').get()?.page_size ?? 0);
    const tableCount = Number(
      this.db
        .prepare("SELECT COUNT(*) AS total FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
        .get()?.total ?? 0
    );
    const fileSizeBytes = existsSync(this.dbPath) ? statSync(this.dbPath).size : 0;

    return {
      dbPath: this.dbPath,
      fileSizeBytes,
      pageCount,
      pageSize,
      estimatedBytes: pageCount * pageSize,
      tableCount
    };
  }

  inspectMyState(userId) {
    return {
      counts: {
        trainingTasks: this.listTrainingTasks(userId).length,
        completedTrainingTasks: this.listTrainingTasks(userId).filter((item) => item.status === 'completed').length,
        errorReplays: this.listErrorReplays(userId).length,
        resolvedReplays: this.listErrorReplays(userId).filter((item) => item.status === 'resolved').length,
        masks: this.listPersonaMasks(userId).length,
        memories: this.listMemoryEntries(userId).length,
        backups: this.listBackups(userId).filter((item) => item.status === 'active').length,
        journalEntries: this.listGrowthJournal(userId, 100).length
      },
      latestSync: this.latestSyncSnapshot(userId),
      latestGrowth: this.latestGrowthSnapshot(userId),
      database: this.inspectDatabaseStatus(),
      rawMemoryStorage: this.listMemoryEntries(userId).map((entry) => ({
        id: entry.id,
        checksum: entry.checksum,
        cipherTextPreview: entry.cipherText.slice(0, 64),
        permissionScope: entry.permissionScope
      }))
    };
  }
}
