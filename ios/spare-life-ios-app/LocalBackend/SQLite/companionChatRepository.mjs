import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import {
  fromJson,
  isoNow,
  sanitizeText,
  stableId,
  toJson
} from '../../Domain/Models/sceneContracts.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationPath = resolve(__dirname, '../Migrations/004_companion_chat.sql');

function parseContactRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.owner_user_id,
    displayName: row.display_name,
    personaSummary: row.persona_summary,
    tags: fromJson(row.tags_json, []),
    defaultMask: fromJson(row.default_mask_json, {}),
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
    contactId: row.contact_id,
    tone: row.tone,
    openness: row.openness,
    boundaryTags: fromJson(row.boundary_tags_json, []),
    signature: row.signature,
    overrideRules: fromJson(row.override_rules_json, []),
    isActive: Boolean(row.is_active),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseConversationRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    ownerUserId: row.owner_user_id,
    kind: row.kind,
    title: row.title,
    contactId: row.contact_id,
    groupId: row.group_id,
    unreadCount: Number(row.unread_count),
    lastMessagePreview: row.last_message_preview,
    lastMessageAt: row.last_message_at,
    lastOpenedAt: row.last_opened_at,
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseParticipantRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    conversationId: row.conversation_id,
    participantKey: row.participant_key,
    role: row.role,
    displayName: row.display_name,
    permissions: fromJson(row.permissions_json, {}),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseMessageRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    conversationId: row.conversation_id,
    turnIndex: Number(row.turn_index),
    actorKey: row.actor_key,
    actorRole: row.actor_role,
    channelKind: row.channel_kind,
    content: row.content,
    searchText: row.search_text,
    metadata: fromJson(row.metadata_json, {}),
    signalScore: Number(row.signal_score),
    suppressed: Boolean(row.suppressed),
    unreadForOwner: Boolean(row.unread_for_owner),
    createdAt: row.created_at
  };
}

function parseRelationshipRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    ownerUserId: row.owner_user_id,
    contactId: row.contact_id,
    conversationId: row.conversation_id,
    level: row.level,
    warmthScore: Number(row.warmth_score),
    latestSummary: row.latest_summary,
    memorialCard: fromJson(row.memorial_card_json, {}),
    lastRitualAt: row.last_ritual_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseRitualRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    relationshipId: row.relationship_id,
    conversationId: row.conversation_id,
    ritualKind: row.ritual_kind,
    title: row.title,
    summary: row.summary,
    status: row.status,
    scheduledFor: row.scheduled_for,
    completedAt: row.completed_at,
    memorialCard: fromJson(row.memorial_card_json, {}),
    memoryLaneSummary: row.memory_lane_summary,
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
    ownerUserId: row.owner_user_id,
    contactId: row.contact_id,
    conversationId: row.conversation_id,
    layer: row.layer,
    summary: row.summary,
    keywords: fromJson(row.keywords_json, []),
    emotionLabel: row.emotion_label,
    warmthScore: Number(row.warmth_score),
    sourceMessageIds: fromJson(row.source_message_ids_json, []),
    createdAt: row.created_at
  };
}

function parseGroupRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    ownerUserId: row.owner_user_id,
    title: row.title,
    summary: row.summary,
    toolAgentName: row.tool_agent_name,
    noiseThreshold: Number(row.noise_threshold),
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseGroupMemberRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    groupId: row.group_id,
    memberKey: row.member_key,
    role: row.role,
    displayName: row.display_name,
    contactId: row.contact_id,
    permissions: fromJson(row.permissions_json, {}),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseVoteRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    groupId: row.group_id,
    conversationId: row.conversation_id,
    question: row.question,
    status: row.status,
    options: fromJson(row.options_json, []),
    resultSummary: row.result_summary,
    createdBy: row.created_by,
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseBallotRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    voteId: row.vote_id,
    voterKey: row.voter_key,
    optionId: row.option_id,
    rationale: row.rationale,
    createdAt: row.created_at
  };
}

function parseGroupSummaryRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    groupId: row.group_id,
    conversationId: row.conversation_id,
    summary: row.summary,
    includedMessageIds: fromJson(row.included_message_ids_json, []),
    suppressedCount: Number(row.suppressed_count),
    createdAt: row.created_at
  };
}

export class CompanionChatRepository {
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

  countContactsForOwner(ownerUserId) {
    return Number(
      this.db
        .prepare('SELECT COUNT(*) AS total FROM companion_contacts WHERE owner_user_id = ?')
        .get(ownerUserId)?.total ?? 0
    );
  }

  upsertContact(contact) {
    this.db
      .prepare(
        `INSERT INTO companion_contacts (
          id, owner_user_id, display_name, persona_summary, tags_json, default_mask_json, created_at, updated_at
        ) VALUES (
          @id, @owner_user_id, @display_name, @persona_summary, @tags_json, @default_mask_json, @created_at, @updated_at
        )
        ON CONFLICT(id) DO UPDATE SET
          display_name = excluded.display_name,
          persona_summary = excluded.persona_summary,
          tags_json = excluded.tags_json,
          default_mask_json = excluded.default_mask_json,
          updated_at = excluded.updated_at`
      )
      .run({
        id: contact.id,
        owner_user_id: contact.userId,
        display_name: contact.displayName,
        persona_summary: contact.personaSummary,
        tags_json: toJson(contact.tags),
        default_mask_json: toJson(contact.defaultMask),
        created_at: contact.createdAt ?? isoNow(),
        updated_at: contact.updatedAt ?? isoNow()
      });
    return this.findContact(contact.id);
  }

  listContacts(ownerUserId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_contacts
         WHERE owner_user_id = ?
         ORDER BY display_name ASC`
      )
      .all(ownerUserId)
      .map((row) => parseContactRow(row));
  }

  findContact(contactId) {
    return parseContactRow(this.db.prepare('SELECT * FROM companion_contacts WHERE id = ?').get(contactId));
  }

  upsertGroup(group) {
    this.db
      .prepare(
        `INSERT INTO companion_groups (
          id, owner_user_id, title, summary, tool_agent_name, noise_threshold, route, created_at, updated_at
        ) VALUES (
          @id, @owner_user_id, @title, @summary, @tool_agent_name, @noise_threshold, @route, @created_at, @updated_at
        )
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          summary = excluded.summary,
          tool_agent_name = excluded.tool_agent_name,
          noise_threshold = excluded.noise_threshold,
          route = excluded.route,
          updated_at = excluded.updated_at`
      )
      .run({
        id: group.id,
        owner_user_id: group.userId,
        title: group.title,
        summary: group.summary,
        tool_agent_name: group.toolAgentName,
        noise_threshold: group.noiseThreshold,
        route: group.route,
        created_at: group.createdAt ?? isoNow(),
        updated_at: group.updatedAt ?? isoNow()
      });
    return this.findGroup(group.id);
  }

  listGroups(ownerUserId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_groups
         WHERE owner_user_id = ?
         ORDER BY updated_at DESC`
      )
      .all(ownerUserId)
      .map((row) => parseGroupRow(row));
  }

  findGroup(groupId) {
    return parseGroupRow(this.db.prepare('SELECT * FROM companion_groups WHERE id = ?').get(groupId));
  }

  upsertConversation(conversation) {
    this.db
      .prepare(
        `INSERT INTO companion_conversations (
          id, owner_user_id, kind, title, contact_id, group_id, unread_count, last_message_preview,
          last_message_at, last_opened_at, route, created_at, updated_at
        ) VALUES (
          @id, @owner_user_id, @kind, @title, @contact_id, @group_id, @unread_count, @last_message_preview,
          @last_message_at, @last_opened_at, @route, @created_at, @updated_at
        )
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          unread_count = excluded.unread_count,
          last_message_preview = excluded.last_message_preview,
          last_message_at = excluded.last_message_at,
          last_opened_at = excluded.last_opened_at,
          route = excluded.route,
          updated_at = excluded.updated_at`
      )
      .run({
        id: conversation.id,
        owner_user_id: conversation.ownerUserId,
        kind: conversation.kind,
        title: conversation.title,
        contact_id: conversation.contactId ?? null,
        group_id: conversation.groupId ?? null,
        unread_count: conversation.unreadCount ?? 0,
        last_message_preview: conversation.lastMessagePreview ?? null,
        last_message_at: conversation.lastMessageAt ?? isoNow(),
        last_opened_at: conversation.lastOpenedAt ?? null,
        route: conversation.route,
        created_at: conversation.createdAt ?? isoNow(),
        updated_at: conversation.updatedAt ?? isoNow()
      });
    return this.findConversation(conversation.id);
  }

  findConversation(conversationId) {
    return parseConversationRow(
      this.db.prepare('SELECT * FROM companion_conversations WHERE id = ?').get(conversationId)
    );
  }

  findConversationByContact(ownerUserId, contactId) {
    return parseConversationRow(
      this.db
        .prepare(
          `SELECT *
           FROM companion_conversations
           WHERE owner_user_id = ? AND contact_id = ?
           LIMIT 1`
        )
        .get(ownerUserId, contactId)
    );
  }

  findConversationByGroup(ownerUserId, groupId) {
    return parseConversationRow(
      this.db
        .prepare(
          `SELECT *
           FROM companion_conversations
           WHERE owner_user_id = ? AND group_id = ?
           LIMIT 1`
        )
        .get(ownerUserId, groupId)
    );
  }

  findConversationByLocator(ownerUserId, locator) {
    const kind = sanitizeText(locator?.kind);
    switch (kind) {
      case 'conversation':
        return this.findConversation(locator.conversationID);
      case 'group':
        return this.findConversationByGroup(ownerUserId, locator.groupID);
      case 'dm':
        return this.findConversationByContact(ownerUserId, locator.peerID);
      default:
        throw new Error(`Unsupported conversation locator kind: ${kind || 'unknown'}`);
    }
  }

  listRecentConversations(ownerUserId, limit = 12) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_conversations
         WHERE owner_user_id = ?
         ORDER BY last_message_at DESC
         LIMIT ?`
      )
      .all(ownerUserId, limit)
      .map((row) => parseConversationRow(row));
  }

  replaceConversationParticipants(conversationId, participants, nowIso = isoNow()) {
    const upsert = this.db.prepare(
      `INSERT INTO companion_conversation_participants (
        id, conversation_id, participant_key, role, display_name, permissions_json, created_at, updated_at
      ) VALUES (
        @id, @conversation_id, @participant_key, @role, @display_name, @permissions_json, @created_at, @updated_at
      )
      ON CONFLICT(conversation_id, participant_key) DO UPDATE SET
        role = excluded.role,
        display_name = excluded.display_name,
        permissions_json = excluded.permissions_json,
        updated_at = excluded.updated_at`
    );
    for (const participant of participants) {
      upsert.run({
        id:
          participant.id ??
          stableId('companion-participant', conversationId, participant.participantKey),
        conversation_id: conversationId,
        participant_key: participant.participantKey,
        role: participant.role,
        display_name: participant.displayName,
        permissions_json: toJson(participant.permissions ?? {}),
        created_at: participant.createdAt ?? nowIso,
        updated_at: participant.updatedAt ?? nowIso
      });
    }
  }

  listConversationParticipants(conversationId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_conversation_participants
         WHERE conversation_id = ?
         ORDER BY display_name ASC`
      )
      .all(conversationId)
      .map((row) => parseParticipantRow(row));
  }

  findParticipant(conversationId, participantKey) {
    return parseParticipantRow(
      this.db
        .prepare(
          `SELECT *
           FROM companion_conversation_participants
           WHERE conversation_id = ? AND participant_key = ?
           LIMIT 1`
        )
        .get(conversationId, participantKey)
    );
  }

  updateParticipantPermission({ conversationId, participantKey, permissions, nowIso = isoNow() }) {
    this.db
      .prepare(
        `UPDATE companion_conversation_participants
         SET permissions_json = @permissions_json,
             updated_at = @updated_at
         WHERE conversation_id = @conversation_id AND participant_key = @participant_key`
      )
      .run({
        conversation_id: conversationId,
        participant_key: participantKey,
        permissions_json: toJson(permissions),
        updated_at: nowIso
      });
    return this.findParticipant(conversationId, participantKey);
  }

  nextTurnIndex(conversationId) {
    return (
      Number(
        this.db
          .prepare(
            `SELECT COALESCE(MAX(turn_index), 0) AS turn_index
             FROM companion_messages
             WHERE conversation_id = ?`
          )
          .get(conversationId)?.turn_index ?? 0
      ) + 1
    );
  }

  appendMessage({
    conversationId,
    actorKey,
    actorRole,
    channelKind,
    content,
    metadata = {},
    signalScore = 100,
    suppressed = false,
    unreadForOwner = false,
    createdAt = isoNow()
  }) {
    const turnIndex = this.nextTurnIndex(conversationId);
    const messageId = stableId('companion-message', conversationId, turnIndex, actorKey, createdAt);
    this.db
      .prepare(
        `INSERT INTO companion_messages (
          id, conversation_id, turn_index, actor_key, actor_role, channel_kind, content, search_text,
          metadata_json, signal_score, suppressed, unread_for_owner, created_at
        ) VALUES (
          @id, @conversation_id, @turn_index, @actor_key, @actor_role, @channel_kind, @content, @search_text,
          @metadata_json, @signal_score, @suppressed, @unread_for_owner, @created_at
        )`
      )
      .run({
        id: messageId,
        conversation_id: conversationId,
        turn_index: turnIndex,
        actor_key: actorKey,
        actor_role: actorRole,
        channel_kind: channelKind,
        content,
        search_text: sanitizeText(`${content} ${Object.values(metadata).join(' ')}`).toLowerCase(),
        metadata_json: toJson(metadata),
        signal_score: signalScore,
        suppressed: suppressed ? 1 : 0,
        unread_for_owner: unreadForOwner ? 1 : 0,
        created_at: createdAt
      });
    return this.findMessage(messageId);
  }

  findMessage(messageId) {
    return parseMessageRow(this.db.prepare('SELECT * FROM companion_messages WHERE id = ?').get(messageId));
  }

  listConversationMessages(conversationId, limit = null) {
    const rows = this.db
      .prepare(
        `SELECT *
         FROM companion_messages
         WHERE conversation_id = ?
         ORDER BY turn_index ASC`
      )
      .all(conversationId)
      .map((row) => parseMessageRow(row));
    return limit ? rows.slice(-limit) : rows;
  }

  searchConversationMessages(conversationId, query, limit = 12) {
    const term = `%${sanitizeText(query).toLowerCase()}%`;
    return this.db
      .prepare(
        `SELECT *
         FROM companion_messages
         WHERE conversation_id = ? AND LOWER(search_text) LIKE ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(conversationId, term, limit)
      .map((row) => parseMessageRow(row));
  }

  updateConversationAfterMessage({
    conversationId,
    lastMessagePreview,
    lastMessageAt,
    unreadIncrement = 0,
    nowIso = isoNow()
  }) {
    this.db
      .prepare(
        `UPDATE companion_conversations
         SET unread_count = unread_count + @unread_increment,
             last_message_preview = @last_message_preview,
             last_message_at = @last_message_at,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: conversationId,
        unread_increment: unreadIncrement,
        last_message_preview: lastMessagePreview,
        last_message_at: lastMessageAt,
        updated_at: nowIso
      });
    return this.findConversation(conversationId);
  }

  markConversationRead(conversationId, nowIso = isoNow()) {
    this.db
      .prepare(
        `UPDATE companion_conversations
         SET unread_count = 0,
             last_opened_at = @last_opened_at,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: conversationId,
        last_opened_at: nowIso,
        updated_at: nowIso
      });
    this.db
      .prepare(
        `UPDATE companion_messages
         SET unread_for_owner = 0
         WHERE conversation_id = @conversation_id`
      )
      .run({
        conversation_id: conversationId
      });
    return this.findConversation(conversationId);
  }

  deactivateMasks(contactId, nowIso = isoNow()) {
    this.db
      .prepare(
        `UPDATE companion_masks
         SET is_active = 0,
             updated_at = @updated_at
         WHERE contact_id = @contact_id AND is_active = 1`
      )
      .run({
        contact_id: contactId,
        updated_at: nowIso
      });
  }

  insertMask(mask) {
    this.db
      .prepare(
        `INSERT INTO companion_masks (
          id, contact_id, tone, openness, boundary_tags_json, signature, override_rules_json,
          is_active, created_at, updated_at
        ) VALUES (
          @id, @contact_id, @tone, @openness, @boundary_tags_json, @signature, @override_rules_json,
          @is_active, @created_at, @updated_at
        )`
      )
      .run({
        id: mask.id,
        contact_id: mask.contactId,
        tone: mask.tone,
        openness: mask.openness,
        boundary_tags_json: toJson(mask.boundaryTags),
        signature: mask.signature,
        override_rules_json: toJson(mask.overrideRules ?? []),
        is_active: mask.isActive ? 1 : 0,
        created_at: mask.createdAt ?? isoNow(),
        updated_at: mask.updatedAt ?? isoNow()
      });
    return this.findMask(mask.id);
  }

  findMask(maskId) {
    return parseMaskRow(this.db.prepare('SELECT * FROM companion_masks WHERE id = ?').get(maskId));
  }

  findActiveMask(contactId) {
    return parseMaskRow(
      this.db
        .prepare(
          `SELECT *
           FROM companion_masks
           WHERE contact_id = ? AND is_active = 1
           ORDER BY updated_at DESC
           LIMIT 1`
        )
        .get(contactId)
    );
  }

  listMaskHistory(contactId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_mask_history
         WHERE contact_id = ?
         ORDER BY created_at DESC`
      )
      .all(contactId)
      .map((row) => ({
        id: row.id,
        contactId: row.contact_id,
        maskId: row.mask_id,
        changeSummary: row.change_summary,
        diff: fromJson(row.diff_json, {}),
        createdAt: row.created_at
      }));
  }

  recordMaskHistory({ contactId, maskId, changeSummary, diff = {}, createdAt = isoNow() }) {
    const historyId = stableId('companion-mask-history', contactId, maskId, createdAt);
    this.db
      .prepare(
        `INSERT INTO companion_mask_history (
          id, contact_id, mask_id, change_summary, diff_json, created_at
        ) VALUES (
          @id, @contact_id, @mask_id, @change_summary, @diff_json, @created_at
        )`
      )
      .run({
        id: historyId,
        contact_id: contactId,
        mask_id: maskId,
        change_summary: changeSummary,
        diff_json: toJson(diff),
        created_at: createdAt
      });
    return historyId;
  }

  upsertRelationship(relationship) {
    this.db
      .prepare(
        `INSERT INTO companion_relationships (
          id, owner_user_id, contact_id, conversation_id, level, warmth_score, latest_summary,
          memorial_card_json, last_ritual_at, created_at, updated_at
        ) VALUES (
          @id, @owner_user_id, @contact_id, @conversation_id, @level, @warmth_score, @latest_summary,
          @memorial_card_json, @last_ritual_at, @created_at, @updated_at
        )
        ON CONFLICT(owner_user_id, contact_id) DO UPDATE SET
          conversation_id = excluded.conversation_id,
          level = excluded.level,
          warmth_score = excluded.warmth_score,
          latest_summary = excluded.latest_summary,
          memorial_card_json = excluded.memorial_card_json,
          last_ritual_at = excluded.last_ritual_at,
          updated_at = excluded.updated_at`
      )
      .run({
        id: relationship.id,
        owner_user_id: relationship.ownerUserId,
        contact_id: relationship.contactId,
        conversation_id: relationship.conversationId,
        level: relationship.level,
        warmth_score: relationship.warmthScore,
        latest_summary: relationship.latestSummary,
        memorial_card_json: toJson(relationship.memorialCard ?? {}),
        last_ritual_at: relationship.lastRitualAt ?? null,
        created_at: relationship.createdAt ?? isoNow(),
        updated_at: relationship.updatedAt ?? isoNow()
      });
    return this.findRelationshipByContact(relationship.ownerUserId, relationship.contactId);
  }

  findRelationship(relationshipId) {
    return parseRelationshipRow(
      this.db.prepare('SELECT * FROM companion_relationships WHERE id = ?').get(relationshipId)
    );
  }

  findRelationshipByContact(ownerUserId, contactId) {
    return parseRelationshipRow(
      this.db
        .prepare(
          `SELECT *
           FROM companion_relationships
           WHERE owner_user_id = ? AND contact_id = ?
           LIMIT 1`
        )
        .get(ownerUserId, contactId)
    );
  }

  listRelationshipsForOwner(ownerUserId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_relationships
         WHERE owner_user_id = ?
         ORDER BY updated_at DESC`
      )
      .all(ownerUserId)
      .map((row) => parseRelationshipRow(row));
  }

  createRitual(ritual) {
    this.db
      .prepare(
        `INSERT INTO companion_rituals (
          id, relationship_id, conversation_id, ritual_kind, title, summary, status, scheduled_for,
          completed_at, memorial_card_json, memory_lane_summary, created_at, updated_at
        ) VALUES (
          @id, @relationship_id, @conversation_id, @ritual_kind, @title, @summary, @status, @scheduled_for,
          @completed_at, @memorial_card_json, @memory_lane_summary, @created_at, @updated_at
        )`
      )
      .run({
        id: ritual.ritualId ?? ritual.id,
        relationship_id: ritual.relationshipId,
        conversation_id: ritual.conversationId,
        ritual_kind: ritual.ritualKind,
        title: ritual.title,
        summary: ritual.summary,
        status: ritual.status,
        scheduled_for: ritual.scheduledFor ?? null,
        completed_at: ritual.completedAt ?? null,
        memorial_card_json: toJson(ritual.memorialCard ?? {}),
        memory_lane_summary: ritual.memoryLaneSummary ?? null,
        created_at: ritual.createdAt ?? isoNow(),
        updated_at: ritual.updatedAt ?? isoNow()
      });
    return this.findRitual(ritual.ritualId ?? ritual.id);
  }

  findRitual(ritualId) {
    return parseRitualRow(this.db.prepare('SELECT * FROM companion_rituals WHERE id = ?').get(ritualId));
  }

  completeRitual({ ritualId, summary, memorialCard, memoryLaneSummary, completedAt = isoNow(), nowIso = isoNow() }) {
    this.db
      .prepare(
        `UPDATE companion_rituals
         SET summary = @summary,
             status = 'completed',
             completed_at = @completed_at,
             memorial_card_json = @memorial_card_json,
             memory_lane_summary = @memory_lane_summary,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: ritualId,
        summary,
        completed_at: completedAt,
        memorial_card_json: toJson(memorialCard ?? {}),
        memory_lane_summary: memoryLaneSummary ?? null,
        updated_at: nowIso
      });
    return this.findRitual(ritualId);
  }

  listRitualsForRelationship(relationshipId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_rituals
         WHERE relationship_id = ?
         ORDER BY updated_at DESC`
      )
      .all(relationshipId)
      .map((row) => parseRitualRow(row));
  }

  saveMemorySnapshots(snapshots) {
    const insert = this.db.prepare(
      `INSERT OR REPLACE INTO companion_memory_snapshots (
        id, owner_user_id, contact_id, conversation_id, layer, summary, keywords_json,
        emotion_label, warmth_score, source_message_ids_json, created_at
      ) VALUES (
        @id, @owner_user_id, @contact_id, @conversation_id, @layer, @summary, @keywords_json,
        @emotion_label, @warmth_score, @source_message_ids_json, @created_at
      )`
    );
    for (const snapshot of snapshots) {
      insert.run({
        id: snapshot.id,
        owner_user_id: snapshot.userId ?? snapshot.ownerUserId,
        contact_id: snapshot.contactId,
        conversation_id: snapshot.conversationId,
        layer: snapshot.layer,
        summary: snapshot.summary,
        keywords_json: toJson(snapshot.keywords ?? []),
        emotion_label: snapshot.emotionLabel,
        warmth_score: snapshot.warmthScore,
        source_message_ids_json: toJson(snapshot.sourceMessageIds ?? []),
        created_at: snapshot.createdAt ?? isoNow()
      });
    }
  }

  listMemorySnapshotsForContact(contactId, limit = 18) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_memory_snapshots
         WHERE contact_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(contactId, limit)
      .map((row) => parseMemoryRow(row));
  }

  listMemorySnapshotsForConversation(conversationId, limit = 18) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_memory_snapshots
         WHERE conversation_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(conversationId, limit)
      .map((row) => parseMemoryRow(row));
  }

  replaceGroupMembers(groupId, members, nowIso = isoNow()) {
    const upsert = this.db.prepare(
      `INSERT INTO companion_group_members (
        id, group_id, member_key, role, display_name, contact_id, permissions_json, created_at, updated_at
      ) VALUES (
        @id, @group_id, @member_key, @role, @display_name, @contact_id, @permissions_json, @created_at, @updated_at
      )
      ON CONFLICT(group_id, member_key) DO UPDATE SET
        role = excluded.role,
        display_name = excluded.display_name,
        contact_id = excluded.contact_id,
        permissions_json = excluded.permissions_json,
        updated_at = excluded.updated_at`
    );
    for (const member of members) {
      upsert.run({
        id: member.id ?? stableId('companion-group-member', groupId, member.memberKey),
        group_id: groupId,
        member_key: member.memberKey,
        role: member.role,
        display_name: member.displayName,
        contact_id: member.contactId ?? null,
        permissions_json: toJson(member.permissions ?? {}),
        created_at: member.createdAt ?? nowIso,
        updated_at: member.updatedAt ?? nowIso
      });
    }
  }

  listGroupMembers(groupId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_group_members
         WHERE group_id = ?
         ORDER BY display_name ASC`
      )
      .all(groupId)
      .map((row) => parseGroupMemberRow(row));
  }

  createGroupVote(vote) {
    this.db
      .prepare(
        `INSERT INTO companion_group_votes (
          id, group_id, conversation_id, question, status, options_json, result_summary,
          created_by, route, created_at, updated_at
        ) VALUES (
          @id, @group_id, @conversation_id, @question, @status, @options_json, @result_summary,
          @created_by, @route, @created_at, @updated_at
        )`
      )
      .run({
        id: vote.id,
        group_id: vote.groupId,
        conversation_id: vote.conversationId,
        question: vote.question,
        status: vote.status,
        options_json: toJson(vote.options ?? []),
        result_summary: vote.resultSummary ?? null,
        created_by: vote.createdBy,
        route: vote.route,
        created_at: vote.createdAt ?? isoNow(),
        updated_at: vote.updatedAt ?? isoNow()
      });
    return this.findGroupVote(vote.id);
  }

  findGroupVote(voteId) {
    return parseVoteRow(this.db.prepare('SELECT * FROM companion_group_votes WHERE id = ?').get(voteId));
  }

  listGroupVotes(groupId, limit = 8) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_group_votes
         WHERE group_id = ?
         ORDER BY updated_at DESC
         LIMIT ?`
      )
      .all(groupId, limit)
      .map((row) => parseVoteRow(row));
  }

  saveGroupBallot({ voteId, voterKey, optionId, rationale = null, createdAt = isoNow() }) {
    const ballotId = stableId('companion-ballot', voteId, voterKey);
    this.db
      .prepare(
        `INSERT OR REPLACE INTO companion_group_vote_ballots (
          id, vote_id, voter_key, option_id, rationale, created_at
        ) VALUES (
          @id, @vote_id, @voter_key, @option_id, @rationale, @created_at
        )`
      )
      .run({
        id: ballotId,
        vote_id: voteId,
        voter_key: voterKey,
        option_id: optionId,
        rationale,
        created_at: createdAt
      });
    return parseBallotRow(this.db.prepare('SELECT * FROM companion_group_vote_ballots WHERE id = ?').get(ballotId));
  }

  listGroupBallots(voteId) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_group_vote_ballots
         WHERE vote_id = ?
         ORDER BY created_at ASC`
      )
      .all(voteId)
      .map((row) => parseBallotRow(row));
  }

  closeGroupVote({ voteId, resultSummary, nowIso = isoNow() }) {
    this.db
      .prepare(
        `UPDATE companion_group_votes
         SET status = 'closed',
             result_summary = @result_summary,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: voteId,
        result_summary: resultSummary,
        updated_at: nowIso
      });
    return this.findGroupVote(voteId);
  }

  saveGroupSummary({ groupId, conversationId, summary, includedMessageIds = [], suppressedCount = 0, nowIso = isoNow() }) {
    const summaryId = stableId('companion-group-summary', groupId, conversationId, nowIso, summary);
    this.db
      .prepare(
        `INSERT INTO companion_group_summaries (
          id, group_id, conversation_id, summary, included_message_ids_json, suppressed_count, created_at
        ) VALUES (
          @id, @group_id, @conversation_id, @summary, @included_message_ids_json, @suppressed_count, @created_at
        )`
      )
      .run({
        id: summaryId,
        group_id: groupId,
        conversation_id: conversationId,
        summary,
        included_message_ids_json: toJson(includedMessageIds),
        suppressed_count: suppressedCount,
        created_at: nowIso
      });
    return parseGroupSummaryRow(this.db.prepare('SELECT * FROM companion_group_summaries WHERE id = ?').get(summaryId));
  }

  listGroupSummaries(groupId, limit = 8) {
    return this.db
      .prepare(
        `SELECT *
         FROM companion_group_summaries
         WHERE group_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(groupId, limit)
      .map((row) => parseGroupSummaryRow(row));
  }

  inspectCounts(ownerUserId) {
    const count = (table, clause = '', values = []) =>
      Number(
        this.db
          .prepare(`SELECT COUNT(*) AS total FROM ${table} ${clause}`)
          .get(...values)?.total ?? 0
      );
    return {
      contacts: count('companion_contacts', 'WHERE owner_user_id = ?', [ownerUserId]),
      conversations: count('companion_conversations', 'WHERE owner_user_id = ?', [ownerUserId]),
      messages: count(
        'companion_messages',
        'WHERE conversation_id IN (SELECT id FROM companion_conversations WHERE owner_user_id = ?)',
        [ownerUserId]
      ),
      relationships: count('companion_relationships', 'WHERE owner_user_id = ?', [ownerUserId]),
      rituals: count(
        'companion_rituals',
        'WHERE conversation_id IN (SELECT id FROM companion_conversations WHERE owner_user_id = ?)',
        [ownerUserId]
      ),
      memories: count('companion_memory_snapshots', 'WHERE owner_user_id = ?', [ownerUserId]),
      masks: count(
        'companion_masks',
        'WHERE contact_id IN (SELECT id FROM companion_contacts WHERE owner_user_id = ?)',
        [ownerUserId]
      ),
      groups: count('companion_groups', 'WHERE owner_user_id = ?', [ownerUserId]),
      votes: count(
        'companion_group_votes',
        'WHERE group_id IN (SELECT id FROM companion_groups WHERE owner_user_id = ?)',
        [ownerUserId]
      ),
      summaries: count(
        'companion_group_summaries',
        'WHERE group_id IN (SELECT id FROM companion_groups WHERE owner_user_id = ?)',
        [ownerUserId]
      )
    };
  }
}
