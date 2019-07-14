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
    
    // ui globals
    var currentColorViewIndex = 0
    var colorViews: Dictionary<String, UIButton> = [:]
    public var editingColor: String = ""
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
    @objc func colorPresetClicked(_ sender: UIButton) {
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
        } else {
            editingColor = ""
            setColor(sender.backgroundColor ?? UIColor.black)
            editingColor = key
            if (r > 220 && g > 220 && b > 220) {
                sender.setTitleColor(UIColor.black, for: .selected)
                if let image = UIImage(named: "edit_b.png") {
                    sender.setImage(image, for: .selected)
                }
            } else {
                sender.setTitleColor(UIColor.white, for: .selected)
                if let image = UIImage(named: "edit_w.png") {
                    sender.setImage(image, for: .selected)
                }
            }
            sender.imageView?.contentMode = .scaleAspectFit
            sender.imageEdgeInsets = UIEdgeInsets(top: 35, left: 0, bottom: 35, right: 0)
            sender.isSelected = true
            deletePresetButton.isEnabled = true
        }
    }
    
    // update views with color change
    func colorChange(_ color: UIColor, interval: Bool) {
        loadColor(color: color)
        colorIndicatorView.backgroundColor = color
        colorHexLabel.text = color.hexString
        hexcolor = color.hexString
        if r > 220 && g > 220 && b > 220 {
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
    func setColor(_ color: UIColor) {
        colorlock = true
        let h = color.hsvValue?.h ?? 0.0
        let s = color.hsvValue?.s ?? 0.0
        let v = color.hsvValue?.v ?? 0.0
        colorBarView.hue = h
        colorSquareView.hue = h
        colorSquareView.value.x = s
        colorSquareView.value.y = v
        colorlock = false
        colorChange(color, interval: false)
    }
    // clear color preset list
    func clearColorPresets() {
        scrollContentView.subviews.forEach({ $0.removeFromSuperview() })
        currentColorViewIndex = 0
        colorViews = [:]
        editingColor = ""
        deletePresetButton.isEnabled = false
    }
    // add color preset to list
    func addColorView(preset: ColorPreset) {
        let colorView = UIButton()
        let width: CGFloat = scrollContentView.frame.width / CGFloat(colorsPerRow)
        let x: CGFloat = CGFloat(currentColorViewIndex % colorsPerRow) * width
        let y: CGFloat = CGFloat(currentColorViewIndex / colorsPerRow) * width
        colorView.frame = CGRect(x: x, y: y, width: width, height: width)
        colorView.backgroundColor = getUIColor(red: preset.red, green: preset.green, blue: preset.blue)
        
        colorViews[preset.id] = colorView
        currentColorViewIndex += 1
        scrollContentView.addSubview(colorView)
        scrollContentView.frame.size.height = CGFloat(CGFloat(currentColorViewIndex / colorsPerRow + 1) * width)
        scrollView.contentSize = scrollContentView.frame.size
        if (preset.red > 220 && preset.green > 220 && preset.blue > 220) {
            colorView.setTitleColor(UIColor.black, for: .selected)
            if let image = UIImage(named: "edit_b.png") {
                colorView.setImage(image, for: .selected)
            }
        } else {
            colorView.setTitleColor(UIColor.white, for: .selected)
            if let image = UIImage(named: "edit_w.png") {
                colorView.setImage(image, for: .selected)
            }
        }
        if let image = UIImage(named: "clear.png") {
            colorView.setImage(image, for: .normal)
        }
        colorView.imageView?.contentMode = .scaleAspectFit
        colorView.imageEdgeInsets = UIEdgeInsets(top: 35, left: 0, bottom: 35, right: 0)
        // colorView.setTitle(preset.id, for: .normal)
        colorView.addTarget(self, action: #selector(colorPresetClicked), for: .touchUpInside)
    }
    // update color preset in list
    func updateColorView(preset: ColorPreset) {
        colorViews[preset.id]?.backgroundColor = getUIColor(red: preset.red, green: preset.green, blue: preset.blue)
    }
    
}
