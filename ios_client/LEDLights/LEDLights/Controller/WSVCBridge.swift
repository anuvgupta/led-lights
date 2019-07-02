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
    public var loginVC: LoginController?
    public var colorsVC: ColorsController?
    public var controlsVC: ControlsController?
    public var patternsVC: PatternsController?
    public var patternsNavVC : PatternsNavController?
    public var patternEditVC : PatternEditorController?
}
