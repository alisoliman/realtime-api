//
//  ConversationDetailView.swift
//  realtime-api
//

import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    let conversation: Conversation

    private var sortedMessages: [ConversationMessage] {
        conversation.messages.sorted { $0.timestamp < $1.timestamp }
    }

    private var transcript: String {
        sortedMessages
            .map { "\($0.role.capitalized): \($0.content)" }
            .joined(separator: "\n\n")
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(sortedMessages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: transcript, subject: Text(conversation.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ConversationMessage

    private var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer()
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color(red: 0.42, green: 0.56, blue: 0.69) : Color(red: 0.95, green: 0.94, blue: 0.96))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(18)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "You" : "Assistant"): \(message.content)")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, ConversationMessage.self, configurations: config)

    let conversation = Conversation(
        title: "Test Conversation",
        duration: 120
    )
    conversation.messages = [
        ConversationMessage(role: "user", content: "Hello, how are you?"),
        ConversationMessage(role: "assistant", content: "I'm doing great! How can I help you today?"),
        ConversationMessage(role: "user", content: "Can you tell me a joke?"),
        ConversationMessage(role: "assistant", content: "Why did the developer go broke? Because he used up all his cache!"),
    ]

    container.mainContext.insert(conversation)

    return NavigationStack {
        ConversationDetailView(conversation: conversation)
    }
    .modelContainer(container)
}
