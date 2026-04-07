# Stage 3 Verification Matrix

Date frozen: `2026-04-07`

This document freezes the execution matrix for `S3-095` and the gated contract lane for `S3-096`.

The repo currently has three distinct verification tiers:

- `plugin-demo`
- `client-only-local-seed`
- `server-backed-joint-debug`

The current worker checkout is a `.cron/...` worktree, so the sibling server path cannot be read only as `../spare-life-server`. For Stage 3 verification, the effective same-machine sibling server checkout resolves to `/Users/wangweiyang/GitHub/spare-life-server` from this worker, and today that repo exists but has no tracked files. Therefore `server-backed-joint-debug` is real but currently `gated`.

## Single Entry Point

Run the full matrix from the repo root:

```bash
bash Docs/scripts/validate_stage3_verification_matrix.sh
```

That script runs all currently valid lanes and leaves the server lane as `gated` until the sibling server checkout contains tracked content.

## Validation Log Schema

Future Stage 3 validation receipts and `Docs/ValidationLog_*.md` entries should follow [Docs/Stage3_Validation_Log_Template.md](/Users/wangweiyang/GitHub/spare-life-ios/.cron/stage3_exec_repo_slot4/Docs/Stage3_Validation_Log_Template.md).

At minimum, each receipt must truthfully record:

- which `verification_tier` actually ran
- which runtime lane was exercised and which adjacent lanes stayed placeholder or gated
- whether route / locator proof came from canonical handoff or only from compatibility fields
- whether macOS parity and desktop optimization were both exercised, instead of being collapsed into a generic smoke claim

## Tier Matrix

| Tier ID | Current runtime truth | Commands | Coverage | Gate / expected result | Evidence |
| --- | --- | --- | --- | --- | --- |
| `plugin-demo` | Node/OpenClaw companion runtime under `ios/spare-life-openclaw-plugin/src/demo/companion-chat-flow-demo.mjs` | `bash Docs/scripts/validate_stage3_openclaw_im_smoke.sh` | canonical home handoff, DM/group locator open, DM/group send gating, group vote close, summary persistence, inspect placement | blocking for plugin-side IM route and capability regressions | stdout summary from `validate_stage3_openclaw_im_smoke.sh` |
| `client-only-local-seed` | shared Apple client checkout under `ios/spare-life-ios-app` plus desktop host under `app/macos` | `bash Docs/scripts/validate_ios_paths.sh`, `bash Docs/scripts/validate_stage3_shared_surface.sh`, `bash Docs/scripts/validate_stage3_messages_typed_routes.sh`, `bash Docs/scripts/validate_stage3_macos_smoke.sh` | README/path truth, preview-host smoke, `MessagesPendingHandoff`, typed route recovery, shared Apple primitives, macOS parity and desktop workspace behavior | blocking for client parity, local-seed, and current checkout truth | command output from each script; summarized in validation receipt |
| `server-backed-joint-debug` | future non-empty sibling checkout at `/Users/wangweiyang/GitHub/spare-life-server` plus current client/plugin truth | `bash Docs/scripts/validate_stage3_joint_debug_contracts.sh` | client/plugin/server contract agreement for locator, render fields, error surface, fallback | currently `gated` because sibling server repo has no tracked files; automatically upgrades to active validation once the repo is non-empty | stdout summary from `validate_stage3_joint_debug_contracts.sh` |

## S3-096 Contract Coverage

When the server tier activates, all three sides must agree on the following contract families:

| Contract family | Client / plugin truth today | What the server tier must match |
| --- | --- | --- |
| locator | `MessagesConversationLocator`, `normalizeIMConversationLocator(...)`, `buildIMConversationLocator(...)` | server responses and debug surfaces must preserve `conversation_id`, `channel_id + group_id`, or `channel_id + dm_peer_id` semantics |
| render fields | `buildIMRenderFields(...)`, `buildIMCardEnvelope(...)` | server-backed debug must not silently rename or drop title / subtitle / preview / badge / unread / source-channel fields |
| error surface | `buildOpenClawIMErrorSurface(...)`, `normalizeOpenClawIMActionError(...)` | server-backed errors must still classify as `unsupported`, `not_ready`, `invalid_locator`, `temporarily_unavailable`, or `permission_denied` |
| fallback | `fallbackIDs`, `errorFallback`, `MessagesPendingHandoff` | server-backed joint debug must preserve re-entry and fallback semantics instead of replacing them with server-only strings |

## Current Gating Rule

`server-backed-joint-debug` remains `gated` until both conditions are true:

1. `/Users/wangweiyang/GitHub/spare-life-server` exists as a git checkout with tracked files.
2. The server repo contains searchable contract anchors for locator keys, render fields, error kinds, and fallback handling.

Until then, Stage 3 must not describe client / plugin / server as already wired. The truthful statement is:

- client and plugin contracts are executable today
- server-backed joint debug is reserved and validated as a gate
- the gate does not turn into a passing runtime lane until the sibling server repo stops being empty

## Command Notes

- `plugin-demo` is not a fake unit-test lane. It runs the real demo/runtime path that currently backs the OpenClaw companion IM surface.
- `client-only-local-seed` is the authoritative current checkout lane. It intentionally validates the seeded/local runtime truth instead of pretending a server is already connected.
- `server-backed-joint-debug` is allowed to return `gated` today. That is the truthful passing state for this checkout because the sibling server repo has no tracked files yet.
- Validation receipts should use the Stage 3 template so future logs keep `OpenClaw IM identity`, `typed route / pending handoff`, `macOS parity`, `desktop optimization`, and `platform lane boundary` in one honest record.

Code and executable scripts override this matrix if the repository evolves.
