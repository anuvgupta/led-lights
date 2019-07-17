//
//  ColorsController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import HueKit
import Foundation

class ColorsController: UIViewController {

    // ib ui elements
    @IBOutlet weak var colorSquareView: ColorSquarePicker!
    @IBOutlet weak var colorBarView: ColorBarPicker!
    @IBOutlet weak var colorIndicatorView: UIView!
    @IBOutlet weak var colorHexLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var scrollContentView: UIView!
    @IBOutlet weak var liveTrackingSwitch: UISwitch!
    @IBOutlet weak var newPresetButton: UIButton!
    @IBOutlet weak var deletePresetButton: UIButton!
    @IBOutlet weak var pushPresetButton: UIButton!
    @IBOutlet weak var colorListToolbar: UIView!
    // code ui elements
    let rightBarButton: UIButton = UIButton()
    
    // ui globals
    var currentColorViewIndex = 0
    var colorViews: Dictionary<String, UIButton> = [:]
    var editingColor: String = ""
    var hexcolor: String = "#000000"
    var colorlock: Bool = false
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // lock while loading
        colorlock = true
        
        scrollContentView.frame = CGRect(x: scrollContentView.frame.minX, y: scrollContentView.frame.minY, width: scrollView.frame.width, height: scrollContentView.frame.height)
        
        liveTrackingSwitch.setOn(false, animated: false)
        scrollView.contentSize = scrollContentView.frame.size
        pushPresetButton.layer.cornerRadius = 10
        // colorIndicatorView.roundCorners(corners: [.topLeft, .topRight], radius: 8.0)
        colorIndicatorView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(colorIndicatorClicked)))
        
        let saved_livetrack = UserDefaults.standard.string(forKey: "livetracking") ?? "false"
        if saved_livetrack == "true" {
            liveTrackingSwitch.isOn = true
            liveTracking = true
        } else {
            liveTrackingSwitch.isOn = false
            liveTracking = false
        }
        
        if let image = UIImage(named: "edit_bl.png") {
            rightBarButton.isHidden = true
            rightBarButton.setImage(image, for: .normal)
            rightBarButton.setImage(image.alpha(0.55), for: .highlighted)
            rightBarButton.imageEdgeInsets = UIEdgeInsets(top: 12, left: 48, bottom: 12, right: 0)
            rightBarButton.addTarget(self, action: #selector(editBarButtonClicked), for: .primaryActionTriggered)
            let rightBarButtonItem: UIBarButtonItem = UIBarButtonItem(customView: rightBarButton)
            self.navigationItem.setRightBarButtonItems([ rightBarButtonItem ], animated: true)
        }
        
        let border1 = CALayer()
        border1.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border1.frame = CGRect(x: 0, y: colorListToolbar.frame.size.height - 1, width: colorListToolbar.frame.size.width, height: 1.0)
        border1.borderWidth = 1.0
        colorListToolbar.layer.addSublayer(border1)
        colorListToolbar.layer.masksToBounds = true
        
        bridge.colorsVC = self
        ws.requestColorPalette()
        
        // unlock after loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            self.colorlock = false
        })
    }
    
    // ib ui actions
    @IBAction func colorSquareChanged(_ sender: ColorSquarePicker) {
        if (!colorlock) {
            colorChange(sender.color, interval: true)
        }
    }
    @IBAction func colorBarChanged(_ sender: ColorBarPicker) {
        if (!colorlock) {
            colorSquareView.hue = sender.hue
            colorChange(colorSquareView.color, interval: true)
        }
    }
    @IBAction func colorSquareUp(_ sender: ColorSquarePicker) {
        if liveTracking {
            ws.testColor(interval: false)
        }
        if editingColor != "" {
            ws.updateColor(id: editingColor, interval: false)
        }
    }
    @IBAction func colorBarUp(_ sender: ColorBarPicker) {
        if liveTracking {
            ws.testColor(interval: false)
        }
        if editingColor != "" {
            ws.updateColor(id: editingColor, interval: false)
        }
    }
    @IBAction func pushButtonPressed(_ sender: UIButton) {
        ws.testColor(interval: false)
    }
    @IBAction func liveTrackValueChanged(_ sender: UISwitch) {
        liveTracking = sender.isOn
        UserDefaults.standard.set(String(liveTracking), forKey: "livetracking")
    }
    @IBAction func newPresetClicked(_ sender: UIButton) {
        ws.newPreset(red: r, green: g, blue: b)
    }
    @IBAction func deletePresetClicked(_ sender: UIButton) {
        if (editingColor != "") {
            ws.deletePreset(id: editingColor)
        }
    }
    @IBAction func signOutClicked(_ sender: UIButton) {
        ws.logout(callback: { () -> Void in
            self.performSegue(withIdentifier: "logoutSegue", sender: self)
        })
    }
    // code ui actions
    @objc func colorIndicatorClicked(gesture: UITapGestureRecognizer) {
        let alert = UIAlertController(title: "Edit Color", message: "Enter HEX color", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = self.hexcolor
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in
            bridge.currentAlertVC = nil
        })
        let colorAction = UIAlertAction(title: "Set", style: .default, handler: { a -> Void in
            if let textField = alert.textFields?[0] {
                if textField.text!.count > 0 {
                    let res: (UIColor, Bool) = colorFromString(textField.text ?? "")
                    if (res.1 == true) {
                        self.setColor(res.0)
                    }
                }
            }
            bridge.currentAlertVC = nil
        })
        alert.addAction(cancelAction)
        alert.addAction(colorAction)
        alert.preferredAction = colorAction
        bridge.currentAlertVC = alert
        self.present(alert, animated: true, completion: nil)
    }
    @objc func colorPresetLoad(_ sender: UIButton) {
        setColor(sender.backgroundColor ?? UIColor.black)
    }
    @objc func colorPresetEdit(_ sender: UIButton) {
        var key = ""
        for (id, preset) in colorViews {
            if (preset == sender) {
                key = id
            }
        }
        for (_, preset) in colorViews {
            preset.isSelected = false
        }
        if (editingColor == key) {
            ws.updateColor(id: editingColor, interval: false)
            editingColor = ""
            sender.isSelected = false
            deletePresetButton.isEnabled = false
            self.title = "Colors"
            rightBarButton.isHidden = true
        } else {
            editingColor = ""
            setColor(sender.backgroundColor ?? UIColor.black)
            editingColor = key
            sender.isSelected = true
            deletePresetButton.isEnabled = true
            if let buttonTitle = sender.title(for: .normal) {
                if buttonTitle != "" {
                    self.title = buttonTitle
                } else {
                    self.title = "untitled"
                }
            }
            rightBarButton.isHidden = false
        }
    }
    @objc func colorPresetTap(gesture: UITapGestureRecognizer) {
        let sender: UIButton = gesture.view as! UIButton
        colorPresetLoad(sender);
    }
    @objc func colorPresetLong(gesture: UILongPressGestureRecognizer) {
        let sender: UIButton = gesture.view as! UIButton
        if gesture.state == .began {
            colorPresetEdit(sender);
        }
    }
    @objc func editBarButtonClicked(_ sender: UIBarButtonItem) {
        if editingColor != "" {
            let alert = UIAlertController(title: "Rename Color", message: "Enter new color name", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.text = self.colorViews[self.editingColor]?.title(for: .normal) ?? ""
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in
                bridge.currentAlertVC = nil
            })
            let renameAction = UIAlertAction(title: "Rename", style: .default, handler: { a -> Void in
                if let textField = alert.textFields?[0] {
                    let res: String = textField.text ?? ""
                    if res.count > 0 {
                        ws.namePreset(id: self.editingColor, name: res)
                    }
                }
                bridge.currentAlertVC = nil
            })
            alert.addAction(cancelAction)
            alert.addAction(renameAction)
            alert.preferredAction = renameAction
            bridge.currentAlertVC = alert
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // update views with color change
    func colorChange(_ color: UIColor, interval: Bool) {
        loadColor(color: color)
        colorIndicatorView.backgroundColor = color
        colorHexLabel.text = color.hexString
        hexcolor = color.hexString
        if r > bwThreshold && g > bwThreshold && b > bwThreshold {
            colorHexLabel.textColor = UIColor.black
        } else {
            colorHexLabel.textColor = UIColor.white
        }
        if liveTracking {
            ws.testColor(interval: interval)
        }
        if editingColor != "" {
            ws.updateColor(id: editingColor, interval: interval)
        }
    }
    // set color picker color and update other views
    func setColor(_ color: UIColor, triggerColorChange: Bool = true) {
        colorlock = true
        let h = color.hsvValue?.h ?? 0.0
        let s = color.hsvValue?.s ?? 0.0
        let v = color.hsvValue?.v ?? 0.0
        colorBarView.hue = h
        colorSquareView.hue = h
        colorSquareView.value.x = s
        colorSquareView.value.y = v
        colorlock = false
        if triggerColorChange {
            colorChange(color, interval: false)
        }
    }
    // clear color preset list
    func clearColorPresets() {
        scrollContentView.subviews.forEach({ $0.removeFromSuperview() })
        currentColorViewIndex = 0
        colorViews = [:]
        editingColor = ""
        deletePresetButton.isEnabled = false
        self.title = "Colors"
    }
    // add color preset to list
    func addColorView(preset: ColorPreset) {
        let colorView = UIButton()
        let width: CGFloat = scrollContentView.frame.width / CGFloat(colorsPerRow)
        let height: CGFloat = width / colorsAspectRatio
        let x: CGFloat = CGFloat(currentColorViewIndex % colorsPerRow) * width
        let y: CGFloat = CGFloat(currentColorViewIndex / colorsPerRow) * height
        colorView.frame = CGRect(x: x, y: y, width: width, height: height)
        colorView.backgroundColor = getUIColor(red: preset.red, green: preset.green, blue: preset.blue)
        
        colorViews[preset.id] = colorView
        currentColorViewIndex += 1
        scrollContentView.addSubview(colorView)
        scrollContentView.frame.size.height = CGFloat(CGFloat(currentColorViewIndex / colorsPerRow + 1) * height)
        scrollView.contentSize = scrollContentView.frame.size
        updateColorViewDisplayColor(colorView, red: preset.red, green: preset.green, blue: preset.blue);
        colorView.setTitle(preset.name, for: .normal)
        colorView.setTitle("", for: .selected)
        //colorView.addTarget(self, action: #selector(colorPresetEdit), for: .touchUpInside)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(colorPresetTap))
        tapGesture.numberOfTapsRequired = 1
        colorView.addGestureRecognizer(tapGesture)
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(colorPresetLong))
        longGesture.numberOfTouchesRequired = 1
        longGesture.minimumPressDuration = 0.5
        colorView.addGestureRecognizer(longGesture)
    }
    // update color preset in list
    func updateColorView(preset: ColorPreset) {
        if let colorView = colorViews[preset.id] {
            let updatedColor = getUIColor(red: preset.red, green: preset.green, blue: preset.blue)
            colorView.backgroundColor = updatedColor
            updateColorViewDisplayColor(colorView, red: preset.red, green: preset.green, blue: preset.blue)
            // uncomment to sync up color editors
            //if editingColor == preset.id {
            //    editingColor = ""
            //    setColor(updatedColor)
            //    editingColor = preset.id
            //}
            colorView.setTitle(preset.name, for: .normal)
            if editingColor == preset.id {
                self.title = preset.name
            }
        }
    }
    // update color preset view's text/img color
    func updateColorViewDisplayColor(_ colorView: UIButton, red: Int, green: Int, blue: Int) {
        if (red > bwThreshold && green > bwThreshold && blue > bwThreshold) {
            colorView.setTitleColor(UIColor.black, for: .normal)
            if let image = UIImage(named: "edit_b.png") {
                colorView.setImage(image, for: .selected)
            }
        } else {
            colorView.setTitleColor(UIColor.white, for: .normal)
            if let image = UIImage(named: "edit_w.png") {
                colorView.setImage(image, for: .selected)
            }
        }
        if let image = UIImage(named: "clear.png") {
            colorView.setImage(image, for: .normal)
        }
        colorView.imageView?.contentMode = .scaleAspectFit
        colorView.imageEdgeInsets = UIEdgeInsets(top: 35, left: 0, bottom: 35, right: 0)
    }
    
}
