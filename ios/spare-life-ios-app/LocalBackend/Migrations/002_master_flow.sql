PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS master_domains (
  key TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS master_asset_imports (
  bundle_id TEXT NOT NULL,
  bundle_version TEXT NOT NULL,
  checksum TEXT NOT NULL,
  imported_at TEXT NOT NULL,
  PRIMARY KEY (bundle_id, bundle_version)
);

CREATE TABLE IF NOT EXISTS masters (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  bundle_id TEXT NOT NULL,
  bundle_version TEXT NOT NULL,
  domain_key TEXT NOT NULL,
  display_name TEXT NOT NULL,
  title TEXT NOT NULL,
  tagline TEXT NOT NULL,
  profile_json TEXT NOT NULL,
  character_json TEXT NOT NULL,
  prompt_template TEXT NOT NULL,
  prompt_preview TEXT NOT NULL,
  portrait_asset_path TEXT NOT NULL,
  portrait_checksum TEXT NOT NULL,
  read_only INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(domain_key) REFERENCES master_domains(key)
);

CREATE INDEX IF NOT EXISTS idx_masters_domain ON masters(domain_key);

CREATE TABLE IF NOT EXISTS master_stories (
  id TEXT PRIMARY KEY,
  master_id TEXT NOT NULL,
  story_key TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  full_text TEXT NOT NULL,
  beats_json TEXT NOT NULL,
  tags_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(master_id, story_key),
  FOREIGN KEY(master_id) REFERENCES masters(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_master_stories_master ON master_stories(master_id);

CREATE TABLE IF NOT EXISTS master_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  master_id TEXT NOT NULL,
  topic TEXT NOT NULL,
  unread_count INTEGER NOT NULL DEFAULT 0,
  last_user_message TEXT,
  last_assistant_message TEXT,
  last_story_ids_json TEXT NOT NULL DEFAULT '[]',
  last_memory_ids_json TEXT NOT NULL DEFAULT '[]',
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_message_at TEXT NOT NULL,
  last_opened_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(master_id) REFERENCES masters(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_master_sessions_recent ON master_sessions(user_id, last_message_at DESC);

CREATE TABLE IF NOT EXISTS master_messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  story_ids_json TEXT NOT NULL DEFAULT '[]',
  memory_ids_json TEXT NOT NULL DEFAULT '[]',
  ctas_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES master_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_master_messages_session ON master_messages(session_id, created_at ASC);

CREATE TABLE IF NOT EXISTS master_memories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  master_id TEXT NOT NULL,
  session_id TEXT,
  scope TEXT NOT NULL,
  memory_kind TEXT NOT NULL,
  summary TEXT NOT NULL,
  detail_json TEXT NOT NULL,
  tags_json TEXT NOT NULL,
  authorized_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(master_id) REFERENCES masters(id) ON DELETE CASCADE,
  FOREIGN KEY(session_id) REFERENCES master_sessions(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_master_memories_lookup ON master_memories(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS master_consultations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  issue TEXT NOT NULL,
  shared_scope TEXT NOT NULL,
  merged_summary TEXT NOT NULL,
  conflicts_json TEXT NOT NULL,
  ctas_json TEXT NOT NULL,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_master_consultations_user ON master_consultations(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS master_consultation_members (
  id TEXT PRIMARY KEY,
  consultation_id TEXT NOT NULL,
  master_id TEXT NOT NULL,
  stance TEXT NOT NULL,
  advice TEXT NOT NULL,
  story_ids_json TEXT NOT NULL,
  memory_ids_json TEXT NOT NULL,
  ctas_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(consultation_id) REFERENCES master_consultations(id) ON DELETE CASCADE,
  FOREIGN KEY(master_id) REFERENCES masters(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_master_consult_members_consult ON master_consultation_members(consultation_id);

CREATE TABLE IF NOT EXISTS master_cta_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source_kind TEXT NOT NULL,
  source_id TEXT NOT NULL,
  master_id TEXT,
  cta_id TEXT NOT NULL,
  route TEXT NOT NULL,
  effect_kind TEXT NOT NULL,
  triggered_at TEXT NOT NULL,
  FOREIGN KEY(master_id) REFERENCES masters(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_master_cta_events_user ON master_cta_events(user_id, triggered_at DESC);
