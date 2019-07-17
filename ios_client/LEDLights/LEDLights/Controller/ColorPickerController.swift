//
//  ColorPickerController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 7/6/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class ColorPickerController: UIViewController {
    
    // ib ui elements
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var buttonWrapView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var prevColorView: UIView!
    @IBOutlet weak var newColorView: UIView!
    @IBOutlet weak var colorWrapView: UIView!
    
    // ui globals
    var currentColorViewIndex = 0
    var colorViews: Dictionary<String, UIButton> = [:]
    var patternColorID: Int = 0
    var patternColorData: PatternItem?
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let border1 = CALayer()
        border1.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8).cgColor
        border1.frame = CGRect(x: 0, y: 0, width: buttonWrapView.frame.size.width, height: 1.0)
        border1.borderWidth = 1.0
        buttonWrapView.layer.addSublayer(border1)
        buttonWrapView.layer.masksToBounds = true
        
        let border2 = CALayer()
        border2.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8).cgColor
        border2.frame = CGRect(x: cancelButton.frame.size.width, y: 0, width: 0.5, height: cancelButton.frame.size.height)
        border2.borderWidth = 0.5
        cancelButton.layer.addSublayer(border2)
        cancelButton.layer.masksToBounds = true
        
        let border3 = CALayer()
        border3.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8).cgColor
        border3.frame = CGRect(x: 0, y: 0, width: 1, height: selectButton.frame.size.height)
        border3.borderWidth = 1
        selectButton.layer.addSublayer(border3)
        selectButton.layer.masksToBounds = true
        
        let border4 = CALayer()
        border4.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8).cgColor
        border4.frame = CGRect(x: 0, y: 0, width: colorWrapView.frame.size.width, height: 1.0)
        border4.borderWidth = 1
        colorWrapView.layer.addSublayer(border4)
        colorWrapView.layer.masksToBounds = true
        
        if let pCD = patternColorData {
            let prevColor = UIColor(red: CGFloat(pCD.red) / 255.0, green: CGFloat(pCD.green) / 255.0, blue: CGFloat(pCD.blue) / 255.0, alpha: 1)
            print(prevColor.hexString)
            prevColorView.backgroundColor = prevColor
            prevColorView.roundCorners(corners: [.topLeft, .bottomLeft], radius: 10)
            newColorView.backgroundColor = prevColor
            newColorView.roundCorners(corners: [.topRight, .bottomRight], radius: 10)
        }
//        prevColorView.addBorder(borderColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75), borderWidth: 1, borderCornerRadius: 10)
//        newColorView.addBorder(borderColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75), borderWidth: 1, borderCornerRadius: 10)
        scrollView.contentSize = contentView.frame.size
        
        bridge.colorPickVC = self
        ws.requestColorPalette()
    }
    
    // ib ui actions
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
        self.exit()
    }
    @IBAction func selectButtonClicked(_ sender: UIButton) {
        if let currentPattern = editingPattern {
            if let colorData = patternColorData {
                if let newColor = newColorView.backgroundColor {
                    let rgb: (Int, Int, Int) = getRGB(color: newColor)
                    colorData.red = rgb.0
                    colorData.green = rgb.1
                    colorData.blue = rgb.2
                    ws.updatePatternColor(id: currentPattern.id, colorID: patternColorID, colorData: colorData)
                }
            }
        }
        self.exit()
    }
    // code ui actions
    @objc func colorPresetClicked(_ sender: UIButton) {
        let color: UIColor = sender.backgroundColor ?? UIColor.black
        newColorView.backgroundColor = color
    }
    
    // load color data into view
    func loadColor(colorID: Int, colorData: PatternItem?) {
        patternColorID = colorID
        patternColorData = colorData
        if let currentPattern = editingPattern {
            self.title = currentPattern.name + " – Edit Hue #" + String(patternColorID + 1)
        }
    }
    // clear color preset list
    func clearColorPresets() {
        contentView.subviews.forEach({ $0.removeFromSuperview() })
        currentColorViewIndex = 0
        colorViews = [:]
    }
    // add color preset to list
    func addColorView(preset: ColorPreset) {
        let colorView = UIButton()
        let width: CGFloat = contentView.frame.width / CGFloat(colorsPerRow)
        let height: CGFloat = width / colorsAspectRatio
        let x: CGFloat = CGFloat(currentColorViewIndex % colorsPerRow) * width
        let y: CGFloat = CGFloat(currentColorViewIndex / colorsPerRow) * height
        colorView.frame = CGRect(x: x, y: y, width: width, height: height)
        colorView.backgroundColor = getUIColor(red: preset.red, green: preset.green, blue: preset.blue)
        colorViews[preset.id] = colorView
        currentColorViewIndex += 1
        contentView.addSubview(colorView)
        contentView.frame.size.height = CGFloat(CGFloat(currentColorViewIndex / colorsPerRow + 1) * height)
        scrollView.contentSize = contentView.frame.size
        if (preset.red > bwThreshold && preset.green > bwThreshold && preset.blue > bwThreshold) {
            colorView.setTitleColor(UIColor.black, for: .normal)
        } else {
            colorView.setTitleColor(UIColor.white, for: .normal)
        }
        colorView.setTitle(preset.name, for: .normal)
        colorView.addTarget(self, action: #selector(colorPresetClicked), for: .touchUpInside)
    }
    // update color preset in list
    func updateColorView(preset: ColorPreset) {
        if let colorView = colorViews[preset.id] {
            let updatedColor = getUIColor(red: preset.red, green: preset.green, blue: preset.blue)
            colorView.backgroundColor = updatedColor
            updateColorViewDisplayColor(colorView, red: preset.red, green: preset.green, blue: preset.blue)
            colorView.setTitle(preset.name, for: .normal)
        }
    }
    // update color preset view's text/img color
    func updateColorViewDisplayColor(_ colorView: UIButton, red: Int, green: Int, blue: Int) {
        if (red > bwThreshold && green > bwThreshold && blue > bwThreshold) {
            colorView.setTitleColor(UIColor.black, for: .normal)
        } else {
            colorView.setTitleColor(UIColor.white, for: .normal)
        }
    }
    
    // go back to pattern edit view
    func exit() {
        self.dismiss(animated: true, completion: nil)
    }
}
