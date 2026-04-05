import { MasterExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/masterExperienceUseCase.mjs';
import { MasterFlowRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/masterFlowRepository.mjs';
import {
  normalizeCatalogMutationInput,
  normalizeConsultationInput,
  normalizeCTAActionInput,
  normalizeMasterAssetBundleInput,
  normalizeMasterChatInput,
  normalizeMasterHomeInput,
  normalizeRestoreRecentInput
} from '../inbound/normalizeMasterPayloads.mjs';
import {
  buildCatalogMutationBlockedResponse,
  buildConsultationResponse,
  buildCTAActionResponse,
  buildMasterCatalogResponse,
  buildMasterChatResponse,
  buildMasterHomeResponse,
  buildMasterRestoreResponse
} from '../outbound/buildMasterResponses.mjs';

export function createMasterFlowRuntime({ dbPath }) {
  const repository = new MasterFlowRepository(dbPath);
  const useCase = new MasterExperienceUseCase({
    repository
  });

  return {
    importMasterAssetBundle(payload) {
      const normalized = normalizeMasterAssetBundleInput(payload);
      return buildMasterCatalogResponse(useCase.importMasterAssetBundle(normalized));
    },
    openMasterHome(payload) {
      const normalized = normalizeMasterHomeInput(payload);
      return buildMasterHomeResponse(useCase.openMasterHome(normalized));
    },
    chatWithMaster(payload) {
      const normalized = normalizeMasterChatInput(payload);
      return buildMasterChatResponse(useCase.chatWithMaster(normalized));
    },
    restoreRecentMaster(payload) {
      const normalized = normalizeRestoreRecentInput(payload);
      return buildMasterRestoreResponse(useCase.restoreRecentMasterContext(normalized));
    },
    attemptCatalogMutation(payload) {
      const normalized = normalizeCatalogMutationInput(payload);
      return buildCatalogMutationBlockedResponse(useCase.attemptCatalogMutation(normalized));
    },
    consultMasters(payload) {
      const normalized = normalizeConsultationInput(payload);
      return buildConsultationResponse(useCase.consultMasters(normalized));
    },
    trackCTAAction(payload) {
      const normalized = normalizeCTAActionInput(payload);
      return buildCTAActionResponse(useCase.trackCTAAction(normalized));
    },
    inspectMasterState(userId) {
      return useCase.inspectMasterState(userId);
    },
    close() {
      repository.close();
    }
  };
}
