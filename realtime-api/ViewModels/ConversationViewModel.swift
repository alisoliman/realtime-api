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
    var isDebugEnabled: Bool = true

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
    
    // Track the last update for scroll triggers
    var lastMessageUpdate: Date = Date()

    private struct AccumulatedMessage {
        var itemId: String
        var role: String
        var content: String
        var timestamp: Date
    }

    struct DisplayMessage: Identifiable {
        let id: String
        let role: String  // "user", "assistant", or "tool"
        let content: String
        let timestamp: Date

        var isUser: Bool {
            role == "user"
        }

        var isTool: Bool {
            role == "tool"
        }
    }

    private var realtimeAPI: RealtimeAPI?
    private let tokenService: TokenService
    private let toolRegistry: ToolRegistry
    private let modelContext: ModelContext
    private var eventListenerTask: Task<Void, Never>?

    private var conversationStartTime: Date?
    private var currentConversation: Conversation?
    private var accumulatedMessages: [AccumulatedMessage] = []
    private var messageIndexByItemId: [String: Int] = [:]

    // Tool call argument accumulation
    private var pendingToolArguments: [String: String] = [:]  // callId -> accumulated JSON args
    private var pendingToolNames: [String: String] = [:]      // callId -> function name
    private var pendingToolItemIds: [String: String] = [:]    // callId -> itemId

    init(tokenService: TokenService = TokenService(), modelContext: ModelContext, toolRegistry: ToolRegistry = ToolRegistry()) {
        self.tokenService = tokenService
        self.modelContext = modelContext
        self.toolRegistry = toolRegistry
    }

    @MainActor
    func startConversation() async {
        guard connectionState == .disconnected else { return }

        connectionState = .connecting
        conversationStartTime = Date()
        accumulatedMessages = []
        displayMessages = []
        messageIndexByItemId = [:]

        let microphoneAllowed = await requestMicrophonePermissionIfNeeded()
        guard microphoneAllowed else {
            connectionState = .error("Microphone permission denied")
            errorMessage = "Microphone access is required to start a voice conversation. Enable it in Settings → Privacy → Microphone."
            return
        }

        do {
            // Get user's selected voice from UserDefaults
            let selectedVoice = UserDefaults.standard.string(forKey: "selectedVoice") ?? Session.Voice.alloy.rawValue

            // Fetch token from backend with the selected voice
            let tokenResponse = try await tokenService.fetchToken(voice: selectedVoice)

            // Connect using Azure WebRTC
            realtimeAPI = try await RealtimeAPI.azureWebRTC(
                ephemeralKey: tokenResponse.token,
                azureEndpoint: tokenResponse.endpoint
            )

            connectionState = .connected

            // Listen to events
            eventListenerTask = Task {
                await listenToEvents()
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
        #else
        return true
        #endif
    }

    private func listenToEvents() async {
        guard let api = realtimeAPI else { return }

        do {
            for try await event in api.events {
                if Task.isCancelled { break }

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

    @MainActor
    private func handleEvent(_ event: ServerEvent) {
        switch event {
        // Session created — register tools
        case .sessionCreated(_, let session):
            debugLog("🚀 Session created - Voice: \(session.audio.output.voice.rawValue), Model: \(session.model.rawValue)")
            registerTools(session: session)

        // Session updated confirmation
        case .sessionUpdated(_, let session):
            debugLog("📋 Session updated - Voice: \(session.audio.output.voice.rawValue), Tools: \(session.tools?.count ?? 0)")

        // VAD events - track speaking state
        case .inputAudioBufferSpeechStarted(_, let itemId, let audioStartMs):
            isTalking = true
            debugLog("🎤 Speech started - itemId: \(itemId), audioStartMs: \(audioStartMs)")

        case .inputAudioBufferSpeechStopped(_, let itemId, let audioEndMs):
            isTalking = false
            debugLog("🎤 Speech stopped - itemId: \(itemId), audioEndMs: \(audioEndMs)")

        // Input audio buffer committed - user message is being created
        case .inputAudioBufferCommitted(_, let itemId, _):
            debugLog("📥 Audio committed - itemId: \(itemId)")
            break

        // Conversation item created - track for context awareness
        case .conversationItemCreated(_, let item, _):
            debugLog("💬 Conversation item created - id: \(item.id), \(itemDescription(item))")
            // Track function call names for tool execution
            if case .functionCall(let call) = item {
                pendingToolNames[call.callId] = call.name
            }

        // User audio transcription
        case .conversationItemInputAudioTranscriptionDelta(_, let itemId, _, let delta, _):
            upsertMessage(itemId: itemId, role: "user", text: delta, mode: .append)

        case .conversationItemInputAudioTranscriptionCompleted(_, let itemId, _, let transcript, _, _):
            upsertMessage(itemId: itemId, role: "user", text: transcript, mode: .replace)

        // Assistant audio transcript
        case .responseAudioTranscriptDelta(_, _, let itemId, _, _, let delta):
            upsertMessage(itemId: itemId, role: "assistant", text: delta, mode: .append)

        case .responseAudioTranscriptDone(_, _, let itemId, _, _, let transcript):
            upsertMessage(itemId: itemId, role: "assistant", text: transcript, mode: .replace)

        // Function call arguments streaming
        case .responseFunctionCallArgumentsDelta(_, _, let itemId, _, let callId, let delta):
            pendingToolArguments[callId, default: ""] += delta
            pendingToolItemIds[callId] = itemId
            debugLog("🔧 Tool args delta - callId: \(callId), delta: \(delta)")

        // Function call complete — execute the tool
        case .responseFunctionCallArgumentsDone(_, _, let itemId, _, let callId, let arguments):
            pendingToolArguments[callId] = arguments
            pendingToolItemIds[callId] = itemId
            debugLog("🔧 Tool call complete - callId: \(callId), args: \(arguments)")
            executeToolCall(callId: callId, itemId: itemId)

        // Response lifecycle events
        case .responseCreated(_, let response):
            debugLog("🤖 Response created - id: \(response.id)")

        case .responseDone(_, let response):
            debugLog("✅ Response done - id: \(response.id), status: \(response.status.rawValue)")

        // Error handling
        case .error(_, let error):
            debugLog("❌ Error: \(error.message)")
            errorMessage = error.message

        default:
            break
        }
    }

    // MARK: - Tool Calling

    /// Register tools with the session after creation.
    private func registerTools(session: Session) {
        let tools = toolRegistry.sessionTools
        guard !tools.isEmpty else { return }

        var updatedSession = session
        updatedSession.tools = tools
        updatedSession.toolChoice = .auto

        Task { [weak self] in
            guard let api = self?.realtimeAPI else { return }
            do {
                try await api.send(event: .updateSession(eventId: nil, session: updatedSession))
                await MainActor.run {
                    self?.debugLog("🔧 Registered \(tools.count) tools with session")
                }
            } catch {
                await MainActor.run {
                    self?.debugLog("❌ Failed to register tools: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Execute a tool call and send the result back to the model.
    private func executeToolCall(callId: String, itemId: String) {
        let arguments = pendingToolArguments[callId] ?? "{}"

        // Determine tool name from the conversationItemCreated event or pending state
        // The function name comes from the item — we need to find it
        Task { [weak self] in
            guard let self, let api = self.realtimeAPI else { return }

            // Find the tool name from the item
            let toolName = self.findToolName(for: callId)

            await MainActor.run {
                // Show tool call in chat
                let displayName = toolName ?? "tool"
                self.upsertMessage(itemId: "tool-\(callId)", role: "tool", text: "⚡ Calling \(displayName)…", mode: .replace)
            }

            // Execute the tool
            let result: String
            if let name = toolName {
                result = await self.toolRegistry.execute(name: name, arguments: arguments)
            } else {
                result = "{\"error\": \"Could not determine tool name\"}"
            }

            await MainActor.run {
                self.upsertMessage(itemId: "tool-\(callId)", role: "tool", text: "⚡ \(toolName ?? "tool") → done", mode: .replace)
                self.debugLog("🔧 Tool result: \(result.prefix(200))")
            }

            // Send function call output back to the model
            do {
                let output = Item.FunctionCallOutput(
                    id: UUID().uuidString,
                    callId: callId,
                    output: result
                )
                try await api.send(event: .createConversationItem(eventId: nil, previousItemId: nil, item: .functionCallOutput(output)))

                // Trigger the model to continue responding with the tool result
                try await api.send(event: .createResponse(eventId: nil, response: nil))
            } catch {
                await MainActor.run {
                    self.debugLog("❌ Failed to send tool result: \(error.localizedDescription)")
                }
            }

            // Clean up pending state
            await MainActor.run {
                self.pendingToolArguments.removeValue(forKey: callId)
                self.pendingToolNames.removeValue(forKey: callId)
                self.pendingToolItemIds.removeValue(forKey: callId)
            }
        }
    }

    /// Find the tool name for a given call ID.
    private func findToolName(for callId: String) -> String? {
        return pendingToolNames[callId]
    }

    private func debugLog(_ message: String) {
        guard isDebugEnabled else { return }
        print("[DEBUG] \(message)")
    }

    private func itemDescription(_ item: Item) -> String {
        switch item {
        case .message(let msg):
            return "type: message, role: \(msg.role.rawValue)"
        case .functionCall(let call):
            return "type: function_call, name: \(call.name)"
        case .functionCallOutput(let output):
            return "type: function_call_output, callId: \(output.callId)"
        @unknown default:
            return "type: unknown"
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

            // Update displayMessages
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
                // Signal content update for auto-scroll
                lastMessageUpdate = Date()
            }
            return
        }

        messageIndexByItemId[itemId] = accumulatedMessages.count
        let now = Date()
        accumulatedMessages.append(AccumulatedMessage(itemId: itemId, role: role, content: text, timestamp: now))

        // Add to displayMessages
        displayMessages.append(DisplayMessage(
            id: itemId,
            role: role,
            content: text,
            timestamp: now
        ))
        lastMessageUpdate = Date()
    }

    private func saveConversation() {
        let nonEmptyMessages = accumulatedMessages.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.role != "tool"
        }
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
                content: message.content,
                timestamp: message.timestamp
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

