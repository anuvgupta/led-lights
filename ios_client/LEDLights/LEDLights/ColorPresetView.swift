//
//  ColorPresetView.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/18/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class ColorPresetView : UIButton {
    var id : String = ""
    init(id: String) {
        super.init()
        self.id = id
    }
}
