import { CompanionChatExperienceUseCase } from '../../../spare-life-ios-app/Domain/UseCases/companionChatExperienceUseCase.mjs';
import { CompanionChatRepository } from '../../../spare-life-ios-app/LocalBackend/SQLite/companionChatRepository.mjs';
import {
  assertOpenClawIMCapabilityAllowed,
  createOpenClawIMActionError,
  normalizeOpenClawIMActionError
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';
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
  buildGroupMessageResponse,
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
  const normalizeActionError = (actionKey, error, context = {}) =>
    normalizeOpenClawIMActionError(error, {
      actionKey,
      ...context
    });

  return {
    openMessagesHome(payload) {
      try {
        const normalized = normalizeMessagesHomeInput(payload);
        return buildMessagesHomeResponse(useCase.openMessagesHome(normalized), normalized);
      } catch (error) {
        throw normalizeActionError('open_messages_home', error);
      }
    },
    openConversation(payload) {
      let normalized = null;
      try {
        normalized = normalizeConversationOpenInput(payload);
        useCase.ensureWorkspace(normalized.userId);
        const resolvedConversationInput = {
          ...normalized,
          conversationId:
            normalized.conversationId ??
            repository.findConversationByLocator(normalized.userId, normalized.locator)?.id ??
            null
        };
        if (!resolvedConversationInput.conversationId) {
          throw createOpenClawIMActionError({
            kind: 'invalid_locator',
            actionKey: 'open_conversation',
            surfaceKind: normalized.surfaceKind ?? null,
            missingIDs: ['conversation_id | locator'],
            detail: 'Unable to resolve conversation from provided locator.'
          });
        }
        return buildConversationResponse(
          useCase.openConversation(resolvedConversationInput),
          resolvedConversationInput
        );
      } catch (error) {
        throw normalizeActionError('open_conversation', error, {
          locator: normalized?.locator ?? null,
          surfaceKind: normalized?.surfaceKind ?? null
        });
      }
    },
    searchConversation(payload) {
      let normalized = null;
      try {
        normalized = normalizeConversationSearchInput(payload);
        useCase.ensureWorkspace(normalized.userId);
        const resolvedConversationId =
          normalized.conversationId ??
          repository.findConversationByLocator(normalized.userId, normalized.locator)?.id ??
          null;
        if (!resolvedConversationId) {
          throw createOpenClawIMActionError({
            kind: 'invalid_locator',
            actionKey: 'search_conversation',
            missingIDs: ['conversation_id | locator'],
            detail: 'Unable to resolve conversation for search.'
          });
        }
        const participants = repository.listConversationParticipants(resolvedConversationId);
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
      } catch (error) {
        throw normalizeActionError('search_conversation', error, {
          locator: normalized?.locator ?? null,
          surfaceKind: normalized?.surfaceKind ?? null
        });
      }
    },
    sendDirectMessage(payload) {
      let normalized = null;
      try {
        normalized = normalizeDirectMessageInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'send_direct_message',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          contactId: normalized.contactId
        });
        return buildDirectMessageResponse(useCase.sendDirectMessage(normalized));
      } catch (error) {
        throw normalizeActionError('send_direct_message', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    updateContactMask(payload) {
      let normalized = null;
      try {
        normalized = normalizeMaskUpdateInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'update_contact_mask',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          contactId: normalized.contactId
        });
        return buildMaskUpdateResponse(useCase.updateContactMask(normalized));
      } catch (error) {
        throw normalizeActionError('update_contact_mask', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    draftSharedStage(payload) {
      let normalized = null;
      try {
        normalized = normalizeSharedStageDraftInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'draft_shared_stage',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          contactId: normalized.contactId
        });
        return buildSharedStageDraftResponse(useCase.draftSharedStage(normalized));
      } catch (error) {
        throw normalizeActionError('draft_shared_stage', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    grantStageAccess(payload) {
      let normalized = null;
      try {
        normalized = normalizeStageAccessInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'grant_stage_access',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope
        });
        return buildStageResponse(useCase.grantStageAccess(normalized), 'grant_stage_access');
      } catch (error) {
        throw normalizeActionError('grant_stage_access', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    postStageMessage(payload) {
      let normalized = null;
      try {
        normalized = normalizeStageMessageInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'post_stage_message',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope
        });
        return buildStageResponse(useCase.postStageMessage(normalized), 'post_stage_message');
      } catch (error) {
        throw normalizeActionError('post_stage_message', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    scheduleRelationshipRitual(payload) {
      let normalized = null;
      try {
        normalized = normalizeRitualScheduleInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'schedule_relationship_ritual',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          contactId: normalized.contactId
        });
        return buildRitualResponse(
          useCase.scheduleRelationshipRitual(normalized),
          'schedule_relationship_ritual'
        );
      } catch (error) {
        throw normalizeActionError('schedule_relationship_ritual', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    completeRelationshipRitual(payload) {
      try {
        const normalized = normalizeRitualCompletionInput(payload);
        return buildRitualResponse(
          useCase.completeRelationshipRitual(normalized),
          'complete_relationship_ritual'
        );
      } catch (error) {
        throw normalizeActionError('complete_relationship_ritual', error);
      }
    },
    openGroupConversation(payload) {
      let normalized = null;
      try {
        normalized = normalizeGroupConversationInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'open_group_conversation',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          groupId: normalized.groupId
        });
        return buildGroupConversationResponse(useCase.openGroupConversation(normalized), normalized);
      } catch (error) {
        throw normalizeActionError('open_group_conversation', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    postGroupMessage(payload) {
      let normalized = null;
      try {
        normalized = normalizeGroupMessageInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'post_group_message',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          groupId: normalized.groupId
        });
        return buildGroupMessageResponse(useCase.postGroupMessage(normalized), 'post_group_message');
      } catch (error) {
        throw normalizeActionError('post_group_message', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    launchGroupVote(payload) {
      let normalized = null;
      try {
        normalized = normalizeGroupVoteLaunchInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'launch_group_vote',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          groupId: normalized.groupId
        });
        return buildGroupVoteResponse(useCase.launchGroupVote(normalized), 'launch_group_vote');
      } catch (error) {
        throw normalizeActionError('launch_group_vote', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    castGroupVote(payload) {
      let normalized = null;
      try {
        normalized = normalizeGroupVoteBallotInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'cast_group_vote',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          groupId: normalized.groupId
        });
        const resolvedVote =
          (normalized.voteId && repository.findGroupVote(normalized.voteId)) ||
          (normalized.groupId
            ? repository.listGroupVotes(normalized.groupId, 8).find((vote) => vote.status === 'open') ?? null
            : null);
        if (!resolvedVote) {
          throw createOpenClawIMActionError({
            kind: 'not_ready',
            actionKey: 'cast_group_vote',
            surfaceKind: normalized.surfaceKind,
            detail: normalized.groupId
              ? '当前群聊没有开放中的投票。'
              : '缺少 vote_id，且无法从 group_id 推断开放中的投票。'
          });
        }
        const resolvedOptionId =
          normalized.optionId ??
          resolvedVote.options?.find((option) => option.label === normalized.optionLabel)?.optionId ??
          null;
        if (!resolvedOptionId) {
          throw createOpenClawIMActionError({
            kind: 'invalid_locator',
            actionKey: 'cast_group_vote',
            surfaceKind: normalized.surfaceKind,
            missingIDs: ['option_id'],
            detail: normalized.optionLabel
              ? `未找到名为 “${normalized.optionLabel}” 的投票选项。`
              : '缺少 option_id，且无法从 option_label 推断选项。'
          });
        }
        return buildGroupVoteResponse(
          useCase.castGroupVote({
            ...normalized,
            voteId: resolvedVote.id,
            groupId: resolvedVote.groupId,
            optionId: resolvedOptionId
          }),
          'cast_group_vote'
        );
      } catch (error) {
        throw normalizeActionError('cast_group_vote', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    summarizeGroup(payload) {
      let normalized = null;
      try {
        normalized = normalizeGroupSummaryInput(payload);
        assertOpenClawIMCapabilityAllowed({
          actionKey: 'summarize_group',
          surfaceKind: normalized.surfaceKind,
          locator: normalized.locator,
          envelope: normalized.envelope,
          groupId: normalized.groupId
        });
        const resolvedVote = normalized.voteId ? repository.findGroupVote(normalized.voteId) : null;
        const resolvedGroupId = normalized.groupId ?? resolvedVote?.groupId ?? null;
        if (!resolvedGroupId) {
          throw createOpenClawIMActionError({
            kind: 'invalid_locator',
            actionKey: 'summarize_group',
            surfaceKind: normalized.surfaceKind,
            missingIDs: ['group_id'],
            detail: '缺少 group_id，且无法从 vote_id 或 locator 推断群聊主键。'
          });
        }
        return buildGroupSummaryResponse(
          useCase.summarizeGroup({
            ...normalized,
            groupId: resolvedGroupId,
            voteId: resolvedVote?.id ?? normalized.voteId ?? null
          }),
          'summarize_group'
        );
      } catch (error) {
        throw normalizeActionError('summarize_group', error, {
          surfaceKind: normalized?.surfaceKind ?? null,
          locator: normalized?.locator ?? null
        });
      }
    },
    inspectCompanionState(payload) {
      try {
        const normalized = normalizeCompanionInspectInput(payload);
        return buildCompanionInspectionResponse(useCase.inspectCompanionState(normalized.userId));
      } catch (error) {
        throw normalizeActionError('inspect_companion', error);
      }
    },
    close() {
      repository.close();
    }
  };
}
