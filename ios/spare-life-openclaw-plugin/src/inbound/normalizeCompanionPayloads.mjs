import {
  buildMessagesHomeRoute,
  buildSelfParticipantKey,
  createOpenClawIMActionError,
  normalizeIMCardEnvelope,
  normalizeIMConversationLocator,
  normalizeOpenClawIMActionError,
  resolveIMCapabilitySurfaceKind,
  resolveMessagesHomeTab
} from '../../../spare-life-ios-app/Domain/Models/companionContracts.mjs';

function requireString(value, fieldName) {
  const normalized = `${value ?? ''}`.trim();
  if (!normalized) {
    throw new Error(`Missing required field: ${fieldName}`);
  }
  return normalized;
}

function sanitizeArray(values = []) {
  return Array.isArray(values)
    ? values.map((value) => `${value ?? ''}`.trim()).filter(Boolean)
    : [];
}

function requireActionID(actionKey, value, fieldName, extra = {}) {
  const normalized = `${value ?? ''}`.trim();
  if (!normalized) {
    throw createOpenClawIMActionError({
      kind: 'invalid_locator',
      actionKey,
      missingIDs: [fieldName],
      detail: `Missing required ID: ${fieldName}`,
      ...extra
    });
  }
  return normalized;
}

function normalizeConversationLocatorInput(input, actionKey = null) {
  try {
    if (input.locator && typeof input.locator === 'object') {
      return normalizeIMConversationLocator(input.locator);
    }

    return normalizeIMConversationLocator({
      conversationId: `${input.conversationId ?? input.conversation_id ?? ''}`.trim(),
      channelId: `${input.channelId ?? input.channel_id ?? ''}`.trim(),
      groupId: `${input.groupId ?? input.group_id ?? ''}`.trim(),
      peerId: `${input.peerId ?? input.peer_id ?? input.dmPeerId ?? input.dm_peer_id ?? input.contactId ?? input.contact_id ?? ''}`.trim()
    });
  } catch (error) {
    throw normalizeOpenClawIMActionError(error, {
      actionKey,
      kind: 'invalid_locator'
    });
  }
}

function normalizeCardEnvelopeInput(input, actionKey = null) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    return null;
  }
  try {
    return normalizeIMCardEnvelope(input);
  } catch (error) {
    throw normalizeOpenClawIMActionError(error, {
      actionKey,
      kind: 'invalid_locator'
    });
  }
}

function readCardEnvelopeInput(input) {
  return input.envelope ?? input.cardEnvelope ?? input.card_envelope ?? input.openAction?.cardEnvelope ?? null;
}

function normalizeOptionalSurfaceContext(input, fallbackSurfaceKind, actionKey = null) {
  try {
    const rawEnvelope = readCardEnvelopeInput(input);
    const envelope = normalizeCardEnvelopeInput(readCardEnvelopeInput(input), actionKey);
    const locator = input.openAction?.locator
      ? normalizeIMConversationLocator(input.openAction.locator)
      : input.locator && typeof input.locator === 'object'
        ? normalizeIMConversationLocator(input.locator)
        : envelope?.locator ?? null;
    return {
      envelope,
      locator,
      surfaceKind: resolveIMCapabilitySurfaceKind(
        {
          surfaceKind: input.surfaceKind ?? input.surface_kind ?? null,
          locator,
          envelope,
          groupId: input.groupId ?? input.group_id ?? null,
          contactId: input.contactId ?? input.contact_id ?? null,
          peerId:
            input.peerId ??
            input.peer_id ??
            input.dmPeerId ??
            input.dm_peer_id ??
            null
        },
        fallbackSurfaceKind
      ),
      sourceSurface:
        `${input.sourceSurface ?? input.source_surface ?? input.openAction?.handoff?.sourceSurface ?? rawEnvelope?.handoff?.sourceSurface ?? ''}`.trim() ||
        'messages'
    };
  } catch (error) {
    throw normalizeOpenClawIMActionError(error, {
      actionKey,
      kind: 'invalid_locator'
    });
  }
}

export function normalizeMessagesHomeInput(input) {
  const tab = resolveMessagesHomeTab(input.tab ?? input.homeTab ?? 'recent');
  return {
    userId: requireString(input.userId, 'userId'),
    limit: Number(input.limit ?? 12),
    sourceSurface: `${input.sourceSurface ?? input.source_surface ?? ''}`.trim() || 'messages',
    tab,
    route: buildMessagesHomeRoute(tab)
  };
}

export function normalizeConversationOpenInput(input) {
  const actionKey = 'open_conversation';
  const envelope = normalizeCardEnvelopeInput(
    input.envelope ?? input.cardEnvelope ?? input.card_envelope ?? input.openAction?.cardEnvelope
    ,
    actionKey
  );
  const sourceSurface =
    `${input.sourceSurface ?? input.source_surface ?? input.openAction?.handoff?.sourceSurface ?? input.cardEnvelope?.handoff?.sourceSurface ?? input.envelope?.handoff?.sourceSurface ?? ''}`.trim() ||
    'messages';
  const locator = input.openAction?.locator
    ? normalizeIMConversationLocator(input.openAction.locator)
    : envelope?.locator ?? normalizeConversationLocatorInput(input, actionKey);
  const conversationId =
    `${input.conversationId ?? input.conversation_id ?? input.openAction?.conversationId ?? ''}`.trim() ||
    envelope?.conversationId ||
    (locator.kind === 'conversation' ? locator.conversationID : null);

  return {
    userId: requireString(input.userId, 'userId'),
    conversationId,
    locator,
    envelope,
    sourceSurface,
    markRead: input.markRead !== false,
    limit: Number(input.limit ?? 40)
  };
}

export function normalizeConversationSearchInput(input) {
  const actionKey = 'search_conversation';
  const envelope = normalizeCardEnvelopeInput(
    input.envelope ?? input.cardEnvelope ?? input.card_envelope ?? input.openAction?.cardEnvelope
    ,
    actionKey
  );
  const locator = input.openAction?.locator
    ? normalizeIMConversationLocator(input.openAction.locator)
    : envelope?.locator ?? normalizeConversationLocatorInput(input, actionKey);
  const conversationId =
    `${input.conversationId ?? input.conversation_id ?? input.openAction?.conversationId ?? ''}`.trim() ||
    envelope?.conversationId ||
    (locator.kind === 'conversation' ? locator.conversationID : null);

  return {
    userId: requireString(input.userId, 'userId'),
    conversationId,
    locator,
    query: requireString(input.query ?? input.queryText ?? input.searchText, 'query'),
    sourceSurface:
      `${input.sourceSurface ?? input.source_surface ?? input.openAction?.handoff?.sourceSurface ?? input.cardEnvelope?.handoff?.sourceSurface ?? input.envelope?.handoff?.sourceSurface ?? ''}`.trim() ||
      'messages',
    limit: Number(input.limit ?? 12)
  };
}

export function normalizeDirectMessageInput(input) {
  const actionKey = 'send_direct_message';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireActionID(
      actionKey,
      input.contactId ?? input.contact_id ?? surfaceContext.locator?.peerID,
      'contact_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    text: requireString(input.text, 'text'),
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind
  };
}

export function normalizeMaskUpdateInput(input) {
  const actionKey = 'update_contact_mask';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireActionID(
      actionKey,
      input.contactId ?? input.contact_id ?? surfaceContext.locator?.peerID,
      'contact_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    tone: `${input.tone ?? ''}`.trim() || null,
    openness: `${input.openness ?? ''}`.trim() || null,
    boundaryTags: sanitizeArray(input.boundaryTags),
    signature: `${input.signature ?? ''}`.trim() || null,
    overrideRules: sanitizeArray(input.overrideRules),
    changeSummary: `${input.changeSummary ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}

export function normalizeSharedStageDraftInput(input) {
  const actionKey = 'draft_shared_stage';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireActionID(
      actionKey,
      input.contactId ?? input.contact_id ?? surfaceContext.locator?.peerID,
      'contact_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    text: requireString(input.text, 'text'),
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}

export function normalizeStageAccessInput(input) {
  const actionKey = 'grant_stage_access';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireActionID(
      actionKey,
      input.conversationId ?? input.conversation_id ?? surfaceContext.envelope?.conversationId,
      'conversation_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    participantKey: requireActionID(
      actionKey,
      input.participantKey ?? input.participant_key,
      'participant_key',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    granted: input.granted !== false,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}

export function normalizeStageMessageInput(input) {
  const actionKey = 'post_stage_message';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    conversationId: requireActionID(
      actionKey,
      input.conversationId ?? input.conversation_id ?? surfaceContext.envelope?.conversationId,
      'conversation_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    participantKey: requireActionID(
      actionKey,
      input.participantKey ?? input.participant_key,
      'participant_key',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    content: requireString(input.content, 'content'),
    channelKind: `${input.channelKind ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}

export function normalizeRitualScheduleInput(input) {
  const actionKey = 'schedule_relationship_ritual';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    contactId: requireActionID(
      actionKey,
      input.contactId ?? input.contact_id ?? surfaceContext.locator?.peerID,
      'contact_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    kind: requireString(input.kind, 'kind'),
    scheduledFor: `${input.scheduledFor ?? ''}`.trim() || null,
    note: `${input.note ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}

export function normalizeRitualCompletionInput(input) {
  const actionKey = 'complete_relationship_ritual';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    ritualId: requireString(input.ritualId, 'ritualId'),
    note: `${input.note ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}

export function normalizeGroupConversationInput(input) {
  const actionKey = 'open_group_conversation';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'group', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireActionID(
      actionKey,
      input.groupId ?? input.group_id ?? surfaceContext.locator?.groupID,
      'group_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    limit: Number(input.limit ?? 40),
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind
  };
}

export function normalizeGroupMessageInput(input) {
  const actionKey = 'post_group_message';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'group', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireActionID(
      actionKey,
      input.groupId ?? input.group_id ?? surfaceContext.locator?.groupID,
      'group_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    actorKey: `${input.actorKey ?? input.actor_key ?? ''}`.trim() || buildSelfParticipantKey('human'),
    content: requireString(input.content, 'content'),
    channelKind: `${input.channelKind ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind
  };
}

export function normalizeGroupVoteLaunchInput(input) {
  const actionKey = 'launch_group_vote';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'group', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: requireActionID(
      actionKey,
      input.groupId ?? input.group_id ?? surfaceContext.locator?.groupID,
      'group_id',
      {
        surfaceKind: surfaceContext.surfaceKind
      }
    ),
    question: requireString(input.question, 'question'),
    options: sanitizeArray(input.options),
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind
  };
}

export function normalizeGroupVoteBallotInput(input) {
  const actionKey = 'cast_group_vote';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'group', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    voteId: `${input.voteId ?? input.vote_id ?? ''}`.trim() || null,
    groupId: `${input.groupId ?? input.group_id ?? surfaceContext.locator?.groupID ?? ''}`.trim() || null,
    voterKey: `${input.voterKey ?? input.voter_key ?? ''}`.trim() || buildSelfParticipantKey('human'),
    optionId: `${input.optionId ?? input.option_id ?? ''}`.trim() || null,
    optionLabel: `${input.optionLabel ?? input.option_label ?? input.option ?? ''}`.trim() || null,
    rationale: `${input.rationale ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind
  };
}

export function normalizeGroupSummaryInput(input) {
  const actionKey = 'summarize_group';
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'group', actionKey);
  return {
    userId: requireString(input.userId, 'userId'),
    groupId: `${input.groupId ?? input.group_id ?? surfaceContext.locator?.groupID ?? ''}`.trim() || null,
    voteId: `${input.voteId ?? input.vote_id ?? ''}`.trim() || null,
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind
  };
}

export function normalizeCompanionInspectInput(input) {
  const surfaceContext = normalizeOptionalSurfaceContext(input, 'dm', 'inspect_companion');
  return {
    userId: requireString(input.userId, 'userId'),
    locator: surfaceContext.locator,
    envelope: surfaceContext.envelope,
    surfaceKind: surfaceContext.surfaceKind,
    sourceSurface: surfaceContext.sourceSurface
  };
}
