import { MyDashboardExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/myDashboardExperienceUseCase.mjs';
import { MyDashboardRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/myDashboardRepository.mjs';
import {
  normalizeAuthorizationUpdateInput,
  normalizeBackupCleanupInput,
  normalizeBackupCreateInput,
  normalizeGrowthJournalInput,
  normalizeGrowthReviewInput,
  normalizeMemoryListInput,
  normalizeMemorySaveInput,
  normalizeMyHomeInput,
  normalizeMyInspectInput,
  normalizePersonaUpdateInput,
  normalizeProfileUpdateInput,
  normalizeReplayResolveInput,
  normalizeTrainingCompletionInput
} from '../inbound/normalizeMyDashboardPayloads.mjs';
import {
  buildMyGrowthResponse,
  buildMyHomeResponse,
  buildMyInspectionResponse,
  buildMyMemoryResponse,
  buildMyPersonaResponse,
  buildMyPrivacyResponse,
  buildMyProfileResponse,
  buildMySyncResponse
} from '../outbound/buildMyDashboardResponses.mjs';

export function createMyDashboardRuntime({ dbPath, backupDir = null }) {
  const repository = new MyDashboardRepository(dbPath);
  const useCase = new MyDashboardExperienceUseCase({
    repository,
    backupDir
  });

  return {
    openMyHome(payload) {
      return buildMyHomeResponse(useCase.openMyHome(normalizeMyHomeInput(payload)));
    },
    updateProfile(payload) {
      return buildMyProfileResponse(useCase.updateProfile(normalizeProfileUpdateInput(payload)));
    },
    completeTrainingTask(payload) {
      return buildMySyncResponse(useCase.completeTrainingTask(normalizeTrainingCompletionInput(payload)));
    },
    resolveErrorReplay(payload) {
      return buildMySyncResponse(useCase.resolveErrorReplay(normalizeReplayResolveInput(payload)));
    },
    updatePersonaConfig(payload) {
      return buildMyPersonaResponse(useCase.updatePersonaConfig(normalizePersonaUpdateInput(payload)));
    },
    saveMemoryEntry(payload) {
      return buildMyMemoryResponse(useCase.saveMemoryEntry(normalizeMemorySaveInput(payload)));
    },
    listMemoryPalace(payload) {
      return buildMyMemoryResponse(useCase.listMemoryPalace(normalizeMemoryListInput(payload)));
    },
    recordGrowthJournal(payload) {
      return buildMyGrowthResponse(useCase.recordGrowthJournal(normalizeGrowthJournalInput(payload)));
    },
    openGrowthReview(payload) {
      return buildMyGrowthResponse(useCase.openGrowthReview(normalizeGrowthReviewInput(payload)));
    },
    updateAuthorization(payload) {
      return buildMyPrivacyResponse(useCase.updateAuthorization(normalizeAuthorizationUpdateInput(payload)));
    },
    createLocalBackup(payload) {
      return buildMyPrivacyResponse(useCase.createLocalBackup(normalizeBackupCreateInput(payload)));
    },
    cleanupLocalBackups(payload) {
      return buildMyPrivacyResponse(useCase.cleanupLocalBackups(normalizeBackupCleanupInput(payload)));
    },
    openPrivacyCenter(payload) {
      return buildMyPrivacyResponse(useCase.openPrivacyCenter(normalizeMyInspectInput(payload)));
    },
    inspectMyState(payload) {
      return buildMyInspectionResponse(useCase.inspectMyState(normalizeMyInspectInput(payload)));
    },
    close() {
      repository.close();
    }
  };
}
