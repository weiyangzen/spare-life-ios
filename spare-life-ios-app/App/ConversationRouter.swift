// ConversationRouter.swift
// Spare Life – Centralized router for conversation detail overlays
// The detail views are presented as full-screen overlays above the TabView,
// so the custom tab bar is physically covered (not dynamically hidden).

import SwiftUI

@MainActor
final class ConversationRouter: ObservableObject {
    // MARK: - 消息 tab → ChatThreadView

    @Published var activeChatThread: ConversationThread?

    // MARK: - 闲聊 tab → MasterConversationView

    @Published var isMasterChatActive: Bool = false

    /// Non-published reference to the store driving the active master conversation.
    /// Kept as a plain property to avoid double ObservableObject invalidation.
    private(set) var activeMasterStore: MasterExperienceStore?

    // MARK: - Computed

    var isShowingDetail: Bool {
        activeChatThread != nil || isMasterChatActive
    }

    // MARK: - Actions

    func openChat(_ thread: ConversationThread) {
        activeChatThread = thread
    }

    func openMasterChat(_ store: MasterExperienceStore) {
        activeMasterStore = store
        isMasterChatActive = true
    }

    func dismissDetail() {
        if isMasterChatActive, let store = activeMasterStore {
            store.conversation = nil
        }
        activeMasterStore = nil
        isMasterChatActive = false
        activeChatThread = nil
    }
}
