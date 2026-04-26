//
//  Item.swift
//  FlowState
//
//  Created by Ken Dzisah on 4/26/26.
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
