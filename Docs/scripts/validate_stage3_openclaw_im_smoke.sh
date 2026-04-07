#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage3_openclaw_im_smoke.XXXXXX")"
REPORT_JSON="$TMP_DIR/companion-chat-flow-demo.json"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$ROOT"

node ios/spare-life-openclaw-plugin/src/demo/companion-chat-flow-demo.mjs >"$REPORT_JSON"

node --input-type=module - "$REPORT_JSON" <<'NODE'
import fs from 'node:fs';

const reportPath = process.argv[2];
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const validation = report.validation ?? {};
const contextTypes = new Set((report.reopenedDirect?.contextCards ?? []).map((card) => card.cardType));

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(validation.initialHomeHandoffRouteKind === 'home', 'messages home should resolve to the canonical home handoff.');
assert(typeof validation.locatorOpenConversationID === 'string' && validation.locatorOpenConversationID.length > 0, 'DM open must resolve a live conversation.');
assert(validation.directMessageAvailableOnDirect === true, 'DM card must allow direct send.');
assert(validation.groupConversationAvailableOnGroup === true, 'group card must allow group open.');
assert(validation.directOnlyGateCode === 'unsupported', 'group surface must reject direct-only DM send.');
assert(validation.groupOnlyGateCode === 'unsupported', 'DM surface must reject group-only open.');
assert(typeof report.groupBefore?.messages?.length === 'number' && report.groupBefore.messages.length >= 1, 'group open must return live messages.');
assert(report.noisyGroupMessage?.suppressed === true, 'group send must enforce suppression on low-signal noise.');
assert(validation.closedVoteStatus === 'closed', 'group vote must close after the final ballot.');
assert(typeof validation.closedVoteSummary === 'string' && validation.closedVoteSummary.length > 0, 'group vote must emit a result summary.');
assert(typeof report.groupSummary?.summary?.id === 'string' && report.groupSummary.summary.id.length > 0, 'group summary must persist a real summary payload.');
assert(typeof validation.totalSummaries === 'number' && validation.totalSummaries >= 1, 'summary state must be persisted.');
assert(contextTypes.has('companion_inspect'), 'reopened DM thread must expose the companion inspect entry.');
assert(report.reopenedDirect?.companionInspectionEntry?.diagnosticsEntry?.supported === true, 'inspect must point to diagnostics/internal tool instead of a fake thread subpage.');
assert(typeof report.state?.counts?.messages === 'number' && report.state.counts.messages >= validation.totalMessages, 'inspect state must expose persisted runtime counts.');

console.log(
  [
    'S3-091 OpenClaw IM smoke ok.',
    `home=${validation.initialHomeHandoffRouteKind}`,
    `dm=${validation.locatorOpenConversationID}`,
    `groupMessages=${report.groupBefore.messages.length}`,
    `vote=${validation.closedVoteStatus}`,
    `summaries=${validation.totalSummaries}`,
    `inspect=${report.reopenedDirect.companionInspectionEntry.kind}`
  ].join(' ')
);
NODE
