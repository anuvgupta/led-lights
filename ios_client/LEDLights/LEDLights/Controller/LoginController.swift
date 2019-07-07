//
//  LoginController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/15/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

// login view controller
class LoginController: UIViewController {
    
    // ib ui elements
    @IBOutlet weak var loginStack: UIStackView!
    @IBOutlet weak var textField: UITextField!
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.loginVC = self
        textField.attributedPlaceholder = NSAttributedString(string: "led lights", attributes: [ NSAttributedString.Key.foregroundColor: UIColor.lightGray ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            if ws.connected() {
                self.showLoginStack()
            }
        })
        ws.connect();
    }
    
    // ib ui actions
    @IBAction func textFieldValueChanged(_ sender: UITextField) {
        ws.login(password: sender.text ?? "")
    }
    @IBAction func textFieldSubmitted(_ sender: UITextField) {
        sender.resignFirstResponder()
        ws.login(password: sender.text ?? "")
    }
    
    // display login view content
    func showLoginStack() {
        if let lS = self.loginStack {
            lS.isHidden = false;
        }
    }
    func hideLoginStack() {
        if let lS = self.loginStack {
            lS.isHidden = true;
        }
    }
}

