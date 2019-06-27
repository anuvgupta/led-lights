//
//  PatternsViewController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import PureLayout

class PatternsViewController: UIViewController {

    // ib ui elements
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    // code ui elements
    let addButtonView : UIButton = UIButton()
    
    // ui globals
    var currentPatternViewIndex: Int = 0
    var patternViews: Dictionary<String, PatternView> = [:]
    let patternHeight: Int = 70
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()

        if let image = UIImage(named: "plus2.png") {
            addButtonView.setImage(image.alpha(0.8), for: .normal)
            addButtonView.setImage(image.alpha(0.95), for: .highlighted)
        }
        addButtonView.setBackgroundColor(color: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1), forState: .highlighted)
        addButtonView.addTarget(self, action: #selector(newPatternClicked), for: .primaryActionTriggered)
        addButtonView.imageView?.contentMode = .scaleAspectFit
        addButtonView.imageEdgeInsets = UIEdgeInsets(top: 25, left: 0, bottom: 25, right: 0)

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
    @objc func newPatternClicked(_ sender: UIButton) {
        ws.newPattern()
    }
    @objc func patternSwiped(gesture: UISwipeGestureRecognizer) {
        let sender : PatternView = gesture.view as! PatternView
        switch gesture.direction {
            case .right:
                sender.showDeleteView()
                break
            default:
                break
        }
    }
    
    // clear pattern list
    func clearPatternList() {
        contentView.subviews.forEach({ $0.removeFromSuperview() })
        currentPatternViewIndex = 0
        patternViews = [:]
        contentView.addSubview(addButtonView)
        addButtonView.frame = CGRect(x: 0, y: 0, width: Int(mainView.frame.width), height: Int(Double(patternHeight) * 1.2))
        addBorderToAddButtonView()
    }
    // add pattern to list
    func addPattern(pattern: Pattern) {
        let patternView: PatternView = PatternView()
        let height: Int = patternHeight
        let width: Int = Int(mainView.frame.width)
        patternView.setFrame(frame: CGRect(x: 0, y: currentPatternViewIndex * height, width: width, height: height))
        patternView.load(data: pattern)
        patternView.setup()
        currentPatternViewIndex += 1
        patternView.addTarget(self, action: #selector(patternClicked), for: .primaryActionTriggered)
//        patternView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(colorIndicatorClicked)))
        patternView.addGestureRecognizer(UISwipeGestureRecognizer(target: self, action: #selector(patternSwiped)))
        contentView.addSubview(patternView)
        patternViews[pattern.id] = patternView
        addButtonView.frame = CGRect(x: 0, y: currentPatternViewIndex * height, width: Int(mainView.frame.width), height: Int(Double(patternHeight) * 1.2))
        addBorderToAddButtonView()
        // resize scroll area
        contentView.frame.size.height = CGFloat((currentPatternViewIndex + 1) * height)
        scrollView.contentSize = contentView.frame.size
    }
    // rename pattern in list
    func renamePattern(pattern: Pattern) {
        if let patternView = patternViews[pattern.id] {
            if let patternViewData = patternView.data {
                patternViewData.name = pattern.name
                patternView.load(data: patternViewData)
            }
        }
    }
    // add border to add button view
    func addBorderToAddButtonView() {
        let border = CALayer()
        border.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border.frame = CGRect(x: 0, y: addButtonView.frame.size.height - 1, width: addButtonView.frame.size.width, height: 1.0)
        border.borderWidth = 1.0
        addButtonView.layer.addSublayer(border)
        addButtonView.layer.masksToBounds = true
    }

}
