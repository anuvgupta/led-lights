//
//  AppMain.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/17/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

// global application
let application = UIApplication.shared
// global bridge to ViewControllers for WebSocket interface
let bridge: WSVCBridge = WSVCBridge()
// WebSocket client interface
//let serverURL: String = "ws://10.0.1.40:30003"
let serverURL: String = "ws://leds.anuv.me:3003"
let ws: WSWrapper = WSWrapper()

// global info/settings
let colorsPerRow: Int = 3 // # color presets per row
let colorsAspectRatio: CGFloat = 1.75 // width-height aspect ratio
let bwThreshold: Int = 200 // foreground color contrast threshold
var trackLeft: Bool = false // live tracking left
var trackRight: Bool = false // live tracking right
var lastPassword: String = "" // saved password
// color editor data
var r: Int = 0
var g: Int = 0
var b: Int = 0
// pattern editor data
var editingPattern: Pattern? // currently editing pattern
// device data
var deviceData: Device? = nil
var deviceList: [String: Device] = [:]
// currently playing data
var currentItemType: String = "" // currently playing type (pattern/hue/music)
var currentItemPData: (String, String)? = nil // if pattern currently playing, pattern ID/name
var currentItemCData: ((Int, Int, Int), (Int, Int, Int))? = nil // if color currently playing, color RGB
var musicEnabled: Bool = false

// extensions
extension UIColor {
    // convert UIColor to hex string
    public var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
extension UIImage {
    // add alpha option setting to UIImage
    func alpha(_ value:CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: CGPoint.zero, blendMode: .normal, alpha: value)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    // https://stackoverflow.com/questions/28517866/how-to-set-the-alpha-of-an-uiimage-in-swift-programmatically
}
extension UIButton {
    // add background color to UIButton
    func setBackgroundColor(color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.setBackgroundImage(colorImage, for: forState)
    }
    // https://stackoverflow.com/questions/38562379/uibutton-background-color-for-highlighted-selected-state-issue/38566083
}
extension String {
    // get String substrings using index API
    public func substring(_ start: Int, len: Int) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: start);
        let endIndex = self.index(self.startIndex, offsetBy: start + len);
        return String(self[startIndex ..< endIndex])
    }
    public func substring(_ start: Int) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: start);
        let endIndex = self.index(self.startIndex, offsetBy: self.count);
        return String(self[startIndex ..< endIndex])
    }
}
extension UIView {
    // add full borders to UIViews
    public func addBorder(borderColor: UIColor, borderWidth: CGFloat, borderCornerRadius: CGFloat){
        self.layer.borderWidth = borderWidth
        self.layer.borderColor = borderColor.cgColor
        self.layer.cornerRadius = borderCornerRadius
    }
    // add rounded corners to UIViews
    public func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }
    // https://stackoverflow.com/questions/37163850/round-top-corners-of-a-uibutton-in-swift
}
extension CALayer {
    // add shadows and rounded corners to layer
    private func addShadowWithRoundedCorners() {
        if let contents = self.contents {
            masksToBounds = false
            sublayers?.filter{ $0.frame.equalTo(self.bounds) }
                .forEach{ $0.roundCorners(radius: self.cornerRadius) }
            self.contents = nil
            if let sublayer = sublayers?.first, sublayer.name == "contentLayer" {
                sublayer.removeFromSuperlayer()
            }
            let contentLayer = CALayer()
            contentLayer.name = "contentLayer"
            contentLayer.contents = contents
            contentLayer.frame = bounds
            contentLayer.cornerRadius = cornerRadius
            contentLayer.masksToBounds = true
            insertSublayer(contentLayer, at: 0)
        }
    }
    func addShadow(radius: CGFloat, opacity: Float, offset: CGSize, color: UIColor) {
        self.shadowOffset = offset
        self.shadowOpacity = opacity
        self.shadowRadius = radius
        self.shadowColor = color.cgColor
        self.masksToBounds = false
        if cornerRadius != 0 {
            addShadowWithRoundedCorners()
        }
    }
    func roundCorners(radius: CGFloat) {
        self.cornerRadius = radius
        if shadowOpacity != 0 {
            addShadowWithRoundedCorners()
        }
    }
    // (https://medium.com/swifty-tim/views-with-rounded-corners-and-shadows-c3adc0085182)
}
extension UIViewController {
    //  get topmost ViewController
    func topMostViewController() -> UIViewController {
        if self.presentedViewController == nil {
            return self
        }
        if let navigation = self.presentedViewController as? UINavigationController {
            if let visibleVC = navigation.visibleViewController {
                return visibleVC.topMostViewController()
            }
        }
        if let tab = self.presentedViewController as? UITabBarController {
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            return tab.topMostViewController()
        }
        return self.presentedViewController!.topMostViewController()
    }
    // https://gist.github.com/db0company/369bfa43cb84b145dfd8
}
extension UIApplication {
    // get current ViewController
    func topMostViewController() -> UIViewController? {
        return self.keyWindow?.rootViewController?.topMostViewController()
    }
    // https://gist.github.com/db0company/369bfa43cb84b145dfd8
}
final class ControlContainableScrollView: UIScrollView {
    // custom scroll class
    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl && !(view is UITextInput) && !(view is UISlider) && !(view is UISwitch) {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }
    // (https://www.rightpoint.com/rplabs/fixing-controls-and-scrolling-button-views-ios)
}

// convenience functions
func msTimeStamp() -> Int {
    return Int((Date().timeIntervalSince1970 * 1000.0).rounded())
}
// pad string on left
func lpad(string: String, width: Int, pString: String?) -> String {
    let paddingString = pString ?? ""
    if string.count >= width {
        return string
    }
    let remainingLength: Int = width - string.count
    var padString = String()
    for _ in 0 ..< remainingLength {
        padString += paddingString
    }
    return [padString, string].joined(separator: "")
    
}
// convert rgb to formatted string
func rgbstring(r: Int, g: Int, b: Int) -> String {
    return lpad(string: String(r), width: 3, pString: "0") + lpad(string: String(g), width: 3, pString: "0") + lpad(string: String(b), width: 3, pString: "0")
}
// get duration description from timestamp
func durationDesc(lastTimestamp: Int) -> String {
    if lastTimestamp == 0 {
        return ""
    }
    var deltaSec: Int = Int(NSDate().timeIntervalSince1970) - Int(lastTimestamp / 1000)
    if deltaSec < 0 {
        deltaSec = 0
    }
    var outputString: String = "";
    if deltaSec < 5 {
        outputString += "now"
    } else if deltaSec < 60 {
        outputString += String(Int(round(Double(deltaSec) / 5.0) * 5.0)) + " seconds ago"
    } else if deltaSec < 3600 {
        let mins: Int = Int(deltaSec / 60)
        if mins == 1 {
            outputString += String(mins) + " minute ago"
        } else {
            outputString += String(mins) + " minutes ago"
        }
    } else {
        let hrs: Int = Int(deltaSec / 3600)
        if hrs == 1 {
            outputString += String(hrs) + " hour ago"
        } else {
            outputString += String(hrs) + " hours ago"
        }
    }
    return outputString
}
// dismiss all alerts
func dismissAlerts(callback: (() -> Void)? = nil) {
    if let currentAlertVC = bridge.currentAlertVC {
        currentAlertVC.dismiss(animated: true, completion: callback)
        bridge.currentAlertVC = nil
    } else {
        if let completion = callback {
            completion()
        }
    }
}
// load UIColor RGB values into app color
func loadColor(color: UIColor) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    r = Int(red * 255)
    g = Int(green * 255)
    b = Int(blue * 255)
}
// create UIColor from RGB values
func getUIColor(red: Int, green: Int, blue: Int) -> UIColor {
    return UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
}
// load UIColor RGB values into app color
func getRGB(color: UIColor) -> (Int, Int, Int) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (Int(red * 255), Int(green * 255), Int(blue * 255))
}
// parse UIColor from HEX string
func colorFromString(_ s: String) -> (UIColor, Bool) { // color, success
    var hex: String = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    if (hex.substring(0, len: 1) == "#") {
        hex = hex.substring(1)
    }
    if (hex.count != 6) {
        return (UIColor.gray, false)
    }
    var rgb : [UInt32] = [0, 0, 0]
    Scanner(string: hex.substring(0, len: 2)).scanHexInt32(&rgb[0])
    Scanner(string: hex.substring(2, len: 2)).scanHexInt32(&rgb[1])
    Scanner(string: hex.substring(4, len: 2)).scanHexInt32(&rgb[2])
    return (UIColor(red: CGFloat(Float(rgb[0]) / 255.0), green: CGFloat(Float(rgb[1]) / 255.0), blue: CGFloat(Float(rgb[2]) / 255.0), alpha: CGFloat(1)), true)
}

// global colors
let deleteRed: UIColor = getUIColor(red: 237, green: 69, blue: 61)
let buttonBlue: UIColor = getUIColor(red: 40, green: 124, blue: 246)
let statusGreen: UIColor = getUIColor(red: 85, green: 196, blue: 110)
