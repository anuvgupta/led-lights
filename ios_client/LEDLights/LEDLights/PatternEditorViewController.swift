//
//  PatternEditorViewController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/21/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class PatternEditorViewController: UIViewController {
    
    // ib ui elements
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        if let pattern = editingPattern {
            self.title = pattern.name
        }
        bridge.patternEditVC = self
    }
    
    // ib ui actions
    
}
