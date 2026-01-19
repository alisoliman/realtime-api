//
//  ConversationMessage.swift
//  realtime-api
//

import Foundation
import SwiftData

@Model
final class ConversationMessage {
    @Attribute(.unique) var id: UUID
    var role: String // "user" or "assistant"
    var content: String
    var timestamp: Date

    var conversation: Conversation?

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
