//
//  PatternEditorController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/21/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class PatternEditorController: UIViewController {
    
    // ib ui elements
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    // code ui elements
    let addButtonView : UIButton = UIButton()
    
    // ui globals
    var currentPatternColorViewIndex: Int = 0
    var patternColorViews: [PatternColorView] = []
    let patternColorHeight: Int = 90
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bridge.patternEditVC = self
        
        if let pattern = editingPattern {
            self.title = pattern.name
            ws.loadPattern(id: pattern.id)
        }
        
        if let image = UIImage(named: "edit_bl.png") {
            let rightBarButton: UIButton = UIButton()
            rightBarButton.setImage(image, for: .normal)
            rightBarButton.setImage(image.alpha(0.55), for: .highlighted)
            rightBarButton.imageEdgeInsets = UIEdgeInsets(top: 12, left: 48, bottom: 12, right: 0)
            rightBarButton.addTarget(self, action: #selector(editBarButtonClicked), for: .primaryActionTriggered)
            let rightBarButtonItem: UIBarButtonItem = UIBarButtonItem(customView: rightBarButton)
            self.navigationItem.setRightBarButtonItems([ rightBarButtonItem ], animated: true)
        }
        
        if let image = UIImage(named: "plus_bl.png") {
            addButtonView.setImage(image.alpha(0.8), for: .normal)
            addButtonView.setImage(image.alpha(0.95), for: .highlighted)
        }
        addButtonView.setBackgroundColor(color: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1), forState: .highlighted)
        addButtonView.addTarget(self, action: #selector(addButtonClicked), for: .primaryActionTriggered)
        addButtonView.imageView?.contentMode = .scaleAspectFit
        addButtonView.imageEdgeInsets = UIEdgeInsets(top: 30, left: 0, bottom: 30, right: 0)
        
        scrollView.contentSize = contentView.frame.size
    }
    
    // ib ui actions
    @IBAction func playButtonClicked(_ sender: UIButton) {
        if let currentpattern = editingPattern {
            ws.playPattern(id: currentpattern.id)
        }
    }
    @IBAction func deleteButtonClicked(_ sender: UIButton) {
        if let currentpattern = editingPattern {
            let alert = UIAlertController(title: "Delete Pattern", message: "Permanently delete " + currentpattern.name + "?", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in })
            let deleteAction = UIAlertAction(title: "Delete", style: .default, handler: { a -> Void in
                ws.deletePattern(id: currentpattern.id)
            })
            alert.addAction(cancelAction)
            alert.addAction(deleteAction)
            alert.preferredAction = cancelAction
            self.present(alert, animated: true, completion: nil)
        }
    }
    // code ui actions
    @objc func editBarButtonClicked(_ sender: UIBarButtonItem) {
        if let currentpattern = editingPattern {
            let alert = UIAlertController(title: "Rename Pattern", message: "Enter new pattern name", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.text = currentpattern.name
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in })
            let renameAction = UIAlertAction(title: "Rename", style: .default, handler: { a -> Void in
                if let textField = alert.textFields?[0] {
                    let res: String = textField.text ?? ""
                    if res.count > 0 {
                        ws.renamePattern(id: currentpattern.id, name: res)
                    }
                }
            })
            alert.addAction(cancelAction)
            alert.addAction(renameAction)
            alert.preferredAction = renameAction
            self.present(alert, animated: true, completion: nil)
        }
    }
    @objc func patternColorSwiped(gesture: UISwipeGestureRecognizer) {
        let sender : PatternColorView = gesture.view as! PatternColorView
        switch gesture.direction {
            case .right:
                for patternColorView : PatternColorView in patternColorViews {
                    patternColorView.hideDeleteView()
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
    @objc func addButtonClicked(_ sender: UIButton) {
        print("add")
        if let currentpattern = editingPattern {
            ws.addPatternColor(id: currentpattern.id)
        }
    }
    @objc func draggedView(gesture: UIPanGestureRecognizer) {
        let sender : PatternColorView = gesture.view as! PatternColorView
        if sender.draggable {
//            self.view.bringSubviewToFront(sender)
//            let translation = gesture.translation(in: self.view)
//            sender.center = CGPoint(x: sender.center.x + translation.x, y: sender.center.y + translation.y)
//            gesture.setTranslation(CGPoint.zero, in: self.view)
            let position = gesture.location(in: self.view)
            var y = position.y - scrollView.frame.minY
            if (y < 0) {
                y = 0
            }
            let maxHeight: CGFloat = CGFloat(currentPatternColorViewIndex * patternColorHeight)
            if y > maxHeight {
                y = maxHeight
            }
            let npos = Int(y / CGFloat(patternColorHeight))
            moveColor(colorView: sender, newPos: npos)
        } else {
//            gesture.ignore
            print("nodrag")
        }
    }
    
    // reload title
    func reloadTitle() {
        if let pattern = editingPattern {
            self.title = pattern.name
        }
    }
    // clear pattern color list
    func clearPatternColorList() {
        contentView.subviews.forEach({ $0.removeFromSuperview() })
        currentPatternColorViewIndex = 0
        patternColorViews = []
    }
    // refresh pattern color list
    func refresh(items: [PatternItem]) {
        self.clearPatternColorList()
        let height: Int = patternColorHeight
        let width: Int = Int(mainView.frame.width)
        for item in items {
            let patternColorView: PatternColorView = PatternColorView()
            patternColorView.setFrame(frame: CGRect(x: 0, y: currentPatternColorViewIndex * height, width: width, height: height))
            patternColorView.load(id: currentPatternColorViewIndex, data: item)
            patternColorView.setup()
            let swipeRightHandler = UISwipeGestureRecognizer(target: self, action: #selector(patternColorSwiped))
            swipeRightHandler.direction = .right
            swipeRightHandler.delegate = patternColorView
            patternColorView.swipeRightGesture = swipeRightHandler
            patternColorView.addGestureRecognizer(swipeRightHandler)
            let swipeLeftHandler = UISwipeGestureRecognizer(target: self, action: #selector(patternColorSwiped))
            swipeLeftHandler.direction = .left
            swipeLeftHandler.delegate = patternColorView
            patternColorView.swipeLeftGesture = swipeLeftHandler
            patternColorView.addGestureRecognizer(swipeLeftHandler)
            let panHandler = UIPanGestureRecognizer(target: self, action: #selector(draggedView))
            panHandler.delegate = patternColorView
            patternColorView.isUserInteractionEnabled = true
            patternColorView.panGesture = panHandler
            patternColorView.addGestureRecognizer(panHandler)
            contentView.addSubview(patternColorView)
            patternColorViews.append(patternColorView)
            currentPatternColorViewIndex += 1
            contentView.frame.size.height = CGFloat((currentPatternColorViewIndex) * height)
            scrollView.contentSize = contentView.frame.size
        }
        contentView.addSubview(addButtonView)
        let addButtonHeight = Int(Double(patternColorHeight - 15) * 1.2)
        addButtonView.frame = CGRect(x: 0, y: currentPatternColorViewIndex * height, width: Int(mainView.frame.width), height: addButtonHeight)
        contentView.frame.size.height += CGFloat(addButtonHeight)
        scrollView.contentSize = contentView.frame.size
        contentView.backgroundColor = UIColor.white
        scrollView.backgroundColor = UIColor.white
    }
    // go back to pattern list view
    func exit() {
        editingPattern = nil
        if let patternsNavVC = bridge.patternsNavVC {
            patternsNavVC.back()
        }
    }
    // display fade modal
    func presentFadeModal(colorID: Int, colorData: PatternItem) {
        if let currentpattern = editingPattern {
            let alert = UIAlertController(title: "Edit Fade", message: "Enter new fade time (ms)", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.text = String(colorData.fade)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in })
            let setAction = UIAlertAction(title: "Set", style: .default, handler: { a -> Void in
                if let textField = alert.textFields?[0] {
                    colorData.fade = Int(textField.text ?? "0") ?? 0
                    ws.updatePatternColor(id: currentpattern.id, colorID: colorID, colorData: colorData)
                }
            })
            alert.addAction(cancelAction)
            alert.addAction(setAction)
            alert.preferredAction = setAction
            self.present(alert, animated: true, completion: nil)
        }
    }
    // display hold modal
    func presentHoldModal(colorID: Int, colorData: PatternItem) {
        if let currentpattern = editingPattern {
            let alert = UIAlertController(title: "Edit Hold", message: "Enter new hold time (ms)", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.text = String(colorData.hold)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in })
            let setAction = UIAlertAction(title: "Set", style: .default, handler: { a -> Void in
                if let textField = alert.textFields?[0] {
                    colorData.hold = Int(textField.text ?? "0") ?? 0
                    ws.updatePatternColor(id: currentpattern.id, colorID: colorID, colorData: colorData)
                }
            })
            alert.addAction(cancelAction)
            alert.addAction(setAction)
            alert.preferredAction = setAction
            self.present(alert, animated: true, completion: nil)
        }
    }
    // remove pattern color
    func removeColor(colorID: Int) {
        if let currentpattern = editingPattern {
            ws.deletePatternColor(id: currentpattern.id, colorID: colorID)
        }
    }
    // swap two colors
    private func moveColor(colorView: PatternColorView, newPos: Int) {
        if (newPos >= 0 && newPos < currentPatternColorViewIndex) {
            if newPos * patternColorHeight != Int(colorView.frame.minY) {
                print(newPos)
                var colorViewToReplace: PatternColorView? = nil // patternColorViews[newPos]
                for pcv in patternColorViews {
                    if pcv.ordinalPosition == newPos {
                        colorViewToReplace = pcv
                    }
                }
                if let replaceView = colorViewToReplace {
                    let tempFrame: CGRect = replaceView.frame
                    replaceView.frame = colorView.frame
                    colorView.frame = tempFrame
                    replaceView.ordinalPosition = colorView.ordinalPosition
                    colorView.ordinalPosition = newPos
                }
            }
        }
    }
}
