//
//  DeviceView.swift
//  LEDLights
//
//  Created by Anuv Gupta on 8/20/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import PureLayout
import Foundation

class DeviceView: UIView {
    
    // instance data
    public var data: Device?
    let deleteButtonWidth: CGFloat = 90
    var shouldSetupConstraints: Bool = true
    // ui elements
    let mainView: UIView = UIView()
    var mainViewLeftConstraint: NSLayoutConstraint?
    var mainViewRightConstraint: NSLayoutConstraint?
    public let deleteView: UIButton = UIButton()
    let nameLabel: UILabel = UILabel()
    let timeLabel: UILabel = UILabel()
    let statusWrapView: UIView = UIView()
    let statusIndicatorView: UIView = UIView()
    public var liveLabel: UILabel = UILabel()
    // ui globals
    var statusTimer: Timer?
    var statusTimerOn: Bool = false
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
        mainView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mainViewClicked)))
        self.addSubview(mainView)
        
        statusWrapView.configureForAutoLayout()
        statusIndicatorView.configureForAutoLayout()
        statusIndicatorView.backgroundColor = UIColor.lightGray
        statusIndicatorView.layer.roundCorners(radius: 7.5)
        statusIndicatorView.layer.masksToBounds = true
        statusWrapView.addSubview(statusIndicatorView)
        mainView.addSubview(statusWrapView)
        
        nameLabel.configureForAutoLayout()
        nameLabel.text = "Device Name"
        nameLabel.textColor = UIColor.black
        nameLabel.font = UIFont.systemFont(ofSize: 24, weight: .light)
        mainView.addSubview(nameLabel)
        
        timeLabel.configureForAutoLayout()
        timeLabel.text = "Online Now"
        timeLabel.textColor = UIColor(red: 0.01, green: 0.01, blue: 0.1, alpha: 0.8)
        if let desc = UIFont.systemFont(ofSize: 14, weight: .thin).fontDescriptor.withSymbolicTraits(.traitItalic) {
            timeLabel.font = UIFont(descriptor: desc, size: 14)
        }
        mainView.addSubview(timeLabel)
        
        liveLabel.configureForAutoLayout()
        liveLabel.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.9)
        liveLabel.font = UIFont.systemFont(ofSize: 17, weight: .thin)
        hideLiveLabel()
        mainView.addSubview(liveLabel)
        
        enableTimer()
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
            
            statusWrapView.autoPinEdge(.left, to: .left, of: mainView, withOffset: 10)
            statusWrapView.autoPinEdge(.top, to: .top, of: mainView)
            statusWrapView.autoPinEdge(.bottom, to: .bottom, of: mainView)
            statusWrapView.autoSetDimension(.width, toSize: 80)
            statusIndicatorView.autoCenterInSuperview()
            statusIndicatorView.autoSetDimension(.width, toSize: 15)
            statusIndicatorView.autoSetDimension(.height, toSize: 15)
            
            liveLabel.autoPinEdge(.right, to: .right, of: mainView, withOffset: -25)
            liveLabel.autoAlignAxis(.horizontal, toSameAxisOf: mainView)
            liveLabel.autoSetDimension(.width, toSize: 40)
            
            nameLabel.autoPinEdge(.left, to: .right, of: statusWrapView)
            nameLabel.autoPinEdge(.right, to: .left, of: liveLabel)
            nameLabel.autoAlignAxis(.horizontal, toSameAxisOf: mainView, withOffset: -8)
            timeLabel.autoPinEdge(.left, to: .right, of: statusWrapView)
            timeLabel.autoPinEdge(.right, to: .left, of: liveLabel)
            timeLabel.autoAlignAxis(.horizontal, toSameAxisOf: mainView, withOffset: 14)
            
            shouldSetupConstraints = false
        }
        super.updateConstraints()
    }
    
    // ui actions
    @objc func removeClicked(_ sender: UIButton) {
        if let devicesVC = bridge.devicesVC {
            if let device = data {
                devicesVC.removeDevice(device.id)
            }
        }
    }
    // select this device on main view click
    @objc func mainViewClicked(gesture: UITapGestureRecognizer?) {
        if let devicesVC = bridge.devicesVC {
            if let device = data {
                devicesVC.selectDevice(device.id)
            }
        }
    }
    // timer tick
    @objc func statusTimerTick() {
        if let dD = data {
            if dD.lastEvent != "" && dD.lastTimestamp > 0 {
                if dD.lastEvent == "online" {
                    timeLabel.text = "Online Now"
                    statusIndicatorView.backgroundColor = statusGreen
                } else {
                    var prefix: String = ""
                    if dD.lastEvent == "disconnected" {
                        prefix = "Offline"
                        statusIndicatorView.backgroundColor = deleteRed
                    } else if dD.lastEvent == "connected" {
                        prefix =  "Syncing"
                        statusIndicatorView.backgroundColor = buttonBlue
                    } else if dD.lastEvent == "authenticated" {
                        prefix =  "Syncing"
                        statusIndicatorView.backgroundColor = buttonBlue
                    } else if dD.lastEvent == "online" {
                        prefix = "Online"
                        statusIndicatorView.backgroundColor = statusGreen
                    } else if dD.lastEvent == "loading" {
                        prefix =  "Loading"
                        statusIndicatorView.backgroundColor = UIColor.lightGray
                    }
                    timeLabel.text = prefix + " " + durationDesc(lastTimestamp: dD.lastTimestamp)
                }
            }
        }
    }
    
    // load data
    func load(data: Device) {
        self.data = data
        nameLabel.text = data.name
        statusTimerTick()
        if let dD = deviceData {
            if data.id == dD.id {
                showLiveLabel()
            }
        }
    }
    // add border
    func addBorder() {
        let border = CALayer()
        border.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - 1, width: self.frame.size.width, height: 1.0)
        border.borderWidth = 1.0
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
    }
    // change size
    func setFrame(frame: CGRect) {
        self.frame = frame
    }
    // bgcolor setter
    func setBGColor(_ color: UIColor) {
        self.mainView.backgroundColor = color
    }
    // show/hide live label
    func showLiveLabel() {
        liveLabel.text = "LIVE"
    }
    func hideLiveLabel() {
        liveLabel.text = " "
    }
    // enable new timer
    func enableTimer() {
        if statusTimerOn {
            disableTimer()
        }
        if !statusTimerOn {
            statusTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(statusTimerTick), userInfo: nil, repeats: true)
            statusTimerOn = true
        }
    }
    // disable timer
    func disableTimer() {
        if let timer = self.statusTimer {
            timer.invalidate()
            statusTimerOn = false
        }
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
