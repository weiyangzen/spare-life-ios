import {
  CHAT_MODES,
  SORT_MODES,
  sanitizeText
} from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';

export function assertSceneScanPayload(payload) {
  if (!payload || typeof payload !== 'object') {
    throw new Error('Scene scan payload must be an object.');
  }
  if (payload.eventType !== 'scene_scan') {
    throw new Error(`Unsupported event type: ${payload.eventType}`);
  }
  if (!sanitizeText(payload.rawCode)) {
    throw new Error('Scene scan payload requires rawCode.');
  }
  if (!Array.isArray(payload.discussionPosts) || payload.discussionPosts.length === 0) {
    throw new Error('Scene scan payload requires at least one discussion post.');
  }
  if (!Array.isArray(payload.agentPublicCards)) {
    throw new Error('Scene scan payload requires agentPublicCards.');
  }
  if (payload.request?.sortBy && !SORT_MODES.has(payload.request.sortBy)) {
    throw new Error(`Unsupported sortBy mode: ${payload.request.sortBy}`);
  }
  return payload;
}

export function assertSceneIntentRequest(intentRequest) {
  if (!intentRequest) {
    throw new Error('Intent request is required.');
  }
  if (!CHAT_MODES.has(intentRequest.mode)) {
    throw new Error(`Unsupported intent mode: ${intentRequest.mode}`);
  }
  if (!sanitizeText(intentRequest.message)) {
    throw new Error('Intent request message is required.');
  }
  return intentRequest;
}
