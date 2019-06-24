//
//  PatternView.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/21/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class PatternView : UIButton {
    
    public var data: Pattern?
    
    func setup() {
        self.contentHorizontalAlignment = .left
        self.setTitleColor(UIColor.black, for: .normal)
        if let title = self.titleLabel {
            title.font = title.font.withSize(20)
        }
        self.titleEdgeInsets.left -= 20.0
        
        let border = CALayer()
        border.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - 1, width: self.frame.size.width, height: 1.0)
        border.borderWidth = 1.0
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
        
        if let image = UIImage(named: "next.png") {
            self.setImage(image.alpha(0.5), for: .normal)
        }
        self.imageEdgeInsets = UIEdgeInsets(top: 22.0, left: frame.size.width - 45, bottom: 22.0, right: 15);
        
        self.setBackgroundColor(color: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1), forState: .highlighted)
    }
    func load(data: Pattern) {
        self.data = data
        self.setTitle(data.name, for: .normal)
    }
    func setFrame(frame: CGRect) {
        self.frame = frame
    }
    func getID() -> String {
        if let d = self.data {
            return d.id
        }
        return ""
    }
    func getName() -> String {
        if let d = self.data {
            return d.name
        }
        return ""
    }
}
