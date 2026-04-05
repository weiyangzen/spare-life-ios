CREATE TABLE IF NOT EXISTS companion_contacts (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  persona_summary TEXT NOT NULL,
  tags_json TEXT NOT NULL,
  default_mask_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_companion_contacts_owner ON companion_contacts(owner_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_masks (
  id TEXT PRIMARY KEY,
  contact_id TEXT NOT NULL,
  tone TEXT NOT NULL,
  openness TEXT NOT NULL,
  boundary_tags_json TEXT NOT NULL,
  signature TEXT NOT NULL,
  override_rules_json TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(contact_id) REFERENCES companion_contacts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_masks_contact ON companion_masks(contact_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_mask_history (
  id TEXT PRIMARY KEY,
  contact_id TEXT NOT NULL,
  mask_id TEXT NOT NULL,
  change_summary TEXT NOT NULL,
  diff_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(contact_id) REFERENCES companion_contacts(id) ON DELETE CASCADE,
  FOREIGN KEY(mask_id) REFERENCES companion_masks(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_mask_history_contact ON companion_mask_history(contact_id, created_at DESC);

CREATE TABLE IF NOT EXISTS companion_groups (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  tool_agent_name TEXT NOT NULL,
  noise_threshold REAL NOT NULL,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_companion_groups_owner ON companion_groups(owner_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_conversations (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  contact_id TEXT,
  group_id TEXT,
  unread_count INTEGER NOT NULL DEFAULT 0,
  last_message_preview TEXT,
  last_message_at TEXT NOT NULL,
  last_opened_at TEXT,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(contact_id) REFERENCES companion_contacts(id) ON DELETE CASCADE,
  FOREIGN KEY(group_id) REFERENCES companion_groups(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_conversations_owner ON companion_conversations(owner_user_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_companion_conversations_contact ON companion_conversations(contact_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_companion_conversations_group ON companion_conversations(group_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_conversation_participants (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  participant_key TEXT NOT NULL,
  role TEXT NOT NULL,
  display_name TEXT NOT NULL,
  permissions_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(conversation_id, participant_key),
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_participants_conversation ON companion_conversation_participants(conversation_id, role);

CREATE TABLE IF NOT EXISTS companion_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  turn_index INTEGER NOT NULL,
  actor_key TEXT NOT NULL,
  actor_role TEXT NOT NULL,
  channel_kind TEXT NOT NULL,
  content TEXT NOT NULL,
  search_text TEXT NOT NULL,
  metadata_json TEXT NOT NULL,
  signal_score REAL NOT NULL DEFAULT 100,
  suppressed INTEGER NOT NULL DEFAULT 0,
  unread_for_owner INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_messages_conversation ON companion_messages(conversation_id, turn_index ASC);
CREATE INDEX IF NOT EXISTS idx_companion_messages_search ON companion_messages(conversation_id, search_text);

CREATE TABLE IF NOT EXISTS companion_relationships (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  contact_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  level TEXT NOT NULL,
  warmth_score REAL NOT NULL,
  latest_summary TEXT NOT NULL,
  memorial_card_json TEXT NOT NULL,
  last_ritual_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(owner_user_id, contact_id),
  FOREIGN KEY(contact_id) REFERENCES companion_contacts(id) ON DELETE CASCADE,
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_relationships_owner ON companion_relationships(owner_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_rituals (
  id TEXT PRIMARY KEY,
  relationship_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  ritual_kind TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  status TEXT NOT NULL,
  scheduled_for TEXT,
  completed_at TEXT,
  memorial_card_json TEXT NOT NULL,
  memory_lane_summary TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(relationship_id) REFERENCES companion_relationships(id) ON DELETE CASCADE,
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_rituals_relationship ON companion_rituals(relationship_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_memory_snapshots (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  contact_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  layer TEXT NOT NULL,
  summary TEXT NOT NULL,
  keywords_json TEXT NOT NULL,
  emotion_label TEXT NOT NULL,
  warmth_score REAL NOT NULL,
  source_message_ids_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(contact_id) REFERENCES companion_contacts(id) ON DELETE CASCADE,
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_memory_contact ON companion_memory_snapshots(contact_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_companion_memory_conversation ON companion_memory_snapshots(conversation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS companion_group_members (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  member_key TEXT NOT NULL,
  role TEXT NOT NULL,
  display_name TEXT NOT NULL,
  contact_id TEXT,
  permissions_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(group_id, member_key),
  FOREIGN KEY(group_id) REFERENCES companion_groups(id) ON DELETE CASCADE,
  FOREIGN KEY(contact_id) REFERENCES companion_contacts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_group_members_group ON companion_group_members(group_id, role);

CREATE TABLE IF NOT EXISTS companion_group_votes (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  question TEXT NOT NULL,
  status TEXT NOT NULL,
  options_json TEXT NOT NULL,
  result_summary TEXT,
  created_by TEXT NOT NULL,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(group_id) REFERENCES companion_groups(id) ON DELETE CASCADE,
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_group_votes_group ON companion_group_votes(group_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS companion_group_vote_ballots (
  id TEXT PRIMARY KEY,
  vote_id TEXT NOT NULL,
  voter_key TEXT NOT NULL,
  option_id TEXT NOT NULL,
  rationale TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(vote_id, voter_key),
  FOREIGN KEY(vote_id) REFERENCES companion_group_votes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_ballots_vote ON companion_group_vote_ballots(vote_id, created_at ASC);

CREATE TABLE IF NOT EXISTS companion_group_summaries (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  summary TEXT NOT NULL,
  included_message_ids_json TEXT NOT NULL,
  suppressed_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY(group_id) REFERENCES companion_groups(id) ON DELETE CASCADE,
  FOREIGN KEY(conversation_id) REFERENCES companion_conversations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_companion_group_summaries_group ON companion_group_summaries(group_id, created_at DESC);
