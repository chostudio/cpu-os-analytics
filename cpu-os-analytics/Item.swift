//
//  Item.swift
//  cpu-os-analytics
//
//  Created by Chris Ho on 12/25/25.
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
