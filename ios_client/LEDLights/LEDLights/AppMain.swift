//
//  AppMain.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/17/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

// WebSocket client interface
let ws: WSWrapper = WSWrapper()
// WebSocket's bridge to UI Views
let bridge: WSVCBridge = WSVCBridge()

// global info/settings
let colorsPerRow: Int = 4
var liveTracking: Bool = false
var lastPassword: String = ""
// app color values
var r: Int = 0
var g: Int = 0
var b: Int = 0
// pattern editor data
var editingPattern: Pattern?
var currentItemType: String = ""
var currentItemData: String = ""

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
extension UIView {
    // add rounded corners to UIViews
    public func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
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
}
extension UIButton {
    func setBackgroundColor(color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.setBackgroundImage(colorImage, for: forState)
    }
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

// convenience functions
func msTimeStamp() -> Int {
    return Int((Date().timeIntervalSince1970 * 1000.0).rounded())
}
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

func rgbstring(r: Int, g: Int, b: Int) -> String {
    return lpad(string: String(r), width: 3, pString: "0") + lpad(string: String(g), width: 3, pString: "0") + lpad(string: String(b), width: 3, pString: "0")
}
func loadColor(color: UIColor) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    r = Int(red * 255)
    g = Int(green * 255)
    b = Int(blue * 255)
    print(r, g, b)
}
func getUIColor(red: Int, green: Int, blue: Int) -> UIColor {
    return UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1)
}
func colorFromString(_ s: String) -> (UIColor, Bool) {
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
