#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stage3_joint_debug_contracts.XXXXXX")"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

resolve_server_root() {
  local candidates=(
    "${REPO_ROOT}/../spare-life-server"
    "${REPO_ROOT}/../../spare-life-server"
    "${REPO_ROOT}/../../../spare-life-server"
    "/Users/wangweiyang/GitHub/spare-life-server"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -d "${candidate}" ] && git -C "${candidate}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

if ! SERVER_ROOT="$(resolve_server_root)"; then
  echo "[stage3-joint-debug] gated: no sibling spare-life-server checkout found."
  exit 0
fi

echo "[stage3-joint-debug] repo root: ${REPO_ROOT}"
echo "[stage3-joint-debug] server root: ${SERVER_ROOT}"

node --input-type=module - "${REPO_ROOT}" <<'NODE'
import assert from 'node:assert/strict';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const repoRoot = process.argv[2];
const contractsPath = path.join(repoRoot, 'ios/spare-life-ios-app/Domain/Models/companionContracts.mjs');
const contracts = await import(pathToFileURL(contractsPath).href);

const conversationLocator = contracts.buildIMConversationLocator({
  conversationId: 'conv-001'
});
assert.equal(conversationLocator.kind, 'conversation');

const groupLocator = contracts.buildIMConversationLocator({
  channelId: 'companion',
  groupId: 'weekend-makers'
});
assert.equal(groupLocator.kind, 'group');

const dmLocator = contracts.buildIMConversationLocator({
  channelId: 'companion',
  peerId: 'lin-zhou'
});
assert.equal(dmLocator.kind, 'dm');

const renderFields = contracts.buildIMRenderFields({
  surfaceKind: 'group',
  primaryTitle: '周末共创小组',
  secondaryTitle: '3 人在线',
  preview: '周六先砍需求，再演示一个闭环。',
  badge: '3',
  unreadCount: 3,
  sourceChannelID: 'companion'
});
assert.equal(renderFields.primaryTitle, '周末共创小组');
assert.equal(renderFields.surfaceKind, 'group');
assert.equal(renderFields.unreadCount, 3);

const actionContract = contracts.buildOpenClawIMActionContract('open_conversation', {
  surfaceKind: 'dm',
  locator: dmLocator
});
assert.equal(actionContract.actionKey, 'open_conversation');
assert(actionContract.fallbackIDs.includes('card_envelope.locator'));
assert(actionContract.supportedErrorKinds.includes('invalid_locator'));

const errorSurface = contracts.buildOpenClawIMErrorSurface({
  kind: 'invalid_locator',
  actionKey: 'open_conversation',
  surfaceKind: 'dm',
  missingIDs: ['locator.peer_id']
});
assert.equal(errorSurface.kind, 'invalid_locator');
assert(errorSurface.fallbackIDs.includes('card_envelope.locator'));

const normalizedError = contracts.normalizeOpenClawIMActionError(
  new Error('Unknown conversation locator for direct thread.'),
  {
    actionKey: 'open_conversation',
    surfaceKind: 'dm'
  }
);
assert.equal(normalizedError.errorSurface.kind, 'invalid_locator');

const envelope = contracts.buildIMCardEnvelope({
  locator: dmLocator,
  surfaceKind: 'dm',
  renderFields: {
    primaryTitle: '周琳',
    preview: '先把 Demo 收尾，不再加新功能。',
    unreadCount: 1
  }
});
assert.equal(envelope.renderFields.primaryTitle, '周琳');
assert.equal(envelope.renderFields.unreadCount, 1);
assert.equal(envelope.locator.kind, 'dm');

console.log(
  [
    '[stage3-joint-debug] local-contract-ok',
    `conversation=${conversationLocator.kind}`,
    `group=${groupLocator.kind}`,
    `dm=${dmLocator.kind}`,
    `error=${errorSurface.kind}`,
    `fallbacks=${actionContract.fallbackIDs.length}`
  ].join(' ')
);
NODE

TRACKED_FILES="$(git -C "${SERVER_ROOT}" ls-files)"
if [ -z "${TRACKED_FILES}" ]; then
  echo "[stage3-joint-debug] gated: sibling server checkout exists but has no tracked files yet."
  exit 0
fi

require_server_anchor() {
  local pattern="$1"
  local description="$2"
  if ! rg -n -m 1 "${pattern}" "${SERVER_ROOT}" >/dev/null; then
    echo "[stage3-joint-debug] missing server anchor: ${description}" >&2
    exit 1
  fi
}

require_server_anchor 'conversation_id|conversationId' 'locator conversation id'
require_server_anchor 'channel_id|channelId' 'locator channel id'
require_server_anchor 'group_id|groupId' 'locator group id'
require_server_anchor 'dm_peer_id|peerId|contactId' 'locator dm peer id'
require_server_anchor 'renderFields|primaryTitle|secondaryTitle|preview|badge' 'render fields'
require_server_anchor 'invalid_locator' 'error kind invalid_locator'
require_server_anchor 'temporarily_unavailable' 'error kind temporarily_unavailable'
require_server_anchor 'permission_denied' 'error kind permission_denied'
require_server_anchor 'fallback' 'fallback handling'

echo "[stage3-joint-debug] server-contract-ok tracked_files=$(printf '%s\n' "${TRACKED_FILES}" | wc -l | tr -d ' ')"
