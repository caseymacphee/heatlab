//
//  Item.swift
//  heatlab
//
//  Created by Casey MacPhee on 1/11/26.
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
