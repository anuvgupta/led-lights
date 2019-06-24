//
//  PatternsViewController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit

class PatternsViewController: UIViewController {

    // ib ui elements
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    // ui globals
    var currentPatternViewIndex: Int = 0
    var patternViews: Dictionary<String, PatternView> = [:]
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.contentSize = contentView.frame.size
        
        bridge.patternsVC = self
        ws.requestPatternList()
    }
    
    // ib ui actions
    @IBAction func signOutClicked(_ sender: UIButton) {
        ws.logout(callback: { () -> Void in
            self.performSegue(withIdentifier: "logoutSegue", sender: self)
        })
    }
    // code ui actions
    @objc func patternClicked(_ sender: PatternView) {
        if let data = sender.data {
            editingPattern = data
        }
        self.performSegue(withIdentifier: "editSegue", sender: self)
    }
    
    // clear pattern list
    func clearPatternList() {
        contentView.subviews.forEach({ $0.removeFromSuperview() })
        currentPatternViewIndex = 0
        patternViews = [:]
    }
    // add pattern to list
    func addPattern(pattern: Pattern) {
        let patternView: PatternView = PatternView()
        let height: Int = 70
        let width: Int = Int(mainView.frame.width)
        patternView.setFrame(frame: CGRect(x: 0, y: currentPatternViewIndex * height, width: width, height: height))
        patternView.load(data: pattern)
        patternView.setup()
        currentPatternViewIndex += 1
        patternView.addTarget(self, action: #selector(patternClicked), for: .primaryActionTriggered)
        contentView.addSubview(patternView)
        contentView.frame.size.height = CGFloat((currentPatternViewIndex) * height)
        scrollView.contentSize = contentView.frame.size
        patternViews[pattern.id] = patternView
    }

}
