//
//  SettingsView.swift
//  realtime-api
//

import SwiftUI
import RealtimeAPI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedVoice") private var selectedVoiceRaw: String = Session.Voice.shimmer.rawValue

    private var selectedVoice: Session.Voice {
        Session.Voice(rawValue: selectedVoiceRaw) ?? .shimmer
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Voice", selection: $selectedVoiceRaw) {
                        ForEach(Session.Voice.allCases, id: \.self) { voice in
                            Text(voice.rawValue.capitalized)
                                .tag(voice.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Assistant Voice")
                } footer: {
                    Text("Voice will be applied when you start a new conversation. It cannot be changed during an active conversation.")
                        .font(.caption)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Selection")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.blue)
                            Text(selectedVoice.rawValue.capitalized)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
