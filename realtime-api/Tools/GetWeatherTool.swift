//
//  GetWeatherTool.swift
//  realtime-api
//

import Foundation
import RealtimeAPI

struct GetWeatherTool: CallableTool {
    let name = "get_weather"
    let description = "Get the current weather for a given location. Returns temperature, conditions, and humidity."

    let parameters: JSONSchema = .object(properties: [
        "location": .string(description: "City name, e.g. 'San Francisco' or 'London, UK'")
    ], description: "Weather query parameters")

    func execute(arguments: String) async -> String {
        // Parse location from arguments
        let location: String
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let loc = json["location"] as? String {
            location = loc
        } else {
            location = "Unknown"
        }

        // Simulated weather — in production, call a real weather API
        let conditions = ["Sunny", "Partly Cloudy", "Cloudy", "Light Rain", "Clear"].randomElement()!
        let temp = Int.random(in: 5...35)
        let humidity = Int.random(in: 30...90)

        return """
        {"location": "\(location)", "temperature_celsius": \(temp), "conditions": "\(conditions)", "humidity_percent": \(humidity), "note": "Simulated data for demo purposes"}
        """
    }
}
