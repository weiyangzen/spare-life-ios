# Stage 3 Validation Log Template

Date frozen: `2026-04-07`

This template is the required Stage 3 validation-log schema for future `Docs/ValidationLog_*.md` entries and local validation receipts that claim closure for:

- route / locator / handoff work
- OpenClaw IM identity or capability parity
- iOS / macOS parity and desktop optimization
- platform-lane boundary validation

If code, smoke output, and older logs disagree, code plus the latest executable evidence win.

## Required Use

Use this template whenever a Stage 3 batch claims any of the following:

- `plugin-demo` proof for OpenClaw IM
- `client-only-local-seed` proof for Apple shared source, typed routes, or macOS desktop behavior
- `server-backed-joint-debug` proof for future client/plugin/server contract alignment

The minimum honest log is not “commands ran successfully.” It must also state which runtime lane was actually exercised and which adjacent lanes stayed placeholder or gated.

## Required Header

Copy this skeleton into the validation log and fill every placeholder that applies:

```md
# Validation Log - <Surface> <Lane> Batch <N>
Worker: <slot / lane>
Date: YYYY-MM-DD

## Trace
- stage_items: S3-0xx, S4-0x
- bp_refs: [line:....][id:....]
- code_refs:
  - <path>
- research_refs:
  - <path>
- artifact_refs:
  - <path or n/a>

## Summary
- result: passed | blocked | failed | partial
- blocker_code: <code or none>
- environment_class: node | swiftpm | xcodebuild | mixed
- verification_tier: plugin-demo | client-only-local-seed | server-backed-joint-debug
- runtime_lane: ios | app/macos | ios/spare-life-openclaw-plugin | mixed
- latest_run_at: YYYY-MM-DD HH:MM TZ

## Lane Boundary Truth
- active_runtime_surfaces:
  - <surface actually exercised>
- shared_source_intake:
  - <shared source roots actually compiled or executed>
- non_runtime_or_gated_surfaces:
  - <placeholder, mock-only, or gated lanes that were not exercised>
- lane_boundary_notes:
  - <for example: windows11/ubuntu placeholders, empty sibling server repo, diagnostics-only surface>

## Commands
1. `<exact command>`
   - Result: pass | blocked | fail
   - Key output: <short factual summary>

## Contract Checks
- messages route / handoff:
  - canonical route kind(s): <home / compose_draft / thread / pendingThread / other>
  - legacy normalization exercised: yes | no
  - pending handoff behavior exercised: yes | no
- OpenClaw IM identity:
  - canonicalCardID evidence: <value or n/a>
  - locator evidence: <conversation | group | dm | n/a>
  - sourceChannelID evidence: <value or n/a>
  - surfaceKind evidence: <dm | group | n/a>
  - capability / error-surface evidence: <short summary or n/a>
- macOS parity:
  - mirrored pages checked: <list or n/a>
  - typed-route enter / return checked: yes | no
  - default + minimum window coverage: yes | no
- desktop optimization:
  - layout style evidence: <hub-thread-detail / list-detail-inspector / other / n/a>
  - multi-column workspace evidence: yes | no
  - inspector / sidebar / toolbar evidence: yes | no

## Environment Limitations
- <toolchain, simulator, sibling repo, or host limitation>

## Run Notes
- <brief factual notes only>
```

## Stage 3-Specific Rules

### 1. OpenClaw IM Identity Must Be Logged Explicitly

If the batch touches `messages home`, `thread open`, OpenClaw IM smoke, or route normalization, the log must explicitly name:

- the `verification_tier`
- the `runtime_lane`
- whether the evidence came from `cardEnvelope`, `openAction`, or canonical `locator`
- the `canonicalCardID` or a truthful `n/a`
- the `locator` kind or a truthful `n/a`

This prevents future logs from claiming “IM identity is aligned” while only proving a display string or ad-hoc route string.

### 2. macOS Parity And Desktop Optimization Are Separate Checks

If the batch touches the desktop host, the log must separately answer:

- did the mirrored page order stay truthful
- did typed-route detail enter and return still work
- did both default and minimum desktop sizes render
- did the host keep a real multi-column workspace instead of a scaled-up mobile page

Do not collapse these into a generic “macOS smoke passed” sentence.

### 3. Lane Boundary Truth Is Mandatory

Every Stage 3 log must say which nearby lanes were *not* exercised. The common cases today are:

- `android/` is placeholder-only
- `app/windows11/` is placeholder-only
- `app/ubuntu/` is placeholder-only
- `server-backed-joint-debug` is still `gated` while `/Users/wangweiyang/GitHub/spare-life-server` has no tracked files
- infrastructure or diagnostic surfaces are not proof of shipped runtime wiring

If a lane stayed placeholder or gated, say so in the log instead of letting readers infer it incorrectly.

### 4. Route And Parity Claims Must Stay In The Same Receipt

If a batch claims both messages route closure and macOS parity closure, record them in the same receipt so readers can tell whether:

- the shared typed route was exercised before the macOS shell wrapped it
- the macOS shell preserved that typed route behavior

This avoids repeating the earlier documentation failure where route strings and desktop shells were each logged as “done” without proving they still matched each other.
