//
//  ConversationDetailView.swift
//  realtime-api
//

import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    let conversation: Conversation

    private var transcript: String {
        conversation.messages
            .map { "\($0.role.capitalized): \($0.content)" }
            .joined(separator: "\n\n")
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(conversation.messages) { message in
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
                    .padding(12)
                    .background(isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer()
            }
        }
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
