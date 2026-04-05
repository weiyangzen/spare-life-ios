import {
  SCAN_TARGET_KINDS,
  SORT_MODES,
  requireEnum,
  sanitizeText,
  stableId,
  uniqueStrings
} from '../../../spare-life-ios-app/Domain/Models/sceneContracts.mjs';
import {
  assertSceneIntentRequest,
  assertSceneScanPayload
} from '../schemas/channelContracts.mjs';

function titleFromSlug(slug) {
  return slug
    .split(/[-_]/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function parseRawCode(rawCode, codeType) {
  const trimmed = sanitizeText(rawCode);
  if (/^https?:\/\//i.test(trimmed)) {
    const url = new URL(trimmed);
    const slug = url.pathname.split('/').filter(Boolean).pop() ?? 'scene';
    const targetKind = requireEnum(url.searchParams.get('kind') ?? 'event', SCAN_TARGET_KINDS, 'event', 'target kind');
    return {
      sourceType: codeType ?? 'short_link',
      targetKind,
      slug,
      canonicalCode: `${targetKind}:${slug}`,
      title: sanitizeText(url.searchParams.get('title')) || titleFromSlug(slug),
      locationLabel: sanitizeText(url.searchParams.get('location'))
    };
  }

  if (trimmed.startsWith('ACT:')) {
    const slug = trimmed.slice(4).toLowerCase();
    return {
      sourceType: codeType ?? 'activity_code',
      targetKind: 'event',
      slug,
      canonicalCode: `event:${slug}`,
      title: titleFromSlug(slug),
      locationLabel: ''
    };
  }

  if (trimmed.startsWith('INV:')) {
    const [, kind = 'group', slug = 'scene'] = trimmed.split(':');
    const targetKind = requireEnum(kind, SCAN_TARGET_KINDS, 'group', 'target kind');
    return {
      sourceType: codeType ?? 'invite_code',
      targetKind,
      slug: slug.toLowerCase(),
      canonicalCode: `${targetKind}:${slug.toLowerCase()}`,
      title: titleFromSlug(slug),
      locationLabel: ''
    };
  }

  if (trimmed.startsWith('lobster://scene/')) {
    const url = new URL(trimmed);
    const parts = url.pathname.split('/').filter(Boolean);
    const targetKind = requireEnum(parts[0] ?? 'event', SCAN_TARGET_KINDS, 'event', 'target kind');
    const slug = parts[1] ?? 'scene';
    return {
      sourceType: codeType ?? 'qr',
      targetKind,
      slug,
      canonicalCode: `${targetKind}:${slug}`,
      title: sanitizeText(url.searchParams.get('title')) || titleFromSlug(slug),
      locationLabel: sanitizeText(url.searchParams.get('location'))
    };
  }

  return {
    sourceType: codeType ?? 'qr',
    targetKind: 'event',
    slug: trimmed.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
    canonicalCode: `event:${trimmed.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
    title: trimmed,
    locationLabel: ''
  };
}

export function normalizeSceneScanEvent(payload) {
  const input = assertSceneScanPayload(payload);
  const parsed = parseRawCode(input.rawCode, input.codeType);
  const sceneKey = `${parsed.targetKind}:${parsed.slug}`;
  const sceneTags = uniqueStrings([...(input.scene?.tags ?? []), ...(input.viewer?.focusTags ?? [])]);

  return {
    eventId:
      sanitizeText(input.eventId) ||
      stableId('scene-scan-payload', input.rawCode, input.viewer?.userId ?? 'guest', input.receivedAt ?? ''),
    channel: sanitizeText(input.channel) || 'camera',
    receivedAt: input.receivedAt ?? new Date().toISOString(),
    sortBy: SORT_MODES.has(input.request?.sortBy) ? input.request.sortBy : 'best_match',
    scanTarget: {
      id: stableId('scan-target', sceneKey),
      sceneKey,
      rawCode: input.rawCode,
      canonicalCode: parsed.canonicalCode,
      targetKind: parsed.targetKind,
      sourceType: parsed.sourceType,
      title: sanitizeText(input.scene?.title) || parsed.title,
      locationLabel: sanitizeText(input.scene?.locationLabel) || parsed.locationLabel || 'scene nearby',
      sceneTags
    },
    scene: {
      sceneKey,
      targetKind: parsed.targetKind,
      title: sanitizeText(input.scene?.title) || parsed.title,
      locationLabel: sanitizeText(input.scene?.locationLabel) || parsed.locationLabel || 'scene nearby',
      tags: sceneTags
    },
    viewerContext: {
      userId: sanitizeText(input.viewer?.userId) || 'guest-viewer',
      profileTags: uniqueStrings(input.viewer?.profileTags ?? [])
    },
    discussionPosts: input.discussionPosts.map((post, index) => ({
      id: stableId('scene-post', sceneKey, post.externalId ?? `${index}`),
      externalId: sanitizeText(post.externalId) || stableId('external-post', sceneKey, index),
      authorName: sanitizeText(post.authorName) || `user-${index + 1}`,
      text: sanitizeText(post.text),
      createdAt: post.createdAt ?? new Date().toISOString(),
      engagement: Number(post.engagement ?? 0),
      topicTags: uniqueStrings(post.topicTags ?? []),
      agentId: sanitizeText(post.agentId) || null
    })),
    agentPublicCards: input.agentPublicCards.map((card, index) => ({
      id: stableId('agent-card', card.agentId ?? `card-${index}`),
      agentId: sanitizeText(card.agentId) || stableId('agent', index),
      userId: sanitizeText(card.userId) || stableId('user', index),
      displayName: sanitizeText(card.displayName) || `Agent ${index + 1}`,
      identityTags: uniqueStrings(card.identityTags ?? []),
      intentTags: uniqueStrings(card.intentTags ?? []),
      expertiseTags: uniqueStrings(card.expertiseTags ?? []),
      publicBio: sanitizeText(card.publicBio) || 'Open to scene conversations.',
      allowsAgentIntro: Boolean(card.allowsAgentIntro),
      visibilityScope: sanitizeText(card.visibilityScope) || 'scene_only',
      privacyRadius: sanitizeText(card.privacyRadius) || 'district',
      trustScore: Number(card.trustScore ?? 0.5),
      locationLabel: sanitizeText(card.locationLabel) || sanitizeText(input.scene?.locationLabel) || 'scene nearby'
    })),
    intentRequest: input.intentRequest
      ? {
          ...assertSceneIntentRequest(input.intentRequest),
          targetAgentId: sanitizeText(input.intentRequest.targetAgentId) || null,
          message: sanitizeText(input.intentRequest.message),
          intentType: sanitizeText(input.intentRequest.intentType) || 'scene_social',
          extraTags: uniqueStrings(input.intentRequest.extraTags ?? []),
          createdAt: input.intentRequest.createdAt ?? new Date().toISOString()
        }
      : null
  };
}
