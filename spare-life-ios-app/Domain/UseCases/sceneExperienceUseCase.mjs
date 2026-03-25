import {
  buildSceneRoute,
  fingerprint,
  isoNow
} from '../Models/sceneContracts.mjs';
import {
  buildSceneCards,
  clusterPosts,
  moderatePosts,
  rankActiveAgents
} from '../../Services/SceneRadar/sceneDiscussionEngine.mjs';
import {
  buildIntentDraft,
  evaluateIntentRisk
} from '../../Services/SceneRadar/sceneIntentGuard.mjs';

export class SceneExperienceUseCase {
  constructor({ repository, feedTtlMinutes = 30 }) {
    this.repository = repository;
    this.feedTtlMinutes = feedTtlMinutes;
  }

  openSceneDiscussion(input) {
    const nowIso = isoNow(input.receivedAt);
    const scanTarget = this.repository.upsertScanTarget(input.scanTarget, nowIso);
    const sourceFingerprint = fingerprint(
      input.discussionPosts.map((post) => [
        post.externalId,
        post.text,
        post.engagement,
        post.createdAt
      ])
    );
    const cachedFeed = this.repository.getFreshSceneFeed(input.scene.sceneKey, nowIso);

    let usedCache = false;
    let feed = cachedFeed;
    if (!cachedFeed || cachedFeed.sourceFingerprint !== sourceFingerprint) {
      const moderation = moderatePosts(input.discussionPosts);
      const clusters = clusterPosts(moderation.approvedPosts);
      const cards = buildSceneCards({
        scene: input.scene,
        approvedPosts: moderation.approvedPosts,
        flaggedPosts: moderation.flaggedPosts,
        clusters
      });
      const activeAgents = rankActiveAgents({
        approvedPosts: moderation.approvedPosts,
        agentPublicCards: input.agentPublicCards,
        viewerContext: input.viewerContext,
        sortBy: input.sortBy,
        sceneLocation: input.scene.locationLabel
      });
      const expiresAt = new Date(new Date(nowIso).getTime() + this.feedTtlMinutes * 60_000).toISOString();
      feed = this.repository.saveSceneExperience({
        scene: input.scene,
        scanTargetId: scanTarget.id,
        approvedPosts: moderation.approvedPosts,
        flaggedPosts: moderation.flaggedPosts,
        summaryCard: cards.summaryCard,
        hotTakeCards: cards.hotTakeCards,
        riskCards: cards.riskCards,
        traceability: cards.traceability,
        clusters,
        moderationSummary: {
          ...moderation.moderationSummary,
          overallSentiment: cards.overallSentiment
        },
        sourceFingerprint,
        expiresAt,
        activeAgents,
        agentPublicCards: input.agentPublicCards,
        nowIso
      });
    } else {
      usedCache = true;
    }

    const activeAgents = this.repository.listSceneAgentPresence(input.scene.sceneKey, input.sortBy);
    this.repository.logScanEvent({
      sceneKey: input.scene.sceneKey,
      scanTargetId: scanTarget.id,
      channel: input.channel,
      sourceType: input.scanTarget.sourceType,
      rawCode: input.scanTarget.rawCode,
      usedCache,
      nowIso
    });

    return {
      scene: input.scene,
      scanTarget,
      usedCache,
      feed,
      activeAgents,
      sceneRoute: buildSceneRoute(input.scene.sceneKey, scanTarget.id)
    };
  }

  createSceneIntent(input, intentRequest = input.intentRequest) {
    if (!intentRequest) {
      throw new Error('Scene intent request is required.');
    }

    const nowIso = isoNow();
    const targetAgent = intentRequest.targetAgentId
      ? this.repository.findAgentPublicCard(intentRequest.targetAgentId)
      : null;
    const recentIntentCount = this.repository.countRecentIntentAttempts({
      sceneKey: input.scene.sceneKey,
      initiatorUserId: input.viewerContext.userId,
      targetAgentId: intentRequest.targetAgentId ?? null,
      cutoffIso: new Date(new Date(nowIso).getTime() - 10 * 60_000).toISOString()
    });
    const risk = evaluateIntentRisk({
      intentRequest,
      recentIntentCount,
      targetAgent
    });
    const draft = buildIntentDraft({
      scene: input.scene,
      viewerContext: input.viewerContext,
      intentRequest,
      risk,
      targetAgent,
      now: nowIso
    });

    this.repository.saveIntentDraft(draft, nowIso);
    return {
      draft,
      risk,
      targetAgent
    };
  }
}
