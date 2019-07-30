//
//  MusicController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 7/29/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class MusicController: UIViewController {
    
    // ib ui elements
    
    // ui globals
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bridge.musicVC = self
    }
    
    // ib ui actions
    @IBAction func signOutClicked(_ sender: UIButton) {
        ws.logout(callback: { () -> Void in
            self.performSegue(withIdentifier: "logoutSegue", sender: self)
        })
    }
    
    // methods
    
}
