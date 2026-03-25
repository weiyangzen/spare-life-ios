import { EarnSocialExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/earnSocialExperienceUseCase.mjs';
import { EarnSocialRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/earnSocialRepository.mjs';
import {
  normalizeArenaCreateInput,
  normalizeArenaResolveInput,
  normalizeArenaVoteInput,
  normalizeBondTaskInput,
  normalizeBrowsePersonaInput,
  normalizeConsentInput,
  normalizeEarnSocialHomeInput,
  normalizeIcebreakStartInput,
  normalizeIntentPostInput,
  normalizePersonaFeedbackInput,
  normalizeTrendInput
} from '../inbound/normalizeEarnSocialPayloads.mjs';
import {
  buildArenaResponse,
  buildBondResponse,
  buildEarnSocialHomeResponse,
  buildIcebreakResponse,
  buildIntentMarketResponse,
  buildPersonaDeckResponse,
  buildPersonaFeedbackResponse,
  buildTrendResponse
} from '../outbound/buildEarnSocialResponses.mjs';

export function createEarnSocialRuntime({ dbPath }) {
  const repository = new EarnSocialRepository(dbPath);
  const useCase = new EarnSocialExperienceUseCase({
    repository
  });

  return {
    openEarnSocialHome(payload) {
      const normalized = normalizeEarnSocialHomeInput(payload);
      return buildEarnSocialHomeResponse(useCase.openEarnSocialHome(normalized));
    },
    publishIntent(payload) {
      const normalized = normalizeIntentPostInput(payload);
      return buildIntentMarketResponse(useCase.publishIntent(normalized));
    },
    browsePersonaDeck(payload) {
      const normalized = normalizeBrowsePersonaInput(payload);
      return buildPersonaDeckResponse(useCase.browsePersonaDeck(normalized));
    },
    recordPersonaFeedback(payload) {
      const normalized = normalizePersonaFeedbackInput(payload);
      return buildPersonaFeedbackResponse(useCase.recordPersonaFeedback(normalized));
    },
    startDualAgentIcebreak(payload) {
      const normalized = normalizeIcebreakStartInput(payload);
      return buildIcebreakResponse(useCase.startDualAgentIcebreak(normalized));
    },
    recordHumanConsent(payload) {
      const normalized = normalizeConsentInput(payload);
      return buildIcebreakResponse(useCase.recordHumanConsent(normalized));
    },
    exploreLaneTrends(payload) {
      const normalized = normalizeTrendInput(payload);
      return buildTrendResponse(useCase.exploreLaneTrends(normalized));
    },
    createArenaMatch(payload) {
      const normalized = normalizeArenaCreateInput(payload);
      return buildArenaResponse(useCase.createArenaMatch(normalized));
    },
    castArenaVote(payload) {
      const normalized = normalizeArenaVoteInput(payload);
      return buildArenaResponse(useCase.castArenaVote(normalized));
    },
    resolveArenaMatch(payload) {
      const normalized = normalizeArenaResolveInput(payload);
      return buildArenaResponse(useCase.resolveArenaMatch(normalized));
    },
    completeBondTask(payload) {
      const normalized = normalizeBondTaskInput(payload);
      return buildBondResponse(useCase.completeBondTask(normalized));
    },
    inspectEarnSocialState(userId) {
      return useCase.inspectEarnSocialState(userId);
    },
    close() {
      repository.close();
    }
  };
}
