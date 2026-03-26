PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS unified_feed_scroll_states (
  user_id TEXT NOT NULL,
  surface_key TEXT NOT NULL,
  anchor_card_id TEXT,
  anchor_offset REAL NOT NULL,
  last_visible_card_id TEXT,
  metadata_json TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, surface_key)
);
CREATE INDEX IF NOT EXISTS idx_unified_feed_scroll_states_user ON unified_feed_scroll_states(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS unified_card_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  surface_key TEXT NOT NULL,
  card_id TEXT NOT NULL,
  card_type TEXT NOT NULL,
  reference_id TEXT,
  event_type TEXT NOT NULL,
  route TEXT,
  detail_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_unified_card_events_user ON unified_card_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_unified_card_events_surface ON unified_card_events(user_id, surface_key, created_at DESC);

