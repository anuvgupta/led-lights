//
//  Models.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/20/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import Foundation

// device object
class Device {
    public var id: String
    public var name: String
    public var lastEvent: String
    public var lastTimestamp: Int
    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.lastEvent = ""
        self.lastTimestamp = 0
    }
}

// color preset data object
class ColorPreset {
    public var red: Int = 0
    public var green: Int = 0
    public var blue: Int = 0
    public var timestamp: Int = 0 // last updated
    public var id: String = ""
    public var name: String = ""
    init(red: Int, green: Int, blue: Int, timestamp: Int, id: String, name: String) {
        self.red = red
        self.green = green
        self.blue = blue
        self.timestamp = timestamp
        self.id = id
        self.name = name
    }
}

// pattern data object
class Pattern {
    public var id: String = ""
    public var name: String = ""
    public var list: [PatternItem] = []
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// pattern color-item data object
class PatternItem {
    public var red: Int = 0
    public var green: Int = 0
    public var blue: Int = 0
    public var fade: Int = 0 // fade-in time (ms)
    public var hold: Int = 0 // hold color time (ms)
    init(red: Int, green: Int, blue: Int, fade: Int, hold: Int) {
        self.red = red
        self.green = green
        self.blue = blue
        self.fade = fade
        self.hold = hold
    }
}
