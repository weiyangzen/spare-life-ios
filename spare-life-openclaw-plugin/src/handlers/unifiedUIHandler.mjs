import { CompanionChatExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/companionChatExperienceUseCase.mjs';
import { EarnSocialExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/earnSocialExperienceUseCase.mjs';
import { MasterExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/masterExperienceUseCase.mjs';
import { MyDashboardExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/myDashboardExperienceUseCase.mjs';
import { UnifiedUIExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/unifiedUIExperienceUseCase.mjs';
import { CompanionChatRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/companionChatRepository.mjs';
import { EarnSocialRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/earnSocialRepository.mjs';
import { MasterFlowRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/masterFlowRepository.mjs';
import { MyDashboardRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/myDashboardRepository.mjs';
import { SceneFlowRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/sceneFlowRepository.mjs';
import { UnifiedUIRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/unifiedUIRepository.mjs';
import {
  normalizeCardEventInput,
  normalizeConversationDetailInput,
  normalizeConversationHubInput,
  normalizeScrollStateInput,
  normalizeUnifiedInspectInput,
  normalizeWaterfallHomeInput
} from '../inbound/normalizeUnifiedUIPayloads.mjs';
import {
  buildCardEventResponse,
  buildConversationDetailResponse,
  buildConversationHubResponse,
  buildScrollStateResponse,
  buildUnifiedInspectionResponse,
  buildWaterfallHomeResponse
} from '../outbound/buildUnifiedUIResponses.mjs';

export function createUnifiedUIRuntime({ dbPath, backupDir = null }) {
  const sceneRepository = new SceneFlowRepository(dbPath);
  const masterRepository = new MasterFlowRepository(dbPath);
  const earnSocialRepository = new EarnSocialRepository(dbPath);
  const companionRepository = new CompanionChatRepository(dbPath);
  const myRepository = new MyDashboardRepository(dbPath);
  const repository = new UnifiedUIRepository(dbPath);

  const useCase = new UnifiedUIExperienceUseCase({
    repository,
    sceneRepository,
    masterUseCase: new MasterExperienceUseCase({
      repository: masterRepository
    }),
    earnSocialUseCase: new EarnSocialExperienceUseCase({
      repository: earnSocialRepository
    }),
    companionUseCase: new CompanionChatExperienceUseCase({
      repository: companionRepository
    }),
    myUseCase: new MyDashboardExperienceUseCase({
      repository: myRepository,
      backupDir
    })
  });

  return {
    openWaterfallHome(payload) {
      return buildWaterfallHomeResponse(useCase.openWaterfallHome(normalizeWaterfallHomeInput(payload)));
    },
    openConversationHub(payload) {
      return buildConversationHubResponse(useCase.openConversationHub(normalizeConversationHubInput(payload)));
    },
    openConversationDetail(payload) {
      return buildConversationDetailResponse(
        useCase.openConversationDetail(normalizeConversationDetailInput(payload))
      );
    },
    saveFeedScrollState(payload) {
      return buildScrollStateResponse(useCase.saveFeedScrollState(normalizeScrollStateInput(payload)));
    },
    trackFeedCardEvent(payload) {
      return buildCardEventResponse(useCase.trackFeedCardEvent(normalizeCardEventInput(payload)));
    },
    inspectUnifiedUIState(payload) {
      return buildUnifiedInspectionResponse(useCase.inspectUnifiedUIState(normalizeUnifiedInspectInput(payload)));
    },
    close() {
      repository.close();
      sceneRepository.close();
      masterRepository.close();
      earnSocialRepository.close();
      companionRepository.close();
      myRepository.close();
    }
  };
}
