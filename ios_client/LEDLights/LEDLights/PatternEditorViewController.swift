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
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    // ui globals
    var currentPatternColorViewIndex: Int = 0
    var patternColorViews: [PatternColorView] = []
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bridge.patternEditVC = self
        
        if let pattern = editingPattern {
            self.title = pattern.name
            ws.loadPattern(id: pattern.id)
        }
        scrollView.contentSize = contentView.frame.size
    }
    
    // ib ui actions
    @IBAction func editButtonClicked(_ sender: UIButton) {
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
    @IBAction func addButtonClicked(_ sender: UIButton) {
        if let currentpattern = editingPattern {
            ws.addPatternColor(id: currentpattern.id)
        }
    }
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
        for item in items {
            let patternColorView: PatternColorView = PatternColorView()
            let height: Int = 90
            let width: Int = Int(mainView.frame.width)
            patternColorView.setFrame(frame: CGRect(x: 0, y: currentPatternColorViewIndex * height, width: width, height: height))
            patternColorView.load(id: currentPatternColorViewIndex, data: item)
            patternColorView.setup()
            contentView.addSubview(patternColorView)
            patternColorViews.append(patternColorView)
            currentPatternColorViewIndex += 1
            contentView.frame.size.height = CGFloat((currentPatternColorViewIndex) * height)
            scrollView.contentSize = contentView.frame.size
        }
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
}
