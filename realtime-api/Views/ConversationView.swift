//
//  ConversationView.swift
//  realtime-api
//
//  Zero Interface: Voice-first, ambient, progressive disclosure

import SwiftUI
import SwiftData

// MARK: - Zero Interface Colors

private enum ZeroColors {
    static let mutedBlue = Color(red: 0.42, green: 0.56, blue: 0.69)     // #6B8FAF — listening
    static let gentlePurple = Color(red: 0.61, green: 0.56, blue: 0.73)  // #9B8FBB — AI speaking
    static let warmOrange = Color(red: 0.90, green: 0.65, blue: 0.35)    // connecting
    static let softGray = Color(red: 0.88, green: 0.88, blue: 0.88)      // muted/idle
    static let userBubble = Color(red: 0.42, green: 0.56, blue: 0.69)    // muted blue
    static let assistantBubble = Color(red: 0.95, green: 0.94, blue: 0.96) // very soft purple-gray
}

struct ConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ConversationViewModel
    @State private var showControls = false

    init(modelContext: ModelContext, tokenService: TokenService = TokenService()) {
        _viewModel = State(initialValue: ConversationViewModel(
            tokenService: tokenService,
            modelContext: modelContext
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.displayMessages) { message in
                            LiveMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                    .onChange(of: viewModel.lastMessageUpdate) { _, _ in
                        if let lastMessage = viewModel.displayMessages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            // Ambient Voice Orb — the primary interface element
            VStack(spacing: 8) {
                AmbientVoiceOrb(
                    connectionState: viewModel.connectionState,
                    isTalking: viewModel.isTalking,
                    isMuted: viewModel.isAudioMuted
                )
                .onTapGesture {
                    guard case .connected = viewModel.connectionState else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showControls.toggle()
                    }
                }
                .accessibilityLabel(orbAccessibilityLabel)
                .accessibilityHint(viewModel.connectionState == .connected ? "Tap to show or hide controls" : "")

                // Minimal status — only when not connected
                if case .connecting = viewModel.connectionState {
                    Text("Connecting")
                        .font(.caption)
                        .foregroundColor(ZeroColors.warmOrange)
                        .transition(.opacity)
                } else if case .error(let msg) = viewModel.connectionState {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .transition(.opacity)
                } else if case .connected = viewModel.connectionState {
                    Text(showControls ? "Tap orb to hide" : orbSubtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 16)
            .animation(.easeInOut(duration: 0.3), value: viewModel.connectionState)

            // Progressive Disclosure: Controls revealed on orb tap
            if showControls, case .connected = viewModel.connectionState {
                VStack(spacing: 10) {
                    // Mode Toggle
                    Picker("Mode", selection: $viewModel.conversationMode) {
                        Text("Live").tag(ConversationMode.liveSession)
                        Text("Push-to-Talk").tag(ConversationMode.pushToTalk)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    // PTT Button
                    if case .pushToTalk = viewModel.conversationMode {
                        Text("Hold to Talk")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(viewModel.isAudioMuted ? ZeroColors.softGray : ZeroColors.mutedBlue)
                            .cornerRadius(10)
                            .padding(.horizontal, 24)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if viewModel.isAudioMuted { viewModel.isAudioMuted = false }
                                    }
                                    .onEnded { _ in
                                        if !viewModel.isAudioMuted { viewModel.isAudioMuted = true }
                                    }
                            )
                    }

                    // End Conversation
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        viewModel.endConversation()
                        dismiss()
                    } label: {
                        Text("End")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .connected = viewModel.connectionState {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isDebugEnabled.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isDebugEnabled ? "ladybug.fill" : "ladybug")
                            .foregroundColor(viewModel.isDebugEnabled ? .orange : .secondary)
                    }
                    .accessibilityLabel(viewModel.isDebugEnabled ? "Debug enabled" : "Debug disabled")
                }
            }
        }
        .onDisappear {
            viewModel.endConversation()
        }
        .task {
            await viewModel.startConversation()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
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

    private var orbAccessibilityLabel: String {
        switch viewModel.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting to voice service"
        case .connected:
            if viewModel.isAudioMuted { return "Microphone muted" }
            if viewModel.isTalking { return "AI is speaking" }
            return "Listening"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var orbSubtitle: String {
        if viewModel.isAudioMuted { return "Muted" }
        if viewModel.isTalking { return "Speaking" }
        switch viewModel.conversationMode {
        case .liveSession: return "Listening"
        case .pushToTalk: return "Push-to-Talk"
        }
    }
}

// MARK: - Ambient Voice Orb

/// A breathing, pulsing circle that communicates voice state through animation.
/// Replaces the static mic icon — the orb IS the interface.
struct AmbientVoiceOrb: View {
    let connectionState: ConnectionState
    let isTalking: Bool
    let isMuted: Bool

    @State private var breathe = false
    @State private var pulse = false

    private var orbColor: Color {
        switch connectionState {
        case .disconnected: return ZeroColors.softGray
        case .connecting: return ZeroColors.warmOrange
        case .connected:
            if isMuted { return ZeroColors.softGray }
            if isTalking { return ZeroColors.gentlePurple }
            return ZeroColors.mutedBlue
        case .error: return .red.opacity(0.6)
        }
    }

    private var isActive: Bool {
        if case .connected = connectionState, !isMuted { return true }
        if case .connecting = connectionState { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Outer breathing ring
            Circle()
                .fill(orbColor.opacity(0.08))
                .frame(width: 120, height: 120)
                .scaleEffect(breathe && isActive ? 1.15 : 1.0)

            // Middle ring
            Circle()
                .fill(orbColor.opacity(0.15))
                .frame(width: 88, height: 88)
                .scaleEffect(breathe && isActive ? 1.1 : 0.95)

            // Inner orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbColor.opacity(0.6), orbColor.opacity(0.25)],
                        center: .center,
                        startRadius: 5,
                        endRadius: 40
                    )
                )
                .frame(width: 64, height: 64)
                .scaleEffect(pulse && isTalking ? 1.12 : 1.0)

            // Center icon — minimal, only for muted state
            if isMuted, case .connected = connectionState {
                Image(systemName: "mic.slash")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .animation(.easeInOut(duration: isTalking ? 0.6 : 2.5).repeatForever(autoreverses: true), value: breathe)
        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: pulse)
        .animation(.easeInOut(duration: 0.5), value: orbColor)
        .onAppear {
            breathe = true
            pulse = true
        }
    }
}

// MARK: - Live Message Bubble (Zero Interface style)

struct LiveMessageBubble: View {
    let message: ConversationViewModel.DisplayMessage

    private var isUser: Bool {
        message.role == "user"
    }

    private var isTool: Bool {
        message.role == "tool"
    }

    var body: some View {
        if isTool {
            // Tool call: centered, subtle, compact
            HStack {
                Spacer()
                Text(message.content)
                    .font(.caption)
                    .foregroundColor(ZeroColors.gentlePurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ZeroColors.gentlePurple.opacity(0.08))
                    .cornerRadius(12)
                    .animation(.none, value: message.content)
                Spacer()
            }
            .accessibilityLabel("Tool call: \(message.content)")
        } else {
            HStack {
                if isUser { Spacer() }

                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isUser ? ZeroColors.userBubble : ZeroColors.assistantBubble)
                        .foregroundColor(isUser ? .white : .primary)
                        .cornerRadius(18)
                        .animation(.none, value: message.content)

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

                if !isUser { Spacer() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isUser ? "You" : "Assistant"): \(message.content)")
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
