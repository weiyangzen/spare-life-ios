// ConversationRouter.swift
// Spare Life – lightweight router for message-thread presentation only.

import SwiftUI

@MainActor
final class ConversationRouter: ObservableObject {
    @Published var activeChatThread: ConversationThread?

    func openChat(_ thread: ConversationThread) {
        activeChatThread = thread
    }
}
