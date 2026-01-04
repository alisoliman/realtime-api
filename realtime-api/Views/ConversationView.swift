//
//  ConversationView.swift
//  realtime-api
//

import SwiftUI
import SwiftData

struct ConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ConversationViewModel

    init(modelContext: ModelContext, tokenService: TokenService = TokenService()) {
        _viewModel = State(initialValue: ConversationViewModel(
            tokenService: tokenService,
            modelContext: modelContext
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Section: Scrollable Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.displayMessages) { message in
                            MessageBubble(message: ConversationMessage(
                                id: UUID(uuidString: message.id) ?? UUID(),
                                role: message.role,
                                content: message.content,
                                timestamp: message.timestamp
                            ))
                            .id(message.id)
                        }
                    }
                    .padding()
                    .onChange(of: viewModel.displayMessages.count) { _, _ in
                        // Auto-scroll to latest message
                        if let lastMessage = viewModel.displayMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Divider()

            // Middle Section: Microphone Icon + Status
            VStack(spacing: 16) {
                Image(systemName: viewModel.isAudioMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(connectionColor)
                    .symbolEffect(.bounce, value: !viewModel.isAudioMuted)

                VStack(spacing: 8) {
                    Text(statusText)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if case .connected = viewModel.connectionState {
                        Text(modeText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 20)

            // Bottom Section: Controls
            if case .connected = viewModel.connectionState {
                VStack(spacing: 12) {
                    // Mode Toggle
                    Picker("Conversation Mode", selection: $viewModel.conversationMode) {
                        Text("Live Session").tag(ConversationMode.liveSession)
                        Text("Push-to-Talk").tag(ConversationMode.pushToTalk)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // PTT Button (changes based on mode)
                    if case .pushToTalk = viewModel.conversationMode {
                        // Hold-to-talk button
                        Text("Hold to Talk")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isAudioMuted ? Color.gray : Color.blue)
                            .cornerRadius(12)
                            .overlay(
                                HStack {
                                    Image(systemName: "mic.circle.fill")
                                        .font(.title3)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            )
                            .padding(.horizontal)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if viewModel.isAudioMuted {
                                            viewModel.isAudioMuted = false
                                        }
                                    }
                                    .onEnded { _ in
                                        if !viewModel.isAudioMuted {
                                            viewModel.isAudioMuted = true
                                        }
                                    }
                            )
                    } else {
                        // Live mode indicator
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .font(.title3)
                            Text("Microphone Active")
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // End Conversation Button
                    Button(action: {
                        viewModel.endConversation()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "phone.down.circle.fill")
                                .font(.title3)
                            Text("End Conversation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startConversation()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private var modeText: String {
        switch viewModel.conversationMode {
        case .liveSession:
            return "Continuous Listening"
        case .pushToTalk:
            return "Hold button to speak"
        }
    }

    private var connectionColor: Color {
        switch viewModel.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return viewModel.isAudioMuted ? .gray : .green
        case .error:
            return .red
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, ConversationMessage.self, configurations: config)

    NavigationStack {
        ConversationView(modelContext: container.mainContext)
    }
    .modelContainer(container)
}
