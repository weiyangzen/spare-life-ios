import {
  buildCompanionInspectionEntryModel,
  buildConversationOpenAction,
  buildConversationOpenInputModel,
  buildConversationOpenOutputModel,
  buildConversationSearchInputModel,
  buildConversationSearchOutputModel,
  buildDirectThreadActionEntryModel,
  buildIMCardEnvelope,
  buildOpenClawIMActionContract,
  buildIMCapabilityFlags,
  buildMessagesHomeHandoff,
  buildMessagesHomeInputModel,
  buildMessagesHomeOutputModel,
  buildMessagesThreadHandoff,
  buildOpenClawIMCapabilityChecklist
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';

function decorateCapabilitySurface(result, actionKey, surfaceKind) {
  return {
    ...result,
    surfaceKind,
    capabilityFlags: buildIMCapabilityFlags(surfaceKind),
    capabilityChecklist: buildOpenClawIMCapabilityChecklist(surfaceKind),
    actionContract: buildOpenClawIMActionContract(actionKey, {
      surfaceKind
    })
  };
}

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
    card.conversationID ??
    card.id ??
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

function dedupeContextCards(cards = []) {
  const seen = new Set();
  return (Array.isArray(cards) ? cards : []).filter((card) => {
    const key = `${card?.cardType ?? 'unknown'}:${card?.route ?? 'no-route'}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

function buildGroupLaneContextCards(groupContext = null) {
  const lanes = Array.isArray(groupContext?.actionLanes) ? groupContext.actionLanes : [];
  return lanes.map((lane) => ({
    cardType: lane.laneKey,
    title: lane.title,
    route: lane.route,
    handoff: lane.handoff,
    payload: {
      actionKey: lane.actionKey,
      stage3Item: lane.stage3Item,
      targetID: lane.targetID,
      uiReady: lane.uiReady,
      uiStatus: lane.uiStatus,
      uiUnavailableCopy: lane.uiUnavailableCopy,
      errorSurface: lane.errorSurface,
      requiredIDs: lane.requiredIDs,
      fallbackIDs: lane.fallbackIDs,
      optionalHints: lane.optionalHints,
      supportedErrorKinds: lane.supportedErrorKinds,
      surfaceGate: lane.surfaceGate,
      latestVote: groupContext?.latestVote ?? null,
      latestSummary: groupContext?.latestSummary ?? null
    }
  }));
}

function buildDirectLaneContextCards(stageContext = null) {
  const lanes = Array.isArray(stageContext?.actionLanes) ? stageContext.actionLanes : [];
  return lanes.map((lane) => ({
    cardType: lane.laneKey,
    title: lane.title,
    route: lane.route,
    handoff: lane.handoff,
    payload: {
      actionKey: lane.actionKey,
      stage3Item: lane.stage3Item,
      targetID: lane.targetID,
      uiReady: lane.uiReady,
      uiStatus: lane.uiStatus,
      uiUnavailableCopy: lane.uiUnavailableCopy,
      errorSurface: lane.errorSurface,
      requiredIDs: lane.requiredIDs,
      fallbackIDs: lane.fallbackIDs,
      optionalHints: lane.optionalHints,
      supportedErrorKinds: lane.supportedErrorKinds,
      surfaceGate: lane.surfaceGate,
      cardEntry: lane.cardEntry,
      threadEntry: lane.threadEntry,
      errorFallback: lane.errorFallback
    }
  }));
}

function buildInspectionContextCard(inspectionEntry = null) {
  if (!inspectionEntry) {
    return [];
  }
  return [
    {
      cardType: 'companion_inspect',
      title: 'Companion Inspect',
      route:
        inspectionEntry.threadEntry?.route ??
        inspectionEntry.cardEntry?.route ??
        null,
      handoff:
        inspectionEntry.threadEntry?.handoff ??
        inspectionEntry.cardEntry?.handoff ??
        null,
      payload: inspectionEntry
    }
  ];
}

function attachGroupLaneCards(outputModel) {
  const laneCards = buildGroupLaneContextCards(outputModel?.groupContext);
  if (!laneCards.length) {
    return outputModel;
  }
  return {
    ...outputModel,
    contextCards: dedupeContextCards([...(outputModel.contextCards ?? []), ...laneCards])
  };
}

function attachDirectLaneCards(outputModel) {
  const laneCards = buildDirectLaneContextCards(outputModel?.stageContext);
  const inspectionCards = buildInspectionContextCard(outputModel?.companionInspectionEntry);
  if (!laneCards.length && !inspectionCards.length) {
    return outputModel;
  }
  return {
    ...outputModel,
    contextCards: dedupeContextCards([
      ...(outputModel.contextCards ?? []),
      ...laneCards,
      ...inspectionCards
    ])
  };
}

function buildDirectActionPlacement(actionKey, result = {}, input = {}) {
  const conversationId =
    result.conversation?.id ??
    result.relationship?.conversationId ??
    result.ritual?.conversationId ??
    null;
  const contactId =
    result.contact?.id ??
    result.relationship?.contactId ??
    result.conversation?.contactId ??
    input.contactId ??
    input.locator?.peerID ??
    input.envelope?.locator?.peerID ??
    null;
  const conversation = result.conversation ?? {
    id: conversationId,
    contactId,
    locator: input.locator ?? input.envelope?.locator ?? null,
    route: input.envelope?.route ?? input.envelope?.openAction?.route ?? null,
    surfaceKind: 'dm'
  };

  return buildDirectThreadActionEntryModel(actionKey, {
    conversation,
    contactId,
    participants: result.participants ?? [],
    messages: result.messages ?? [],
    rituals: result.rituals ?? [],
    sourceSurface: input.sourceSurface ?? 'messages'
  });
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
  const inputModel = buildConversationOpenInputModel({
    ...input,
    envelope: normalizedConversationEnvelope
  });
  const outputModel = buildConversationOpenOutputModel({
    conversation: result.conversation ?? {},
    cardEnvelope: normalizedConversationEnvelope,
    participants: result.participants ?? [],
    messages: result.messages ?? [],
    rituals: result.rituals ?? [],
    contextCards: result.contextCards ?? [],
    votes: result.votes ?? [],
    groupSummaries: result.groupSummaries ?? [],
    sourceSurface: inputModel.sourceSurface,
    homeRoute: result.homeRoute ?? null,
    homeHandoff: buildMessagesHomeHandoff({
      sourceSurface: inputModel.sourceSurface
    })
  });
  const normalizedOutputModel = attachDirectLaneCards(attachGroupLaneCards(outputModel));

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
          capabilityChecklist: normalizedConversationEnvelope.capabilityChecklist,
          capabilityFlags: normalizedConversationEnvelope.capabilityFlags,
          handoff: normalizedConversationEnvelope.handoff,
          openAction: normalizedConversationEnvelope.openAction
        }
      : result.conversation,
    input: inputModel,
    output: normalizedOutputModel,
    conversationSummary: normalizedOutputModel.conversation,
    surfaceKind: normalizedOutputModel.conversation.surfaceKind,
    capabilityFlags: normalizedOutputModel.conversation.capabilityFlags,
    capabilityChecklist: normalizedOutputModel.conversation.capabilityChecklist,
    participantModels: normalizedOutputModel.participants,
    messageModels: normalizedOutputModel.messages,
    timeline: normalizedOutputModel.timeline,
    stageContext: normalizedOutputModel.stageContext,
    groupContext: normalizedOutputModel.groupContext,
    companionInspectionEntry: normalizedOutputModel.companionInspectionEntry,
    contextCards: normalizedOutputModel.contextCards,
    homeRoute: normalizedOutputModel.homeRoute,
    homeHandoff: normalizedOutputModel.homeHandoff
  };
}

export function buildConversationSearchResponse(result, input = {}, extras = {}) {
  const inputModel = buildConversationSearchInputModel({
    ...input,
    conversationId: input.conversationId ?? result.conversation?.id ?? null,
    locator: input.locator ?? result.conversation?.locator ?? null
  });
  const outputModel = buildConversationSearchOutputModel({
    conversation: result.conversation ?? {},
    query: result.query ?? inputModel.query.text,
    limit: inputModel.limit,
    participants: extras.participants ?? [],
    hits: result.hits ?? [],
    sourceSurface: inputModel.sourceSurface
  });

  return {
    ...result,
    input: inputModel,
    output: outputModel,
    conversationSummary: outputModel.conversation,
    locator: outputModel.locator,
    queryModel: outputModel.query,
    searchQuery: outputModel.query,
    resultItems: outputModel.resultItems,
    hitCount: outputModel.resultCount,
    emptyState: outputModel.emptyState
  };
}

export function buildDirectMessageResponse(result) {
  return decorateCapabilitySurface(result, 'send_direct_message', 'dm');
}

export function buildMaskUpdateResponse(result, input = {}) {
  return {
    ...decorateCapabilitySurface(result, 'update_contact_mask', 'dm'),
    clientPlacement: buildDirectActionPlacement('update_contact_mask', result, input)
  };
}

export function buildSharedStageDraftResponse(result, input = {}) {
  return {
    ...decorateCapabilitySurface(result, 'draft_shared_stage', 'dm'),
    clientPlacement: buildDirectActionPlacement('draft_shared_stage', result, input)
  };
}

export function buildStageResponse(result, actionKey = 'post_stage_message', input = {}) {
  return {
    ...decorateCapabilitySurface(result, actionKey, 'dm'),
    clientPlacement: buildDirectActionPlacement(actionKey, result, input)
  };
}

export function buildRitualResponse(result, actionKey = 'schedule_relationship_ritual', input = {}) {
  return {
    ...decorateCapabilitySurface(result, actionKey, 'dm'),
    clientPlacement: buildDirectActionPlacement(actionKey, result, input)
  };
}

export function buildGroupConversationResponse(result, input = {}) {
  const sourceSurface = input.sourceSurface ?? 'messages';
  const fallbackLocator = {
    kind: 'group',
    conversationId: result.conversation?.id ?? null,
    groupId: result.group?.id ?? result.conversation?.groupId ?? null
  };
  const normalizedConversationEnvelope = rewriteCardEnvelopeForSourceSurface(
    result.cardEnvelope ?? {
      ...result.conversation,
      locator: result.conversation?.locator ?? fallbackLocator,
      surfaceKind: result.conversation?.surfaceKind ?? 'group'
    },
    sourceSurface
  );
  const inputModel = buildConversationOpenInputModel({
    ...input,
    conversationId: result.conversation?.id ?? input.conversationId ?? null,
    locator:
      input.locator ??
      normalizedConversationEnvelope?.locator ?? {
        kind: 'group',
        conversationId: result.conversation?.id ?? null,
        groupId: result.group?.id ?? result.conversation?.groupId ?? null
      },
    sourceSurface,
    markRead: false,
    limit: input.limit ?? 40,
    envelope: normalizedConversationEnvelope
  });
  const outputModel = attachGroupLaneCards(
    buildConversationOpenOutputModel({
      conversation: result.conversation ?? {},
      cardEnvelope: normalizedConversationEnvelope,
      participants: result.participants ?? [],
      messages: result.messages ?? [],
      rituals: result.rituals ?? [],
      contextCards: result.contextCards ?? [],
      votes: result.votes ?? [],
      groupSummaries: result.summaries ?? result.groupSummaries ?? [],
      sourceSurface: inputModel.sourceSurface
    })
  );
  const normalizedOutputModel = attachDirectLaneCards(outputModel);

  return {
    ...decorateCapabilitySurface(result, 'open_group_conversation', 'group'),
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
          capabilityChecklist: normalizedConversationEnvelope.capabilityChecklist,
          capabilityFlags: normalizedConversationEnvelope.capabilityFlags,
          handoff: normalizedConversationEnvelope.handoff,
          openAction: normalizedConversationEnvelope.openAction
        }
      : result.conversation,
    input: inputModel,
    output: normalizedOutputModel,
    conversationSummary: normalizedOutputModel.conversation,
    participantModels: normalizedOutputModel.participants,
    messageModels: normalizedOutputModel.messages,
    timeline: normalizedOutputModel.timeline,
    stageContext: normalizedOutputModel.stageContext,
    groupContext: normalizedOutputModel.groupContext,
    companionInspectionEntry: normalizedOutputModel.companionInspectionEntry,
    contextCards: normalizedOutputModel.contextCards
  };
}

export function buildGroupMessageResponse(result, actionKey = 'post_group_message') {
  return decorateCapabilitySurface(result, actionKey, 'group');
}

export function buildGroupVoteResponse(result, actionKey = 'launch_group_vote') {
  return decorateCapabilitySurface(result, actionKey, 'group');
}

export function buildGroupSummaryResponse(result, actionKey = 'summarize_group') {
  return decorateCapabilitySurface(result, actionKey, 'group');
}

export function buildCompanionInspectionResponse(result, input = {}) {
  const conversation = input.envelope?.conversationId || input.locator
    ? {
        conversationId: input.envelope?.conversationId ?? null,
        locator: input.locator ?? input.envelope?.locator ?? null,
        route: input.envelope?.route ?? input.envelope?.openAction?.route ?? null,
        surfaceKind: input.surfaceKind ?? null
      }
    : null;
  return {
    ...result,
    actionContract: buildOpenClawIMActionContract('inspect_companion', {}),
    clientPlacement: buildCompanionInspectionEntryModel({
      conversation,
      sourceSurface: input.sourceSurface ?? 'messages'
    })
  };
}
