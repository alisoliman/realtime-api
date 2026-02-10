//
//  GetDeviceInfoTool.swift
//  realtime-api
//

import Foundation
import RealtimeAPI
#if canImport(UIKit)
import UIKit
#endif

struct GetDeviceInfoTool: CallableTool {
    let name = "get_device_info"
    let description = "Get information about the user's device including model, OS version, and battery level."
    let parameters: JSONSchema = .object(properties: [:], description: "No parameters required")

    func execute(arguments: String) async -> String {
        #if canImport(UIKit)
        let device = await MainActor.run { UIDevice.current }
        let name = await MainActor.run { device.name }
        let systemName = await MainActor.run { device.systemName }
        let systemVersion = await MainActor.run { device.systemVersion }
        let model = await MainActor.run { device.model }

        await MainActor.run { device.isBatteryMonitoringEnabled = true }
        let batteryLevel = await MainActor.run { device.batteryLevel }
        let batteryString = batteryLevel >= 0 ? "\(Int(batteryLevel * 100))%" : "unknown"

        return """
        {"device_name": "\(name)", "model": "\(model)", "os": "\(systemName) \(systemVersion)", "battery_level": "\(batteryString)"}
        """
        #else
        let info = ProcessInfo.processInfo
        return """
        {"platform": "macOS", "os_version": "\(info.operatingSystemVersionString)", "processor_count": \(info.processorCount)}
        """
        #endif
    }
}
