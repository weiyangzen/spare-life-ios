export function buildMasterCatalogResponse(result) {
  return {
    eventType: 'master_catalog_synced',
    bundleId: result.bundleId,
    bundleVersion: result.bundleVersion,
    status: result.status,
    importedMasters: result.importedMasters,
    importedStories: result.importedStories,
    catalogReadOnly: result.catalogReadOnly,
    domains: result.domains
  };
}

export function buildMasterHomeResponse(result) {
  return {
    eventType: 'master_home_ready',
    appRoute: result.appRoute,
    catalogReadOnly: result.catalogReadOnly,
    query: result.query,
    selectedDomain: result.selectedDomain,
    totalMatches: result.totalMatches,
    domains: result.domains,
    recentChats: result.recentChats
  };
}

export function buildMasterChatResponse(result) {
  return {
    eventType: 'master_reply_ready',
    route: result.route,
    master: {
      id: result.master.id,
      displayName: result.master.displayName,
      title: result.master.title,
      promptTemplate: result.master.promptTemplate
    },
    session: result.session,
    reply: result.reply,
    recentChats: result.recentChats
  };
}

export function buildMasterRestoreResponse(result) {
  return {
    eventType: 'master_session_restored',
    session: result.session,
    master: result.master,
    messages: result.messages
  };
}

export function buildCatalogMutationBlockedResponse(result) {
  return {
    eventType: 'master_catalog_mutation_blocked',
    status: result.status,
    reason: result.reason,
    requestedOperation: result.requestedOperation,
    appRoute: result.appRoute
  };
}

export function buildConsultationResponse(result) {
  return {
    eventType: 'master_consultation_ready',
    consultation: result.consultation,
    members: result.members,
    merged: result.merged
  };
}

export function buildCTAActionResponse(result) {
  return {
    eventType: 'master_cta_tracked',
    tracking: result
  };
}
