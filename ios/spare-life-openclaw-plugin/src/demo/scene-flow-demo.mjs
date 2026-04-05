import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { createSceneFlowRuntime } from '../handlers/sceneScanHandler.mjs';
import { handleSceneIntent } from '../handlers/sceneIntentHandler.mjs';

const args = parseArgs({
  options: {
    db: { type: 'string' },
    payload: { type: 'string' },
    reset: { type: 'boolean', default: true }
  }
});

const dbPath = resolve(args.values.db ?? join(tmpdir(), 'spare-life-scene-flow.sqlite'));
const payloadPath = resolve(
  args.values.payload ?? new URL('../../fixtures/scene_scan_payload.json', import.meta.url).pathname
);

if (args.values.reset && existsSync(dbPath)) {
  unlinkSync(dbPath);
}

const payload = JSON.parse(readFileSync(payloadPath, 'utf8'));
const runtime = createSceneFlowRuntime({ dbPath });

try {
  const firstScan = runtime.handleSceneScan(payload);
  const secondScan = runtime.handleSceneScan(payload);
  const allowedIntent = handleSceneIntent(runtime, payload);
  const duplicateIntent = handleSceneIntent(runtime, payload);
  const sceneState = runtime.inspectSceneState(firstScan.scene.sceneKey);

  console.log(
    JSON.stringify(
      {
        validation: {
          dbPath,
          firstScanUsedCache: firstScan.cache.usedCache,
          secondScanUsedCache: secondScan.cache.usedCache,
          allowedIntentStatus: allowedIntent.riskStatus,
          duplicateIntentStatus: duplicateIntent.riskStatus
        },
        firstScan,
        allowedIntent,
        duplicateIntent,
        sceneState
      },
      null,
      2
    )
  );
} finally {
  runtime.close();
}
