//
//  GetCurrentTimeTool.swift
//  realtime-api
//

import Foundation
import RealtimeAPI

struct GetCurrentTimeTool: CallableTool {
    let name = "get_current_time"
    let description = "Get the current date and time in the user's local timezone."
    let parameters: JSONSchema = .object(properties: [:], description: "No parameters required")

    func execute(arguments: String) async -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .long
        formatter.timeZone = .current

        let timeZone = TimeZone.current
        return """
        {"datetime": "\(formatter.string(from: now))", "timezone": "\(timeZone.identifier)", "unix_timestamp": \(Int(now.timeIntervalSince1970))}
        """
    }
}
