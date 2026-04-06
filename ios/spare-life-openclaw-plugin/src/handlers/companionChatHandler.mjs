import { CompanionChatExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/companionChatExperienceUseCase.mjs';
import { CompanionChatRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/companionChatRepository.mjs';
import { assertOpenClawIMCapabilityAllowed } from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';
import {
  normalizeCompanionInspectInput,
  normalizeConversationOpenInput,
  normalizeConversationSearchInput,
  normalizeDirectMessageInput,
  normalizeGroupConversationInput,
  normalizeGroupMessageInput,
  normalizeGroupSummaryInput,
  normalizeGroupVoteBallotInput,
  normalizeGroupVoteLaunchInput,
  normalizeMaskUpdateInput,
  normalizeMessagesHomeInput,
  normalizeRitualCompletionInput,
  normalizeRitualScheduleInput,
  normalizeSharedStageDraftInput,
  normalizeStageAccessInput,
  normalizeStageMessageInput
} from '../inbound/normalizeCompanionPayloads.mjs';
import {
  buildCompanionInspectionResponse,
  buildConversationResponse,
  buildConversationSearchResponse,
  buildDirectMessageResponse,
  buildGroupConversationResponse,
  buildGroupSummaryResponse,
  buildGroupVoteResponse,
  buildMaskUpdateResponse,
  buildMessagesHomeResponse,
  buildRitualResponse,
  buildSharedStageDraftResponse,
  buildStageResponse
} from '../outbound/buildCompanionResponses.mjs';

export function createCompanionChatRuntime({ dbPath }) {
  const repository = new CompanionChatRepository(dbPath);
  const useCase = new CompanionChatExperienceUseCase({
    repository
  });

  return {
    openMessagesHome(payload) {
      const normalized = normalizeMessagesHomeInput(payload);
      return buildMessagesHomeResponse(useCase.openMessagesHome(normalized), normalized);
    },
    openConversation(payload) {
      const normalized = normalizeConversationOpenInput(payload);
      useCase.ensureWorkspace(normalized.userId);
      const resolvedConversationId =
        normalized.conversationId ??
        repository.findConversationByLocator(normalized.userId, normalized.locator)?.id ??
        null;
      return buildConversationResponse(
        useCase.openConversation({
          ...normalized,
          conversationId: resolvedConversationId
        }),
        {
          ...normalized,
          conversationId: resolvedConversationId
        }
      );
    },
    searchConversation(payload) {
      const normalized = normalizeConversationSearchInput(payload);
      useCase.ensureWorkspace(normalized.userId);
      const resolvedConversationId =
        normalized.conversationId ??
        repository.findConversationByLocator(normalized.userId, normalized.locator)?.id ??
        null;
      const participants = resolvedConversationId
        ? repository.listConversationParticipants(resolvedConversationId)
        : [];
      return buildConversationSearchResponse(
        useCase.searchConversation({
          ...normalized,
          conversationId: resolvedConversationId
        }),
        {
          ...normalized,
          conversationId: resolvedConversationId
        },
        {
          participants
        }
      );
    },
    sendDirectMessage(payload) {
      const normalized = normalizeDirectMessageInput(payload);
      assertOpenClawIMCapabilityAllowed({
        actionKey: 'send_direct_message',
        surfaceKind: normalized.surfaceKind,
        locator: normalized.locator,
        envelope: normalized.envelope,
        contactId: normalized.contactId
      });
      return buildDirectMessageResponse(useCase.sendDirectMessage(normalized));
    },
    updateContactMask(payload) {
      const normalized = normalizeMaskUpdateInput(payload);
      return buildMaskUpdateResponse(useCase.updateContactMask(normalized));
    },
    draftSharedStage(payload) {
      const normalized = normalizeSharedStageDraftInput(payload);
      return buildSharedStageDraftResponse(useCase.draftSharedStage(normalized));
    },
    grantStageAccess(payload) {
      const normalized = normalizeStageAccessInput(payload);
      return buildStageResponse(useCase.grantStageAccess(normalized));
    },
    postStageMessage(payload) {
      const normalized = normalizeStageMessageInput(payload);
      return buildStageResponse(useCase.postStageMessage(normalized));
    },
    scheduleRelationshipRitual(payload) {
      const normalized = normalizeRitualScheduleInput(payload);
      return buildRitualResponse(useCase.scheduleRelationshipRitual(normalized));
    },
    completeRelationshipRitual(payload) {
      const normalized = normalizeRitualCompletionInput(payload);
      return buildRitualResponse(useCase.completeRelationshipRitual(normalized));
    },
    openGroupConversation(payload) {
      const normalized = normalizeGroupConversationInput(payload);
      assertOpenClawIMCapabilityAllowed({
        actionKey: 'open_group_conversation',
        surfaceKind: normalized.surfaceKind,
        locator: normalized.locator,
        envelope: normalized.envelope,
        groupId: normalized.groupId
      });
      return buildGroupConversationResponse(useCase.openGroupConversation(normalized));
    },
    postGroupMessage(payload) {
      const normalized = normalizeGroupMessageInput(payload);
      return buildGroupConversationResponse(useCase.postGroupMessage(normalized));
    },
    launchGroupVote(payload) {
      const normalized = normalizeGroupVoteLaunchInput(payload);
      return buildGroupVoteResponse(useCase.launchGroupVote(normalized));
    },
    castGroupVote(payload) {
      const normalized = normalizeGroupVoteBallotInput(payload);
      return buildGroupVoteResponse(useCase.castGroupVote(normalized));
    },
    summarizeGroup(payload) {
      const normalized = normalizeGroupSummaryInput(payload);
      return buildGroupSummaryResponse(useCase.summarizeGroup(normalized));
    },
    inspectCompanionState(payload) {
      const normalized = normalizeCompanionInspectInput(payload);
      return buildCompanionInspectionResponse(useCase.inspectCompanionState(normalized.userId));
    },
    close() {
      repository.close();
    }
  };
}
