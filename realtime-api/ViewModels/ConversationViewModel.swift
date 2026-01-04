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

enum ConversationMode: Equatable {
    case liveSession
    case pushToTalk
}

@Observable
class ConversationViewModel {
    var connectionState: ConnectionState = .disconnected
    var isTalking: Bool = false
    var errorMessage: String?

    var conversationMode: ConversationMode = .liveSession {
        didSet {
            // Only update mute state if connected
            guard connectionState == .connected else { return }

            switch conversationMode {
            case .liveSession:
                // Switching to live session: unmute microphone
                isAudioMuted = false
            case .pushToTalk:
                // Switching to push-to-talk: mute microphone until button is held
                isAudioMuted = true
            }
        }
    }

    var isAudioMuted: Bool = false {
        didSet {
            setAudioEnabled(!isAudioMuted)
        }
    }

    var displayMessages: [DisplayMessage] = []

    private struct AccumulatedMessage {
        var itemId: String
        var role: String
        var content: String
    }

    struct DisplayMessage: Identifiable {
        let id: String  // Use itemId from AccumulatedMessage
        let role: String
        let content: String
        let timestamp: Date

        var isUser: Bool {
            role == "user"
        }
    }

    private var realtimeAPI: RealtimeAPI?
    private let tokenService: TokenService
    private let modelContext: ModelContext
    private var eventListenerTask: Task<Void, Never>?

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

        print("🚀 Starting conversation...")
        connectionState = .connecting
        conversationStartTime = Date()
        accumulatedMessages = []
        displayMessages = []
        messageIndexByItemId = [:]

        let microphoneAllowed = await requestMicrophonePermissionIfNeeded()
        guard microphoneAllowed else {
            print("❌ Microphone permission denied")
            connectionState = .error("Microphone permission denied")
            errorMessage = "Microphone access is required to start a voice conversation. Enable it in Settings → Privacy → Microphone."
            return
        }
        print("✅ Microphone permission granted")

        do {
            // Fetch token from backend
            print("🔑 Fetching token from backend...")
            let tokenResponse = try await tokenService.fetchToken()
            print("✅ Token received, endpoint: \(tokenResponse.endpoint)")

            // Connect using Azure WebRTC
            print("🌐 Connecting to Azure WebRTC...")
            realtimeAPI = try await RealtimeAPI.azureWebRTC(
                ephemeralKey: tokenResponse.token,
                azureEndpoint: tokenResponse.endpoint
            )
            print("✅ Azure WebRTC connection established")

            connectionState = .connected

            // Listen to events - STORE the task reference
            print("🎧 Starting event listener task...")
            eventListenerTask = Task {
                await listenToEvents()
            }

        } catch {
            print("❌ Connection failed: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
    }

    @MainActor
    func endConversation() {
        guard connectionState == .connected else { return }

        // Save conversation to SwiftData
        saveConversation()

        // Cancel event listener Task
        eventListenerTask?.cancel()
        eventListenerTask = nil

        // Disconnect RealtimeAPI
        realtimeAPI = nil

        connectionState = .disconnected
        isTalking = false
    }

    func toggleAudioMute() {
        isAudioMuted.toggle()
    }

    @MainActor
    private func setAudioEnabled(_ enabled: Bool) {
        guard let api = realtimeAPI else { return }
        api.setAudioEnabled(enabled)
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

    private func listenToEvents() async {
        guard let api = realtimeAPI else {
            print("❌ listenToEvents: realtimeAPI is nil")
            return
        }

        print("🔄 Starting event listener...")

        do {
            print("📡 Waiting for events from RealtimeAPI...")
            for try await event in api.events {
                // Check if cancelled
                if Task.isCancelled {
                    print("⚠️ Event listener cancelled")
                    break
                }

                print("📨 Received event: \(event)")
                await MainActor.run {
                    handleEvent(event)
                }
            }
            print("⚠️ Event stream ended")
        } catch {
            print("❌ Event stream error: \(error)")
            await MainActor.run {
                connectionState = .error("Event stream error: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func handleEvent(_ event: ServerEvent) {
        // Extract transcript information from events
        switch event {
        // Session created event - configure voice
        case .sessionCreated(_, var session):
            print("📋 Session created event received")
            print("📋 Current voice: \(session.audio.output.voice.rawValue)")

            // Get selected voice from preferences
            let selectedVoice = VoicePreferencesService.shared.selectedVoice

            // Only update if different
            if session.audio.output.voice != selectedVoice {
                print("🎤 Updating voice to: \(selectedVoice.rawValue)")
                session.audio.output.voice = selectedVoice

                Task { [weak self] in
                    do {
                        try await self?.realtimeAPI?.send(event: .updateSession(session))
                        print("✅ Voice update sent")
                    } catch {
                        print("❌ Failed to update voice: \(error)")
                    }
                }
            } else {
                print("✅ Voice already set to: \(selectedVoice.rawValue)")
            }

        // Session updated confirmation
        case .sessionUpdated(_, let session):
            print("🎯 Server confirmed session update - voice is now: \(session.audio.output.voice.rawValue)")

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

            // NEW: Update displayMessages
            if let displayIndex = displayMessages.firstIndex(where: { $0.id == itemId }) {
                let newContent = switch mode {
                    case .append: displayMessages[displayIndex].content + text
                    case .replace: text
                }
                displayMessages[displayIndex] = DisplayMessage(
                    id: itemId,
                    role: role,
                    content: newContent,
                    timestamp: displayMessages[displayIndex].timestamp
                )
            }
            return
        }

        messageIndexByItemId[itemId] = accumulatedMessages.count
        accumulatedMessages.append(AccumulatedMessage(itemId: itemId, role: role, content: text))

        // NEW: Add to displayMessages
        displayMessages.append(DisplayMessage(
            id: itemId,
            role: role,
            content: text,
            timestamp: Date()
        ))
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

