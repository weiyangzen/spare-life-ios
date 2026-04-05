import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

import {
  buildMasterChatRoute,
  buildMasterHomeRoute,
  buildPromptPreview,
  clipText,
  combineTags,
  scoreTextMatch,
  sha1
} from '../../Domain/Models/masterContracts.mjs';
import { sanitizeText, uniqueStrings } from '../../Domain/Models/sceneContracts.mjs';

function requireString(value, fieldName) {
  const normalized = sanitizeText(value);
  if (!normalized) {
    throw new Error(`${fieldName} is required.`);
  }
  return normalized;
}

function normalizeStory(story, masterId, index) {
  const storyId = requireString(story.storyId ?? story.id ?? `story-${index + 1}`, `story id for ${masterId}`);
  const title = requireString(story.title, `story title for ${masterId}/${storyId}`);
  const summary = requireString(story.summary, `story summary for ${masterId}/${storyId}`);
  const beats = uniqueStrings(story.beats ?? []);
  if (beats.length < 3) {
    throw new Error(`story ${masterId}/${storyId} must include at least 3 beats.`);
  }

  return {
    id: `${masterId}:${storyId}`,
    storyKey: storyId,
    title,
    summary,
    fullText: sanitizeText(story.fullText) || [summary, ...beats].join(' '),
    beats,
    tags: uniqueStrings(story.tags ?? [])
  };
}

function normalizePortrait(portrait, bundleBaseDir, masterId) {
  const assetPath = requireString(portrait?.assetPath, `portrait assetPath for ${masterId}`);
  const resolvedPath = resolve(bundleBaseDir, assetPath);
  if (!existsSync(resolvedPath)) {
    throw new Error(`portrait asset for ${masterId} does not exist: ${resolvedPath}`);
  }

  return {
    assetPath: resolvedPath,
    checksum: sha1(readFileSync(resolvedPath)),
    palette: uniqueStrings(portrait?.palette ?? [])
  };
}

export function normalizeMasterAssetBundle(bundle, { sourcePath } = {}) {
  if (!bundle || typeof bundle !== 'object') {
    throw new Error('Master asset bundle must be an object.');
  }

  const bundleId = requireString(bundle.bundleId, 'bundleId');
  const version = requireString(bundle.version, 'bundle version');
  const bundleBaseDir = sourcePath ? dirname(sourcePath) : process.cwd();
  const domains = (bundle.domains ?? []).map((domain, index) => ({
    key: requireString(domain.key, `domain key #${index + 1}`),
    title: requireString(domain.title, `domain title #${index + 1}`),
    description: sanitizeText(domain.description),
    sortOrder: Number(domain.sortOrder ?? index + 1)
  }));

  if (!domains.length) {
    throw new Error('Master asset bundle requires at least one domain.');
  }

  const domainKeys = new Set(domains.map((domain) => domain.key));
  const masters = (bundle.masters ?? []).map((master, index) => {
    const masterId = requireString(master.masterId ?? master.id ?? `master-${index + 1}`, 'master id');
    const domainKey = requireString(master.domainKey, `domainKey for ${masterId}`);
    if (!domainKeys.has(domainKey)) {
      throw new Error(`master ${masterId} references unknown domain ${domainKey}.`);
    }

    const profile = master.profile ?? {};
    const character = master.character ?? {};
    const normalizedStories = (master.stories ?? []).map((story, storyIndex) =>
      normalizeStory(story, masterId, storyIndex)
    );

    if (normalizedStories.length < 3 || normalizedStories.length > 5) {
      throw new Error(`master ${masterId} must provide 3-5 stories.`);
    }

    const normalizedPortrait = normalizePortrait(master.portrait, bundleBaseDir, masterId);
    return {
      id: masterId,
      slug: sanitizeText(master.slug) || masterId,
      bundleId,
      bundleVersion: version,
      domainKey,
      displayName: requireString(profile.displayName ?? master.displayName, `displayName for ${masterId}`),
      title: requireString(profile.title ?? master.title, `title for ${masterId}`),
      tagline: requireString(profile.tagline ?? master.tagline, `tagline for ${masterId}`),
      promptTemplate: requireString(master.promptTemplate, `promptTemplate for ${masterId}`),
      promptPreview: buildPromptPreview(master.promptTemplate),
      profile: {
        headline: sanitizeText(profile.headline) || sanitizeText(profile.tagline) || sanitizeText(master.tagline),
        expertiseTags: uniqueStrings(profile.expertiseTags ?? []),
        focusTags: uniqueStrings(profile.focusTags ?? []),
        voice: sanitizeText(profile.voice)
      },
      character: {
        coreBelief: sanitizeText(character.coreBelief),
        adviceStyle: requireString(character.adviceStyle ?? '先澄清目标，再给节奏化建议', `adviceStyle for ${masterId}`),
        decisionStyle: sanitizeText(character.decisionStyle) || 'steady_execution',
        riskAppetite: sanitizeText(character.riskAppetite) || 'steady',
        boundaries: uniqueStrings(character.boundaries ?? [])
      },
      portrait: normalizedPortrait,
      searchTags: combineTags(
        profile.expertiseTags,
        profile.focusTags,
        normalizedStories.flatMap((story) => story.tags)
      ),
      stories: normalizedStories
    };
  });

  if (!masters.length) {
    throw new Error('Master asset bundle requires at least one master.');
  }

  const checksum = sha1(
    JSON.stringify({
      bundleId,
      version,
      domains,
      masters: masters.map((master) => ({
        id: master.id,
        domainKey: master.domainKey,
        promptTemplate: master.promptTemplate,
        portraitChecksum: master.portrait.checksum,
        stories: master.stories
      }))
    })
  );

  return {
    bundleId,
    version,
    checksum,
    domains,
    masters
  };
}

function scoreMasterSearch(master, domain, query) {
  if (!sanitizeText(query)) {
    return 1;
  }
  return (
    scoreTextMatch(
      [
        master.displayName,
        master.title,
        master.tagline,
        domain?.title ?? '',
        master.profile?.headline ?? '',
        master.searchTags?.join(' ') ?? ''
      ].join(' '),
      query
    ) +
    scoreTextMatch(
      master.stories?.map((story) => `${story.title} ${story.summary} ${story.tags.join(' ')}`).join(' ') ?? '',
      query
    ) *
      0.35
  );
}

export function buildMasterHome({ domains, masters, recentSessions, query = '', domainKey = null }) {
  const trimmedQuery = sanitizeText(query);
  const selectedDomain = sanitizeText(domainKey) || null;
  const domainMap = new Map(domains.map((domain) => [domain.key, domain]));

  const rankedMasters = masters
    .filter((master) => !selectedDomain || master.domainKey === selectedDomain)
    .map((master) => {
      const domain = domainMap.get(master.domainKey);
      return {
        ...master,
        searchScore: scoreMasterSearch(master, domain, trimmedQuery)
      };
    })
    .filter((master) => !trimmedQuery || master.searchScore > 0)
    .sort((left, right) => right.searchScore - left.searchScore || left.displayName.localeCompare(right.displayName));

  const groupedDomains = domains
    .sort((left, right) => left.sortOrder - right.sortOrder)
    .map((domain) => ({
      domainKey: domain.key,
      title: domain.title,
      description: domain.description,
      masters: rankedMasters
        .filter((master) => master.domainKey === domain.key)
        .map((master) => ({
          masterId: master.id,
          displayName: master.displayName,
          title: master.title,
          tagline: clipText(master.tagline, 100),
          promptPreview: master.promptPreview,
          portraitAssetPath: master.portrait.assetPath,
          profileTags: combineTags(master.profile.expertiseTags, master.profile.focusTags).slice(0, 6),
          chatRoute: buildMasterChatRoute(master.id),
          promptTemplate: master.promptTemplate
        }))
    }))
    .filter((domain) => domain.masters.length > 0);

  return {
    catalogReadOnly: true,
    query: trimmedQuery,
    selectedDomain,
    totalMatches: rankedMasters.length,
    appRoute: buildMasterHomeRoute({
      domainKey: selectedDomain,
      query: trimmedQuery
    }),
    domains: groupedDomains,
    recentChats: recentSessions.map((session) => ({
      sessionId: session.id,
      masterId: session.masterId,
      displayName: session.displayName,
      title: session.title,
      unreadCount: session.unreadCount,
      preview: session.lastAssistantMessage || session.lastUserMessage || session.topic,
      restoreRoute: buildMasterChatRoute(session.masterId, session.id),
      lastMessageAt: session.lastMessageAt
    }))
  };
}
