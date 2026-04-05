PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS my_profiles (
  user_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  agent_display_name TEXT NOT NULL,
  headline TEXT NOT NULL,
  bio TEXT NOT NULL,
  city TEXT NOT NULL,
  occupation TEXT NOT NULL,
  growth_focus TEXT NOT NULL,
  persona_tags_json TEXT NOT NULL,
  interests_json TEXT NOT NULL,
  availability_note TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS my_profile_visibility_rules (
  user_id TEXT NOT NULL,
  field_key TEXT NOT NULL,
  visibility_level TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, field_key),
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS my_training_tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  focus_area TEXT NOT NULL,
  target_behavior TEXT NOT NULL,
  difficulty INTEGER NOT NULL,
  status TEXT NOT NULL,
  progress REAL NOT NULL,
  due_at TEXT,
  completed_at TEXT,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_my_training_tasks_user ON my_training_tasks(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS my_error_replays (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source_channel TEXT NOT NULL,
  mismatch_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  transcript_json TEXT NOT NULL,
  diagnosis TEXT NOT NULL,
  repair_brief TEXT NOT NULL,
  status TEXT NOT NULL,
  resolved_note TEXT,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_my_error_replays_user ON my_error_replays(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS my_persona_configs (
  user_id TEXT PRIMARY KEY,
  awakening_seed INTEGER NOT NULL,
  growth_mode TEXT NOT NULL,
  dna_json TEXT NOT NULL,
  values_json TEXT NOT NULL,
  active_mask_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS my_persona_masks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL,
  scenario_key TEXT NOT NULL,
  tone TEXT NOT NULL,
  openness TEXT NOT NULL,
  boundary_tags_json TEXT NOT NULL,
  style_tags_json TEXT NOT NULL,
  is_default INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_my_persona_masks_user ON my_persona_masks(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS my_memory_entries (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title_hint TEXT NOT NULL,
  memory_kind TEXT NOT NULL,
  permission_scope TEXT NOT NULL,
  grants_json TEXT NOT NULL,
  cipher_algorithm TEXT NOT NULL,
  cipher_iv TEXT NOT NULL,
  cipher_text TEXT NOT NULL,
  auth_tag TEXT NOT NULL,
  checksum TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_opened_at TEXT,
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_my_memory_entries_user ON my_memory_entries(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS my_sync_snapshots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  score INTEGER NOT NULL,
  delta INTEGER NOT NULL,
  band TEXT NOT NULL,
  confidence INTEGER NOT NULL,
  breakdown_json TEXT NOT NULL,
  next_actions_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_my_sync_snapshots_user ON my_sync_snapshots(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS my_growth_snapshots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  idle_energy INTEGER NOT NULL,
  social_score INTEGER NOT NULL,
  sync_score INTEGER NOT NULL,
  awakening_score INTEGER NOT NULL,
  memory_count INTEGER NOT NULL,
  active_backups INTEGER NOT NULL,
  note TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_my_growth_snapshots_user ON my_growth_snapshots(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS my_growth_journal (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  mood TEXT NOT NULL,
  stat_delta_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_my_growth_journal_user ON my_growth_journal(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS my_authorizations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  resource_key TEXT NOT NULL,
  status TEXT NOT NULL,
  detail TEXT NOT NULL,
  last_prompted_at TEXT,
  updated_at TEXT NOT NULL,
  UNIQUE (user_id, resource_key),
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS my_local_backups (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  checksum TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  purged_at TEXT,
  FOREIGN KEY (user_id) REFERENCES my_profiles(user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_my_local_backups_user ON my_local_backups(user_id, created_at DESC);
