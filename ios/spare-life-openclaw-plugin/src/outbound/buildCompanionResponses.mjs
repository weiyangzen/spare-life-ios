import {
  buildConversationOpenAction,
  buildIMCardEnvelope,
  buildMessagesHomeHandoff,
  buildMessagesHomeInputModel,
  buildMessagesHomeOutputModel,
  buildMessagesThreadHandoff
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';

function rewriteCardEnvelopeForSourceSurface(card, sourceSurface = 'messages') {
  if (!card || typeof card !== 'object' || Array.isArray(card)) {
    return card;
  }

  const locator = card.locator ?? card.cardEnvelope?.locator ?? null;
  if (!locator) {
    return card;
  }

  const sourceChannelID =
    card.sourceChannelID ??
    card.cardEnvelope?.sourceChannelID ??
    card.renderFields?.sourceChannelID ??
    'companion';
  const conversationId =
    card.conversationId ??
    card.cardEnvelope?.conversationId ??
    (locator.kind === 'conversation' ? locator.conversationID : null);
  const envelope = buildIMCardEnvelope({
    canonicalCardID: card.canonicalCardID ?? card.cardEnvelope?.canonicalCardID,
    conversationId,
    locator,
    surfaceKind: card.surfaceKind ?? card.cardEnvelope?.surfaceKind,
    route: card.route ?? card.openAction?.route ?? null,
    sourceChannelID,
    renderFields: {
      primaryTitle: card.renderFields?.primaryTitle ?? card.title,
      secondaryTitle: card.renderFields?.secondaryTitle ?? card.subtitle,
      preview: card.renderFields?.preview ?? card.preview ?? card.lastMessagePreview,
      badge: card.renderFields?.badge ?? card.badge,
      avatarHint: card.renderFields?.avatarHint ?? null,
      unreadCount: card.renderFields?.unreadCount ?? card.unreadCount,
      lastMessageAt: card.renderFields?.lastMessageAt ?? card.lastMessageAt,
      capabilityFlags: card.renderFields?.capabilityFlags ?? card.capabilityFlags
    },
    fieldSources: card.fieldSources ?? {},
    handoff: buildMessagesThreadHandoff({
      sourceSurface,
      conversationId,
      channelId: locator.channelID ?? sourceChannelID,
      groupId: locator.groupID ?? null,
      peerId: locator.peerID ?? null
    }),
    openAction: buildConversationOpenAction({
      sourceSurface,
      conversationId,
      locator,
      route: card.route ?? card.openAction?.route ?? null
    })
  });

  return {
    ...card,
    ...envelope
  };
}

export function buildMessagesHomeResponse(result, input = {}) {
  const inputModel = buildMessagesHomeInputModel(input);
  const normalizedCards = (result.recentChats ?? []).map((card) =>
    rewriteCardEnvelopeForSourceSurface(card, inputModel.sourceSurface)
  );
  const outputModel = buildMessagesHomeOutputModel({
    route: result.route ?? inputModel.route,
    handoff: buildMessagesHomeHandoff({
      sourceSurface: inputModel.sourceSurface,
      tab: inputModel.tab
    }),
    unreadTotal: result.unreadTotal,
    cards: normalizedCards,
    tab: inputModel.tab
  });

  return {
    ...result,
    input: inputModel,
    output: outputModel,
    route: outputModel.route,
    handoff: outputModel.handoff,
    sourceChannelID: outputModel.sourceChannelID,
    tab: outputModel.tab,
    recentChats: outputModel.cardEnvelopes,
    cardEnvelopes: outputModel.cardEnvelopes,
    unreadTotal: outputModel.unreadTotal
  };
}

export function buildConversationResponse(result, input = {}) {
  const normalizedConversationEnvelope = result.cardEnvelope
    ? rewriteCardEnvelopeForSourceSurface(result.cardEnvelope, input.sourceSurface ?? 'messages')
    : rewriteCardEnvelopeForSourceSurface(result.conversation, input.sourceSurface ?? 'messages');

  return {
    ...result,
    cardEnvelope: normalizedConversationEnvelope,
    conversation: normalizedConversationEnvelope
      ? {
          ...result.conversation,
          canonicalCardID: normalizedConversationEnvelope.canonicalCardID,
          locator: normalizedConversationEnvelope.locator,
          sourceChannelID: normalizedConversationEnvelope.sourceChannelID,
          surfaceKind: normalizedConversationEnvelope.surfaceKind,
          renderFields: normalizedConversationEnvelope.renderFields,
          fieldSources: normalizedConversationEnvelope.fieldSources,
          capabilityFlags: normalizedConversationEnvelope.capabilityFlags,
          handoff: normalizedConversationEnvelope.handoff,
          openAction: normalizedConversationEnvelope.openAction
        }
      : result.conversation,
    input: {
      userId: input.userId ?? null,
      conversationId: input.conversationId ?? null,
      locator: input.locator ?? null,
      sourceSurface: input.sourceSurface ?? 'messages',
      markRead: input.markRead !== false,
      limit: Number(input.limit ?? 40),
      envelope: input.envelope ?? null
    }
  };
}

export function buildConversationSearchResponse(result) {
  return result;
}

export function buildDirectMessageResponse(result) {
  return result;
}

export function buildMaskUpdateResponse(result) {
  return result;
}

export function buildSharedStageDraftResponse(result) {
  return result;
}

export function buildStageResponse(result) {
  return result;
}

export function buildRitualResponse(result) {
  return result;
}

export function buildGroupConversationResponse(result) {
  return result;
}

export function buildGroupVoteResponse(result) {
  return result;
}

export function buildGroupSummaryResponse(result) {
  return result;
}

export function buildCompanionInspectionResponse(result) {
  return result;
}
