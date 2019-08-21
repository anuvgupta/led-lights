
//
//  DevicesController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 8/20/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class DevicesController: UIViewController {
    
    // ib ui elements
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var noneView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    // ui globals
    var deviceViewIndex: Int = 0
    var deviceViews: [String: DeviceView] = [:]
    let deviceViewHeight: Int = 100
    
    // ui view onload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.contentSize = contentView.frame.size
        
        bridge.devicesVC = self
        self.refresh()
    }
    
    // ib ui actions
    
    // code ui actions
    @objc func deviceSwiped(gesture: UISwipeGestureRecognizer) {
        let sender: DeviceView = gesture.view as! DeviceView
        switch gesture.direction {
            case .right:
                for (_, deviceView) in deviceViews {
                    deviceView.hideDeleteView()
                }
                sender.showDeleteView()
                break
            case .left:
                sender.hideDeleteView()
                break
            default:
                break
        }
    }
    // clear device lsit
    func clearDevices() {
        contentView.subviews.forEach({ $0.removeFromSuperview() })
        deviceViewIndex = 0
        deviceViews = [:]
    }
    // refresh from global list
    func refresh() {
        if deviceList.count < 1 {
            scrollView.isHidden = true
            noneView.isHidden = false
            clearDevices()
        } else {
            for (d_id, _) in deviceViews {
                if deviceViews[d_id] != nil && deviceList[d_id] == nil {
                    clearDevices()
                    break;
                }
            }
            for (d, _) in deviceList {
                if let deviceView = deviceViews[d] {
                    deviceView.load(data: deviceList[d]!)
                } else {
                    let height: Int = deviceViewHeight
                    let width: Int = Int(mainView.frame.width)
                    let deviceView: DeviceView = DeviceView()
                    deviceView.setFrame(frame: CGRect(x: 0, y: deviceViewIndex * height, width: width, height: height))
                    deviceView.load(data: deviceList[d]!)
                    deviceView.addBorder()
                    let swipeRightHandler = UISwipeGestureRecognizer(target: self, action: #selector(deviceSwiped))
                    swipeRightHandler.direction = .right
                    deviceView.swipeRightGesture = swipeRightHandler
                    deviceView.addGestureRecognizer(swipeRightHandler)
                    let swipeLeftHandler = UISwipeGestureRecognizer(target: self, action: #selector(deviceSwiped))
                    swipeLeftHandler.direction = .left
                    deviceView.swipeLeftGesture = swipeLeftHandler
                    deviceView.addGestureRecognizer(swipeLeftHandler)
                    deviceView.isUserInteractionEnabled = true
                    deviceView.isExclusiveTouch = true
                    contentView.addSubview(deviceView)
                    deviceViews[d] = deviceView
                    deviceViewIndex += 1
                    contentView.frame.size.height = CGFloat((deviceViewIndex) * height)
                    scrollView.contentSize = contentView.frame.size
                }
            }
            scrollView.contentSize = contentView.frame.size
            contentView.backgroundColor = UIColor.white
            scrollView.backgroundColor = UIColor.white
            noneView.isHidden = true
            scrollView.isHidden = false
        }
    }
    // remove device
    func removeDevice(_ id: String) {
        ws.removeDevice(d_id: id)
    }
    // select device
    func selectDevice(_ id: String) {
        if let controlsVC = bridge.controlsVC {
            for (_, v) in deviceViews {
                v.hideLiveLabel()
            }
            if let dV = deviceViews[id] {
                dV.showLiveLabel()
                controlsVC.selectDevice(id)
                exit()
            }
        }
    }
    // go back to control view
    func exit() {
        if let controlsNavVC = bridge.controlsNavVC {
            controlsNavVC.back()
        }
    }
}
