//
//  WSVCBridge.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/18/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import Foundation

class WSVCBridge {
    // provides WebSocket client interface links to UI ViewControllers
    public var loginVC: LoginViewController?
    public var colorsVC: ColorsViewController?
    public var controlsVC: ControlsViewController?
    public var patternsVC: PatternsViewController?
    public var patternEditVC : PatternEditorViewController?
}
