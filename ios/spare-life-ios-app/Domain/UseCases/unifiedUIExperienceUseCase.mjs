import { resolvePrincipalRole } from '../Models/myContracts.mjs';
import {
  buildSurfaceKey,
  resolveCardEventType,
  resolveUnifiedHomeKey
} from '../Models/unifiedUIContracts.mjs';
import { sanitizeText } from '../Models/sceneContracts.mjs';
import {
  buildConversationHubList,
  buildEarnSocialWaterfallFeed,
  buildMasterWaterfallFeed,
  buildMessageDetailSurface,
  buildMyWaterfallFeed,
  buildSceneWaterfallFeed
} from '../../Services/UnifiedUI/unifiedFeedService.mjs';

export class UnifiedUIExperienceUseCase {
  constructor({
    repository,
    sceneRepository,
    masterUseCase,
    earnSocialUseCase,
    companionUseCase,
    myUseCase
  }) {
    this.repository = repository;
    this.sceneRepository = sceneRepository;
    this.masterUseCase = masterUseCase;
    this.earnSocialUseCase = earnSocialUseCase;
    this.companionUseCase = companionUseCase;
    this.myUseCase = myUseCase;
  }

  openWaterfallHome(input) {
    const homeKey = resolveUnifiedHomeKey(input.homeKey);
    switch (homeKey) {
      case 'masters':
        return this.openMasterHomeFeed(input);
      case 'earn_social':
        return this.openEarnSocialHomeFeed(input);
      case 'my':
        return this.openMyHomeFeed(input);
      case 'xianxia':
      default:
        return this.openXianxiaHomeFeed(input);
    }
  }

  openXianxiaHomeFeed(input) {
    const entries = this.sceneRepository
      .listRecentSceneHomeEntries(input.limit ?? 6)
      .map((entry) => ({
        ...entry,
        topAgent: this.sceneRepository.listSceneAgentPresence(entry.sceneKey, 'best_match')[0] ?? null,
        latestIntent:
          this.sceneRepository
            .listRecentIntentDrafts(input.userId, 24)
            .find((intent) => intent.sceneKey === entry.sceneKey) ?? null
      }));
    return buildSceneWaterfallFeed({
      entries,
      scrollState: this.repository.findFeedScrollState(input.userId, buildSurfaceKey('xianxia_home'))
    });
  }

  openMasterHomeFeed(input) {
    const home = this.masterUseCase.openMasterHome({
      userId: input.userId,
      query: sanitizeText(input.query),
      domainKey: sanitizeText(input.domainKey) || null
    });
    return buildMasterWaterfallFeed({
      home,
      scrollState: this.repository.findFeedScrollState(input.userId, buildSurfaceKey('masters_home'))
    });
  }

  openEarnSocialHomeFeed(input) {
    const selectedLaneId = sanitizeText(input.laneId) || null;
    const home = this.earnSocialUseCase.openEarnSocialHome({
      userId: input.userId,
      laneId: selectedLaneId,
      viewerTags: input.viewerTags ?? []
    }).home;

    return buildEarnSocialWaterfallFeed({
      home,
      selectedLaneId,
      scrollState: this.repository.findFeedScrollState(
        input.userId,
        buildSurfaceKey('earn_social_home', selectedLaneId ?? 'all')
      )
    });
  }

  openMyHomeFeed(input) {
    const home = this.myUseCase.openMyHome({
      userId: input.userId,
      principalKey: sanitizeText(input.principalKey) || 'self_human',
      principalRole: resolvePrincipalRole(input.principalRole, 'owner'),
      vaultSecret: input.vaultSecret,
      memoryLimit: input.memoryLimit ?? 4
    });

    return buildMyWaterfallFeed({
      home,
      scrollState: this.repository.findFeedScrollState(input.userId, buildSurfaceKey('my_home'))
    });
  }

  openConversationHub(input) {
    const home = this.companionUseCase.openMessagesHome({
      userId: input.userId,
      limit: input.limit ?? 12
    });
    return buildConversationHubList({
      home,
      scrollState: this.repository.findFeedScrollState(input.userId, buildSurfaceKey('messages_home'))
    });
  }

  openConversationDetail(input) {
    const detail = this.companionUseCase.openConversation({
      userId: input.userId,
      conversationId: input.conversationId,
      markRead: input.markRead !== false,
      limit: input.limit ?? 40
    });
    return buildMessageDetailSurface({
      detail,
      scrollState: this.repository.findFeedScrollState(
        input.userId,
        buildSurfaceKey('messages_detail', input.conversationId)
      )
    });
  }

  saveFeedScrollState(input) {
    const surfaceKey = sanitizeText(input.surfaceKey);
    if (!surfaceKey) {
      throw new Error('surfaceKey is required.');
    }
    return this.repository.upsertFeedScrollState({
      userId: input.userId,
      surfaceKey,
      anchorCardId: input.anchorCardId,
      anchorOffset: input.anchorOffset ?? 0,
      lastVisibleCardId: input.lastVisibleCardId,
      metadata: input.metadata ?? {}
    });
  }

  trackFeedCardEvent(input) {
    const surfaceKey = sanitizeText(input.surfaceKey);
    const cardId = sanitizeText(input.cardId);
    if (!surfaceKey || !cardId) {
      throw new Error('surfaceKey and cardId are required.');
    }

    return this.repository.recordCardEvent({
      userId: input.userId,
      surfaceKey,
      cardId,
      cardType: sanitizeText(input.cardType) || 'summary',
      referenceId: input.referenceId,
      eventType: resolveCardEventType(input.eventType),
      route: input.route,
      detail: input.detail ?? {}
    });
  }

  inspectUnifiedUIState(input) {
    return this.repository.inspectUnifiedUIState(input.userId);
  }
}
