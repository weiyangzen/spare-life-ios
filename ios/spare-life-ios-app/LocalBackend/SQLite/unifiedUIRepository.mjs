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
const migrationPath = resolve(__dirname, '../Migrations/006_unified_ui.sql');

function parseScrollStateRow(row) {
  if (!row) {
    return null;
  }
  return {
    userId: row.user_id,
    surfaceKey: row.surface_key,
    anchorCardId: row.anchor_card_id,
    anchorOffset: Number(row.anchor_offset),
    lastVisibleCardId: row.last_visible_card_id,
    metadata: fromJson(row.metadata_json, {}),
    updatedAt: row.updated_at
  };
}

function parseCardEventRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    surfaceKey: row.surface_key,
    cardId: row.card_id,
    cardType: row.card_type,
    referenceId: row.reference_id,
    eventType: row.event_type,
    route: row.route,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at
  };
}

export class UnifiedUIRepository {
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

  upsertFeedScrollState({
    userId,
    surfaceKey,
    anchorCardId = null,
    anchorOffset = 0,
    lastVisibleCardId = null,
    metadata = {},
    updatedAt = isoNow()
  }) {
    this.db
      .prepare(
        `INSERT INTO unified_feed_scroll_states (
          user_id, surface_key, anchor_card_id, anchor_offset, last_visible_card_id, metadata_json, updated_at
        ) VALUES (
          @user_id, @surface_key, @anchor_card_id, @anchor_offset, @last_visible_card_id, @metadata_json, @updated_at
        )
        ON CONFLICT(user_id, surface_key) DO UPDATE SET
          anchor_card_id = excluded.anchor_card_id,
          anchor_offset = excluded.anchor_offset,
          last_visible_card_id = excluded.last_visible_card_id,
          metadata_json = excluded.metadata_json,
          updated_at = excluded.updated_at`
      )
      .run({
        user_id: userId,
        surface_key: surfaceKey,
        anchor_card_id: sanitizeText(anchorCardId) || null,
        anchor_offset: Number(anchorOffset ?? 0),
        last_visible_card_id: sanitizeText(lastVisibleCardId) || null,
        metadata_json: toJson(metadata),
        updated_at: updatedAt
      });
    return this.findFeedScrollState(userId, surfaceKey);
  }

  findFeedScrollState(userId, surfaceKey) {
    return parseScrollStateRow(
      this.db
        .prepare(
          `SELECT *
           FROM unified_feed_scroll_states
           WHERE user_id = ? AND surface_key = ?
           LIMIT 1`
        )
        .get(userId, surfaceKey)
    );
  }

  listFeedScrollStates(userId) {
    return this.db
      .prepare(
        `SELECT *
         FROM unified_feed_scroll_states
         WHERE user_id = ?
         ORDER BY updated_at DESC`
      )
      .all(userId)
      .map((row) => parseScrollStateRow(row));
  }

  recordCardEvent({
    userId,
    surfaceKey,
    cardId,
    cardType,
    referenceId = null,
    eventType,
    route = null,
    detail = {},
    createdAt = isoNow()
  }) {
    const eventId = stableId(
      'unified-card-event',
      userId,
      surfaceKey,
      cardId,
      eventType,
      createdAt,
      JSON.stringify(detail)
    );
    this.db
      .prepare(
        `INSERT INTO unified_card_events (
          id, user_id, surface_key, card_id, card_type, reference_id, event_type, route, detail_json, created_at
        ) VALUES (
          @id, @user_id, @surface_key, @card_id, @card_type, @reference_id, @event_type, @route, @detail_json, @created_at
        )`
      )
      .run({
        id: eventId,
        user_id: userId,
        surface_key: surfaceKey,
        card_id: cardId,
        card_type: cardType,
        reference_id: sanitizeText(referenceId) || null,
        event_type: eventType,
        route: sanitizeText(route) || null,
        detail_json: toJson(detail),
        created_at: createdAt
      });
    return this.findCardEvent(eventId);
  }

  findCardEvent(eventId) {
    return parseCardEventRow(
      this.db
        .prepare(
          `SELECT *
           FROM unified_card_events
           WHERE id = ?
           LIMIT 1`
        )
        .get(eventId)
    );
  }

  listCardEvents(userId, limit = 120) {
    return this.db
      .prepare(
        `SELECT *
         FROM unified_card_events
         WHERE user_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(userId, limit)
      .map((row) => parseCardEventRow(row));
  }

  inspectUnifiedUIState(userId) {
    const count = (clause = '', values = []) =>
      Number(
        this.db
          .prepare(`SELECT COUNT(*) AS total FROM unified_card_events ${clause}`)
          .get(...values)?.total ?? 0
      );

    const groupedEvents = this.db
      .prepare(
        `SELECT surface_key, event_type, COUNT(*) AS total
         FROM unified_card_events
         WHERE user_id = ?
         GROUP BY surface_key, event_type
         ORDER BY surface_key ASC, event_type ASC`
      )
      .all(userId)
      .map((row) => ({
        surfaceKey: row.surface_key,
        eventType: row.event_type,
        total: Number(row.total)
      }));

    return {
      counts: {
        scrollStates: this.listFeedScrollStates(userId).length,
        cardEvents: count('WHERE user_id = ?', [userId])
      },
      groupedEvents,
      scrollStates: this.listFeedScrollStates(userId),
      recentEvents: this.listCardEvents(userId)
    };
  }
}
