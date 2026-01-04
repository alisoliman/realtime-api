//
//  VoicePreferencesService.swift
//  realtime-api
//

import Foundation
import RealtimeAPI

final class VoicePreferencesService {
    static let shared = VoicePreferencesService()

    private let defaults = UserDefaults.standard
    private let voiceKey = "selectedVoice"
    private let defaultVoice: Session.Voice = .shimmer

    var selectedVoice: Session.Voice {
        get {
            guard let rawValue = defaults.string(forKey: voiceKey),
                  let voice = Session.Voice(rawValue: rawValue) else {
                return defaultVoice
            }
            return voice
        }
        set {
            defaults.set(newValue.rawValue, forKey: voiceKey)
        }
    }

    private init() {
        // Set default on first launch
        if defaults.string(forKey: voiceKey) == nil {
            defaults.set(defaultVoice.rawValue, forKey: voiceKey)
        }
    }
}
