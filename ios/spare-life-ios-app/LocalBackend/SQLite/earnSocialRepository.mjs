import { randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import { buildBondRoute } from '../../Domain/Models/a2aContracts.mjs';
import {
  fromJson,
  isoNow,
  stableId,
  toJson
} from '../../Domain/Models/sceneContracts.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const migrationPath = resolve(__dirname, '../Migrations/003_earn_social_flow.sql');

function parseLaneRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    title: row.title,
    tone: row.tone,
    summary: row.summary,
    shortcutLabel: row.shortcut_label,
    keywords: fromJson(row.keywords_json, []),
    sortOrder: Number(row.sort_order),
    entryRoute: row.entry_route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseTemplateRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    laneId: row.lane_id,
    title: row.title,
    summary: row.summary,
    modeHints: fromJson(row.mode_hints_json, []),
    tags: fromJson(row.tags_json, []),
    formTemplate: fromJson(row.form_template_json, []),
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
    laneId: row.lane_id,
    displayName: row.display_name,
    personaTags: fromJson(row.persona_tags_json, []),
    expertiseTags: fromJson(row.expertise_tags_json, []),
    openHours: fromJson(row.open_hours_json, []),
    expectedPartner: fromJson(row.expected_partner_json, []),
    explanationTags: fromJson(row.explanation_tags_json, []),
    allowsAgentIntro: Boolean(row.allows_agent_intro),
    publicBio: row.public_bio,
    trustScore: Number(row.trust_score),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseIntentRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    laneId: row.lane_id,
    templateId: row.template_id,
    title: row.title,
    summary: row.summary,
    mode: row.mode,
    status: row.status,
    targetAgentId: row.target_agent_id,
    formPayload: fromJson(row.form_payload_json, {}),
    tags: fromJson(row.tags_json, []),
    rankingScore: Number(row.ranking_score),
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseEventRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    intentId: row.intent_id,
    eventType: row.event_type,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at
  };
}

function parseFeedbackRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    agentId: row.agent_id,
    laneId: row.lane_id,
    feedback: row.feedback,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at
  };
}

function parseIcebreakRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    laneId: row.lane_id,
    intentId: row.intent_id,
    initiatorUserId: row.initiator_user_id,
    targetAgentId: row.target_agent_id,
    counterpartUserId: row.counterpart_user_id,
    mode: row.mode,
    status: row.status,
    compatibilityScore: Number(row.compatibility_score),
    handoffRule: fromJson(row.handoff_rule_json, {}),
    consent: fromJson(row.consent_json, {}),
    summary: row.summary,
    route: row.route,
    humanThreadRoute: row.human_thread_route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseIcebreakMessageRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    sessionId: row.session_id,
    turnIndex: Number(row.turn_index),
    actorKind: row.actor_kind,
    stage: row.stage,
    content: row.content,
    auditStatus: row.audit_status,
    promptKind: row.prompt_kind,
    createdAt: row.created_at
  };
}

function parseAuditRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    sessionId: row.session_id,
    messageId: row.message_id,
    promptKind: row.prompt_kind,
    policyStatus: row.policy_status,
    policyResult: fromJson(row.policy_result_json, {}),
    createdAt: row.created_at
  };
}

function parseWalletRow(row) {
  if (!row) {
    return null;
  }
  return {
    userId: row.user_id,
    balance: Number(row.balance),
    frozenBalance: Number(row.frozen_balance),
    lifetimeEarned: Number(row.lifetime_earned),
    lifetimeSpent: Number(row.lifetime_spent),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseLedgerRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.user_id,
    laneId: row.lane_id,
    entryType: row.entry_type,
    amount: Number(row.amount),
    status: row.status,
    ruleKey: row.rule_key,
    referenceKind: row.reference_kind,
    referenceId: row.reference_id,
    dedupeKey: row.dedupe_key,
    riskStatus: row.risk_status,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at,
    settledAt: row.settled_at
  };
}

function parseLaneEventRow(row) {
  if (!row) {
    return null;
  }
  return {
    eventId: row.id,
    laneId: row.lane_id,
    title: row.title,
    summary: row.summary,
    heatDelta: Number(row.heat_delta),
    rewardAmount: Number(row.reward_amount),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseLaneHeatRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    laneId: row.lane_id,
    openIntents: Number(row.open_intents),
    activeIcebreaks: Number(row.active_icebreaks),
    activePersonas: Number(row.active_personas),
    activeArenaMatches: Number(row.active_arena_matches),
    eventHeat: Number(row.event_heat),
    engagementScore: Number(row.engagement_score),
    profitScore: Number(row.profit_score),
    supplyGapScore: Number(row.supply_gap_score),
    responseSpeedScore: Number(row.response_speed_score),
    heatScore: Number(row.heat_score),
    createdAt: row.created_at
  };
}

function parseArenaMatchRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    laneId: row.lane_id,
    theme: row.theme,
    challengerAgentId: row.challenger_agent_id,
    opponentAgentId: row.opponent_agent_id,
    createdByUserId: row.created_by_user_id,
    status: row.status,
    roundCount: Number(row.round_count),
    winnerSide: row.winner_side,
    scoreboard: fromJson(row.scoreboard_json, {}),
    recap: fromJson(row.recap_json, {}),
    route: row.route,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseArenaRoundRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    matchId: row.match_id,
    roundIndex: Number(row.round_index),
    prompt: row.prompt,
    challengerReply: row.challenger_reply,
    opponentReply: row.opponent_reply,
    judgeScore: fromJson(row.judge_score_json, {}),
    summary: row.summary,
    createdAt: row.created_at
  };
}

function parseArenaVoteRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    matchId: row.match_id,
    voterUserId: row.voter_user_id,
    preferredSide: row.preferred_side,
    weight: Number(row.weight),
    createdAt: row.created_at
  };
}

function parseBondRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    laneId: row.lane_id,
    sourceSessionId: row.source_session_id,
    initiatorUserId: row.initiator_user_id,
    counterpartUserId: row.counterpart_user_id,
    counterpartAgentId: row.counterpart_agent_id,
    level: row.level,
    strengthScore: Number(row.strength_score),
    status: row.status,
    milestoneCount: Number(row.milestone_count),
    memorialCard: fromJson(row.memorial_card_json, {}),
    threadRoute: row.thread_route,
    lastActivityAt: row.last_activity_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseBondTaskRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    bondId: row.bond_id,
    title: row.title,
    summary: row.summary,
    status: row.status,
    targetCount: Number(row.target_count),
    progressCount: Number(row.progress_count),
    rewardAmount: Number(row.reward_amount),
    milestoneKey: row.milestone_key,
    completedAt: row.completed_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseMilestoneRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    bondId: row.bond_id,
    milestoneKey: row.milestone_key,
    title: row.title,
    summary: row.summary,
    achievedAt: row.achieved_at
  };
}

function parseLeadRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    laneId: row.lane_id,
    intentId: row.intent_id,
    sourceSessionId: row.source_session_id,
    bondId: row.bond_id,
    initiatorUserId: row.initiator_user_id,
    counterpartUserId: row.counterpart_user_id,
    targetAgentId: row.target_agent_id,
    humanTakeover: Boolean(row.human_takeover),
    sourceRoute: row.source_route,
    route: row.route,
    currentStageKey: row.current_stage_key,
    currentStageLabel: row.current_stage_label,
    confirmations: fromJson(row.confirmations_json, {}),
    latestOutcomeCode: row.latest_outcome_code,
    latestOutcomeLabel: row.latest_outcome_label,
    latestOutcomeStatus: row.latest_outcome_status,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseLeadStageRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    leadId: row.lead_id,
    stageIndex: Number(row.stage_index),
    stageKey: row.stage_key,
    stageLabel: row.stage_label,
    actorKind: row.actor_kind,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at
  };
}

function parseLeadAuditRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    leadId: row.lead_id,
    eventType: row.event_type,
    actorKind: row.actor_kind,
    actorId: row.actor_id,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at
  };
}

function parseOutcomeRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    leadId: row.lead_id,
    laneId: row.lane_id,
    outcomeCode: row.outcome_code,
    outcomeLabel: row.outcome_label,
    outcomeStatus: row.outcome_status,
    recordedByUserId: row.recorded_by_user_id,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseLeadSettlementRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    leadId: row.lead_id,
    beneficiaryUserId: row.beneficiary_user_id,
    settlementType: row.settlement_type,
    amount: Number(row.amount),
    status: row.status,
    dedupeKey: row.dedupe_key,
    ledgerEntryId: row.ledger_entry_id,
    detail: fromJson(row.detail_json, {}),
    createdAt: row.created_at,
    settledAt: row.settled_at
  };
}

export class EarnSocialRepository {
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

  countRows(tableName) {
    return Number(this.db.prepare(`SELECT COUNT(*) AS total FROM ${tableName}`).get()?.total ?? 0);
  }

  seedLaneCatalog({ lanes, templatesByLane }, nowIso = isoNow()) {
    return this.withTransaction(() => {
      const upsertLane = this.db.prepare(
        `INSERT INTO a2a_lanes (
          id, title, tone, summary, shortcut_label, keywords_json, sort_order, entry_route, created_at, updated_at
        ) VALUES (
          @id, @title, @tone, @summary, @shortcut_label, @keywords_json, @sort_order, @entry_route, @created_at, @updated_at
        )
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          tone = excluded.tone,
          summary = excluded.summary,
          shortcut_label = excluded.shortcut_label,
          keywords_json = excluded.keywords_json,
          sort_order = excluded.sort_order,
          entry_route = excluded.entry_route,
          updated_at = excluded.updated_at`
      );
      const upsertTemplate = this.db.prepare(
        `INSERT INTO a2a_intent_templates (
          id, lane_id, title, summary, mode_hints_json, tags_json, form_template_json, created_at, updated_at
        ) VALUES (
          @id, @lane_id, @title, @summary, @mode_hints_json, @tags_json, @form_template_json, @created_at, @updated_at
        )
        ON CONFLICT(id) DO UPDATE SET
          lane_id = excluded.lane_id,
          title = excluded.title,
          summary = excluded.summary,
          mode_hints_json = excluded.mode_hints_json,
          tags_json = excluded.tags_json,
          form_template_json = excluded.form_template_json,
          updated_at = excluded.updated_at`
      );

      for (const lane of lanes) {
        upsertLane.run({
          id: lane.id,
          title: lane.title,
          tone: lane.tone,
          summary: lane.summary,
          shortcut_label: lane.shortcutLabel,
          keywords_json: toJson(lane.keywords),
          sort_order: lane.defaultSort,
          entry_route: lane.entryRoute ?? lane.route ?? `sparelife://earn-social/home?lane=${encodeURIComponent(lane.id)}`,
          created_at: nowIso,
          updated_at: nowIso
        });
      }

      for (const group of templatesByLane) {
        for (const template of group.templates) {
          upsertTemplate.run({
            id: template.id,
            lane_id: template.laneId,
            title: template.title,
            summary: template.summary,
            mode_hints_json: toJson(template.modeHints),
            tags_json: toJson(template.tags),
            form_template_json: toJson(template.formTemplate),
            created_at: nowIso,
            updated_at: nowIso
          });
        }
      }
    });
  }

  seedPublicAgentCards(cards, nowIso = isoNow()) {
    const upsertCard = this.db.prepare(
      `INSERT INTO a2a_public_agent_cards (
        id, agent_id, user_id, lane_id, display_name, persona_tags_json, expertise_tags_json, open_hours_json,
        expected_partner_json, explanation_tags_json, allows_agent_intro, public_bio, trust_score, created_at, updated_at
      ) VALUES (
        @id, @agent_id, @user_id, @lane_id, @display_name, @persona_tags_json, @expertise_tags_json, @open_hours_json,
        @expected_partner_json, @explanation_tags_json, @allows_agent_intro, @public_bio, @trust_score, @created_at, @updated_at
      )
      ON CONFLICT(agent_id) DO UPDATE SET
        user_id = excluded.user_id,
        lane_id = excluded.lane_id,
        display_name = excluded.display_name,
        persona_tags_json = excluded.persona_tags_json,
        expertise_tags_json = excluded.expertise_tags_json,
        open_hours_json = excluded.open_hours_json,
        expected_partner_json = excluded.expected_partner_json,
        explanation_tags_json = excluded.explanation_tags_json,
        allows_agent_intro = excluded.allows_agent_intro,
        public_bio = excluded.public_bio,
        trust_score = excluded.trust_score,
        updated_at = excluded.updated_at`
    );

    for (const card of cards) {
      upsertCard.run({
        id: stableId('a2a-public-card', card.agentId),
        agent_id: card.agentId,
        user_id: card.userId,
        lane_id: card.laneId,
        display_name: card.displayName,
        persona_tags_json: toJson(card.personaTags),
        expertise_tags_json: toJson(card.expertiseTags),
        open_hours_json: toJson(card.openHours),
        expected_partner_json: toJson(card.expectedPartner),
        explanation_tags_json: toJson(card.explanationTags),
        allows_agent_intro: card.allowsAgentIntro ? 1 : 0,
        public_bio: card.publicBio,
        trust_score: card.trustScore,
        created_at: nowIso,
        updated_at: nowIso
      });
    }
  }

  seedLaneEvents(events, nowIso = isoNow()) {
    const upsertEvent = this.db.prepare(
      `INSERT INTO a2a_lane_events (
        id, lane_id, title, summary, heat_delta, reward_amount, created_at, updated_at
      ) VALUES (
        @id, @lane_id, @title, @summary, @heat_delta, @reward_amount, @created_at, @updated_at
      )
      ON CONFLICT(id) DO UPDATE SET
        lane_id = excluded.lane_id,
        title = excluded.title,
        summary = excluded.summary,
        heat_delta = excluded.heat_delta,
        reward_amount = excluded.reward_amount,
        updated_at = excluded.updated_at`
    );

    for (const event of events) {
      upsertEvent.run({
        id: event.eventId,
        lane_id: event.laneId,
        title: event.title,
        summary: event.summary,
        heat_delta: event.heatDelta,
        reward_amount: event.rewardAmount,
        created_at: nowIso,
        updated_at: nowIso
      });
    }
  }

  seedIntentCandidates(candidates, nowIso = isoNow()) {
    if (this.countRows('a2a_intent_posts') > 0) {
      return;
    }
    for (const candidate of candidates) {
      this.createIntentPost(
        {
          id: candidate.intentId,
          userId: candidate.userId,
          laneId: candidate.laneId,
          templateId: candidate.template.id,
          title: candidate.title,
          summary: candidate.summary,
          mode: candidate.mode,
          status: candidate.status,
          targetAgentId: candidate.targetAgentId ?? null,
          formPayload: candidate.normalizedForm,
          tags: candidate.tags,
          rankingScore: candidate.rankingScore,
          route: candidate.route
        },
        nowIso
      );
      this.recordIntentEvent(candidate.intentId, 'seeded', { source: 'bootstrap' }, nowIso);
    }
  }

  listLanes() {
    return this.db
      .prepare('SELECT * FROM a2a_lanes ORDER BY sort_order ASC')
      .all()
      .map(parseLaneRow);
  }

  listTemplatesForLane(laneId) {
    return this.db
      .prepare('SELECT * FROM a2a_intent_templates WHERE lane_id = ? ORDER BY title ASC')
      .all(laneId)
      .map(parseTemplateRow);
  }

  listLaneEvents() {
    return this.db.prepare('SELECT * FROM a2a_lane_events ORDER BY created_at ASC').all().map(parseLaneEventRow);
  }

  findLaneEvent(eventId) {
    return parseLaneEventRow(this.db.prepare('SELECT * FROM a2a_lane_events WHERE id = ?').get(eventId));
  }

  listPublicAgentCards(laneId = null) {
    const rows = this.db.prepare('SELECT * FROM a2a_public_agent_cards ORDER BY trust_score DESC, display_name ASC').all();
    return rows.map(parseCardRow).filter((card) => !laneId || card.laneId === laneId);
  }

  findPublicAgentCard(agentId) {
    return parseCardRow(this.db.prepare('SELECT * FROM a2a_public_agent_cards WHERE agent_id = ?').get(agentId));
  }

  recordPersonaFeedback({ userId, agentId, laneId, feedback, detail = {}, nowIso = isoNow() }) {
    const feedbackId = `a2a_feedback_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO a2a_persona_feedback_events (
          id, user_id, agent_id, lane_id, feedback, detail_json, created_at
        ) VALUES (
          @id, @user_id, @agent_id, @lane_id, @feedback, @detail_json, @created_at
        )`
      )
      .run({
        id: feedbackId,
        user_id: userId,
        agent_id: agentId,
        lane_id: laneId,
        feedback,
        detail_json: toJson(detail),
        created_at: nowIso
      });
    return parseFeedbackRow(this.db.prepare('SELECT * FROM a2a_persona_feedback_events WHERE id = ?').get(feedbackId));
  }

  listPersonaFeedback(userId, laneId = null) {
    const rows = this.db
      .prepare('SELECT * FROM a2a_persona_feedback_events WHERE user_id = ? ORDER BY created_at DESC')
      .all(userId);
    return rows.map(parseFeedbackRow).filter((row) => !laneId || row.laneId === laneId);
  }

  createIntentPost(intent, nowIso = isoNow()) {
    this.db
      .prepare(
        `INSERT INTO a2a_intent_posts (
          id, user_id, lane_id, template_id, title, summary, mode, status, target_agent_id,
          form_payload_json, tags_json, ranking_score, route, created_at, updated_at
        ) VALUES (
          @id, @user_id, @lane_id, @template_id, @title, @summary, @mode, @status, @target_agent_id,
          @form_payload_json, @tags_json, @ranking_score, @route, @created_at, @updated_at
        )`
      )
      .run({
        id: intent.id,
        user_id: intent.userId,
        lane_id: intent.laneId,
        template_id: intent.templateId,
        title: intent.title,
        summary: intent.summary,
        mode: intent.mode,
        status: intent.status,
        target_agent_id: intent.targetAgentId,
        form_payload_json: toJson(intent.formPayload),
        tags_json: toJson(intent.tags),
        ranking_score: intent.rankingScore,
        route: intent.route,
        created_at: nowIso,
        updated_at: nowIso
      });
    return this.findIntentPost(intent.id);
  }

  findIntentPost(intentId) {
    return parseIntentRow(this.db.prepare('SELECT * FROM a2a_intent_posts WHERE id = ?').get(intentId));
  }

  updateIntentStatus(intentId, status, detail = {}, nowIso = isoNow()) {
    this.db
      .prepare('UPDATE a2a_intent_posts SET status = ?, updated_at = ? WHERE id = ?')
      .run(status, nowIso, intentId);
    this.recordIntentEvent(intentId, `status:${status}`, detail, nowIso);
    return this.findIntentPost(intentId);
  }

  recordIntentEvent(intentId, eventType, detail = {}, nowIso = isoNow()) {
    const eventId = `a2a_intent_event_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO a2a_intent_events (
          id, intent_id, event_type, detail_json, created_at
        ) VALUES (
          @id, @intent_id, @event_type, @detail_json, @created_at
        )`
      )
      .run({
        id: eventId,
        intent_id: intentId,
        event_type: eventType,
        detail_json: toJson(detail),
        created_at: nowIso
      });
    return parseEventRow(this.db.prepare('SELECT * FROM a2a_intent_events WHERE id = ?').get(eventId));
  }

  listIntentEvents(intentId) {
    return this.db
      .prepare('SELECT * FROM a2a_intent_events WHERE intent_id = ? ORDER BY created_at ASC')
      .all(intentId)
      .map(parseEventRow);
  }

  listIntentPosts({ laneId = null, statuses = [], userId = null, limit = 20 } = {}) {
    const rows = this.db.prepare('SELECT * FROM a2a_intent_posts ORDER BY created_at DESC').all();
    return rows
      .map(parseIntentRow)
      .filter((intent) => (!laneId || intent.laneId === laneId) && (!userId || intent.userId === userId) && (!statuses.length || statuses.includes(intent.status)))
      .slice(0, limit);
  }

  listIntentHistoryForUser(userId, laneId = null, limit = 20) {
    return this.listIntentPosts({
      userId,
      laneId,
      statuses: [],
      limit
    });
  }

  ensureWallet(userId, nowIso = isoNow()) {
    this.db
      .prepare(
        `INSERT INTO a2a_energy_wallets (
          user_id, balance, frozen_balance, lifetime_earned, lifetime_spent, created_at, updated_at
        ) VALUES (
          @user_id, 0, 0, 0, 0, @created_at, @updated_at
        )
        ON CONFLICT(user_id) DO NOTHING`
      )
      .run({
        user_id: userId,
        created_at: nowIso,
        updated_at: nowIso
      });
    return this.getWallet(userId);
  }

  getWallet(userId) {
    return parseWalletRow(this.db.prepare('SELECT * FROM a2a_energy_wallets WHERE user_id = ?').get(userId));
  }

  findLedgerByDedupeKey(dedupeKey) {
    if (!dedupeKey) {
      return null;
    }
    return parseLedgerRow(this.db.prepare('SELECT * FROM a2a_energy_ledger WHERE dedupe_key = ?').get(dedupeKey));
  }

  adjustWallet(userId, { balanceDelta = 0, frozenDelta = 0, earnedDelta = 0, spentDelta = 0, nowIso = isoNow() }) {
    this.ensureWallet(userId, nowIso);
    this.db
      .prepare(
        `UPDATE a2a_energy_wallets
         SET balance = balance + @balance_delta,
             frozen_balance = frozen_balance + @frozen_delta,
             lifetime_earned = lifetime_earned + @earned_delta,
             lifetime_spent = lifetime_spent + @spent_delta,
             updated_at = @updated_at
         WHERE user_id = @user_id`
      )
      .run({
        user_id: userId,
        balance_delta: balanceDelta,
        frozen_delta: frozenDelta,
        earned_delta: earnedDelta,
        spent_delta: spentDelta,
        updated_at: nowIso
      });
    return this.getWallet(userId);
  }

  insertLedgerEntry({
    userId,
    laneId = null,
    entryType,
    amount,
    status,
    ruleKey,
    referenceKind,
    referenceId = null,
    dedupeKey = null,
    riskStatus = 'clear',
    detail = {},
    nowIso = isoNow(),
    settledAt = null
  }) {
    const ledgerId = `a2a_ledger_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO a2a_energy_ledger (
          id, user_id, lane_id, entry_type, amount, status, rule_key, reference_kind, reference_id,
          dedupe_key, risk_status, detail_json, created_at, settled_at
        ) VALUES (
          @id, @user_id, @lane_id, @entry_type, @amount, @status, @rule_key, @reference_kind, @reference_id,
          @dedupe_key, @risk_status, @detail_json, @created_at, @settled_at
        )`
      )
      .run({
        id: ledgerId,
        user_id: userId,
        lane_id: laneId,
        entry_type: entryType,
        amount,
        status,
        rule_key: ruleKey,
        reference_kind: referenceKind,
        reference_id: referenceId,
        dedupe_key: dedupeKey,
        risk_status: riskStatus,
        detail_json: toJson(detail),
        created_at: nowIso,
        settled_at: settledAt
      });
    return parseLedgerRow(this.db.prepare('SELECT * FROM a2a_energy_ledger WHERE id = ?').get(ledgerId));
  }

  awardEnergy({ userId, laneId = null, amount, ruleKey, referenceKind, referenceId = null, dedupeKey = null, detail = {}, nowIso = isoNow() }) {
    const duplicate = this.findLedgerByDedupeKey(dedupeKey);
    if (duplicate) {
      return {
        applied: false,
        reason: 'duplicate_rule',
        entry: duplicate,
        wallet: this.getWallet(userId)
      };
    }
    const entry = this.insertLedgerEntry({
      userId,
      laneId,
      entryType: 'income',
      amount,
      status: 'posted',
      ruleKey,
      referenceKind,
      referenceId,
      dedupeKey,
      detail,
      nowIso
    });
    const wallet = this.adjustWallet(userId, {
      balanceDelta: amount,
      earnedDelta: amount,
      nowIso
    });
    return {
      applied: true,
      entry,
      wallet
    };
  }

  spendEnergy({ userId, laneId = null, amount, ruleKey, referenceKind, referenceId = null, dedupeKey = null, detail = {}, nowIso = isoNow() }) {
    const duplicate = this.findLedgerByDedupeKey(dedupeKey);
    if (duplicate) {
      return {
        applied: false,
        reason: 'duplicate_rule',
        entry: duplicate,
        wallet: this.getWallet(userId)
      };
    }
    const wallet = this.ensureWallet(userId, nowIso);
    if (wallet.balance < amount) {
      return {
        applied: false,
        reason: 'insufficient_balance',
        entry: null,
        wallet
      };
    }
    const entry = this.insertLedgerEntry({
      userId,
      laneId,
      entryType: 'expense',
      amount: -Math.abs(amount),
      status: 'posted',
      ruleKey,
      referenceKind,
      referenceId,
      dedupeKey,
      detail,
      nowIso
    });
    const updatedWallet = this.adjustWallet(userId, {
      balanceDelta: -Math.abs(amount),
      spentDelta: Math.abs(amount),
      nowIso
    });
    return {
      applied: true,
      entry,
      wallet: updatedWallet
    };
  }

  freezeEnergy({ userId, laneId = null, amount, ruleKey, referenceKind, referenceId = null, dedupeKey = null, detail = {}, nowIso = isoNow() }) {
    const duplicate = this.findLedgerByDedupeKey(dedupeKey);
    if (duplicate) {
      return {
        applied: false,
        reason: 'duplicate_rule',
        entry: duplicate,
        wallet: this.getWallet(userId)
      };
    }
    const wallet = this.ensureWallet(userId, nowIso);
    if (wallet.balance < amount) {
      return {
        applied: false,
        reason: 'insufficient_balance',
        entry: null,
        wallet
      };
    }
    const entry = this.insertLedgerEntry({
      userId,
      laneId,
      entryType: 'freeze',
      amount,
      status: 'frozen',
      ruleKey,
      referenceKind,
      referenceId,
      dedupeKey,
      detail,
      nowIso
    });
    const updatedWallet = this.adjustWallet(userId, {
      balanceDelta: -Math.abs(amount),
      frozenDelta: Math.abs(amount),
      nowIso
    });
    return {
      applied: true,
      entry,
      wallet: updatedWallet
    };
  }

  settleFrozenEnergy({ userId, laneId = null, amount, releaseFrozenAmount, ruleKey, referenceKind, referenceId = null, dedupeKey = null, detail = {}, nowIso = isoNow() }) {
    const duplicate = this.findLedgerByDedupeKey(dedupeKey);
    if (duplicate) {
      return {
        applied: false,
        reason: 'duplicate_rule',
        entry: duplicate,
        wallet: this.getWallet(userId)
      };
    }
    const entry = this.insertLedgerEntry({
      userId,
      laneId,
      entryType: 'settlement',
      amount,
      status: 'settled',
      ruleKey,
      referenceKind,
      referenceId,
      dedupeKey,
      detail: {
        ...detail,
        releaseFrozenAmount
      },
      nowIso,
      settledAt: nowIso
    });
    const updatedWallet = this.adjustWallet(userId, {
      balanceDelta: releaseFrozenAmount + amount,
      frozenDelta: -Math.abs(releaseFrozenAmount),
      earnedDelta: amount > 0 ? amount : 0,
      spentDelta: amount < 0 ? Math.abs(amount) : 0,
      nowIso
    });
    return {
      applied: true,
      entry,
      wallet: updatedWallet
    };
  }

  listEnergyLedger(userId, limit = 20) {
    return this.db
      .prepare('SELECT * FROM a2a_energy_ledger WHERE user_id = ? ORDER BY created_at DESC')
      .all(userId)
      .map(parseLedgerRow)
      .slice(0, limit);
  }

  createIcebreakSession({ session, messages }, nowIso = isoNow()) {
    return this.withTransaction(() => {
      this.db
        .prepare(
          `INSERT INTO a2a_icebreak_sessions (
            id, lane_id, intent_id, initiator_user_id, target_agent_id, counterpart_user_id,
            mode, status, compatibility_score, handoff_rule_json, consent_json, summary,
            route, human_thread_route, created_at, updated_at
          ) VALUES (
            @id, @lane_id, @intent_id, @initiator_user_id, @target_agent_id, @counterpart_user_id,
            @mode, @status, @compatibility_score, @handoff_rule_json, @consent_json, @summary,
            @route, @human_thread_route, @created_at, @updated_at
          )`
        )
        .run({
          id: session.sessionId,
          lane_id: session.laneId,
          intent_id: session.intentId,
          initiator_user_id: session.initiatorUserId,
          target_agent_id: session.targetAgentId,
          counterpart_user_id: session.counterpartUserId,
          mode: session.mode,
          status: session.status,
          compatibility_score: session.compatibilityScore,
          handoff_rule_json: toJson(session.handoffRule),
          consent_json: toJson(session.consent),
          summary: session.summary,
          route: session.route,
          human_thread_route: session.humanThreadRoute ?? null,
          created_at: nowIso,
          updated_at: nowIso
        });

      const insertMessage = this.db.prepare(
        `INSERT INTO a2a_icebreak_messages (
          id, session_id, turn_index, actor_kind, stage, content, audit_status, prompt_kind, created_at
        ) VALUES (
          @id, @session_id, @turn_index, @actor_kind, @stage, @content, @audit_status, @prompt_kind, @created_at
        )`
      );
      const insertAudit = this.db.prepare(
        `INSERT INTO a2a_icebreak_audit_logs (
          id, session_id, message_id, prompt_kind, policy_status, policy_result_json, created_at
        ) VALUES (
          @id, @session_id, @message_id, @prompt_kind, @policy_status, @policy_result_json, @created_at
        )`
      );

      for (const [index, message] of messages.entries()) {
        insertMessage.run({
          id: message.messageId,
          session_id: session.sessionId,
          turn_index: index + 1,
          actor_kind: message.actorKind,
          stage: message.stage,
          content: message.content,
          audit_status: message.audit.status,
          prompt_kind: message.stage,
          created_at: message.createdAt ?? nowIso
        });
        insertAudit.run({
          id: stableId('icebreak-audit', session.sessionId, message.messageId),
          session_id: session.sessionId,
          message_id: message.messageId,
          prompt_kind: message.stage,
          policy_status: message.audit.status,
          policy_result_json: toJson(message.audit),
          created_at: message.createdAt ?? nowIso
        });
      }

      return this.findIcebreakSession(session.sessionId);
    });
  }

  findIcebreakSession(sessionId) {
    return parseIcebreakRow(this.db.prepare('SELECT * FROM a2a_icebreak_sessions WHERE id = ?').get(sessionId));
  }

  updateIcebreakSession({ sessionId, status, consent, summary, humanThreadRoute = null, nowIso = isoNow() }) {
    this.db
      .prepare(
        `UPDATE a2a_icebreak_sessions
         SET status = @status,
             consent_json = @consent_json,
             summary = @summary,
             human_thread_route = @human_thread_route,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: sessionId,
        status,
        consent_json: toJson(consent),
        summary,
        human_thread_route: humanThreadRoute,
        updated_at: nowIso
      });
    return this.findIcebreakSession(sessionId);
  }

  listIcebreakMessages(sessionId) {
    return this.db
      .prepare('SELECT * FROM a2a_icebreak_messages WHERE session_id = ? ORDER BY turn_index ASC')
      .all(sessionId)
      .map(parseIcebreakMessageRow);
  }

  listIcebreakAuditLogs(sessionId) {
    return this.db
      .prepare('SELECT * FROM a2a_icebreak_audit_logs WHERE session_id = ? ORDER BY created_at ASC')
      .all(sessionId)
      .map(parseAuditRow);
  }

  listIcebreakSessions({ userId = null, laneId = null, statuses = [], limit = 20 } = {}) {
    return this.db
      .prepare('SELECT * FROM a2a_icebreak_sessions ORDER BY updated_at DESC')
      .all()
      .map(parseIcebreakRow)
      .filter((session) => (!userId || session.initiatorUserId === userId) && (!laneId || session.laneId === laneId) && (!statuses.length || statuses.includes(session.status)))
      .slice(0, limit);
  }

  saveLaneHeatSnapshots(snapshots, nowIso = isoNow()) {
    return this.withTransaction(() => {
      const insertSnapshot = this.db.prepare(
        `INSERT INTO a2a_lane_heat_snapshots (
          id, lane_id, open_intents, active_icebreaks, active_personas, active_arena_matches,
          event_heat, engagement_score, profit_score, supply_gap_score, response_speed_score,
          heat_score, created_at
        ) VALUES (
          @id, @lane_id, @open_intents, @active_icebreaks, @active_personas, @active_arena_matches,
          @event_heat, @engagement_score, @profit_score, @supply_gap_score, @response_speed_score,
          @heat_score, @created_at
        )`
      );

      for (const snapshot of snapshots) {
        insertSnapshot.run({
          id: stableId('a2a-lane-heat', snapshot.laneId, nowIso),
          lane_id: snapshot.laneId,
          open_intents: snapshot.openIntents,
          active_icebreaks: snapshot.activeIcebreaks,
          active_personas: snapshot.activePersonas,
          active_arena_matches: snapshot.activeArenaMatches,
          event_heat: snapshot.eventHeat,
          engagement_score: snapshot.engagementScore,
          profit_score: snapshot.profitScore,
          supply_gap_score: snapshot.supplyGapScore,
          response_speed_score: snapshot.responseSpeedScore,
          heat_score: snapshot.heatScore,
          created_at: nowIso
        });
      }
    });
  }

  listLatestLaneHeatSnapshots() {
    const rows = this.db
      .prepare(
        `SELECT snapshot.*
         FROM a2a_lane_heat_snapshots AS snapshot
         JOIN (
           SELECT lane_id, MAX(created_at) AS latest_created_at
           FROM a2a_lane_heat_snapshots
           GROUP BY lane_id
         ) AS latest
         ON latest.lane_id = snapshot.lane_id AND latest.latest_created_at = snapshot.created_at`
      )
      .all();
    return rows.map(parseLaneHeatRow);
  }

  recordLaneExplorationReward({ userId, laneId, eventId, ledgerEntryId, nowIso = isoNow() }) {
    const rewardId = stableId('a2a-lane-reward', userId, eventId, ledgerEntryId);
    this.db
      .prepare(
        `INSERT OR REPLACE INTO a2a_lane_exploration_rewards (
          id, user_id, lane_id, event_id, ledger_entry_id, created_at
        ) VALUES (
          @id, @user_id, @lane_id, @event_id, @ledger_entry_id, @created_at
        )`
      )
      .run({
        id: rewardId,
        user_id: userId,
        lane_id: laneId,
        event_id: eventId,
        ledger_entry_id: ledgerEntryId,
        created_at: nowIso
      });
    return {
      id: rewardId,
      userId,
      laneId,
      eventId,
      ledgerEntryId,
      createdAt: nowIso
    };
  }

  createArenaMatch({ match, rounds }, nowIso = isoNow()) {
    return this.withTransaction(() => {
      this.db
        .prepare(
          `INSERT INTO a2a_arena_matches (
            id, lane_id, theme, challenger_agent_id, opponent_agent_id, created_by_user_id,
            status, round_count, winner_side, scoreboard_json, recap_json, route, created_at, updated_at
          ) VALUES (
            @id, @lane_id, @theme, @challenger_agent_id, @opponent_agent_id, @created_by_user_id,
            @status, @round_count, @winner_side, @scoreboard_json, @recap_json, @route, @created_at, @updated_at
          )`
        )
        .run({
          id: match.matchId,
          lane_id: match.laneId,
          theme: match.theme,
          challenger_agent_id: match.challengerAgentId,
          opponent_agent_id: match.opponentAgentId,
          created_by_user_id: match.createdByUserId,
          status: match.status,
          round_count: rounds.length,
          winner_side: null,
          scoreboard_json: toJson({}),
          recap_json: toJson({}),
          route: match.route,
          created_at: nowIso,
          updated_at: nowIso
        });

      const insertRound = this.db.prepare(
        `INSERT INTO a2a_arena_rounds (
          id, match_id, round_index, prompt, challenger_reply, opponent_reply, judge_score_json, summary, created_at
        ) VALUES (
          @id, @match_id, @round_index, @prompt, @challenger_reply, @opponent_reply, @judge_score_json, @summary, @created_at
        )`
      );

      for (const round of rounds) {
        insertRound.run({
          id: stableId('arena-round', match.matchId, round.roundIndex),
          match_id: match.matchId,
          round_index: round.roundIndex,
          prompt: round.prompt,
          challenger_reply: round.challengerReply,
          opponent_reply: round.opponentReply,
          judge_score_json: toJson(round.judgeScore ?? {}),
          summary: round.summary ?? '',
          created_at: nowIso
        });
      }

      return this.findArenaMatch(match.matchId);
    });
  }

  findArenaMatch(matchId) {
    return parseArenaMatchRow(this.db.prepare('SELECT * FROM a2a_arena_matches WHERE id = ?').get(matchId));
  }

  listArenaRounds(matchId) {
    return this.db
      .prepare('SELECT * FROM a2a_arena_rounds WHERE match_id = ? ORDER BY round_index ASC')
      .all(matchId)
      .map(parseArenaRoundRow);
  }

  recordArenaVote({ matchId, voterUserId, preferredSide, weight = 1, nowIso = isoNow() }) {
    const voteId = `arena_vote_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO a2a_arena_votes (
          id, match_id, voter_user_id, preferred_side, weight, created_at
        ) VALUES (
          @id, @match_id, @voter_user_id, @preferred_side, @weight, @created_at
        )`
      )
      .run({
        id: voteId,
        match_id: matchId,
        voter_user_id: voterUserId,
        preferred_side: preferredSide,
        weight,
        created_at: nowIso
      });
    return parseArenaVoteRow(this.db.prepare('SELECT * FROM a2a_arena_votes WHERE id = ?').get(voteId));
  }

  listArenaVotes(matchId) {
    return this.db
      .prepare('SELECT * FROM a2a_arena_votes WHERE match_id = ? ORDER BY created_at ASC')
      .all(matchId)
      .map(parseArenaVoteRow);
  }

  resolveArenaMatch({ matchId, winnerSide, scoreboard, recap, rounds, nowIso = isoNow() }) {
    return this.withTransaction(() => {
      const updateRound = this.db.prepare(
        `UPDATE a2a_arena_rounds
         SET judge_score_json = @judge_score_json,
             summary = @summary
         WHERE id = @id`
      );
      for (const round of rounds) {
        updateRound.run({
          id: stableId('arena-round', matchId, round.roundIndex),
          judge_score_json: toJson(round),
          summary: round.summary
        });
      }

      this.db
        .prepare(
          `UPDATE a2a_arena_matches
           SET status = 'resolved',
               winner_side = @winner_side,
               scoreboard_json = @scoreboard_json,
               recap_json = @recap_json,
               updated_at = @updated_at
           WHERE id = @id`
        )
        .run({
          id: matchId,
          winner_side: winnerSide,
          scoreboard_json: toJson(scoreboard),
          recap_json: toJson(recap),
          updated_at: nowIso
        });

      return this.findArenaMatch(matchId);
    });
  }

  listArenaMatches({ laneId = null, statuses = [], limit = 10 } = {}) {
    return this.db
      .prepare('SELECT * FROM a2a_arena_matches ORDER BY updated_at DESC')
      .all()
      .map(parseArenaMatchRow)
      .filter((match) => (!laneId || match.laneId === laneId) && (!statuses.length || statuses.includes(match.status)))
      .slice(0, limit);
  }

  findBondBySession(sessionId) {
    return parseBondRow(this.db.prepare('SELECT * FROM a2a_bond_relationships WHERE source_session_id = ?').get(sessionId));
  }

  findBond(bondId) {
    return parseBondRow(this.db.prepare('SELECT * FROM a2a_bond_relationships WHERE id = ?').get(bondId));
  }

  createBondRelationship({ bond, tasks }, nowIso = isoNow()) {
    return this.withTransaction(() => {
      this.db
        .prepare(
          `INSERT INTO a2a_bond_relationships (
            id, lane_id, source_session_id, initiator_user_id, counterpart_user_id, counterpart_agent_id,
            level, strength_score, status, milestone_count, memorial_card_json, thread_route,
            last_activity_at, created_at, updated_at
          ) VALUES (
            @id, @lane_id, @source_session_id, @initiator_user_id, @counterpart_user_id, @counterpart_agent_id,
            @level, @strength_score, @status, @milestone_count, @memorial_card_json, @thread_route,
            @last_activity_at, @created_at, @updated_at
          )`
        )
        .run({
          id: bond.bondId,
          lane_id: bond.laneId,
          source_session_id: bond.sourceSessionId,
          initiator_user_id: bond.initiatorUserId,
          counterpart_user_id: bond.counterpartUserId,
          counterpart_agent_id: bond.counterpartAgentId,
          level: bond.level,
          strength_score: bond.strengthScore,
          status: bond.status,
          milestone_count: 0,
          memorial_card_json: toJson(bond.memorialCard),
          thread_route: bond.threadRoute,
          last_activity_at: nowIso,
          created_at: nowIso,
          updated_at: nowIso
        });

      const insertTask = this.db.prepare(
        `INSERT INTO a2a_bond_tasks (
          id, bond_id, title, summary, status, target_count, progress_count, reward_amount,
          milestone_key, completed_at, created_at, updated_at
        ) VALUES (
          @id, @bond_id, @title, @summary, @status, @target_count, @progress_count, @reward_amount,
          @milestone_key, @completed_at, @created_at, @updated_at
        )`
      );

      for (const task of tasks) {
        insertTask.run({
          id: task.taskId,
          bond_id: bond.bondId,
          title: task.title,
          summary: task.summary,
          status: 'open',
          target_count: task.targetCount,
          progress_count: 0,
          reward_amount: task.rewardAmount,
          milestone_key: task.milestoneKey,
          completed_at: null,
          created_at: nowIso,
          updated_at: nowIso
        });
      }
      return this.findBond(bond.bondId);
    });
  }

  createThreadMigration({ bondId, sessionId, messagesRoute, nowIso = isoNow() }) {
    const migrationId = stableId('a2a-thread-migration', bondId, sessionId);
    this.db
      .prepare(
        `INSERT OR REPLACE INTO a2a_thread_migrations (
          id, bond_id, source_session_id, messages_route, status, created_at
        ) VALUES (
          @id, @bond_id, @source_session_id, @messages_route, @status, @created_at
        )`
      )
      .run({
        id: migrationId,
        bond_id: bondId,
        source_session_id: sessionId,
        messages_route: messagesRoute,
        status: 'ready',
        created_at: nowIso
      });
    return {
      id: migrationId,
      bondId,
      sessionId,
      messagesRoute,
      status: 'ready',
      createdAt: nowIso
    };
  }

  listBondTasks(bondId) {
    return this.db
      .prepare('SELECT * FROM a2a_bond_tasks WHERE bond_id = ? ORDER BY created_at ASC')
      .all(bondId)
      .map(parseBondTaskRow);
  }

  listBondMilestones(bondId) {
    return this.db
      .prepare('SELECT * FROM a2a_bond_milestones WHERE bond_id = ? ORDER BY achieved_at ASC')
      .all(bondId)
      .map(parseMilestoneRow);
  }

  listActiveBondTasks({ userId, laneId = null, limit = 10 }) {
    const rows = this.db
      .prepare(
        `SELECT tasks.*, bonds.lane_id, bonds.strength_score, bonds.thread_route
         FROM a2a_bond_tasks AS tasks
         JOIN a2a_bond_relationships AS bonds ON bonds.id = tasks.bond_id
         WHERE bonds.initiator_user_id = ?
         ORDER BY tasks.updated_at DESC`
      )
      .all(userId);
    return rows
      .map((row) => ({
        ...parseBondTaskRow(row),
        laneId: row.lane_id,
        strengthScore: Number(row.strength_score),
        route: buildBondRoute(row.bond_id),
        threadRoute: row.thread_route
      }))
      .filter((task) => task.status !== 'completed' && (!laneId || task.laneId === laneId))
      .slice(0, limit);
  }

  updateBondTaskProgress({ taskId, increment = 1, nowIso = isoNow() }) {
    const task = parseBondTaskRow(this.db.prepare('SELECT * FROM a2a_bond_tasks WHERE id = ?').get(taskId));
    if (!task) {
      throw new Error(`Unknown bond task: ${taskId}`);
    }
    const nextProgress = Math.min(task.targetCount, task.progressCount + increment);
    const completed = nextProgress >= task.targetCount;
    this.db
      .prepare(
        `UPDATE a2a_bond_tasks
         SET progress_count = @progress_count,
             status = @status,
             completed_at = @completed_at,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: taskId,
        progress_count: nextProgress,
        status: completed ? 'completed' : task.status,
        completed_at: completed ? nowIso : task.completedAt,
        updated_at: nowIso
      });
    return parseBondTaskRow(this.db.prepare('SELECT * FROM a2a_bond_tasks WHERE id = ?').get(taskId));
  }

  updateBondRelationship({ bondId, level, strengthScore, milestoneCount, lastActivityAt = isoNow(), status = 'active', nowIso = isoNow() }) {
    this.db
      .prepare(
        `UPDATE a2a_bond_relationships
         SET level = @level,
             strength_score = @strength_score,
             milestone_count = @milestone_count,
             status = @status,
             last_activity_at = @last_activity_at,
             updated_at = @updated_at
         WHERE id = @id`
      )
      .run({
        id: bondId,
        level,
        strength_score: strengthScore,
        milestone_count: milestoneCount,
        status,
        last_activity_at: lastActivityAt,
        updated_at: nowIso
      });
    return this.findBond(bondId);
  }

  saveBondMilestone({ bondId, milestoneKey, title, summary, achievedAt = isoNow() }) {
    const milestoneId = stableId('a2a-bond-milestone', bondId, milestoneKey);
    this.db
      .prepare(
        `INSERT OR REPLACE INTO a2a_bond_milestones (
          id, bond_id, milestone_key, title, summary, achieved_at
        ) VALUES (
          @id, @bond_id, @milestone_key, @title, @summary, @achieved_at
        )`
      )
      .run({
        id: milestoneId,
        bond_id: bondId,
        milestone_key: milestoneKey,
        title,
        summary,
        achieved_at: achievedAt
      });
    return parseMilestoneRow(this.db.prepare('SELECT * FROM a2a_bond_milestones WHERE id = ?').get(milestoneId));
  }

  createLeadPipeline({ lead, stages = [], auditEvents = [] }, nowIso = isoNow()) {
    return this.withTransaction(() => {
      this.db
        .prepare(
          `INSERT INTO a2a_lead_pipelines (
            id, lane_id, intent_id, source_session_id, bond_id, initiator_user_id, counterpart_user_id,
            target_agent_id, human_takeover, source_route, route, current_stage_key, current_stage_label,
            confirmations_json, latest_outcome_code, latest_outcome_label, latest_outcome_status, created_at, updated_at
          ) VALUES (
            @id, @lane_id, @intent_id, @source_session_id, @bond_id, @initiator_user_id, @counterpart_user_id,
            @target_agent_id, @human_takeover, @source_route, @route, @current_stage_key, @current_stage_label,
            @confirmations_json, @latest_outcome_code, @latest_outcome_label, @latest_outcome_status, @created_at, @updated_at
          )`
        )
        .run({
          id: lead.leadId,
          lane_id: lead.laneId,
          intent_id: lead.intentId,
          source_session_id: lead.sourceSessionId,
          bond_id: lead.bondId,
          initiator_user_id: lead.initiatorUserId,
          counterpart_user_id: lead.counterpartUserId,
          target_agent_id: lead.targetAgentId,
          human_takeover: lead.humanTakeover ? 1 : 0,
          source_route: lead.sourceRoute,
          route: lead.route,
          current_stage_key: lead.currentStageKey,
          current_stage_label: lead.currentStageLabel,
          confirmations_json: toJson(lead.confirmations ?? {}),
          latest_outcome_code: lead.latestOutcomeCode ?? null,
          latest_outcome_label: lead.latestOutcomeLabel ?? null,
          latest_outcome_status: lead.latestOutcomeStatus ?? null,
          created_at: nowIso,
          updated_at: nowIso
        });

      const insertStage = this.db.prepare(
        `INSERT INTO a2a_lead_stage_events (
          id, lead_id, stage_index, stage_key, stage_label, actor_kind, detail_json, created_at
        ) VALUES (
          @id, @lead_id, @stage_index, @stage_key, @stage_label, @actor_kind, @detail_json, @created_at
        )`
      );
      for (const [index, stage] of stages.entries()) {
        const stageIndex = Number(stage.stageIndex ?? index + 1);
        insertStage.run({
          id: stableId('lead-stage', lead.leadId, stageIndex),
          lead_id: lead.leadId,
          stage_index: stageIndex,
          stage_key: stage.stageKey,
          stage_label: stage.stageLabel,
          actor_kind: stage.actorKind ?? 'system',
          detail_json: toJson(stage.detail ?? {}),
          created_at: stage.createdAt ?? nowIso
        });
      }

      const insertAudit = this.db.prepare(
        `INSERT INTO a2a_lead_audit_events (
          id, lead_id, event_type, actor_kind, actor_id, detail_json, created_at
        ) VALUES (
          @id, @lead_id, @event_type, @actor_kind, @actor_id, @detail_json, @created_at
        )`
      );
      for (const event of auditEvents) {
        const auditId = `lead_audit_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
        insertAudit.run({
          id: auditId,
          lead_id: lead.leadId,
          event_type: event.eventType,
          actor_kind: event.actorKind ?? 'system',
          actor_id: event.actorId ?? null,
          detail_json: toJson(event.detail ?? {}),
          created_at: event.createdAt ?? nowIso
        });
      }

      return this.findLeadPipeline(lead.leadId);
    });
  }

  findLeadPipeline(leadId) {
    return parseLeadRow(this.db.prepare('SELECT * FROM a2a_lead_pipelines WHERE id = ?').get(leadId));
  }

  findLeadBySession(sessionId) {
    return parseLeadRow(this.db.prepare('SELECT * FROM a2a_lead_pipelines WHERE source_session_id = ?').get(sessionId));
  }

  listLeadPipelines({ userId = null, laneId = null, currentStageKeys = [], limit = 10 } = {}) {
    return this.db
      .prepare('SELECT * FROM a2a_lead_pipelines ORDER BY updated_at DESC')
      .all()
      .map(parseLeadRow)
      .filter(
        (lead) =>
          (!userId || lead.initiatorUserId === userId) &&
          (!laneId || lead.laneId === laneId) &&
          (!currentStageKeys.length || currentStageKeys.includes(lead.currentStageKey))
      )
      .slice(0, limit);
  }

  listLeadStages(leadId) {
    return this.db
      .prepare('SELECT * FROM a2a_lead_stage_events WHERE lead_id = ? ORDER BY stage_index ASC')
      .all(leadId)
      .map(parseLeadStageRow);
  }

  recordLeadAuditEvent({ leadId, eventType, actorKind = 'system', actorId = null, detail = {}, nowIso = isoNow() }) {
    const auditId = `lead_audit_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO a2a_lead_audit_events (
          id, lead_id, event_type, actor_kind, actor_id, detail_json, created_at
        ) VALUES (
          @id, @lead_id, @event_type, @actor_kind, @actor_id, @detail_json, @created_at
        )`
      )
      .run({
        id: auditId,
        lead_id: leadId,
        event_type: eventType,
        actor_kind: actorKind,
        actor_id: actorId,
        detail_json: toJson(detail),
        created_at: nowIso
      });
    return parseLeadAuditRow(this.db.prepare('SELECT * FROM a2a_lead_audit_events WHERE id = ?').get(auditId));
  }

  listLeadAuditEvents(leadId) {
    return this.db
      .prepare('SELECT * FROM a2a_lead_audit_events WHERE lead_id = ? ORDER BY created_at ASC')
      .all(leadId)
      .map(parseLeadAuditRow);
  }

  advanceLeadStage({ leadId, stageKey, stageLabel, actorKind = 'system', actorId = null, detail = {}, nowIso = isoNow() }) {
    return this.withTransaction(() => {
      const nextStageIndex =
        Number(
          this.db
            .prepare('SELECT MAX(stage_index) AS max_stage_index FROM a2a_lead_stage_events WHERE lead_id = ?')
            .get(leadId)?.max_stage_index ?? 0
        ) + 1;
      const stageId = stableId('lead-stage', leadId, nextStageIndex);

      this.db
        .prepare(
          `INSERT INTO a2a_lead_stage_events (
            id, lead_id, stage_index, stage_key, stage_label, actor_kind, detail_json, created_at
          ) VALUES (
            @id, @lead_id, @stage_index, @stage_key, @stage_label, @actor_kind, @detail_json, @created_at
          )`
        )
        .run({
          id: stageId,
          lead_id: leadId,
          stage_index: nextStageIndex,
          stage_key: stageKey,
          stage_label: stageLabel,
          actor_kind: actorKind,
          detail_json: toJson(detail),
          created_at: nowIso
        });

      this.db
        .prepare(
          `UPDATE a2a_lead_pipelines
           SET current_stage_key = @current_stage_key,
               current_stage_label = @current_stage_label,
               updated_at = @updated_at
           WHERE id = @id`
        )
        .run({
          id: leadId,
          current_stage_key: stageKey,
          current_stage_label: stageLabel,
          updated_at: nowIso
        });

      const audit = this.recordLeadAuditEvent({
        leadId,
        eventType: 'stage_entered',
        actorKind,
        actorId,
        detail: {
          stageKey,
          stageLabel,
          ...detail
        },
        nowIso
      });

      return {
        lead: this.findLeadPipeline(leadId),
        stage: parseLeadStageRow(this.db.prepare('SELECT * FROM a2a_lead_stage_events WHERE id = ?').get(stageId)),
        audit
      };
    });
  }

  findLeadOutcome(leadId) {
    return parseOutcomeRow(this.db.prepare('SELECT * FROM a2a_match_outcomes WHERE lead_id = ?').get(leadId));
  }

  saveLeadOutcome({ leadId, laneId, outcomeCode, outcomeLabel, outcomeStatus, recordedByUserId, detail = {}, nowIso = isoNow() }) {
    return this.withTransaction(() => {
      const outcomeId = stableId('lead-outcome', leadId);
      this.db
        .prepare(
          `INSERT INTO a2a_match_outcomes (
            id, lead_id, lane_id, outcome_code, outcome_label, outcome_status, recorded_by_user_id,
            detail_json, created_at, updated_at
          ) VALUES (
            @id, @lead_id, @lane_id, @outcome_code, @outcome_label, @outcome_status, @recorded_by_user_id,
            @detail_json, @created_at, @updated_at
          )
          ON CONFLICT(lead_id) DO UPDATE SET
            lane_id = excluded.lane_id,
            outcome_code = excluded.outcome_code,
            outcome_label = excluded.outcome_label,
            outcome_status = excluded.outcome_status,
            recorded_by_user_id = excluded.recorded_by_user_id,
            detail_json = excluded.detail_json,
            updated_at = excluded.updated_at`
        )
        .run({
          id: outcomeId,
          lead_id: leadId,
          lane_id: laneId,
          outcome_code: outcomeCode,
          outcome_label: outcomeLabel,
          outcome_status: outcomeStatus,
          recorded_by_user_id: recordedByUserId,
          detail_json: toJson(detail),
          created_at: nowIso,
          updated_at: nowIso
        });

      this.db
        .prepare(
          `UPDATE a2a_lead_pipelines
           SET latest_outcome_code = @latest_outcome_code,
               latest_outcome_label = @latest_outcome_label,
               latest_outcome_status = @latest_outcome_status,
               updated_at = @updated_at
           WHERE id = @id`
        )
        .run({
          id: leadId,
          latest_outcome_code: outcomeCode,
          latest_outcome_label: outcomeLabel,
          latest_outcome_status: outcomeStatus,
          updated_at: nowIso
        });

      const audit = this.recordLeadAuditEvent({
        leadId,
        eventType: 'outcome_recorded',
        actorKind: 'initiator_user',
        actorId: recordedByUserId,
        detail: {
          outcomeCode,
          outcomeLabel,
          outcomeStatus,
          ...detail
        },
        nowIso
      });

      return {
        lead: this.findLeadPipeline(leadId),
        outcome: this.findLeadOutcome(leadId),
        audit
      };
    });
  }

  findLeadSettlementByDedupeKey(dedupeKey) {
    if (!dedupeKey) {
      return null;
    }
    return parseLeadSettlementRow(this.db.prepare('SELECT * FROM a2a_lead_settlements WHERE dedupe_key = ?').get(dedupeKey));
  }

  saveLeadSettlement({
    leadId,
    beneficiaryUserId,
    settlementType,
    amount,
    status,
    dedupeKey,
    ledgerEntryId = null,
    detail = {},
    nowIso = isoNow(),
    settledAt = null
  }) {
    const existing = this.findLeadSettlementByDedupeKey(dedupeKey);
    if (existing) {
      return existing;
    }
    const settlementId = `lead_settlement_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    this.db
      .prepare(
        `INSERT INTO a2a_lead_settlements (
          id, lead_id, beneficiary_user_id, settlement_type, amount, status, dedupe_key,
          ledger_entry_id, detail_json, created_at, settled_at
        ) VALUES (
          @id, @lead_id, @beneficiary_user_id, @settlement_type, @amount, @status, @dedupe_key,
          @ledger_entry_id, @detail_json, @created_at, @settled_at
        )`
      )
      .run({
        id: settlementId,
        lead_id: leadId,
        beneficiary_user_id: beneficiaryUserId,
        settlement_type: settlementType,
        amount,
        status,
        dedupe_key: dedupeKey,
        ledger_entry_id: ledgerEntryId,
        detail_json: toJson(detail),
        created_at: nowIso,
        settled_at: settledAt
      });
    this.recordLeadAuditEvent({
      leadId,
      eventType: 'settlement_recorded',
      actorKind: 'system',
      actorId: beneficiaryUserId,
      detail: {
        settlementType,
        amount,
        status,
        ledgerEntryId
      },
      nowIso
    });
    return parseLeadSettlementRow(this.db.prepare('SELECT * FROM a2a_lead_settlements WHERE id = ?').get(settlementId));
  }

  listLeadSettlements(leadId) {
    return this.db
      .prepare('SELECT * FROM a2a_lead_settlements WHERE lead_id = ? ORDER BY created_at DESC')
      .all(leadId)
      .map(parseLeadSettlementRow);
  }

  inspectEarnSocialState(userId) {
    const counts = {
      lanes: this.countRows('a2a_lanes'),
      templates: this.countRows('a2a_intent_templates'),
      publicCards: this.countRows('a2a_public_agent_cards'),
      intents: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_intent_posts').get()?.total ?? 0),
      userIntents: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_intent_posts WHERE user_id = ?').get(userId)?.total ?? 0),
      icebreaks: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_icebreak_sessions WHERE initiator_user_id = ?').get(userId)?.total ?? 0),
      bonds: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_bond_relationships WHERE initiator_user_id = ?').get(userId)?.total ?? 0),
      leads: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_lead_pipelines WHERE initiator_user_id = ?').get(userId)?.total ?? 0),
      leadOutcomes: Number(
        this.db
          .prepare(
            `SELECT COUNT(*) AS total
             FROM a2a_match_outcomes AS outcomes
             JOIN a2a_lead_pipelines AS leads ON leads.id = outcomes.lead_id
             WHERE leads.initiator_user_id = ?`
          )
          .get(userId)?.total ?? 0
      ),
      leadSettlements: Number(
        this.db
          .prepare(
            `SELECT COUNT(*) AS total
             FROM a2a_lead_settlements AS settlements
             JOIN a2a_lead_pipelines AS leads ON leads.id = settlements.lead_id
             WHERE leads.initiator_user_id = ?`
          )
          .get(userId)?.total ?? 0
      ),
      leadAuditEvents: Number(
        this.db
          .prepare(
            `SELECT COUNT(*) AS total
             FROM a2a_lead_audit_events AS audits
             JOIN a2a_lead_pipelines AS leads ON leads.id = audits.lead_id
             WHERE leads.initiator_user_id = ?`
          )
          .get(userId)?.total ?? 0
      ),
      bondMilestones: Number(
        this.db
          .prepare(
            `SELECT COUNT(*) AS total
             FROM a2a_bond_milestones AS milestones
             JOIN a2a_bond_relationships AS bonds ON bonds.id = milestones.bond_id
             WHERE bonds.initiator_user_id = ?`
          )
          .get(userId)?.total ?? 0
      ),
      arenaMatches: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_arena_matches WHERE created_by_user_id = ?').get(userId)?.total ?? 0),
      arenaVotes: this.countRows('a2a_arena_votes'),
      laneHeatSnapshots: this.countRows('a2a_lane_heat_snapshots'),
      ledgerEntries: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_energy_ledger WHERE user_id = ?').get(userId)?.total ?? 0),
      feedbackEvents: Number(this.db.prepare('SELECT COUNT(*) AS total FROM a2a_persona_feedback_events WHERE user_id = ?').get(userId)?.total ?? 0)
    };

    return {
      counts,
      wallet: this.getWallet(userId),
      recentIntents: this.listIntentHistoryForUser(userId, null, 5),
      activeIcebreaks: this.listIcebreakSessions({
        userId,
        statuses: ['screening', 'consent_pending', 'human_takeover'],
        limit: 5
      }),
      activeBondTasks: this.listActiveBondTasks({
        userId,
        limit: 5
      }),
      recentLeads: this.listLeadPipelines({
        userId,
        limit: 5
      }).map((lead) => ({
        ...lead,
        stages: this.listLeadStages(lead.id),
        outcome: this.findLeadOutcome(lead.id),
        settlements: this.listLeadSettlements(lead.id),
        auditTrail: this.listLeadAuditEvents(lead.id)
      })),
      ledger: this.listEnergyLedger(userId, 8),
      laneHeat: this.listLatestLaneHeatSnapshots()
    };
  }
}
