import { SceneExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/sceneExperienceUseCase.mjs';
import { SceneFlowRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/sceneFlowRepository.mjs';
import { normalizeSceneScanEvent } from '../inbound/normalizeSceneScanEvent.mjs';
import {
  buildSceneDiscussionResponse,
  buildSceneIntentResponse
} from '../outbound/buildSceneDiscussionResponse.mjs';

export function createSceneFlowRuntime({ dbPath, feedTtlMinutes = 30 }) {
  const repository = new SceneFlowRepository(dbPath);
  const useCase = new SceneExperienceUseCase({
    repository,
    feedTtlMinutes
  });

  return {
    handleSceneScan(payload) {
      const normalized = normalizeSceneScanEvent(payload);
      const sceneExperience = useCase.openSceneDiscussion(normalized);
      return buildSceneDiscussionResponse({
        normalizedEvent: normalized,
        sceneExperience
      });
    },
    handleSceneIntent(payload) {
      const normalized = normalizeSceneScanEvent(payload);
      const intentResult = useCase.createSceneIntent(normalized);
      return buildSceneIntentResponse({
        normalizedEvent: normalized,
        intentResult
      });
    },
    inspectSceneState(sceneKey) {
      return repository.inspectSceneState(sceneKey);
    },
    close() {
      repository.close();
    }
  };
}
