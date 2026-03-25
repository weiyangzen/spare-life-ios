CREATE TABLE IF NOT EXISTS a2a_lanes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  tone TEXT NOT NULL,
  summary TEXT NOT NULL,
  shortcut_label TEXT NOT NULL,
  keywords_json TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  entry_route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS a2a_intent_templates (
  id TEXT PRIMARY KEY,
  lane_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  mode_hints_json TEXT NOT NULL,
  tags_json TEXT NOT NULL,
  form_template_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_templates_lane ON a2a_intent_templates(lane_id);

CREATE TABLE IF NOT EXISTS a2a_public_agent_cards (
  id TEXT PRIMARY KEY,
  agent_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  lane_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  persona_tags_json TEXT NOT NULL,
  expertise_tags_json TEXT NOT NULL,
  open_hours_json TEXT NOT NULL,
  expected_partner_json TEXT NOT NULL,
  explanation_tags_json TEXT NOT NULL,
  allows_agent_intro INTEGER NOT NULL DEFAULT 1,
  public_bio TEXT NOT NULL,
  trust_score REAL NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_public_cards_lane ON a2a_public_agent_cards(lane_id, trust_score DESC);

CREATE TABLE IF NOT EXISTS a2a_intent_posts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  lane_id TEXT NOT NULL,
  template_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  mode TEXT NOT NULL,
  status TEXT NOT NULL,
  target_agent_id TEXT,
  form_payload_json TEXT NOT NULL,
  tags_json TEXT NOT NULL,
  ranking_score REAL NOT NULL,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE,
  FOREIGN KEY(template_id) REFERENCES a2a_intent_templates(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_intents_lane_status ON a2a_intent_posts(lane_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_a2a_intents_user ON a2a_intent_posts(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS a2a_intent_events (
  id TEXT PRIMARY KEY,
  intent_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  detail_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(intent_id) REFERENCES a2a_intent_posts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_intent_events_intent ON a2a_intent_events(intent_id, created_at DESC);

CREATE TABLE IF NOT EXISTS a2a_persona_feedback_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  lane_id TEXT NOT NULL,
  feedback TEXT NOT NULL,
  detail_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_persona_feedback_user ON a2a_persona_feedback_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_a2a_persona_feedback_agent ON a2a_persona_feedback_events(agent_id, created_at DESC);

CREATE TABLE IF NOT EXISTS a2a_icebreak_sessions (
  id TEXT PRIMARY KEY,
  lane_id TEXT NOT NULL,
  intent_id TEXT NOT NULL,
  initiator_user_id TEXT NOT NULL,
  target_agent_id TEXT NOT NULL,
  counterpart_user_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  status TEXT NOT NULL,
  compatibility_score REAL NOT NULL,
  handoff_rule_json TEXT NOT NULL,
  consent_json TEXT NOT NULL,
  summary TEXT NOT NULL,
  route TEXT NOT NULL,
  human_thread_route TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE,
  FOREIGN KEY(intent_id) REFERENCES a2a_intent_posts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_icebreak_user ON a2a_icebreak_sessions(initiator_user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_a2a_icebreak_lane ON a2a_icebreak_sessions(lane_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS a2a_icebreak_messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  turn_index INTEGER NOT NULL,
  actor_kind TEXT NOT NULL,
  stage TEXT NOT NULL,
  content TEXT NOT NULL,
  audit_status TEXT NOT NULL,
  prompt_kind TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES a2a_icebreak_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_icebreak_messages_session ON a2a_icebreak_messages(session_id, turn_index ASC);

CREATE TABLE IF NOT EXISTS a2a_icebreak_audit_logs (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  message_id TEXT NOT NULL,
  prompt_kind TEXT NOT NULL,
  policy_status TEXT NOT NULL,
  policy_result_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(session_id) REFERENCES a2a_icebreak_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY(message_id) REFERENCES a2a_icebreak_messages(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_icebreak_audit_session ON a2a_icebreak_audit_logs(session_id, created_at ASC);

CREATE TABLE IF NOT EXISTS a2a_energy_wallets (
  user_id TEXT PRIMARY KEY,
  balance INTEGER NOT NULL DEFAULT 0,
  frozen_balance INTEGER NOT NULL DEFAULT 0,
  lifetime_earned INTEGER NOT NULL DEFAULT 0,
  lifetime_spent INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS a2a_energy_ledger (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  lane_id TEXT,
  entry_type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL,
  rule_key TEXT NOT NULL,
  reference_kind TEXT NOT NULL,
  reference_id TEXT,
  dedupe_key TEXT,
  risk_status TEXT NOT NULL,
  detail_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  settled_at TEXT,
  UNIQUE(dedupe_key)
);

CREATE INDEX IF NOT EXISTS idx_a2a_energy_user ON a2a_energy_ledger(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS a2a_lane_events (
  id TEXT PRIMARY KEY,
  lane_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  heat_delta INTEGER NOT NULL,
  reward_amount INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_lane_events_lane ON a2a_lane_events(lane_id);

CREATE TABLE IF NOT EXISTS a2a_lane_heat_snapshots (
  id TEXT PRIMARY KEY,
  lane_id TEXT NOT NULL,
  open_intents INTEGER NOT NULL,
  active_icebreaks INTEGER NOT NULL,
  active_personas INTEGER NOT NULL,
  active_arena_matches INTEGER NOT NULL,
  event_heat INTEGER NOT NULL,
  engagement_score REAL NOT NULL,
  profit_score REAL NOT NULL,
  supply_gap_score REAL NOT NULL,
  response_speed_score REAL NOT NULL,
  heat_score REAL NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_lane_heat_lane ON a2a_lane_heat_snapshots(lane_id, created_at DESC);

CREATE TABLE IF NOT EXISTS a2a_lane_exploration_rewards (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  lane_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  ledger_entry_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE,
  FOREIGN KEY(event_id) REFERENCES a2a_lane_events(id) ON DELETE CASCADE,
  FOREIGN KEY(ledger_entry_id) REFERENCES a2a_energy_ledger(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_lane_rewards_user ON a2a_lane_exploration_rewards(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS a2a_arena_matches (
  id TEXT PRIMARY KEY,
  lane_id TEXT NOT NULL,
  theme TEXT NOT NULL,
  challenger_agent_id TEXT NOT NULL,
  opponent_agent_id TEXT NOT NULL,
  created_by_user_id TEXT NOT NULL,
  status TEXT NOT NULL,
  round_count INTEGER NOT NULL,
  winner_side TEXT,
  scoreboard_json TEXT NOT NULL,
  recap_json TEXT NOT NULL,
  route TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_arena_lane ON a2a_arena_matches(lane_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS a2a_arena_rounds (
  id TEXT PRIMARY KEY,
  match_id TEXT NOT NULL,
  round_index INTEGER NOT NULL,
  prompt TEXT NOT NULL,
  challenger_reply TEXT NOT NULL,
  opponent_reply TEXT NOT NULL,
  judge_score_json TEXT NOT NULL,
  summary TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(match_id) REFERENCES a2a_arena_matches(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_arena_rounds_match ON a2a_arena_rounds(match_id, round_index ASC);

CREATE TABLE IF NOT EXISTS a2a_arena_votes (
  id TEXT PRIMARY KEY,
  match_id TEXT NOT NULL,
  voter_user_id TEXT NOT NULL,
  preferred_side TEXT NOT NULL,
  weight INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(match_id) REFERENCES a2a_arena_matches(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_arena_votes_match ON a2a_arena_votes(match_id, created_at ASC);

CREATE TABLE IF NOT EXISTS a2a_bond_relationships (
  id TEXT PRIMARY KEY,
  lane_id TEXT NOT NULL,
  source_session_id TEXT NOT NULL,
  initiator_user_id TEXT NOT NULL,
  counterpart_user_id TEXT NOT NULL,
  counterpart_agent_id TEXT NOT NULL,
  level TEXT NOT NULL,
  strength_score REAL NOT NULL,
  status TEXT NOT NULL,
  milestone_count INTEGER NOT NULL DEFAULT 0,
  memorial_card_json TEXT NOT NULL,
  thread_route TEXT NOT NULL,
  last_activity_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(lane_id) REFERENCES a2a_lanes(id) ON DELETE CASCADE,
  FOREIGN KEY(source_session_id) REFERENCES a2a_icebreak_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_bonds_user ON a2a_bond_relationships(initiator_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS a2a_bond_tasks (
  id TEXT PRIMARY KEY,
  bond_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  status TEXT NOT NULL,
  target_count INTEGER NOT NULL,
  progress_count INTEGER NOT NULL,
  reward_amount INTEGER NOT NULL,
  milestone_key TEXT NOT NULL,
  completed_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(bond_id) REFERENCES a2a_bond_relationships(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_bond_tasks_bond ON a2a_bond_tasks(bond_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS a2a_bond_milestones (
  id TEXT PRIMARY KEY,
  bond_id TEXT NOT NULL,
  milestone_key TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  achieved_at TEXT NOT NULL,
  FOREIGN KEY(bond_id) REFERENCES a2a_bond_relationships(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_bond_milestones_bond ON a2a_bond_milestones(bond_id, achieved_at DESC);

CREATE TABLE IF NOT EXISTS a2a_thread_migrations (
  id TEXT PRIMARY KEY,
  bond_id TEXT NOT NULL,
  source_session_id TEXT NOT NULL,
  messages_route TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(bond_id) REFERENCES a2a_bond_relationships(id) ON DELETE CASCADE,
  FOREIGN KEY(source_session_id) REFERENCES a2a_icebreak_sessions(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_a2a_thread_migrations_bond ON a2a_thread_migrations(bond_id, created_at DESC);
