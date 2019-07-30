//
//  WSVCBridge.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/18/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

// provides links to ViewControllers
class WSVCBridge {
    // singleton ViewControllers
    public var loginVC: LoginController?
    public var musicVC: MusicController?
    public var colorsVC: ColorsController?
    public var controlsVC: ControlsController?
    public var patternsVC: PatternsController?
    public var patternsNavVC: PatternsNavController?
    public var patternEditVC: PatternEditorController?
    public var colorPickVC: ColorPickerController?
    // current ViewController
    public var lastVC: UIViewController?
    func currentVC() -> UIViewController? {
        return application.topMostViewController()
    }
    public var currentAlertVC: UIAlertController?
}
