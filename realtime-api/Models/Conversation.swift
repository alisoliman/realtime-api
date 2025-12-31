//
//  Conversation.swift
//  realtime-api
//

import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var title: String
    var duration: TimeInterval

    @Relationship(deleteRule: .cascade, inverse: \ConversationMessage.conversation)
    var messages: [ConversationMessage] = []

    init(id: UUID = UUID(), timestamp: Date = Date(), title: String = "", duration: TimeInterval = 0) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.duration = duration
    }
}
