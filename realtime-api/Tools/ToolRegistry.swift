//
//  ToolRegistry.swift
//  realtime-api
//

import Foundation
import RealtimeAPI

/// A tool that can be called by the realtime model during conversation.
protocol CallableTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: JSONSchema { get }

    func execute(arguments: String) async -> String
}

extension CallableTool {
    /// Converts this tool to the SDK's `Tool` type for session registration.
    var asTool: Tool {
        .function(.init(name: name, description: description, parameters: parameters))
    }
}

/// Manages available tools and executes function calls from the model.
final class ToolRegistry: Sendable {
    let tools: [CallableTool]

    init(tools: [CallableTool]? = nil) {
        self.tools = tools ?? [
            GetCurrentTimeTool(),
            GetWeatherTool(),
            GetDeviceInfoTool()
        ]
    }

    /// Tools array for session configuration.
    var sessionTools: [Tool] {
        tools.map(\.asTool)
    }

    /// Execute a tool by name with the given JSON arguments string.
    func execute(name: String, arguments: String) async -> String {
        guard let tool = tools.first(where: { $0.name == name }) else {
            return "{\"error\": \"Unknown tool: \(name)\"}"
        }
        return await tool.execute(arguments: arguments)
    }


}
