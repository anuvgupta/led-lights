//
//  ColorPreset.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/18/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import Foundation

class ColorPreset {
    // represents color preset data object
    init(red: Int, green: Int, blue: Int, timestamp: Int, id: String) {
        self.red = red
        self.green = green
        self.blue = blue
        self.timestamp = timestamp
        self.id = id
    }
    public var red : Int = 0
    public var green : Int = 0
    public var blue : Int = 0
    public var timestamp : Int = 0
    public var id : String = ""
}
