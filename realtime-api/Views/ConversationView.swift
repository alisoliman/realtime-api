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
        VStack(spacing: 30) {
            Spacer()

            // Microphone Icon
            Image(systemName: viewModel.isTalking ? "mic.fill" : "mic")
                .font(.system(size: 100))
                .foregroundColor(connectionColor)
                .symbolEffect(.bounce, value: viewModel.isTalking)

            // Status Text
            VStack(spacing: 8) {
                Text(statusText)
                    .font(.title2)
                    .fontWeight(.semibold)

                if viewModel.isTalking {
                    Text("Listening...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Push-to-Talk Button
            if case .connected = viewModel.connectionState {
                Button(action: {
                    viewModel.toggleTalking()
                }) {
                    Text(viewModel.isTalking ? "Stop Talking" : "Press to Talk")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isTalking ? Color.red : Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            // End Conversation Button
            if case .connected = viewModel.connectionState {
                Button(action: {
                    viewModel.endConversation()
                    dismiss()
                }) {
                    Text("End Conversation")
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            Spacer()
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

    private var connectionColor: Color {
        switch viewModel.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return viewModel.isTalking ? .red : .green
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
