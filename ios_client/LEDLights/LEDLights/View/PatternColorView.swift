//
//  PatternColorView.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/24/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import PureLayout
import Foundation

class PatternColorView: UIView, UIGestureRecognizerDelegate {
    
    // instance data
    public var id: Int = 0
    public var data: PatternItem?
    public var draggable: Bool = false
    public var ordinalPosition: Int = 0
    let deleteButtonWidth: CGFloat = 90
    var shouldSetupConstraints: Bool = true
    // ui elements
    let mainView: UIView = UIView()
    var mainViewLeftConstraint: NSLayoutConstraint?
    var mainViewRightConstraint: NSLayoutConstraint?
    public let deleteView: UIButton = UIButton()
    public let handleButton: HandleButton = HandleButton()
    let fadeLabel: UIButton = UIButton()
    let colorView: UIButton = UIButton()
    let holdLabel: UIButton = UIButton()
    // swipe gestures
    var swipeLeftGesture: UISwipeGestureRecognizer? = nil
    var swipeRightGesture: UISwipeGestureRecognizer? = nil
    
    // init setup
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        deleteView.configureForAutoLayout()
        deleteView.contentHorizontalAlignment = .center
        deleteView.setTitle("Delete", for: .normal)
        deleteView.setTitleColor(UIColor.white, for: .normal)
        if let title = deleteView.titleLabel {
            title.font = title.font.withSize(16)
        }
        deleteView.setBackgroundColor(color: deleteRed, forState: .normal)
        deleteView.addTarget(self, action: #selector(removeClicked), for: .primaryActionTriggered)
        self.addSubview(deleteView)
        
        mainView.configureForAutoLayout()
        mainView.backgroundColor = UIColor.white
        self.addSubview(mainView)
        
        handleButton.configureForAutoLayout()
        if let image = UIImage(named: "handle_b.png") {
            handleButton.setImage(image.alpha(0.55), for: .normal)
        }
        handleButton.imageView?.contentMode = .scaleAspectFit
        // handleButton.addTarget(self, action: #selector(handleDown), for: .touchDown)
        // handleButton.addTarget(self, action: #selector(handleUp), for: .touchUpOutside)
        // handleButton.addTarget(self, action: #selector(handleUp), for: .touchUpInside)
        // handleButton.addTarget(self, action: #selector(handleDrag), for: .touchDragInside)
        handleButton.parentColorView = self
        mainView.addSubview(handleButton)
        
        fadeLabel.configureForAutoLayout()
        fadeLabel.setTitle("10000", for: .normal)
        fadeLabel.setTitleColor(UIColor.black, for: .normal)
        fadeLabel.titleLabel?.numberOfLines = 0
        fadeLabel.titleLabel?.textAlignment = .center
        if let label = fadeLabel.titleLabel {
            label.font = UIFont.systemFont(ofSize: 18, weight: .light)
        }
        fadeLabel.addTarget(self, action: #selector(fadeClicked), for: .primaryActionTriggered)
        mainView.addSubview(fadeLabel)
        
        colorView.configureForAutoLayout()
        colorView.layer.cornerRadius = 8.0
        colorView.clipsToBounds = true
        colorView.addTarget(self, action: #selector(colorClicked), for: .primaryActionTriggered)
        mainView.addSubview(colorView)
        
        holdLabel.configureForAutoLayout()
        holdLabel.setTitle("10000", for: .normal)
        holdLabel.setTitleColor(UIColor.black, for: .normal)
        holdLabel.titleLabel?.numberOfLines = 0
        holdLabel.titleLabel?.textAlignment = .center
        if let label = holdLabel.titleLabel {
            label.font = UIFont.systemFont(ofSize: 18, weight: .light)
        }
        holdLabel.addTarget(self, action: #selector(holdClicked), for: .primaryActionTriggered)
        mainView.addSubview(holdLabel)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    // constraints update
    override func updateConstraints() {
        if shouldSetupConstraints {
            mainView.autoMatch(.height, to: .height, of: self)
            mainView.autoPinEdge(.top, to: .top, of: self)
            mainView.autoPinEdge(.bottom, to: .bottom, of: self)
            mainViewLeftConstraint = mainView.autoPinEdge(.left, to: .left, of: self, withOffset: 0)
            mainViewRightConstraint = mainView.autoPinEdge(.right, to: .right, of: self, withOffset: 0)
            
            deleteView.autoMatch(.height, to: .height, of: self)
            deleteView.autoSetDimension(.width, toSize: deleteButtonWidth)
            deleteView.autoPinEdge(.top, to: .top, of: self)
            deleteView.autoPinEdge(.bottom, to: .bottom, of: self)
            deleteView.autoPinEdge(.left, to: .left, of: self)
            
            handleButton.autoSetDimension(.width, toSize: 80)
            handleButton.autoMatch(.height, to: .height, of: mainView)
            handleButton.autoPinEdge(.left, to: .left, of: mainView)
            handleButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 30)
            
            fadeLabel.autoSetDimension(.width, toSize: 80)
            fadeLabel.autoMatch(.height, to: .height, of: mainView)
            fadeLabel.autoPinEdge(.top, to: .top, of: mainView)
            fadeLabel.autoPinEdge(.left, to: .right, of: handleButton, withOffset: -5)
            
            holdLabel.autoSetDimension(.width, toSize: 80)
            holdLabel.autoMatch(.height, to: .height, of: mainView)
            holdLabel.autoPinEdge(.top, to: .top, of: mainView)
            holdLabel.autoPinEdge(.left, to: .right, of: fadeLabel)
            
            colorView.autoAlignAxis(.horizontal, toSameAxisOf: mainView)
            colorView.autoMatch(.height, to: .height, of: mainView, withMultiplier: 0.60)
            colorView.autoPinEdge(.left, to: .right, of: holdLabel, withOffset: 25)
            colorView.autoPinEdge(.right, to: .right, of: mainView, withOffset: -25)
            
            shouldSetupConstraints = false
        }
        super.updateConstraints()
    }
    
    // ui actions
    @objc func fadeClicked(_ sender: UIButton) {
        if let colordata = self.data {
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.presentFadeModal(colorID: self.id, colorData: colordata)
            }
        }
    }
    @objc func holdClicked(_ sender: UIButton) {
        if let colordata = self.data {
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.presentHoldModal(colorID: self.id, colorData: colordata)
            }
        }
    }
    @objc func colorClicked(_ sender: UIButton) {
        if let colordata = self.data {
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.presentColorPicker(colorID: self.id, colorData: colordata)
            }
        }
    }
    @objc func removeClicked(_ sender: UIButton) {
        if let patternEditVC = bridge.patternEditVC {
            patternEditVC.removeColor(colorID: id)
        }
    }
    // handle button targeted drag handler (unneccessary)
    // @objc func handleDrag(_ sender: UIButton) {
    //     print(String(id) + ": handle drag")
    // }
    // handle button targeted touchUp handler (unneccessary)
    // @objc func handleUp(_ sender: UIButton) {
    //     print(String(id) + ": handle up")
    //     mainView.backgroundColor = UIColor.white
    //     self.draggable = false
    // }
    // handle button targeted touchDown handler (for bgcolor & draggable)
    // @objc func handleDown(_ sender: UIButton) {
    //     print(String(id) + ": handle down")
    //     mainView.backgroundColor = UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1)
    //     self.draggable = true
    // }
    
    // load data
    func load(id: Int, data: PatternItem) {
        self.id = id
        self.data = data
        self.ordinalPosition = id
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
            fadeLabel.setTitle("fade\n" + String(colordata.fade), for: .normal)
            holdLabel.setTitle("hold\n" + String(colordata.hold), for: .normal)
        }
    }
    // change size
    func setFrame(frame: CGRect) {
        self.frame = frame
    }
    // set handle button touch handler
    func setTouchHandler(_ handler: @escaping (PatternColorView?, HandleEvent, CGPoint) -> Void) {
        self.handleButton.touchHandler = handler
    }
    // bgcolor setter
    func setBGColor(_ color: UIColor) {
        self.mainView.backgroundColor = color
    }
    // show/hide delete button
    func showDeleteView() {
        setMainViewLeftOffset(deleteButtonWidth)
    }
    func hideDeleteView() {
        setMainViewLeftOffset(0)
    }
    // shift main view
    private func setMainViewLeftOffset(_ left: CGFloat) {
        if let leftConstraint = mainViewLeftConstraint {
            if let rightConstraint = mainViewRightConstraint {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, animations: {
                    rightConstraint.constant = 0
                    leftConstraint.constant = left
                    self.mainView.layoutIfNeeded()
                })
            }
        }
    }
}
