CREATE TABLE IF NOT EXISTS ai_memory_records (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  channel TEXT NOT NULL,
  route_key TEXT NOT NULL,
  action TEXT NOT NULL,
  intent_label TEXT NOT NULL,
  summary TEXT NOT NULL,
  prompt_preview TEXT NOT NULL,
  keywords_json TEXT NOT NULL DEFAULT '[]',
  source_ref TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_memory_records_owner_created
  ON ai_memory_records(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_memory_records_intent
  ON ai_memory_records(owner_user_id, intent_label, created_at DESC);

CREATE TABLE IF NOT EXISTS ai_memory_query_logs (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  route_key TEXT NOT NULL,
  action TEXT NOT NULL,
  query_text TEXT NOT NULL,
  intent_label TEXT NOT NULL,
  recalled_memory_ids_json TEXT NOT NULL DEFAULT '[]',
  candidate_ranking_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_memory_query_logs_owner_created
  ON ai_memory_query_logs(owner_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS security_permission_rules (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  route_key TEXT NOT NULL,
  action TEXT NOT NULL,
  effect TEXT NOT NULL,
  reason TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(owner_user_id, route_key, action)
);

CREATE INDEX IF NOT EXISTS idx_security_permission_rules_owner
  ON security_permission_rules(owner_user_id, route_key, action);

CREATE TABLE IF NOT EXISTS security_audit_logs (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  channel TEXT NOT NULL,
  route_key TEXT NOT NULL,
  action TEXT NOT NULL,
  decision TEXT NOT NULL,
  risk_level TEXT NOT NULL,
  reason TEXT,
  payload_digest TEXT NOT NULL,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_security_audit_logs_owner_created
  ON security_audit_logs(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_audit_logs_decision
  ON security_audit_logs(owner_user_id, decision, created_at DESC);

CREATE TABLE IF NOT EXISTS security_incident_reports (
  id TEXT PRIMARY KEY,
  reporter_user_id TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  detail TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_security_incident_reports_reporter
  ON security_incident_reports(reporter_user_id, created_at DESC);
