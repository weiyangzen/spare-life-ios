import { AIMemoryMatchingUseCase } from '../../../spare-life-ios-app/Domain/UseCases/aiMemoryMatchingUseCase.mjs';
import { SecurityRiskUseCase } from '../../../spare-life-ios-app/Domain/UseCases/securityRiskUseCase.mjs';
import { FoundationRepository } from '../../../spare-life-ios-app/LocalBackend/Repositories/foundationRepository.mjs';
import { LocalBackendDatabase } from '../../../spare-life-ios-app/LocalBackend/SQLite/localBackendDatabase.mjs';
import { sanitizeText, uniqueStrings } from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';
import { normalizeUnifiedChannelEnvelope } from '../inbound/normalizeUnifiedChannelEnvelope.mjs';
import {
  buildUnifiedChannelFailure,
  buildUnifiedChannelIntercept,
  buildUnifiedChannelSuccess
} from '../outbound/buildUnifiedChannelResponses.mjs';
import { createCompanionChatRuntime } from './companionChatHandler.mjs';
import { createEarnSocialRuntime } from './earnSocialFlowHandler.mjs';
import { createMasterFlowRuntime } from './masterFlowHandler.mjs';
import { createMyDashboardRuntime } from './myDashboardHandler.mjs';
import { createSceneFlowRuntime } from './sceneScanHandler.mjs';
import { createUnifiedUIRuntime } from './unifiedUIHandler.mjs';

function actionMapForRuntime(runtimes) {
  return {
    scene: {
      scan: (body) => runtimes.scene.handleSceneScan(body),
      intent: (body) => runtimes.scene.handleSceneIntent(body),
      inspect: (body) => runtimes.scene.inspectSceneState(sanitizeText(body.sceneKey))
    },
    masters: {
      import_asset_bundle: (body) => runtimes.masters.importMasterAssetBundle(body),
      open_home: (body) => runtimes.masters.openMasterHome(body),
      chat: (body) => runtimes.masters.chatWithMaster(body),
      restore_recent: (body) => runtimes.masters.restoreRecentMaster(body),
      attempt_catalog_mutation: (body) => runtimes.masters.attemptCatalogMutation(body),
      consult: (body) => runtimes.masters.consultMasters(body),
      track_cta: (body) => runtimes.masters.trackCTAAction(body),
      inspect: (body) => runtimes.masters.inspectMasterState(sanitizeText(body.userId))
    },
    earn_social: {
      open_home: (body) => runtimes.earnSocial.openEarnSocialHome(body),
      publish_intent: (body) => runtimes.earnSocial.publishIntent(body),
      browse_persona_deck: (body) => runtimes.earnSocial.browsePersonaDeck(body),
      record_persona_feedback: (body) => runtimes.earnSocial.recordPersonaFeedback(body),
      start_dual_agent_icebreak: (body) => runtimes.earnSocial.startDualAgentIcebreak(body),
      record_human_consent: (body) => runtimes.earnSocial.recordHumanConsent(body),
      explore_lane_trends: (body) => runtimes.earnSocial.exploreLaneTrends(body),
      create_arena_match: (body) => runtimes.earnSocial.createArenaMatch(body),
      cast_arena_vote: (body) => runtimes.earnSocial.castArenaVote(body),
      resolve_arena_match: (body) => runtimes.earnSocial.resolveArenaMatch(body),
      complete_bond_task: (body) => runtimes.earnSocial.completeBondTask(body),
      advance_lead_stage: (body) => runtimes.earnSocial.advanceLeadStage(body),
      record_lead_outcome: (body) => runtimes.earnSocial.recordLeadOutcome(body),
      settle_lead_outcome: (body) => runtimes.earnSocial.settleLeadOutcome(body),
      inspect: (body) => runtimes.earnSocial.inspectEarnSocialState(sanitizeText(body.userId))
    },
    companion: {
      open_messages_home: (body) => runtimes.companion.openMessagesHome(body),
      open_conversation: (body) => runtimes.companion.openConversation(body),
      search_conversation: (body) => runtimes.companion.searchConversation(body),
      send_direct_message: (body) => runtimes.companion.sendDirectMessage(body),
      update_contact_mask: (body) => runtimes.companion.updateContactMask(body),
      draft_shared_stage: (body) => runtimes.companion.draftSharedStage(body),
      grant_stage_access: (body) => runtimes.companion.grantStageAccess(body),
      post_stage_message: (body) => runtimes.companion.postStageMessage(body),
      schedule_relationship_ritual: (body) => runtimes.companion.scheduleRelationshipRitual(body),
      complete_relationship_ritual: (body) => runtimes.companion.completeRelationshipRitual(body),
      open_group_conversation: (body) => runtimes.companion.openGroupConversation(body),
      post_group_message: (body) => runtimes.companion.postGroupMessage(body),
      launch_group_vote: (body) => runtimes.companion.launchGroupVote(body),
      cast_group_vote: (body) => runtimes.companion.castGroupVote(body),
      summarize_group: (body) => runtimes.companion.summarizeGroup(body),
      inspect: (body) => runtimes.companion.inspectCompanionState(body)
    },
    my: {
      open_home: (body) => runtimes.my.openMyHome(body),
      update_profile: (body) => runtimes.my.updateProfile(body),
      complete_training_task: (body) => runtimes.my.completeTrainingTask(body),
      resolve_error_replay: (body) => runtimes.my.resolveErrorReplay(body),
      update_persona_config: (body) => runtimes.my.updatePersonaConfig(body),
      save_memory_entry: (body) => runtimes.my.saveMemoryEntry(body),
      list_memory_palace: (body) => runtimes.my.listMemoryPalace(body),
      record_growth_journal: (body) => runtimes.my.recordGrowthJournal(body),
      open_growth_review: (body) => runtimes.my.openGrowthReview(body),
      update_authorization: (body) => runtimes.my.updateAuthorization(body),
      create_local_backup: (body) => runtimes.my.createLocalBackup(body),
      cleanup_local_backups: (body) => runtimes.my.cleanupLocalBackups(body),
      open_privacy_center: (body) => runtimes.my.openPrivacyCenter(body),
      inspect: (body) => runtimes.my.inspectMyState(body)
    },
    unified_ui: {
      open_waterfall_home: (body) => runtimes.unifiedUI.openWaterfallHome(body),
      open_conversation_hub: (body) => runtimes.unifiedUI.openConversationHub(body),
      open_conversation_detail: (body) => runtimes.unifiedUI.openConversationDetail(body),
      save_feed_scroll_state: (body) => runtimes.unifiedUI.saveFeedScrollState(body),
      track_feed_card_event: (body) => runtimes.unifiedUI.trackFeedCardEvent(body),
      inspect: (body) => runtimes.unifiedUI.inspectUnifiedUIState(body)
    }
  };
}

function collectAutoMemoryText(normalizedEnvelope) {
  const body = normalizedEnvelope.body ?? {};
  const textParts = [
    body.text,
    body.message,
    body.query,
    body.issue,
    body.question,
    body.note,
    body.title,
    body.reason,
    body.detail,
    Array.isArray(body.messages) ? body.messages.join(' ') : '',
    Array.isArray(body.options) ? body.options.join(' ') : ''
  ]
    .map((item) => sanitizeText(item))
    .filter(Boolean);

  return textParts.join(' ');
}

function buildAutoMemoryTags(normalizedEnvelope) {
  return uniqueStrings([
    normalizedEnvelope.routeKey,
    normalizedEnvelope.action,
    normalizedEnvelope.channel
  ]);
}

export function createUnifiedChannelRuntime({ dbPath, backupDir = null }) {
  const sharedDatabase = new LocalBackendDatabase({ dbPath });
  const foundationRepository = new FoundationRepository({
    database: sharedDatabase
  });
  const memoryUseCase = new AIMemoryMatchingUseCase({
    repository: foundationRepository
  });
  const securityUseCase = new SecurityRiskUseCase({
    repository: foundationRepository
  });

  const runtimes = {
    scene: createSceneFlowRuntime({ dbPath }),
    masters: createMasterFlowRuntime({ dbPath }),
    earnSocial: createEarnSocialRuntime({ dbPath }),
    companion: createCompanionChatRuntime({ dbPath }),
    my: createMyDashboardRuntime({ dbPath, backupDir }),
    unifiedUI: createUnifiedUIRuntime({ dbPath, backupDir })
  };

  const dispatchMap = actionMapForRuntime(runtimes);

  function dispatch(normalizedEnvelope) {
    if (normalizedEnvelope.routeKey === 'ai_memory') {
      switch (normalizedEnvelope.action) {
        case 'remember':
          return memoryUseCase.rememberInteraction({
            ...normalizedEnvelope.body,
            routeKey: normalizedEnvelope.routeKey,
            action: normalizedEnvelope.action,
            channel: normalizedEnvelope.channel
          });
        case 'recall':
          return memoryUseCase.recallMemories({
            ...normalizedEnvelope.body,
            routeKey: normalizedEnvelope.routeKey,
            action: normalizedEnvelope.action
          });
        case 'match':
          return memoryUseCase.matchIntentCandidates({
            ...normalizedEnvelope.body,
            routeKey: normalizedEnvelope.routeKey,
            action: normalizedEnvelope.action
          });
        case 'inspect':
          return memoryUseCase.inspectMemoryState(normalizedEnvelope.body);
        default:
          throw new Error(`Unsupported ai_memory action: ${normalizedEnvelope.action}`);
      }
    }

    if (normalizedEnvelope.routeKey === 'security') {
      switch (normalizedEnvelope.action) {
        case 'set_permission':
          return securityUseCase.setPermission(normalizedEnvelope.body);
        case 'report':
          return securityUseCase.reportIncident({
            ...normalizedEnvelope.body,
            channel: normalizedEnvelope.channel
          });
        case 'inspect':
          return securityUseCase.inspectSecurityState(normalizedEnvelope.body);
        default:
          throw new Error(`Unsupported security action: ${normalizedEnvelope.action}`);
      }
    }

    const routeActions = dispatchMap[normalizedEnvelope.routeKey];
    if (!routeActions) {
      throw new Error(`No dispatch route for ${normalizedEnvelope.routeKey}`);
    }

    const handler = routeActions[normalizedEnvelope.action];
    if (!handler) {
      throw new Error(`Unsupported action ${normalizedEnvelope.action} for route ${normalizedEnvelope.routeKey}`);
    }

    return handler(normalizedEnvelope.body);
  }

  return {
    processEnvelope(payload) {
      let normalizedEnvelope = null;
      try {
        normalizedEnvelope = normalizeUnifiedChannelEnvelope(payload);

        const guard = ['security', 'ai_memory'].includes(normalizedEnvelope.routeKey)
          ? null
          : securityUseCase.guardRequest({
              userId: normalizedEnvelope.userId,
              requestId: normalizedEnvelope.requestId,
              channel: normalizedEnvelope.channel,
              routeKey: normalizedEnvelope.routeKey,
              action: normalizedEnvelope.action,
              body: normalizedEnvelope.body
            });

        if (guard && !guard.allowed) {
          return buildUnifiedChannelIntercept({
            normalizedEnvelope,
            guard
          });
        }

        const result = dispatch(normalizedEnvelope);
        let memory = null;
        if (!['ai_memory', 'security'].includes(normalizedEnvelope.routeKey)) {
          const autoMemoryText = collectAutoMemoryText(normalizedEnvelope);
          if (autoMemoryText) {
            memory = memoryUseCase.rememberInteraction({
              userId: normalizedEnvelope.userId,
              channel: normalizedEnvelope.channel,
              routeKey: normalizedEnvelope.routeKey,
              action: normalizedEnvelope.action,
              text: autoMemoryText,
              sourceRef: normalizedEnvelope.requestId,
              tags: buildAutoMemoryTags(normalizedEnvelope),
              metadata: {
                autoCaptured: true
              }
            });
          }
        }

        return buildUnifiedChannelSuccess({
          normalizedEnvelope,
          result,
          guard,
          memory
        });
      } catch (error) {
        return buildUnifiedChannelFailure({
          normalizedEnvelope:
            normalizedEnvelope ?? {
              requestId: sanitizeText(payload?.requestId) || 'unknown-request',
              envelopeVersion: sanitizeText(payload?.envelopeVersion) || 'unknown',
              channel: sanitizeText(payload?.channel) || 'openclaw',
              routeKey: sanitizeText(payload?.routeKey) || 'unknown',
              action: sanitizeText(payload?.action) || 'unknown'
            },
          error
        });
      }
    },
    inspectFoundationState(userId) {
      return foundationRepository.inspectFoundationState(sanitizeText(userId));
    },
    close() {
      runtimes.scene.close();
      runtimes.masters.close();
      runtimes.earnSocial.close();
      runtimes.companion.close();
      runtimes.my.close();
      runtimes.unifiedUI.close();
      foundationRepository.close();
      sharedDatabase.close();
    }
  };
}
