import {
  fromJson,
  isoNow,
  sanitizeText,
  stableId,
  toJson
} from '../../Domain/Models/sceneContracts.mjs';
import { LocalBackendDatabase } from '../SQLite/localBackendDatabase.mjs';

function requireUserId(userId) {
  const normalized = sanitizeText(userId);
  if (!normalized) {
    throw new Error('userId is required.');
  }
  return normalized;
}

function parseMemoryRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.owner_user_id,
    channel: row.channel,
    routeKey: row.route_key,
    action: row.action,
    intentLabel: row.intent_label,
    summary: row.summary,
    promptPreview: row.prompt_preview,
    keywords: fromJson(row.keywords_json, []),
    sourceRef: row.source_ref,
    metadata: fromJson(row.metadata_json, {}),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseQueryRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.owner_user_id,
    routeKey: row.route_key,
    action: row.action,
    queryText: row.query_text,
    intentLabel: row.intent_label,
    recalledMemoryIds: fromJson(row.recalled_memory_ids_json, []),
    candidateRanking: fromJson(row.candidate_ranking_json, []),
    createdAt: row.created_at
  };
}

function parsePermissionRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.owner_user_id,
    routeKey: row.route_key,
    action: row.action,
    effect: row.effect,
    reason: row.reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function parseAuditRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    userId: row.owner_user_id,
    channel: row.channel,
    routeKey: row.route_key,
    action: row.action,
    decision: row.decision,
    riskLevel: row.risk_level,
    reason: row.reason,
    payloadDigest: row.payload_digest,
    metadata: fromJson(row.metadata_json, {}),
    createdAt: row.created_at
  };
}

function parseReportRow(row) {
  if (!row) {
    return null;
  }
  return {
    id: row.id,
    reporterUserId: row.reporter_user_id,
    targetType: row.target_type,
    targetId: row.target_id,
    reason: row.reason,
    detail: row.detail,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

export class FoundationRepository {
  constructor({ dbPath = null, database = null }) {
    if (database) {
      this.database = database;
      this.ownsDatabase = false;
    } else {
      const normalizedDbPath = sanitizeText(dbPath);
      if (!normalizedDbPath) {
        throw new Error('dbPath is required when database is not provided.');
      }
      this.database = new LocalBackendDatabase({
        dbPath: normalizedDbPath
      });
      this.ownsDatabase = true;
    }
    this.db = this.database.db;
  }

  close() {
    if (this.ownsDatabase) {
      this.database.close();
    }
  }

  saveMemoryRecord({
    userId,
    channel,
    routeKey,
    action,
    intentLabel,
    summary,
    promptPreview,
    keywords = [],
    sourceRef = null,
    metadata = {},
    createdAt = isoNow()
  }) {
    const ownerUserId = requireUserId(userId);
    const nowIso = createdAt;
    const recordId = stableId(
      'ai-memory-record',
      ownerUserId,
      sanitizeText(routeKey),
      sanitizeText(action),
      sanitizeText(summary),
      nowIso
    );

    this.db
      .prepare(
        `INSERT INTO ai_memory_records (
          id, owner_user_id, channel, route_key, action, intent_label, summary,
          prompt_preview, keywords_json, source_ref, metadata_json, created_at, updated_at
        ) VALUES (
          @id, @owner_user_id, @channel, @route_key, @action, @intent_label, @summary,
          @prompt_preview, @keywords_json, @source_ref, @metadata_json, @created_at, @updated_at
        )`
      )
      .run({
        id: recordId,
        owner_user_id: ownerUserId,
        channel: sanitizeText(channel) || 'openclaw',
        route_key: sanitizeText(routeKey) || 'unknown',
        action: sanitizeText(action) || 'unknown',
        intent_label: sanitizeText(intentLabel) || 'general_chat',
        summary: sanitizeText(summary),
        prompt_preview: sanitizeText(promptPreview),
        keywords_json: toJson(keywords),
        source_ref: sanitizeText(sourceRef) || null,
        metadata_json: toJson(metadata),
        created_at: nowIso,
        updated_at: nowIso
      });

    return this.getMemoryRecord(recordId);
  }

  getMemoryRecord(memoryId) {
    return parseMemoryRow(this.db.prepare('SELECT * FROM ai_memory_records WHERE id = ?').get(memoryId));
  }

  listMemoryRecords(userId, limit = 80) {
    const ownerUserId = requireUserId(userId);
    return this.db
      .prepare(
        `SELECT *
         FROM ai_memory_records
         WHERE owner_user_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(ownerUserId, Number(limit))
      .map(parseMemoryRow);
  }

  recordMemoryQuery({
    userId,
    routeKey,
    action,
    queryText,
    intentLabel,
    recalledMemoryIds = [],
    candidateRanking = [],
    createdAt = isoNow()
  }) {
    const ownerUserId = requireUserId(userId);
    const queryId = stableId(
      'ai-memory-query',
      ownerUserId,
      sanitizeText(routeKey),
      sanitizeText(action),
      sanitizeText(queryText),
      createdAt
    );

    this.db
      .prepare(
        `INSERT INTO ai_memory_query_logs (
          id, owner_user_id, route_key, action, query_text, intent_label,
          recalled_memory_ids_json, candidate_ranking_json, created_at
        ) VALUES (
          @id, @owner_user_id, @route_key, @action, @query_text, @intent_label,
          @recalled_memory_ids_json, @candidate_ranking_json, @created_at
        )`
      )
      .run({
        id: queryId,
        owner_user_id: ownerUserId,
        route_key: sanitizeText(routeKey) || 'ai_memory',
        action: sanitizeText(action) || 'recall',
        query_text: sanitizeText(queryText),
        intent_label: sanitizeText(intentLabel) || 'general_chat',
        recalled_memory_ids_json: toJson(recalledMemoryIds),
        candidate_ranking_json: toJson(candidateRanking),
        created_at: createdAt
      });

    return parseQueryRow(this.db.prepare('SELECT * FROM ai_memory_query_logs WHERE id = ?').get(queryId));
  }

  listMemoryQueries(userId, limit = 40) {
    const ownerUserId = requireUserId(userId);
    return this.db
      .prepare(
        `SELECT *
         FROM ai_memory_query_logs
         WHERE owner_user_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(ownerUserId, Number(limit))
      .map(parseQueryRow);
  }

  upsertPermissionRule({
    userId,
    routeKey,
    action,
    effect,
    reason = null,
    nowIso = isoNow()
  }) {
    const ownerUserId = requireUserId(userId);
    const normalizedRouteKey = sanitizeText(routeKey) || '*';
    const normalizedAction = sanitizeText(action) || '*';
    const normalizedEffect = sanitizeText(effect) || 'allow';
    const ruleId = stableId('security-permission', ownerUserId, normalizedRouteKey, normalizedAction);

    this.db
      .prepare(
        `INSERT INTO security_permission_rules (
          id, owner_user_id, route_key, action, effect, reason, created_at, updated_at
        ) VALUES (
          @id, @owner_user_id, @route_key, @action, @effect, @reason, @created_at, @updated_at
        )
        ON CONFLICT(owner_user_id, route_key, action) DO UPDATE SET
          effect = excluded.effect,
          reason = excluded.reason,
          updated_at = excluded.updated_at`
      )
      .run({
        id: ruleId,
        owner_user_id: ownerUserId,
        route_key: normalizedRouteKey,
        action: normalizedAction,
        effect: normalizedEffect,
        reason: sanitizeText(reason) || null,
        created_at: nowIso,
        updated_at: nowIso
      });

    return parsePermissionRow(
      this.db
        .prepare(
          `SELECT *
           FROM security_permission_rules
           WHERE owner_user_id = ? AND route_key = ? AND action = ?`
        )
        .get(ownerUserId, normalizedRouteKey, normalizedAction)
    );
  }

  listPermissionRules(userId, limit = 120) {
    const ownerUserId = requireUserId(userId);
    return this.db
      .prepare(
        `SELECT *
         FROM security_permission_rules
         WHERE owner_user_id = ?
         ORDER BY route_key ASC, action ASC, updated_at DESC
         LIMIT ?`
      )
      .all(ownerUserId, Number(limit))
      .map(parsePermissionRow);
  }

  findPermissionRule({ userId, routeKey, action }) {
    const ownerUserId = requireUserId(userId);
    const normalizedRouteKey = sanitizeText(routeKey) || '*';
    const normalizedAction = sanitizeText(action) || '*';

    const exact = this.db
      .prepare(
        `SELECT *
         FROM security_permission_rules
         WHERE owner_user_id = ? AND route_key = ? AND action = ?
         LIMIT 1`
      )
      .get(ownerUserId, normalizedRouteKey, normalizedAction);
    if (exact) {
      return parsePermissionRow(exact);
    }

    const routeWildcard = this.db
      .prepare(
        `SELECT *
         FROM security_permission_rules
         WHERE owner_user_id = ? AND route_key = ? AND action = '*'
         LIMIT 1`
      )
      .get(ownerUserId, normalizedRouteKey);
    if (routeWildcard) {
      return parsePermissionRow(routeWildcard);
    }

    const globalWildcard = this.db
      .prepare(
        `SELECT *
         FROM security_permission_rules
         WHERE owner_user_id = ? AND route_key = '*' AND action = '*'
         LIMIT 1`
      )
      .get(ownerUserId);

    return parsePermissionRow(globalWildcard);
  }

  appendAuditLog({
    userId,
    channel,
    routeKey,
    action,
    decision,
    riskLevel,
    reason,
    payloadDigest,
    metadata = {},
    createdAt = isoNow()
  }) {
    const ownerUserId = requireUserId(userId);
    const logId = stableId(
      'security-audit',
      ownerUserId,
      sanitizeText(routeKey),
      sanitizeText(action),
      sanitizeText(decision),
      createdAt,
      sanitizeText(payloadDigest)
    );

    this.db
      .prepare(
        `INSERT INTO security_audit_logs (
          id, owner_user_id, channel, route_key, action, decision,
          risk_level, reason, payload_digest, metadata_json, created_at
        ) VALUES (
          @id, @owner_user_id, @channel, @route_key, @action, @decision,
          @risk_level, @reason, @payload_digest, @metadata_json, @created_at
        )`
      )
      .run({
        id: logId,
        owner_user_id: ownerUserId,
        channel: sanitizeText(channel) || 'openclaw',
        route_key: sanitizeText(routeKey) || 'unknown',
        action: sanitizeText(action) || 'unknown',
        decision: sanitizeText(decision) || 'allow',
        risk_level: sanitizeText(riskLevel) || 'low',
        reason: sanitizeText(reason) || null,
        payload_digest: sanitizeText(payloadDigest) || 'unknown',
        metadata_json: toJson(metadata),
        created_at: createdAt
      });

    return parseAuditRow(this.db.prepare('SELECT * FROM security_audit_logs WHERE id = ?').get(logId));
  }

  listAuditLogs(userId, limit = 80) {
    const ownerUserId = requireUserId(userId);
    return this.db
      .prepare(
        `SELECT *
         FROM security_audit_logs
         WHERE owner_user_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(ownerUserId, Number(limit))
      .map(parseAuditRow);
  }

  createIncidentReport({
    reporterUserId,
    targetType,
    targetId,
    reason,
    detail = null,
    status = 'open',
    createdAt = isoNow()
  }) {
    const normalizedReporter = requireUserId(reporterUserId);
    const reportId = stableId(
      'security-report',
      normalizedReporter,
      sanitizeText(targetType),
      sanitizeText(targetId),
      sanitizeText(reason),
      createdAt
    );

    this.db
      .prepare(
        `INSERT INTO security_incident_reports (
          id, reporter_user_id, target_type, target_id, reason, detail, status, created_at, updated_at
        ) VALUES (
          @id, @reporter_user_id, @target_type, @target_id, @reason, @detail, @status, @created_at, @updated_at
        )`
      )
      .run({
        id: reportId,
        reporter_user_id: normalizedReporter,
        target_type: sanitizeText(targetType) || 'message',
        target_id: sanitizeText(targetId) || 'unknown',
        reason: sanitizeText(reason) || 'unspecified',
        detail: sanitizeText(detail) || null,
        status: sanitizeText(status) || 'open',
        created_at: createdAt,
        updated_at: createdAt
      });

    return parseReportRow(this.db.prepare('SELECT * FROM security_incident_reports WHERE id = ?').get(reportId));
  }

  listIncidentReports(reporterUserId, limit = 40) {
    const normalizedReporter = requireUserId(reporterUserId);
    return this.db
      .prepare(
        `SELECT *
         FROM security_incident_reports
         WHERE reporter_user_id = ?
         ORDER BY created_at DESC
         LIMIT ?`
      )
      .all(normalizedReporter, Number(limit))
      .map(parseReportRow);
  }

  inspectFoundationState(userId) {
    const ownerUserId = requireUserId(userId);
    const count = (table, whereClause = '', params = []) =>
      Number(
        this.db
          .prepare(`SELECT COUNT(*) AS total FROM ${table} ${whereClause}`)
          .get(...params)?.total ?? 0
      );

    return {
      userId: ownerUserId,
      counts: {
        memoryRecords: count('ai_memory_records', 'WHERE owner_user_id = ?', [ownerUserId]),
        memoryQueries: count('ai_memory_query_logs', 'WHERE owner_user_id = ?', [ownerUserId]),
        permissions: count('security_permission_rules', 'WHERE owner_user_id = ?', [ownerUserId]),
        auditLogs: count('security_audit_logs', 'WHERE owner_user_id = ?', [ownerUserId]),
        incidentReports: count('security_incident_reports', 'WHERE reporter_user_id = ?', [ownerUserId])
      },
      latest: {
        memory: parseMemoryRow(
          this.db
            .prepare(
              `SELECT *
               FROM ai_memory_records
               WHERE owner_user_id = ?
               ORDER BY created_at DESC
               LIMIT 1`
            )
            .get(ownerUserId)
        ),
        audit: parseAuditRow(
          this.db
            .prepare(
              `SELECT *
               FROM security_audit_logs
               WHERE owner_user_id = ?
               ORDER BY created_at DESC
               LIMIT 1`
            )
            .get(ownerUserId)
        ),
        report: parseReportRow(
          this.db
            .prepare(
              `SELECT *
               FROM security_incident_reports
               WHERE reporter_user_id = ?
               ORDER BY created_at DESC
               LIMIT 1`
            )
            .get(ownerUserId)
        )
      },
      database: this.database.inspectDatabaseStatus()
    };
  }
}
