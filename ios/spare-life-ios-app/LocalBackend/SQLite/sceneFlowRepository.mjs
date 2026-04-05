import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import {
  fromJson,
  stableId,
  toJson,
  uniqueStrings
} from '../../Domain/Models/sceneContracts.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationPath = resolve(__dirname, '../Migrations/001_scene_flow.sql');

function parseFeedRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    sceneKey: row.scene_key,
    scanTargetId: row.scan_target_id,
    summaryCard: fromJson(row.summary_card_json, {}),
    hotTakeCards: fromJson(row.hot_take_cards_json, []),
    riskCards: fromJson(row.risk_cards_json, []),
    clusters: fromJson(row.clusters_json, []),
    moderation: fromJson(row.moderation_json, {}),
    sourceFingerprint: row.source_fingerprint,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseCardRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    agentId: row.agent_id,
    userId: row.user_id,
    displayName: row.display_name,
    identityTags: fromJson(row.identity_tags_json, []),
    intentTags: fromJson(row.intent_tags_json, []),
    expertiseTags: fromJson(row.expertise_tags_json, []),
    publicBio: row.public_bio,
    allowsAgentIntro: Boolean(row.allows_agent_intro),
    visibilityScope: row.visibility_scope,
    privacyRadius: row.privacy_radius,
    trustScore: Number(row.trust_score),
    locationLabel: row.location_label
  };
}

function parseIntentRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    sceneKey: row.scene_key,
    initiatorUserId: row.initiator_user_id,
    targetAgentId: row.target_agent_id,
    title: row.title,
    message: row.message,
    chatMode: row.chat_mode,
    sceneTags: fromJson(row.scene_tags_json, []),
    route: row.route,
    riskStatus: row.risk_status,
    riskReason: row.risk_reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

export class SceneFlowRepository {
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

  upsertScanTarget(scanTarget, nowIso) {
    this.db
      .prepare(
        `INSERT INTO scan_targets (
          id, scene_key, raw_code, canonical_code, target_kind, source_type, title, location_label,
          scene_tags_json, created_at, last_scanned_at
        ) VALUES (
          @id, @scene_key, @raw_code, @canonical_code, @target_kind, @source_type, @title, @location_label,
          @scene_tags_json, @created_at, @last_scanned_at
        )
        ON CONFLICT(scene_key) DO UPDATE SET
          raw_code = excluded.raw_code,
          canonical_code = excluded.canonical_code,
          target_kind = excluded.target_kind,
          source_type = excluded.source_type,
          title = excluded.title,
          location_label = excluded.location_label,
          scene_tags_json = excluded.scene_tags_json,
          last_scanned_at = excluded.last_scanned_at`
      )
      .run({
        id: scanTarget.id,
        scene_key: scanTarget.sceneKey,
        raw_code: scanTarget.rawCode,
        canonical_code: scanTarget.canonicalCode,
        target_kind: scanTarget.targetKind,
        source_type: scanTarget.sourceType,
        title: scanTarget.title,
        location_label: scanTarget.locationLabel,
        scene_tags_json: toJson(scanTarget.sceneTags),
        created_at: nowIso,
        last_scanned_at: nowIso
      });

    return this.db
      .prepare(
        `SELECT id, scene_key, raw_code, canonical_code, target_kind, source_type, title, location_label,
                scene_tags_json, created_at, last_scanned_at
         FROM scan_targets
         WHERE scene_key = ?`
      )
      .get(scanTarget.sceneKey);
  }

  getFreshSceneFeed(sceneKey, nowIso) {
    const row = this.db
      .prepare(
        `SELECT *
         FROM scene_feeds
         WHERE scene_key = ? AND expires_at > ?
         LIMIT 1`
      )
      .get(sceneKey, nowIso);
    return parseFeedRow(row);
  }

  saveSceneExperience({
    scene,
    scanTargetId,
    approvedPosts,
    flaggedPosts,
    summaryCard,
    hotTakeCards,
    riskCards,
    traceability,
    clusters,
    moderationSummary,
    sourceFingerprint,
    expiresAt,
    activeAgents,
    agentPublicCards,
    nowIso
  }) {
    return this.withTransaction(() => {
      this.db.prepare('DELETE FROM scene_posts WHERE scene_key = ?').run(scene.sceneKey);
      this.db.prepare('DELETE FROM scene_agent_presence WHERE scene_key = ?').run(scene.sceneKey);

      const insertPost = this.db.prepare(
        `INSERT INTO scene_posts (
          id, scene_key, external_id, author_name, text, sentiment, engagement, created_at,
          topic_tags_json, is_flagged, flag_reason, source_agent_id
        ) VALUES (
          @id, @scene_key, @external_id, @author_name, @text, @sentiment, @engagement, @created_at,
          @topic_tags_json, @is_flagged, @flag_reason, @source_agent_id
        )`
      );

      for (const post of [...approvedPosts, ...flaggedPosts]) {
        insertPost.run({
          id: post.id,
          scene_key: scene.sceneKey,
          external_id: post.externalId,
          author_name: post.authorName,
          text: post.text,
          sentiment: post.sentiment,
          engagement: post.engagement,
          created_at: post.createdAt,
          topic_tags_json: toJson(post.topicTags),
          is_flagged: flaggedPosts.includes(post) ? 1 : 0,
          flag_reason: post.flagReason ?? null,
          source_agent_id: post.agentId ?? null
        });
      }

      const upsertCard = this.db.prepare(
        `INSERT INTO agent_public_cards (
          id, agent_id, user_id, display_name, identity_tags_json, intent_tags_json,
          expertise_tags_json, public_bio, allows_agent_intro, visibility_scope,
          privacy_radius, trust_score, location_label, created_at, updated_at
        ) VALUES (
          @id, @agent_id, @user_id, @display_name, @identity_tags_json, @intent_tags_json,
          @expertise_tags_json, @public_bio, @allows_agent_intro, @visibility_scope,
          @privacy_radius, @trust_score, @location_label, @created_at, @updated_at
        )
        ON CONFLICT(agent_id) DO UPDATE SET
          user_id = excluded.user_id,
          display_name = excluded.display_name,
          identity_tags_json = excluded.identity_tags_json,
          intent_tags_json = excluded.intent_tags_json,
          expertise_tags_json = excluded.expertise_tags_json,
          public_bio = excluded.public_bio,
          allows_agent_intro = excluded.allows_agent_intro,
          visibility_scope = excluded.visibility_scope,
          privacy_radius = excluded.privacy_radius,
          trust_score = excluded.trust_score,
          location_label = excluded.location_label,
          updated_at = excluded.updated_at`
      );

      for (const card of agentPublicCards) {
        upsertCard.run({
          id: card.id,
          agent_id: card.agentId,
          user_id: card.userId,
          display_name: card.displayName,
          identity_tags_json: toJson(card.identityTags),
          intent_tags_json: toJson(card.intentTags),
          expertise_tags_json: toJson(card.expertiseTags),
          public_bio: card.publicBio,
          allows_agent_intro: card.allowsAgentIntro ? 1 : 0,
          visibility_scope: card.visibilityScope,
          privacy_radius: card.privacyRadius,
          trust_score: card.trustScore,
          location_label: card.locationLabel,
          created_at: nowIso,
          updated_at: nowIso
        });
      }

      const insertPresence = this.db.prepare(
        `INSERT INTO scene_agent_presence (
          id, scene_key, agent_id, card_id, activity_score, freshness_score, match_score,
          trust_score, heat_score, masked_location_label, contact_hint, combined_tags_json,
          created_at, updated_at
        ) VALUES (
          @id, @scene_key, @agent_id, @card_id, @activity_score, @freshness_score, @match_score,
          @trust_score, @heat_score, @masked_location_label, @contact_hint, @combined_tags_json,
          @created_at, @updated_at
        )`
      );

      for (const agent of activeAgents) {
        const cardId =
          this.db.prepare('SELECT id FROM agent_public_cards WHERE agent_id = ?').get(agent.agentId)?.id ??
          stableId('agent-card', agent.agentId);
        insertPresence.run({
          id: agent.id,
          scene_key: scene.sceneKey,
          agent_id: agent.agentId,
          card_id: cardId,
          activity_score: agent.activityScore,
          freshness_score: agent.freshnessScore,
          match_score: agent.matchScore,
          trust_score: agent.trustScore,
          heat_score: agent.heatScore,
          masked_location_label: agent.maskedLocationLabel,
          contact_hint: agent.contactHint,
          combined_tags_json: toJson(uniqueStrings(agent.combinedTags)),
          created_at: nowIso,
          updated_at: nowIso
        });
      }

      const feedId = stableId('scene-feed', scene.sceneKey);
      this.db
        .prepare(
          `INSERT INTO scene_feeds (
            id, scene_key, scan_target_id, summary_card_json, hot_take_cards_json,
            risk_cards_json, clusters_json, moderation_json, source_fingerprint,
            expires_at, created_at, updated_at
          ) VALUES (
            @id, @scene_key, @scan_target_id, @summary_card_json, @hot_take_cards_json,
            @risk_cards_json, @clusters_json, @moderation_json, @source_fingerprint,
            @expires_at, @created_at, @updated_at
          )
          ON CONFLICT(scene_key) DO UPDATE SET
            scan_target_id = excluded.scan_target_id,
            summary_card_json = excluded.summary_card_json,
            hot_take_cards_json = excluded.hot_take_cards_json,
            risk_cards_json = excluded.risk_cards_json,
            clusters_json = excluded.clusters_json,
            moderation_json = excluded.moderation_json,
            source_fingerprint = excluded.source_fingerprint,
            expires_at = excluded.expires_at,
            updated_at = excluded.updated_at`
        )
        .run({
          id: feedId,
          scene_key: scene.sceneKey,
          scan_target_id: scanTargetId,
          summary_card_json: toJson(summaryCard),
          hot_take_cards_json: toJson(hotTakeCards),
          risk_cards_json: toJson(riskCards),
          clusters_json: toJson(clusters),
          moderation_json: toJson(moderationSummary),
          source_fingerprint: sourceFingerprint,
          expires_at: expiresAt,
          created_at: nowIso,
          updated_at: nowIso
        });

      this.db.prepare('DELETE FROM scene_summary_sources WHERE scene_feed_id = ?').run(feedId);
      const insertSummarySource = this.db.prepare(
        `INSERT INTO scene_summary_sources (
          scene_feed_id, card_type, cluster_key, post_id
        ) VALUES (
          @scene_feed_id, @card_type, @cluster_key, @post_id
        )`
      );
      for (const entry of traceability) {
        for (const postId of entry.sourcePostIds) {
          insertSummarySource.run({
            scene_feed_id: feedId,
            card_type: entry.cardType,
            cluster_key: entry.clusterKey,
            post_id: postId
          });
        }
      }

      return this.getSceneFeedByKey(scene.sceneKey);
    });
  }

  getSceneFeedByKey(sceneKey) {
    return parseFeedRow(
      this.db
        .prepare(
          `SELECT *
           FROM scene_feeds
           WHERE scene_key = ?
           LIMIT 1`
        )
        .get(sceneKey)
    );
  }

  listSceneAgentPresence(sceneKey, sortBy) {
    const orderBy = {
      hottest: 'presence.heat_score DESC, presence.trust_score DESC',
      newest: 'presence.freshness_score DESC, presence.activity_score DESC',
      best_match: 'presence.match_score DESC, presence.trust_score DESC',
      most_trusted: 'presence.trust_score DESC, presence.heat_score DESC'
    }[sortBy] ?? 'presence.match_score DESC, presence.trust_score DESC';

    const rows = this.db
      .prepare(
        `SELECT
            presence.id,
            presence.agent_id,
            cards.user_id,
            cards.display_name,
            cards.identity_tags_json,
            cards.intent_tags_json,
            cards.expertise_tags_json,
            cards.public_bio,
            cards.allows_agent_intro,
            cards.visibility_scope,
            cards.privacy_radius,
            presence.trust_score AS trust_score,
            presence.activity_score,
            presence.freshness_score,
            presence.match_score,
            presence.heat_score,
            presence.masked_location_label,
            presence.contact_hint,
            presence.combined_tags_json
         FROM scene_agent_presence AS presence
         JOIN agent_public_cards AS cards ON cards.id = presence.card_id
         WHERE presence.scene_key = ?
         ORDER BY ${orderBy}`
      )
      .all(sceneKey);

    return rows.map((row) => ({
      id: row.id,
      agentId: row.agent_id,
      userId: row.user_id,
      displayName: row.display_name,
      identityTags: fromJson(row.identity_tags_json, []),
      intentTags: fromJson(row.intent_tags_json, []),
      expertiseTags: fromJson(row.expertise_tags_json, []),
      publicBio: row.public_bio,
      allowsAgentIntro: Boolean(row.allows_agent_intro),
      visibilityScope: row.visibility_scope,
      privacyRadius: row.privacy_radius,
      trustScore: Number(row.trust_score),
      activityScore: Number(row.activity_score),
      freshnessScore: Number(row.freshness_score),
      matchScore: Number(row.match_score),
      heatScore: Number(row.heat_score),
      maskedLocationLabel: row.masked_location_label,
      contactHint: row.contact_hint,
      combinedTags: fromJson(row.combined_tags_json, [])
    }));
  }

  findAgentPublicCard(agentId) {
    return parseCardRow(this.db.prepare('SELECT * FROM agent_public_cards WHERE agent_id = ?').get(agentId));
  }

  countRecentIntentAttempts({ sceneKey, initiatorUserId, targetAgentId, cutoffIso }) {
    const row = this.db
      .prepare(
        `SELECT COUNT(*) AS total
         FROM social_intents
         WHERE scene_key = ?
           AND initiator_user_id = ?
           AND COALESCE(target_agent_id, '') = COALESCE(?, '')
           AND created_at >= ?`
      )
      .get(sceneKey, initiatorUserId, targetAgentId ?? null, cutoffIso);
    return Number(row?.total ?? 0);
  }

  saveIntentDraft(draft, nowIso) {
    this.db
      .prepare(
        `INSERT INTO social_intents (
          id, scene_key, initiator_user_id, target_agent_id, title, message,
          chat_mode, scene_tags_json, route, risk_status, risk_reason, created_at, updated_at
        ) VALUES (
          @id, @scene_key, @initiator_user_id, @target_agent_id, @title, @message,
          @chat_mode, @scene_tags_json, @route, @risk_status, @risk_reason, @created_at, @updated_at
        )`
      )
      .run({
        id: draft.id,
        scene_key: draft.sceneKey,
        initiator_user_id: draft.initiatorUserId,
        target_agent_id: draft.targetAgentId,
        title: draft.title,
        message: draft.message,
        chat_mode: draft.chatMode,
        scene_tags_json: toJson(draft.sceneTags),
        route: draft.route,
        risk_status: draft.riskStatus,
        risk_reason: draft.riskReason,
        created_at: draft.createdAt,
        updated_at: nowIso
      });

    return this.db.prepare('SELECT * FROM social_intents WHERE id = ?').get(draft.id);
  }

  listRecentIntentDrafts(initiatorUserId, limit = 12) {
    return this.db
      .prepare(
        `SELECT *
         FROM social_intents
         WHERE initiator_user_id = ?
         ORDER BY updated_at DESC
         LIMIT ?`
      )
      .all(initiatorUserId, limit)
      .map((row) => parseIntentRow(row));
  }

  listRecentSceneHomeEntries(limit = 8) {
    const rows = this.db
      .prepare(
        `SELECT
            targets.id,
            targets.scene_key,
            targets.title,
            targets.location_label,
            targets.scene_tags_json,
            targets.last_scanned_at,
            feeds.scan_target_id,
            feeds.summary_card_json,
            feeds.hot_take_cards_json,
            feeds.risk_cards_json,
            feeds.clusters_json,
            feeds.moderation_json,
            feeds.expires_at,
            feeds.updated_at,
            (
              SELECT COUNT(*)
              FROM scene_scan_events
              WHERE scene_key = targets.scene_key
            ) AS scan_count,
            (
              SELECT COUNT(*)
              FROM scene_agent_presence
              WHERE scene_key = targets.scene_key
            ) AS active_agent_count,
            (
              SELECT COUNT(*)
              FROM social_intents
              WHERE scene_key = targets.scene_key
            ) AS intent_count
         FROM scan_targets AS targets
         LEFT JOIN scene_feeds AS feeds ON feeds.scene_key = targets.scene_key
         ORDER BY targets.last_scanned_at DESC
         LIMIT ?`
      )
      .all(limit);

    return rows.map((row) => ({
      id: row.id,
      sceneKey: row.scene_key,
      title: row.title,
      locationLabel: row.location_label,
      sceneTags: fromJson(row.scene_tags_json, []),
      scanTargetId: row.scan_target_id ?? row.id,
      route:
        row.scan_target_id ?? row.id
          ? `sparelife://scene/discussion?scene_key=${encodeURIComponent(row.scene_key)}&scan_target_id=${encodeURIComponent(row.scan_target_id ?? row.id)}`
          : null,
      summaryCard: fromJson(row.summary_card_json, {}),
      hotTakeCards: fromJson(row.hot_take_cards_json, []),
      riskCards: fromJson(row.risk_cards_json, []),
      clusters: fromJson(row.clusters_json, []),
      moderation: fromJson(row.moderation_json, {}),
      expiresAt: row.expires_at,
      updatedAt: row.updated_at,
      lastScannedAt: row.last_scanned_at,
      scanCount: Number(row.scan_count ?? 0),
      activeAgentCount: Number(row.active_agent_count ?? 0),
      intentCount: Number(row.intent_count ?? 0)
    }));
  }

  logScanEvent({ sceneKey, scanTargetId, channel, sourceType, rawCode, usedCache, nowIso }) {
    this.db
      .prepare(
        `INSERT INTO scene_scan_events (
          id, scene_key, scan_target_id, channel, source_type, raw_code, used_cache, created_at
        ) VALUES (
          @id, @scene_key, @scan_target_id, @channel, @source_type, @raw_code, @used_cache, @created_at
        )`
      )
      .run({
        id: `scan_event_${randomUUID().replace(/-/g, '').slice(0, 16)}`,
        scene_key: sceneKey,
        scan_target_id: scanTargetId,
        channel,
        source_type: sourceType,
        raw_code: rawCode,
        used_cache: usedCache ? 1 : 0,
        created_at: nowIso
      });
  }

  inspectSceneState(sceneKey) {
    const counts = {
      scanEvents: this.db.prepare('SELECT COUNT(*) AS total FROM scene_scan_events WHERE scene_key = ?').get(sceneKey)
        ?.total,
      posts: this.db.prepare('SELECT COUNT(*) AS total FROM scene_posts WHERE scene_key = ?').get(sceneKey)?.total,
      flaggedPosts: this.db
        .prepare('SELECT COUNT(*) AS total FROM scene_posts WHERE scene_key = ? AND is_flagged = 1')
        .get(sceneKey)?.total,
      activeAgents: this.db
        .prepare('SELECT COUNT(*) AS total FROM scene_agent_presence WHERE scene_key = ?')
        .get(sceneKey)?.total,
      intents: this.db.prepare('SELECT COUNT(*) AS total FROM social_intents WHERE scene_key = ?').get(sceneKey)
        ?.total
    };
    return {
      counts: Object.fromEntries(Object.entries(counts).map(([key, value]) => [key, Number(value ?? 0)])),
      feed: this.getSceneFeedByKey(sceneKey)
    };
  }
}
