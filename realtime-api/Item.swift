//
//  Item.swift
//  realtime-api
//
//  Created by Ali S on 17/12/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
