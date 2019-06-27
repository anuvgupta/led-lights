//
//  PatternColorView.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/24/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation
import PureLayout

class PatternColorView : UIView {
    
    // instance data
    public var id: Int = 0
    public var data: PatternItem?
    var shouldSetupConstraints: Bool = true
    // ui elements
    let handleButton: UIButton = UIButton()
    let fadeLabel: UIButton = UIButton()
    let colorView: UIView = UIView()
    let holdLabel: UIButton = UIButton()
    let removeButton: UIButton = UIButton()
    
    // init setup
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        handleButton.configureForAutoLayout()
        handleButton.autoSetDimension(.width, toSize: 80)
        if let image = UIImage(named: "bars.png") {
            handleButton.setImage(image.alpha(0.6), for: .normal)
        }
        handleButton.addTarget(self, action: #selector(handleDown), for: .touchDown)
        handleButton.addTarget(self, action: #selector(handleUp), for: .touchUpOutside)
        handleButton.addTarget(self, action: #selector(handleUp), for: .touchUpInside)
        self.addSubview(handleButton)
        
        fadeLabel.configureForAutoLayout()
        fadeLabel.setTitle("10000", for: .normal)
        fadeLabel.setTitleColor(UIColor.black, for: .normal)
        if let label = fadeLabel.titleLabel {
            label.font = label.font.withSize(18)
        }
        self.addSubview(fadeLabel)
        fadeLabel.addTarget(self, action: #selector(fadeClicked), for: .primaryActionTriggered)
        
        colorView.configureForAutoLayout()
        colorView.layer.cornerRadius = 8.0
        colorView.clipsToBounds = true
        self.addSubview(colorView)
        
        holdLabel.configureForAutoLayout()
        holdLabel.setTitle("10000", for: .normal)
        holdLabel.setTitleColor(UIColor.black, for: .normal)
        if let label = holdLabel.titleLabel {
            label.font = label.font.withSize(18)
        }
        self.addSubview(holdLabel)
        holdLabel.addTarget(self, action: #selector(holdClicked), for: .primaryActionTriggered)
        
        removeButton.configureForAutoLayout()
        removeButton.autoSetDimension(.width, toSize: 80)
        if let image = UIImage(named: "x.png") {
            removeButton.setImage(image.alpha(0.6), for: .normal)
            removeButton.imageEdgeInsets = UIEdgeInsets(top: 33, left: 30, bottom: 33, right: 26)
        }
        removeButton.addTarget(self, action: #selector(removeClicked), for: .primaryActionTriggered)
        self.addSubview(removeButton)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    // constraints update
    override func updateConstraints() {
        if shouldSetupConstraints {
            
            handleButton.autoMatch(.height, to: .height, of: self)
            handleButton.autoPinEdge(.left, to: .left, of: self)
            
            fadeLabel.autoMatch(.height, to: .height, of: self)
            fadeLabel.autoPinEdge(.left, to: .right, of: handleButton, withOffset: -10)
            fadeLabel.autoPinEdge(.right, to: .left, of: colorView, withOffset: 1)
            fadeLabel.autoPinEdge(.top, to: .top, of: self)
            
            colorView.autoCenterInSuperview()
            colorView.autoMatch(.height, to: .height, of: self, withMultiplier: 0.7)
            colorView.autoMatch(.width, to: .width, of: self, withMultiplier: 0.2)
            
            holdLabel.autoMatch(.height, to: .height, of: self)
            holdLabel.autoPinEdge(.right, to: .left, of: removeButton, withOffset: 10)
            holdLabel.autoPinEdge(.left, to: .right, of: colorView, withOffset: 1)
            holdLabel.autoPinEdge(.top, to: .top, of: self)
            
            removeButton.autoMatch(.height, to: .height, of: self)
            removeButton.autoPinEdge(.right, to: .right, of: self)
            
            shouldSetupConstraints = false
        }
        super.updateConstraints()
    }
    
    // code ui actions
    @objc func handleUp(_ sender: UIButton) {
        print(String(id) + ": handle up")
    }
    @objc func handleDown(_ sender: UIButton) {
        print(String(id) + ": handle down")
    }
    @objc func fadeClicked(_ sender: UIButton) {
        if let colordata = self.data {
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.presentFadeModal(colorID: self.id, colorData: colordata)
            }
        }
    }
    @objc func holdClicked(gesture: UITapGestureRecognizer) {
        if let colordata = self.data {
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.presentHoldModal(colorID: self.id, colorData: colordata)
            }
        }
    }
    @objc func removeClicked(_ sender: UIButton) {
        if let patternEditVC = bridge.patternEditVC {
            patternEditVC.removeColor(colorID: id)
        }
    }
    
    // load data
    func load(id: Int, data: PatternItem) {
        self.id = id
        self.data = data
    }
    // post-init/post-load setup
    func setup() {
        let border = CALayer()
        border.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - 1, width: self.frame.size.width, height: 1.0)
        border.borderWidth = 1.0
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
        
        if let colordata = self.data {
            colorView.backgroundColor = getUIColor(red: colordata.red, green: colordata.green, blue: colordata.blue)
            fadeLabel.setTitle(String(colordata.fade), for: .normal)
            holdLabel.setTitle(String(colordata.hold), for: .normal)
        }
    }
    // change size
    func setFrame(frame: CGRect) {
        self.frame = frame
    }
}
