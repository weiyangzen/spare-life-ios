import { randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import {
  buildMasterChatRoute
} from '../../Domain/Models/masterContracts.mjs';
import {
  fromJson,
  isoNow,
  toJson
} from '../../Domain/Models/sceneContracts.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationPath = resolve(__dirname, '../Migrations/002_master_flow.sql');

function parseMasterRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    slug: row.slug,
    bundleId: row.bundle_id,
    bundleVersion: row.bundle_version,
    domainKey: row.domain_key,
    displayName: row.display_name,
    title: row.title,
    tagline: row.tagline,
    profile: fromJson(row.profile_json, {}),
    character: fromJson(row.character_json, {}),
    promptTemplate: row.prompt_template,
    promptPreview: row.prompt_preview,
    portrait: {
      assetPath: row.portrait_asset_path,
      checksum: row.portrait_checksum
    },
    readOnly: Boolean(row.read_only),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseStoryRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    masterId: row.master_id,
    storyKey: row.story_key,
    title: row.title,
    summary: row.summary,
    fullText: row.full_text,
    beats: fromJson(row.beats_json, []),
    tags: fromJson(row.tags_json, []),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseSessionRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    masterId: row.master_id,
    displayName: row.display_name,
    title: row.title,
    topic: row.topic,
    unreadCount: Number(row.unread_count),
    lastUserMessage: row.last_user_message,
    lastAssistantMessage: row.last_assistant_message,
    lastStoryIds: fromJson(row.last_story_ids_json, []),
    lastMemoryIds: fromJson(row.last_memory_ids_json, []),
    route: row.route,
    createdAt: row.created_at,
    lastMessageAt: row.last_message_at,
    lastOpenedAt: row.last_opened_at,
    updatedAt: row.updated_at
  };
}

function parseMessageRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    sessionId: row.session_id,
    role: row.role,
    content: row.content,
    storyIds: fromJson(row.story_ids_json, []),
    memoryIds: fromJson(row.memory_ids_json, []),
    ctas: fromJson(row.ctas_json, []),
    createdAt: row.created_at
  };
}

function parseMemoryRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    masterId: row.master_id,
    sessionId: row.session_id,
    scope: row.scope,
    memoryKind: row.memory_kind,
    summary: row.summary,
    detail: fromJson(row.detail_json, {}),
    tags: fromJson(row.tags_json, []),
    authorizedAt: row.authorized_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

export class MasterFlowRepository {
  constructor(dbPath) {
    mkdirSync(dirname(dbPath), { recursive: true });
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

  getImportRecord(bundleId, bundleVersion) {
    return this.db
      .prepare(
        `SELECT bundle_id, bundle_version, checksum, imported_at
         FROM master_asset_imports
         WHERE bundle_id = ? AND bundle_version = ?`
      )
      .get(bundleId, bundleVersion);
  }

  countMasters() {
    return Number(this.db.prepare('SELECT COUNT(*) AS total FROM masters').get()?.total ?? 0);
  }

  importCatalog(bundle) {
    const existingImport = this.getImportRecord(bundle.bundleId, bundle.version);
    if (existingImport?.checksum === bundle.checksum && this.countMasters() > 0) {
      return {
        status: 'unchanged',
        importedMasters: 0,
        importedStories: 0,
        bundleId: bundle.bundleId,
        bundleVersion: bundle.version
      };
    }

    const nowIso = isoNow();
    return this.withTransaction(() => {
      const upsertDomain = this.db.prepare(
        `INSERT INTO master_domains (
          key, title, description, sort_order, created_at, updated_at
        ) VALUES (
          @key, @title, @description, @sort_order, @created_at, @updated_at
        )
        ON CONFLICT(key) DO UPDATE SET
          title = excluded.title,
          description = excluded.description,
          sort_order = excluded.sort_order,
          updated_at = excluded.updated_at`
      );

      const upsertMaster = this.db.prepare(
        `INSERT INTO masters (
          id, slug, bundle_id, bundle_version, domain_key, display_name, title, tagline,
          profile_json, character_json, prompt_template, prompt_preview, portrait_asset_path,
          portrait_checksum, read_only, created_at, updated_at
        ) VALUES (
          @id, @slug, @bundle_id, @bundle_version, @domain_key, @display_name, @title, @tagline,
          @profile_json, @character_json, @prompt_template, @prompt_preview, @portrait_asset_path,
          @portrait_checksum, 1, @created_at, @updated_at
        )
        ON CONFLICT(id) DO UPDATE SET
          slug = excluded.slug,
          bundle_id = excluded.bundle_id,
          bundle_version = excluded.bundle_version,
          domain_key = excluded.domain_key,
          display_name = excluded.display_name,
          title = excluded.title,
          tagline = excluded.tagline,
          profile_json = excluded.profile_json,
          character_json = excluded.character_json,
          prompt_template = excluded.prompt_template,
          prompt_preview = excluded.prompt_preview,
          portrait_asset_path = excluded.portrait_asset_path,
          portrait_checksum = excluded.portrait_checksum,
          updated_at = excluded.updated_at`
      );

      const insertStory = this.db.prepare(
        `INSERT INTO master_stories (
          id, master_id, story_key, title, summary, full_text, beats_json, tags_json, created_at, updated_at
        ) VALUES (
          @id, @master_id, @story_key, @title, @summary, @full_text, @beats_json, @tags_json, @created_at, @updated_at
        )`
      );

      for (const domain of bundle.domains) {
        upsertDomain.run({
          key: domain.key,
          title: domain.title,
          description: domain.description,
          sort_order: domain.sortOrder,
          created_at: nowIso,
          updated_at: nowIso
        });
      }

      for (const master of bundle.masters) {
        upsertMaster.run({
          id: master.id,
          slug: master.slug,
          bundle_id: master.bundleId,
          bundle_version: master.bundleVersion,
          domain_key: master.domainKey,
          display_name: master.displayName,
          title: master.title,
          tagline: master.tagline,
          profile_json: toJson(master.profile),
          character_json: toJson(master.character),
          prompt_template: master.promptTemplate,
          prompt_preview: master.promptPreview,
          portrait_asset_path: master.portrait.assetPath,
          portrait_checksum: master.portrait.checksum,
          created_at: nowIso,
          updated_at: nowIso
        });

        this.db.prepare('DELETE FROM master_stories WHERE master_id = ?').run(master.id);
        for (const story of master.stories) {
          insertStory.run({
            id: story.id,
            master_id: master.id,
            story_key: story.storyKey,
            title: story.title,
            summary: story.summary,
            full_text: story.fullText,
            beats_json: toJson(story.beats),
            tags_json: toJson(story.tags),
            created_at: nowIso,
            updated_at: nowIso
          });
        }
      }

      this.db
        .prepare(
          `INSERT INTO master_asset_imports (
            bundle_id, bundle_version, checksum, imported_at
          ) VALUES (
            @bundle_id, @bundle_version, @checksum, @imported_at
          )
          ON CONFLICT(bundle_id, bundle_version) DO UPDATE SET
            checksum = excluded.checksum,
            imported_at = excluded.imported_at`
        )
        .run({
          bundle_id: bundle.bundleId,
          bundle_version: bundle.version,
          checksum: bundle.checksum,
          imported_at: nowIso
        });

      return {
        status: existingImport ? 'updated' : 'imported',
        importedMasters: bundle.masters.length,
        importedStories: bundle.masters.reduce((sum, master) => sum + master.stories.length, 0),
        bundleId: bundle.bundleId,
        bundleVersion: bundle.version
      };
    });
  }

  listDomains() {
    return this.db
      .prepare(
        `SELECT key, title, description, sort_order
         FROM master_domains
         ORDER BY sort_order ASC, title ASC`
      )
      .all()
      .map((row) => ({
        key: row.key,
        title: row.title,
        description: row.description,
        sortOrder: Number(row.sort_order)
      }));
  }

  listMasters() {
    return this.db
      .prepare(
        `SELECT *
         FROM masters
         ORDER BY display_name ASC`
      )
      .all()
      .map((row) => parseMasterRow(row));
  }

  findMaster(masterId) {
    return parseMasterRow(this.db.prepare('SELECT * FROM masters WHERE id = ?').get(masterId));
  }

  listStoriesForMaster(masterId) {
    return this.db
      .prepare(
        `SELECT *
         FROM master_stories
         WHERE master_id = ?
         ORDER BY story_key ASC`
      )
      .all(masterId)
      .map((row) => parseStoryRow(row));
  }

  findLatestSession({ userId, masterId }) {
    return parseSessionRow(
      this.db
        .prepare(
          `SELECT sessions.*, masters.display_name, masters.title
           FROM master_sessions AS sessions
           JOIN masters ON masters.id = sessions.master_id
           WHERE sessions.user_id = ? AND sessions.master_id = ?
           ORDER BY sessions.last_message_at DESC
           LIMIT 1`
        )
        .get(userId, masterId)
    );
  }

  findSessionForUser(sessionId, userId) {
    return parseSessionRow(
      this.db
        .prepare(
          `SELECT sessions.*, masters.display_name, masters.title
           FROM master_sessions AS sessions
           JOIN masters ON masters.id = sessions.master_id
           WHERE sessions.id = ? AND sessions.user_id = ?
           LIMIT 1`
        )
        .get(sessionId, userId)
    );
  }

  createSession({ userId, masterId, topic, nowIso = isoNow() }) {
    const sessionId = `master_session_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    const route = buildMasterChatRoute(masterId, sessionId);
    this.db
      .prepare(
        `INSERT INTO master_sessions (
          id, user_id, master_id, topic, unread_count, last_story_ids_json,
          last_memory_ids_json, route, created_at, last_message_at, last_opened_at, updated_at
        ) VALUES (
          @id, @user_id, @master_id, @topic, 0, '[]', '[]', @route, @created_at, @last_message_at, @last_opened_at, @updated_at
        )`
      )
      .run({
        id: sessionId,
        user_id: userId,
        master_id: masterId,
        topic: topic || '大师对话',
        route,
        created_at: nowIso,
        last_message_at: nowIso,
        last_opened_at: nowIso,
        updated_at: nowIso
      });

    return this.findSessionForUser(sessionId, userId);
  }

  appendMessage({ sessionId, role, content, storyIds = [], memoryIds = [], ctas = [], nowIso = isoNow() }) {
    const messageId = `master_message_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO master_messages (
          id, session_id, role, content, story_ids_json, memory_ids_json, ctas_json, created_at
        ) VALUES (
          @id, @session_id, @role, @content, @story_ids_json, @memory_ids_json, @ctas_json, @created_at
        )`
      )
      .run({
        id: messageId,
        session_id: sessionId,
        role,
        content,
        story_ids_json: toJson(storyIds),
        memory_ids_json: toJson(memoryIds),
        ctas_json: toJson(ctas),
        created_at: nowIso
      });
    return messageId;
  }

  updateSessionAfterTurn({
    sessionId,
    topic,
    lastUserMessage,
    lastAssistantMessage,
    lastStoryIds = [],
    lastMemoryIds = [],
    unreadIncrement = 1,
    nowIso = isoNow()
  }) {
    this.db
      .prepare(
        `UPDATE master_sessions
         SET topic = COALESCE(@topic, topic),
             last_user_message = @last_user_message,
             last_assistant_message = @last_assistant_message,
             last_story_ids_json = @last_story_ids_json,
             last_memory_ids_json = @last_memory_ids_json,
             unread_count = unread_count + @unread_increment,
             last_message_at = @last_message_at,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: sessionId,
        topic,
        last_user_message: lastUserMessage,
        last_assistant_message: lastAssistantMessage,
        last_story_ids_json: toJson(lastStoryIds),
        last_memory_ids_json: toJson(lastMemoryIds),
        unread_increment: unreadIncrement,
        last_message_at: nowIso,
        updated_at: nowIso
      });
  }

  markSessionRead(sessionId, nowIso = isoNow()) {
    this.db
      .prepare(
        `UPDATE master_sessions
         SET unread_count = 0,
             last_opened_at = @last_opened_at,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: sessionId,
        last_opened_at: nowIso,
        updated_at: nowIso
      });
  }

  listSessionMessages(sessionId, limit = 12) {
    return this.db
      .prepare(
        `SELECT *
         FROM master_messages
         WHERE session_id = ?
         ORDER BY created_at ASC
         LIMIT ?`
      )
      .all(sessionId, limit)
      .map((row) => parseMessageRow(row));
  }

  listRecentSessions(userId, limit = 5) {
    return this.db
      .prepare(
        `SELECT sessions.*, masters.display_name, masters.title
         FROM master_sessions AS sessions
         JOIN masters ON masters.id = sessions.master_id
         WHERE sessions.user_id = ?
         ORDER BY sessions.last_message_at DESC
         LIMIT ?`
      )
      .all(userId, limit)
      .map((row) => parseSessionRow(row));
  }

  upsertMemories(memories, nowIso = isoNow()) {
    const upsertMemory = this.db.prepare(
      `INSERT INTO master_memories (
        id, user_id, master_id, session_id, scope, memory_kind, summary,
        detail_json, tags_json, authorized_at, created_at, updated_at
      ) VALUES (
        @id, @user_id, @master_id, @session_id, @scope, @memory_kind, @summary,
        @detail_json, @tags_json, @authorized_at, @created_at, @updated_at
      )
      ON CONFLICT(id) DO UPDATE SET
        summary = excluded.summary,
        detail_json = excluded.detail_json,
        tags_json = excluded.tags_json,
        authorized_at = excluded.authorized_at,
        updated_at = excluded.updated_at`
    );

    for (const memory of memories) {
      upsertMemory.run({
        id: memory.id,
        user_id: memory.userId,
        master_id: memory.masterId,
        session_id: memory.sessionId,
        scope: memory.scope,
        memory_kind: memory.memoryKind,
        summary: memory.summary,
        detail_json: toJson(memory.detail),
        tags_json: toJson(memory.tags),
        authorized_at: memory.authorizedAt,
        created_at: nowIso,
        updated_at: nowIso
      });
    }
  }

  listMemoriesForUser(userId) {
    return this.db
      .prepare(
        `SELECT *
         FROM master_memories
         WHERE user_id = ?
         ORDER BY updated_at DESC`
      )
      .all(userId)
      .map((row) => parseMemoryRow(row));
  }

  saveConsultation({ userId, issue, sharedScope, mergedSummary, conflicts, ctas, members, nowIso = isoNow() }) {
    const consultationId = `master_consult_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    const route = `sparelife://masters/consultation?consultation_id=${consultationId}`;
    this.withTransaction(() => {
      this.db
        .prepare(
          `INSERT INTO master_consultations (
            id, user_id, issue, shared_scope, merged_summary, conflicts_json, ctas_json, route, created_at, updated_at
          ) VALUES (
            @id, @user_id, @issue, @shared_scope, @merged_summary, @conflicts_json, @ctas_json, @route, @created_at, @updated_at
          )`
        )
        .run({
          id: consultationId,
          user_id: userId,
          issue,
          shared_scope: sharedScope,
          merged_summary: mergedSummary,
          conflicts_json: toJson(conflicts),
          ctas_json: toJson(ctas),
          route,
          created_at: nowIso,
          updated_at: nowIso
        });

      const insertMember = this.db.prepare(
        `INSERT INTO master_consultation_members (
          id, consultation_id, master_id, stance, advice, story_ids_json, memory_ids_json, ctas_json, created_at
        ) VALUES (
          @id, @consultation_id, @master_id, @stance, @advice, @story_ids_json, @memory_ids_json, @ctas_json, @created_at
        )`
      );

      for (const member of members) {
        insertMember.run({
          id: `master_consult_member_${randomUUID().replace(/-/g, '').slice(0, 20)}`,
          consultation_id: consultationId,
          master_id: member.masterId,
          stance: member.stance,
          advice: member.advice,
          story_ids_json: toJson(member.storyIds),
          memory_ids_json: toJson(member.memoryIds),
          ctas_json: toJson(member.ctas),
          created_at: nowIso
        });
      }
    });

    return {
      id: consultationId,
      userId,
      issue,
      sharedScope,
      mergedSummary,
      conflicts,
      ctas,
      route,
      members
    };
  }

  trackCTAAction({ userId, sourceKind, sourceId, masterId = null, ctaId, route, effectKind, nowIso = isoNow() }) {
    const eventId = `master_cta_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO master_cta_events (
          id, user_id, source_kind, source_id, master_id, cta_id, route, effect_kind, triggered_at
        ) VALUES (
          @id, @user_id, @source_kind, @source_id, @master_id, @cta_id, @route, @effect_kind, @triggered_at
        )`
      )
      .run({
        id: eventId,
        user_id: userId,
        source_kind: sourceKind,
        source_id: sourceId,
        master_id: masterId,
        cta_id: ctaId,
        route,
        effect_kind: effectKind,
        triggered_at: nowIso
      });

    return {
      id: eventId,
      userId,
      sourceKind,
      sourceId,
      masterId,
      ctaId,
      route,
      effectKind,
      triggeredAt: nowIso
    };
  }

  inspectMasterState(userId) {
    const counts = {
      masters: Number(this.db.prepare('SELECT COUNT(*) AS total FROM masters').get()?.total ?? 0),
      stories: Number(this.db.prepare('SELECT COUNT(*) AS total FROM master_stories').get()?.total ?? 0),
      sessions: Number(
        this.db.prepare('SELECT COUNT(*) AS total FROM master_sessions WHERE user_id = ?').get(userId)?.total ?? 0
      ),
      memories: Number(
        this.db.prepare('SELECT COUNT(*) AS total FROM master_memories WHERE user_id = ?').get(userId)?.total ?? 0
      ),
      consultations: Number(
        this.db.prepare('SELECT COUNT(*) AS total FROM master_consultations WHERE user_id = ?').get(userId)?.total ?? 0
      ),
      ctaEvents: Number(
        this.db.prepare('SELECT COUNT(*) AS total FROM master_cta_events WHERE user_id = ?').get(userId)?.total ?? 0
      ),
      readOnlyMasters: Number(
        this.db.prepare('SELECT COUNT(*) AS total FROM masters WHERE read_only = 1').get()?.total ?? 0
      )
    };

    return {
      counts,
      recentSessions: this.listRecentSessions(userId, 5),
      memories: this.listMemoriesForUser(userId).slice(0, 5),
      domains: this.listDomains()
    };
  }
}
