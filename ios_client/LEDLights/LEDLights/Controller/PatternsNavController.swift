//
//  PatternsNavController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/25/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class PatternsNavController : UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.patternsNavVC = self
    }
    func back() {
        self.popViewController(animated: true)
    }
}
