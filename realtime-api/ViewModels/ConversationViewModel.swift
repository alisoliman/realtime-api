//
//  ConversationViewModel.swift
//  realtime-api
//

import Foundation
import SwiftData
import RealtimeAPI
import AVFAudio

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

@Observable
class ConversationViewModel {
    var connectionState: ConnectionState = .disconnected
    var isTalking: Bool = false
    var errorMessage: String?

    private struct AccumulatedMessage {
        var itemId: String
        var role: String
        var content: String
    }

    private var realtimeAPI: RealtimeAPI?
    private let tokenService: TokenService
    private let modelContext: ModelContext

    private var conversationStartTime: Date?
    private var currentConversation: Conversation?
    private var accumulatedMessages: [AccumulatedMessage] = []
    private var messageIndexByItemId: [String: Int] = [:]

    init(tokenService: TokenService = TokenService(), modelContext: ModelContext) {
        self.tokenService = tokenService
        self.modelContext = modelContext
    }

    @MainActor
    func startConversation() async {
        guard connectionState == .disconnected else { return }

        connectionState = .connecting
        conversationStartTime = Date()
        accumulatedMessages = []
        messageIndexByItemId = [:]

        let microphoneAllowed = await requestMicrophonePermissionIfNeeded()
        guard microphoneAllowed else {
            connectionState = .error("Microphone permission denied")
            errorMessage = "Microphone access is required to start a voice conversation. Enable it in Settings → Privacy → Microphone."
            return
        }

        do {
            // Fetch token from backend
            let tokenResponse = try await tokenService.fetchToken()

            // Connect using Azure WebRTC
            realtimeAPI = try await RealtimeAPI.azureWebRTC(
                ephemeralKey: tokenResponse.token,
                azureEndpoint: tokenResponse.endpoint
            )

            connectionState = .connected

            // Listen to events
            Task {
                listenToEvents()
            }

        } catch {
            connectionState = .error(error.localizedDescription)
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
    }

    @MainActor
    func endConversation() {
        guard connectionState == .connected else { return }

        // Save conversation to SwiftData
        saveConversation()

        // Disconnect - RealtimeAPI doesn't have disconnect, the connection closes when deallocated
        realtimeAPI = nil

        connectionState = .disconnected
        isTalking = false
    }

    func toggleTalking() {
        isTalking.toggle()

        if isTalking {
            // Note: The library handles microphone recording automatically
            // when connected. This toggle is just for UI state.
        }
    }

    @MainActor
    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        }
        #else
        return true
        #endif
    }

    private func listenToEvents() {
        guard let api = realtimeAPI else { return }

        Task {
            do {
                for try await event in api.events {
                    await MainActor.run {
                        handleEvent(event)
                    }
                }
            } catch {
                await MainActor.run {
                    connectionState = .error("Event stream error: \(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    private func handleEvent(_ event: ServerEvent) {
        // Extract transcript information from events
        switch event {
        // User audio transcription completed
        case .conversationItemInputAudioTranscriptionDelta(_, let itemId, _, let delta, _):
            upsertMessage(itemId: itemId, role: "user", text: delta, mode: .append)

        case .conversationItemInputAudioTranscriptionCompleted(_, let itemId, _, let transcript, _, _):
            upsertMessage(itemId: itemId, role: "user", text: transcript, mode: .replace)

        // Assistant audio transcript completed
        case .responseAudioTranscriptDelta(_, _, let itemId, _, _, let delta):
            upsertMessage(itemId: itemId, role: "assistant", text: delta, mode: .append)

        case .responseAudioTranscriptDone(_, _, let itemId, _, _, let transcript):
            upsertMessage(itemId: itemId, role: "assistant", text: transcript, mode: .replace)

        // Error handling
        case .error(_, let error):
            errorMessage = error.message

        default:
            break
        }
    }

    private enum MessageUpdateMode {
        case append
        case replace
    }

    @MainActor
    private func upsertMessage(itemId: String, role: String, text: String, mode: MessageUpdateMode) {
        guard !text.isEmpty else { return }

        if let index = messageIndexByItemId[itemId] {
            accumulatedMessages[index].role = role
            switch mode {
            case .append:
                accumulatedMessages[index].content += text
            case .replace:
                accumulatedMessages[index].content = text
            }
            return
        }

        messageIndexByItemId[itemId] = accumulatedMessages.count
        accumulatedMessages.append(AccumulatedMessage(itemId: itemId, role: role, content: text))
    }

    private func saveConversation() {
        let nonEmptyMessages = accumulatedMessages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !nonEmptyMessages.isEmpty,
              let startTime = conversationStartTime else { return }

        let conversation = Conversation(
            timestamp: startTime,
            title: generateTitle(),
            duration: Date().timeIntervalSince(startTime)
        )

        for message in nonEmptyMessages {
            let conversationMessage = ConversationMessage(
                role: message.role,
                content: message.content
            )
            conversation.messages.append(conversationMessage)
        }

        modelContext.insert(conversation)

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save conversation: \(error.localizedDescription)"
        }
    }

    private func generateTitle() -> String {
        // Generate title from first user message or use timestamp
        if let firstUserMessage = accumulatedMessages.first(where: { $0.role == "user" && !$0.content.isEmpty }) {
            let prefix = String(firstUserMessage.content.prefix(50))
            return prefix + (firstUserMessage.content.count > 50 ? "..." : "")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Conversation \(formatter.string(from: conversationStartTime ?? Date()))"
    }
}

