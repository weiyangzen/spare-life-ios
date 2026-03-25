import {
  buildMasterConsultRoute,
  buildMasterHomeRoute,
  resolveConsultShareMode,
  resolveMemoryScope
} from '../Models/masterContracts.mjs';
import { isoNow, sanitizeText } from '../Models/sceneContracts.mjs';
import { buildMasterHome, normalizeMasterAssetBundle } from '../../Services/Masters/masterCatalogService.mjs';
import {
  composeMasterReply,
  extractAuthorizedMemories,
  mergeConsultationAdvice,
  rankRelevantStories,
  recallRelevantMemories
} from '../../Services/Masters/masterConversationService.mjs';

export class MasterExperienceUseCase {
  constructor({ repository }) {
    this.repository = repository;
  }

  importMasterAssetBundle(input) {
    const normalizedBundle = normalizeMasterAssetBundle(input.bundle, {
      sourcePath: input.sourcePath
    });
    const importResult = this.repository.importCatalog(normalizedBundle);
    return {
      ...importResult,
      catalogReadOnly: true,
      domains: this.repository.listDomains()
    };
  }

  openMasterHome(input) {
    return buildMasterHome({
      domains: this.repository.listDomains(),
      masters: this.repository.listMasters().map((master) => ({
        ...master,
        stories: this.repository.listStoriesForMaster(master.id),
        searchTags: [
          ...(master.profile.expertiseTags ?? []),
          ...(master.profile.focusTags ?? [])
        ]
      })),
      recentSessions: this.repository.listRecentSessions(input.userId, 6),
      query: input.query,
      domainKey: input.domainKey
    });
  }

  chatWithMaster(input) {
    const master = this.repository.findMaster(input.masterId);
    if (!master) {
      throw new Error(`Unknown master: ${input.masterId}`);
    }

    const nowIso = isoNow();
    const memoryScope = resolveMemoryScope(input.memoryScope, 'master_only');
    const stories = this.repository.listStoriesForMaster(master.id);
    const allMemories = this.repository.listMemoriesForUser(input.userId);

    let session =
      (sanitizeText(input.sessionId) && this.repository.findSessionForUser(input.sessionId, input.userId)) ||
      this.repository.findLatestSession({
        userId: input.userId,
        masterId: master.id
      });

    if (!session) {
      session = this.repository.createSession({
        userId: input.userId,
        masterId: master.id,
        topic: input.topic || input.message,
        nowIso
      });
    }

    const recentMessages = this.repository.listSessionMessages(session.id, 8);
    const recalledMemories = recallRelevantMemories({
      memories: allMemories,
      masterId: master.id,
      shareMode: memoryScope,
      message: input.message
    });
    const relevantStories = rankRelevantStories({
      stories,
      message: input.message,
      memories: recalledMemories,
      master: {
        ...master,
        searchTags: [...(master.profile.expertiseTags ?? []), ...(master.profile.focusTags ?? [])]
      }
    });
    const reply = composeMasterReply({
      master,
      userMessage: input.message,
      recentMessages,
      memories: recalledMemories,
      stories: relevantStories,
      sessionId: session.id,
      mode: 'chat'
    });
    const newMemories = extractAuthorizedMemories({
      userId: input.userId,
      masterId: master.id,
      sessionId: session.id,
      message: input.message,
      consentScope: memoryScope,
      nowIso
    });

    this.repository.withTransaction(() => {
      this.repository.appendMessage({
        sessionId: session.id,
        role: 'user',
        content: input.message,
        nowIso
      });
      this.repository.appendMessage({
        sessionId: session.id,
        role: 'assistant',
        content: reply.text,
        storyIds: reply.promptPacket.referencedStoryIds,
        memoryIds: reply.promptPacket.referencedMemoryIds,
        ctas: reply.ctas,
        nowIso
      });
      this.repository.upsertMemories(newMemories, nowIso);
      this.repository.updateSessionAfterTurn({
        sessionId: session.id,
        topic: input.topic || session.topic,
        lastUserMessage: input.message,
        lastAssistantMessage: reply.text,
        lastStoryIds: reply.promptPacket.referencedStoryIds,
        lastMemoryIds: [...reply.promptPacket.referencedMemoryIds, ...newMemories.map((memory) => memory.id)],
        unreadIncrement: 1,
        nowIso
      });
    });

    const updatedSession = this.repository.findSessionForUser(session.id, input.userId);
    return {
      master,
      session: updatedSession,
      route: updatedSession.route,
      reply,
      recentChats: this.repository.listRecentSessions(input.userId, 6)
    };
  }

  restoreRecentMasterContext(input) {
    const session =
      (sanitizeText(input.sessionId) && this.repository.findSessionForUser(input.sessionId, input.userId)) ||
      this.repository.listRecentSessions(input.userId, 1)[0];

    if (!session) {
      throw new Error('No recent master session to restore.');
    }

    this.repository.markSessionRead(session.id, isoNow());
    return {
      session: this.repository.findSessionForUser(session.id, input.userId),
      master: this.repository.findMaster(session.masterId),
      messages: this.repository.listSessionMessages(session.id, 12)
    };
  }

  attemptCatalogMutation(input) {
    return {
      status: 'blocked',
      reason: 'read_only_catalog',
      requestedOperation: input.operation,
      appRoute: buildMasterHomeRoute()
    };
  }

  consultMasters(input) {
    const userId = input.userId;
    const shareMode = resolveConsultShareMode(input.shareMode, 'cross_master');
    const issue = sanitizeText(input.issue);
    const allMemories = this.repository.listMemoriesForUser(userId);
    const members = input.masterIds.map((masterId) => {
      const master = this.repository.findMaster(masterId);
      if (!master) {
        throw new Error(`Unknown master for consultation: ${masterId}`);
      }
      const recalledMemories = recallRelevantMemories({
        memories: allMemories,
        masterId,
        shareMode,
        message: issue
      });
      const relevantStories = rankRelevantStories({
        stories: this.repository.listStoriesForMaster(masterId),
        message: issue,
        memories: recalledMemories,
        master: {
          ...master,
          searchTags: [...(master.profile.expertiseTags ?? []), ...(master.profile.focusTags ?? [])]
        }
      });
      const reply = composeMasterReply({
        master,
        userMessage: issue,
        recentMessages: [],
        memories: recalledMemories,
        stories: relevantStories,
        mode: 'consult'
      });
      return {
        master,
        reply
      };
    });

    const consultationIdSeed = `${userId}:${issue}:${members.map((member) => member.master.id).join(',')}`;
    const merged = mergeConsultationAdvice({
      issue,
      memberReplies: members,
      consultationId: consultationIdSeed
    });

    const consultation = this.repository.saveConsultation({
      userId,
      issue,
      sharedScope: shareMode,
      mergedSummary: merged.mergedSummary,
      conflicts: merged.conflicts,
      ctas: merged.ctas,
      members: members.map((member) => ({
        masterId: member.master.id,
        stance: member.reply.stance,
        advice: member.reply.text,
        storyIds: member.reply.promptPacket.referencedStoryIds,
        memoryIds: member.reply.promptPacket.referencedMemoryIds,
        ctas: member.reply.ctas
      }))
    });

    return {
      consultation: {
        ...consultation,
        route: buildMasterConsultRoute(consultation.id)
      },
      members: members.map((member) => ({
        masterId: member.master.id,
        displayName: member.master.displayName,
        stance: member.reply.stance,
        advice: member.reply.text,
        referencedStories: member.reply.referencedStories,
        referencedMemories: member.reply.referencedMemories,
        ctas: member.reply.ctas
      })),
      merged
    };
  }

  trackCTAAction(input) {
    return this.repository.trackCTAAction({
      userId: input.userId,
      sourceKind: input.sourceKind,
      sourceId: input.sourceId,
      masterId: input.masterId,
      ctaId: input.ctaId,
      route: input.route,
      effectKind: input.effectKind
    });
  }

  inspectMasterState(userId) {
    return this.repository.inspectMasterState(userId);
  }
}
