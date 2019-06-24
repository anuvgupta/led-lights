//
//  LoginViewController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/15/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    
    // ib ui elements
    @IBOutlet weak var loginStack: UIStackView!
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            self.showLoginStack()
        })
        bridge.loginVC = self
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
}

