export function buildSceneDiscussionResponse({ normalizedEvent, sceneExperience }) {
  return {
    eventType: 'scene_discussion_ready',
    scene: {
      sceneKey: normalizedEvent.scene.sceneKey,
      title: normalizedEvent.scene.title,
      targetKind: normalizedEvent.scene.targetKind,
      locationLabel: normalizedEvent.scene.locationLabel,
      tags: normalizedEvent.scene.tags
    },
    appRoute: sceneExperience.sceneRoute,
    cache: {
      usedCache: sceneExperience.usedCache,
      expiresAt: sceneExperience.feed.expiresAt
    },
    moderation: sceneExperience.feed.moderation,
    cards: {
      summary: sceneExperience.feed.summaryCard,
      hotTakes: sceneExperience.feed.hotTakeCards,
      risks: sceneExperience.feed.riskCards,
      activeAgents: sceneExperience.activeAgents
    },
    nextActions: [
      {
        type: 'open_scene_discussion',
        route: sceneExperience.sceneRoute
      },
      {
        type: 'start_scene_social',
        route: `sparelife://earn-social/compose?scene_key=${encodeURIComponent(normalizedEvent.scene.sceneKey)}`
      }
    ]
  };
}

export function buildSceneIntentResponse({ normalizedEvent, intentResult }) {
  return {
    eventType: 'scene_social_intent_ready',
    sceneKey: normalizedEvent.scene.sceneKey,
    route: intentResult.draft.route,
    riskStatus: intentResult.risk.status,
    riskReason: intentResult.risk.reason,
    draft: intentResult.draft
  };
}
