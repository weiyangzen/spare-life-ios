PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS scan_targets (
  id TEXT PRIMARY KEY,
  scene_key TEXT NOT NULL UNIQUE,
  raw_code TEXT NOT NULL,
  canonical_code TEXT NOT NULL,
  target_kind TEXT NOT NULL,
  source_type TEXT NOT NULL,
  title TEXT NOT NULL,
  location_label TEXT,
  scene_tags_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_scanned_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scene_feeds (
  id TEXT PRIMARY KEY,
  scene_key TEXT NOT NULL UNIQUE,
  scan_target_id TEXT NOT NULL,
  summary_card_json TEXT NOT NULL,
  hot_take_cards_json TEXT NOT NULL,
  risk_cards_json TEXT NOT NULL,
  clusters_json TEXT NOT NULL,
  moderation_json TEXT NOT NULL,
  source_fingerprint TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (scan_target_id) REFERENCES scan_targets(id)
);

CREATE TABLE IF NOT EXISTS scene_posts (
  id TEXT PRIMARY KEY,
  scene_key TEXT NOT NULL,
  external_id TEXT NOT NULL,
  author_name TEXT NOT NULL,
  text TEXT NOT NULL,
  sentiment TEXT NOT NULL,
  engagement REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  topic_tags_json TEXT NOT NULL,
  is_flagged INTEGER NOT NULL DEFAULT 0,
  flag_reason TEXT,
  source_agent_id TEXT,
  UNIQUE (scene_key, external_id)
);

CREATE TABLE IF NOT EXISTS agent_public_cards (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  identity_tags_json TEXT NOT NULL,
  intent_tags_json TEXT NOT NULL,
  expertise_tags_json TEXT NOT NULL,
  public_bio TEXT NOT NULL,
  allows_agent_intro INTEGER NOT NULL DEFAULT 0,
  visibility_scope TEXT NOT NULL,
  privacy_radius TEXT NOT NULL,
  trust_score REAL NOT NULL DEFAULT 0,
  location_label TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scene_agent_presence (
  id TEXT PRIMARY KEY,
  scene_key TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  card_id TEXT NOT NULL,
  activity_score REAL NOT NULL,
  freshness_score REAL NOT NULL,
  match_score REAL NOT NULL,
  trust_score REAL NOT NULL,
  heat_score REAL NOT NULL,
  masked_location_label TEXT NOT NULL,
  contact_hint TEXT NOT NULL,
  combined_tags_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (scene_key, agent_id),
  FOREIGN KEY (card_id) REFERENCES agent_public_cards(id)
);

CREATE TABLE IF NOT EXISTS social_intents (
  id TEXT PRIMARY KEY,
  scene_key TEXT NOT NULL,
  initiator_user_id TEXT NOT NULL,
  target_agent_id TEXT,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  chat_mode TEXT NOT NULL,
  scene_tags_json TEXT NOT NULL,
  route TEXT,
  risk_status TEXT NOT NULL,
  risk_reason TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS scene_scan_events (
  id TEXT PRIMARY KEY,
  scene_key TEXT NOT NULL,
  scan_target_id TEXT NOT NULL,
  channel TEXT NOT NULL,
  source_type TEXT NOT NULL,
  raw_code TEXT NOT NULL,
  used_cache INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (scan_target_id) REFERENCES scan_targets(id)
);

CREATE TABLE IF NOT EXISTS scene_summary_sources (
  scene_feed_id TEXT NOT NULL,
  card_type TEXT NOT NULL,
  cluster_key TEXT NOT NULL,
  post_id TEXT NOT NULL,
  PRIMARY KEY (scene_feed_id, card_type, cluster_key, post_id),
  FOREIGN KEY (scene_feed_id) REFERENCES scene_feeds(id)
);

CREATE INDEX IF NOT EXISTS idx_scene_posts_scene_key ON scene_posts(scene_key, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scene_presence_scene_key ON scene_agent_presence(scene_key, heat_score DESC);
CREATE INDEX IF NOT EXISTS idx_social_intents_recent ON social_intents(scene_key, initiator_user_id, created_at DESC);
