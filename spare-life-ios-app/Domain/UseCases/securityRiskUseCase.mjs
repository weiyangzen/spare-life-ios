import { isoNow, sanitizeText } from '../Models/sceneContracts.mjs';
import {
  buildPayloadDigest,
  evaluateRisk,
  resolvePermissionEffect
} from '../../Services/EmotionEngine/securityRiskService.mjs';

function requireUserId(userId) {
  const normalized = sanitizeText(userId);
  if (!normalized) {
    throw new Error('userId is required.');
  }
  return normalized;
}

function resolveDecision({ permissionEffect, riskDecision }) {
  if (permissionEffect === 'deny') {
    return 'intercept';
  }
  if (riskDecision === 'block') {
    return 'intercept';
  }
  if (riskDecision === 'review') {
    return 'review';
  }
  return 'allow';
}

export class SecurityRiskUseCase {
  constructor({ repository }) {
    this.repository = repository;
  }

  setPermission(payload) {
    const userId = requireUserId(payload.userId);
    const routeKey = sanitizeText(payload.routeKey) || '*';
    const action = sanitizeText(payload.action) || '*';
    const effect = sanitizeText(payload.effect) || 'allow';

    if (!['allow', 'deny', 'review'].includes(effect)) {
      throw new Error(`Unsupported permission effect: ${effect}`);
    }

    const rule = this.repository.upsertPermissionRule({
      userId,
      routeKey,
      action,
      effect,
      reason: sanitizeText(payload.reason) || null
    });

    return {
      eventType: 'security_permission_updated',
      rule
    };
  }

  guardRequest(payload) {
    const userId = requireUserId(payload.userId);
    const routeKey = sanitizeText(payload.routeKey) || 'unknown';
    const action = sanitizeText(payload.action) || 'unknown';
    const permissionRule = this.repository.findPermissionRule({
      userId,
      routeKey,
      action
    });
    const permissionEffect = resolvePermissionEffect(permissionRule, 'allow');
    const risk = evaluateRisk({
      payload: payload.body,
      routeKey,
      action
    });
    const decision = resolveDecision({
      permissionEffect,
      riskDecision: permissionEffect === 'review' ? 'review' : risk.decision
    });
    const nowIso = isoNow();

    const audit = this.repository.appendAuditLog({
      userId,
      channel: sanitizeText(payload.channel) || 'openclaw',
      routeKey,
      action,
      decision,
      riskLevel: risk.riskLevel,
      reason:
        decision === 'intercept' && permissionEffect === 'deny'
          ? permissionRule?.reason || '权限拒绝。'
          : risk.reason,
      payloadDigest: buildPayloadDigest(payload.body),
      metadata: {
        permissionEffect,
        riskTags: risk.tags,
        requestId: sanitizeText(payload.requestId) || null
      },
      createdAt: nowIso
    });

    return {
      allowed: decision === 'allow',
      requiresReview: decision === 'review',
      decision,
      permissionRule,
      permissionEffect,
      risk,
      audit
    };
  }

  reportIncident(payload) {
    const reporterUserId = requireUserId(payload.userId);
    const report = this.repository.createIncidentReport({
      reporterUserId,
      targetType: sanitizeText(payload.targetType) || 'message',
      targetId: sanitizeText(payload.targetId) || 'unknown-target',
      reason: sanitizeText(payload.reason) || 'unspecified',
      detail: sanitizeText(payload.detail) || null,
      status: sanitizeText(payload.status) || 'open'
    });

    const audit = this.repository.appendAuditLog({
      userId: reporterUserId,
      channel: sanitizeText(payload.channel) || 'openclaw',
      routeKey: 'security',
      action: 'report',
      decision: 'allow',
      riskLevel: 'medium',
      reason: '用户提交举报并进入审计链。',
      payloadDigest: buildPayloadDigest(payload),
      metadata: {
        reportId: report.id
      }
    });

    return {
      eventType: 'security_incident_reported',
      report,
      audit
    };
  }

  inspectSecurityState(payload) {
    const userId = requireUserId(payload.userId);
    const state = this.repository.inspectFoundationState(userId);

    return {
      eventType: 'security_state',
      userId,
      permissions: this.repository.listPermissionRules(userId, payload.permissionLimit ?? 80),
      audits: this.repository.listAuditLogs(userId, payload.auditLimit ?? 80),
      reports: this.repository.listIncidentReports(userId, payload.reportLimit ?? 40),
      counts: {
        permissions: state.counts.permissions,
        audits: state.counts.auditLogs,
        reports: state.counts.incidentReports
      }
    };
  }
}
