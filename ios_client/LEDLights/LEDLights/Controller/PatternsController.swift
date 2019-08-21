//
//  PatternsController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import PureLayout
import Foundation

class PatternsController: UIViewController {

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

        if let image = UIImage(named: "plus_bl.png") {
            addButtonView.setImage(image.alpha(0.9), for: .normal)
            addButtonView.setImage(image.alpha(1.0), for: .highlighted)
        }
        addButtonView.setBackgroundColor(color: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1), forState: .highlighted)
        addButtonView.addTarget(self, action: #selector(newPatternClicked), for: .primaryActionTriggered)
        addButtonView.imageView?.contentMode = .scaleAspectFit
        addButtonView.imageEdgeInsets = UIEdgeInsets(top: 27, left: 0, bottom: 27, right: 0)

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
    @objc func patternClicked(_ sender: UIButton) {
        let senderPatternView : PatternView = sender.superview as! PatternView
        if let data = senderPatternView.data {
            editingPattern = data
            senderPatternView.hideDeleteView()
            self.performSegue(withIdentifier: "editSegue", sender: self)
        }
    }
    @objc func patternDeleteClicked(_ sender: UIButton) {
        let senderPatternView : PatternView = sender.superview as! PatternView
        if let data = senderPatternView.data {
            let alert = UIAlertController(title: "Delete Pattern", message: "Permanently delete " + data.name + "?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in
                senderPatternView.hideDeleteView()
                bridge.currentAlertVC = nil
            })
            let deleteAction = UIAlertAction(title: "Delete", style: .default, handler: { a -> Void in
                senderPatternView.buttonView.setBackgroundColor(color: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1), forState: .normal)
                senderPatternView.hideDeleteView()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    ws.deletePattern(id: data.id)
                })
                bridge.currentAlertVC = nil
            })
            alert.addAction(cancelAction)
            alert.addAction(deleteAction)
            alert.preferredAction = cancelAction
            bridge.currentAlertVC = alert
            self.present(alert, animated: true, completion:  nil)
        }
    }
    @objc func newPatternClicked(_ sender: UIButton) {
        ws.newPattern()
    }
    @objc func patternSwiped(gesture: UISwipeGestureRecognizer) {
        let sender : PatternView = gesture.view as! PatternView
        switch gesture.direction {
            case .right:
                for (_, patternview) : (String, PatternView) in patternViews {
                    patternview.hideDeleteView()
                }
                sender.showDeleteView()
                break
            case .left:
                sender.hideDeleteView()
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
        let height: Int = patternHeight
        let width: Int = Int(mainView.frame.width)
        let patternView: PatternView = PatternView(frame: CGRect(x: 0, y: currentPatternViewIndex * height, width: width, height: height))
        patternView.load(data: pattern)
        patternView.addBorder()
        currentPatternViewIndex += 1
        patternView.buttonView.addTarget(self, action: #selector(patternClicked), for: .primaryActionTriggered)
        patternView.deleteView.addTarget(self, action: #selector(patternDeleteClicked), for: .primaryActionTriggered)
        let swipeRightHandler = UISwipeGestureRecognizer(target: self, action: #selector(patternSwiped))
        swipeRightHandler.direction = .right
        patternView.addGestureRecognizer(swipeRightHandler)
        let swipeLeftHandler = UISwipeGestureRecognizer(target: self, action: #selector(patternSwiped))
        swipeLeftHandler.direction = .left
        patternView.addGestureRecognizer(swipeLeftHandler)
        contentView.addSubview(patternView)
        patternViews[pattern.id] = patternView
        let addButtonViewHeight: Int = Int(Double(patternHeight) * 1.2)
        addButtonView.frame = CGRect(x: 0, y: currentPatternViewIndex * height, width: Int(mainView.frame.width), height: addButtonViewHeight)
        addBorderToAddButtonView()
        // resize scroll area
        contentView.frame.size.height = CGFloat((currentPatternViewIndex * height) + addButtonViewHeight)
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
        // disabled for aesthetics
        // addButtonView.layer.addSublayer(border)
        // addButtonView.layer.masksToBounds = true
    }

}

class PatternsNavController : UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.patternsNavVC = self
    }
    func back(animated: Bool = true) {
        self.popViewController(animated: animated)
    }
}
