//
//  ControlsController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class ControlsController: UIViewController {

    // ib ui elements
    @IBOutlet weak var arduinoStatusWrap: UIView!
    @IBOutlet weak var deviceSelector: UIView!
    @IBOutlet weak var deviceListLabel: UILabel!
    @IBOutlet weak var statusIndicatorView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var deviceSelectorArrowButton: UIButton!
    @IBOutlet weak var editDeviceNameButton: UIButton!
    @IBOutlet weak var currentPlayingWrap: UIView!
    @IBOutlet weak var currentlyPlayingLabel: UILabel!
    @IBOutlet weak var hueIndicatorViewL: UIView!
    @IBOutlet weak var hueIndicatorViewR: UIView!
    @IBOutlet weak var patternNameLabel: UILabel!
    @IBOutlet weak var brightSliderWrap: UIView!
    @IBOutlet weak var brightSlider: UISlider!
    @IBOutlet weak var brightLabel: UILabel!
    @IBOutlet weak var speedSliderWrap: UIView!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var speedLabel: UILabel!
    // ui globals
    var brightness: Int = 100
    var brightlock: Bool = false
    var speed: Int = 100
    var speedlock: Bool = false
    var statusTimer: Timer?
    var statusTimerOn: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let border1 = CALayer()
        border1.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border1.frame = CGRect(x: 0, y: arduinoStatusWrap.frame.size.height - 1, width: arduinoStatusWrap.frame.size.width, height: 1.0)
        border1.borderWidth = 1.0
        arduinoStatusWrap.layer.addSublayer(border1)
        arduinoStatusWrap.layer.masksToBounds = true
        statusIndicatorView.layer.roundCorners(radius: statusIndicatorView.frame.height / 2)
        statusIndicatorView.layer.masksToBounds = true
        deviceSelector.backgroundColor = UIColor.white
        deviceSelector.addBorder(borderColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), borderWidth: 1.0, borderCornerRadius: 8.0)
        // uncomment to flip arrow image
        // if let img = deviceSelectorArrowButton.image(for: .normal) {
        //     deviceSelectorArrowButton.setImage(img.withHorizontallyFlippedOrientation(), for: .normal)
        // }
        if let tL = timeLabel {
            if let desc = UIFont.systemFont(ofSize: 13, weight: .thin).fontDescriptor.withSymbolicTraits(.traitItalic) {
                tL.font = UIFont(descriptor: desc, size: 13)
            }
        }
        deviceSelector.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(deviceSelectorClicked)))
        
        
        let border2 = CALayer()
        border2.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border2.frame = CGRect(x: 0, y: currentPlayingWrap.frame.size.height - 1, width: currentPlayingWrap.frame.size.width, height: 1.0)
        border2.borderWidth = 1.0
        currentPlayingWrap.layer.addSublayer(border2)
        currentPlayingWrap.layer.masksToBounds = true
        hueIndicatorViewL.addBorder(borderColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75), borderWidth: 1, borderCornerRadius: 0)
        hueIndicatorViewL.roundCorners(corners: [.topLeft, .bottomLeft], radius: 8)
        hueIndicatorViewL.layer.masksToBounds = true
        hueIndicatorViewL.isHidden = true
        hueIndicatorViewR.addBorder(borderColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75), borderWidth: 1, borderCornerRadius: 0)
        hueIndicatorViewR.roundCorners(corners: [.topRight, .bottomRight], radius: 8)
        hueIndicatorViewR.layer.masksToBounds = true
        hueIndicatorViewR.isHidden = true
        patternNameLabel.isHidden = true
        
        if let label = currentlyPlayingLabel {
            if let desc = UIFont.systemFont(ofSize: 19, weight: .light).fontDescriptor.withSymbolicTraits(.traitItalic) {
                label.font = UIFont(descriptor: desc, size: 19)
            }
        }
        
        let border3 = CALayer()
        border3.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border3.frame = CGRect(x: 0, y: brightSliderWrap.frame.size.height - 1, width: brightSliderWrap.frame.size.width, height: 1.0)
        border3.borderWidth = 1.0
        brightSliderWrap.layer.addSublayer(border3)
        brightSliderWrap.layer.masksToBounds = true
        
        let border4 = CALayer()
        border4.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border4.frame = CGRect(x: 0, y: speedSliderWrap.frame.size.height - 1, width: speedSliderWrap.frame.size.width, height: 1.0)
        border4.borderWidth = 1.0
        speedSliderWrap.layer.addSublayer(border4)
        speedSliderWrap.layer.masksToBounds = true

        bridge.controlsVC = self
        selectDevice(nil, save: false)
        enableTimer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            self.selectDevice(UserDefaults.standard.string(forKey: "last_device") ?? "")
        })
    }
    
    // ib ui actions
    @IBAction func signOutClicked(_ sender: UIButton) {
        ws.logout(callback: { () -> Void in
            self.performSegue(withIdentifier: "logoutSegue", sender: self)
        })
    }
    @IBAction func brightSliderChanged(_ sender: UISlider) {
        if !brightlock {
            brightness = Int(sender.value)
            brightLabel.text = String(brightness)
            ws.setBrightness(brightness, interval: true)
        }
    }
    @IBAction func brightSliderUp(_ sender: UISlider) {
        if !brightlock {
            brightness = Int(sender.value)
            brightLabel.text = String(brightness)
            ws.setBrightness(brightness, interval: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.075, execute: {
                ws.playCurrent()
            })
        }
    }
    @IBAction func speedSliderChanged(_ sender: UISlider) {
        if !speedlock {
            speed = Int(round(sender.value / 5.0) * 5.0)
            sender.value = Float(speed)
            speedLabel.text = String(speed)
            ws.setSpeed(speed, interval: true)
        }
    }
    @IBAction func speedSliderUp(_ sender: UISlider) {
        if !speedlock {
            speed = Int(round(sender.value / 5.0) * 5.0)
            sender.value = Float(speed)
            speedLabel.text = String(speed)
            ws.setSpeed(speed, interval: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.075, execute: {
                ws.playCurrent()
            })
        }
    }
    @IBAction func editDeviceNameClicked(_ sender: UIButton) {
        if let dD = deviceData {
            let alert = UIAlertController(title: "Name Device", message: "Enter new device name", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.text = dD.name
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { a -> Void in
                bridge.currentAlertVC = nil
            })
            let setAction = UIAlertAction(title: "Set", style: .default, handler: { a -> Void in
                if let textField = alert.textFields?[0] {
                    let name = textField.text ?? ""
                    if name != "" {
                        ws.nameDevice(name)
                    }
                }
                bridge.currentAlertVC = nil
            })
            alert.addAction(cancelAction)
            alert.addAction(setAction)
            alert.preferredAction = setAction
            bridge.currentAlertVC = alert
            self.present(alert, animated: true, completion: { () -> Void in
                alert.textFields![0].selectAll(nil)
            })
        }
    }
    @IBAction func deviceSelectorArrowClicked(_ sender: UIButton) {
        deviceSelectorClicked(gesture: nil)
    }
    
    // code ui actions
    @objc func deviceSelectorClicked(gesture: UITapGestureRecognizer?) {
        self.performSegue(withIdentifier: "deviceListSegue", sender: self)
    }
    
    // set brightness
    func setBrightness(_ b: Int) {
        brightness = b
        brightlock = true
        brightSlider.value = Float(brightness)
        brightLabel.text = String(brightness)
        brightlock = false
    }
    // set speed
    func setSpeed(_ s: Int) {
        speed = s
        speedlock = true
        speedSlider.value = Float(speed)
        speedLabel.text = String(speed)
        speedlock = false
    }
    // update currently playing from globals
    func updateCurrentlyPlaying() {
        hueIndicatorViewL.isHidden = true
        hueIndicatorViewR.isHidden = true
        patternNameLabel.isHidden = true
        switch currentItemType {
            case "music":
                if let hueData: ((Int, Int, Int), (Int, Int, Int)) = currentItemCData {
                    currentlyPlayingLabel.text = " Audio"
                    if let label = currentlyPlayingLabel {
                        label.font = UIFont.systemFont(ofSize: 19, weight: .light)
                    }
                    hueIndicatorViewL.backgroundColor = getUIColor(red: hueData.0.0, green: hueData.0.1, blue: hueData.0.2)
                    hueIndicatorViewL.isHidden = false
                    hueIndicatorViewR.backgroundColor = getUIColor(red: hueData.1.0, green: hueData.1.1, blue: hueData.1.2)
                    hueIndicatorViewR.isHidden = false
                }
                break;
            case "pattern":
                if let patternData: (String, String) = currentItemPData {
                    print(patternData)
                    currentlyPlayingLabel.text = ""
                    patternNameLabel.text = patternData.1
                    patternNameLabel.isHidden = false
                }
                break;
            case "hue":
                if let hueData: ((Int, Int, Int), (Int, Int, Int)) = currentItemCData {
                    if let label = currentlyPlayingLabel {
                        label.font = UIFont.systemFont(ofSize: 19, weight: .light)
                    }
                    currentlyPlayingLabel.text = " Hue"
                    hueIndicatorViewL.backgroundColor = getUIColor(red: hueData.0.0, green: hueData.0.1, blue: hueData.0.2)
                    hueIndicatorViewL.isHidden = false
                    hueIndicatorViewR.backgroundColor = getUIColor(red: hueData.1.0, green: hueData.1.1, blue: hueData.1.2)
                    hueIndicatorViewR.isHidden = false
                }
                break;
            case "no_device":
                currentlyPlayingLabel.text = " No Device"
                if let label = currentlyPlayingLabel {
                    if let desc = UIFont.systemFont(ofSize: 19, weight: .light).fontDescriptor.withSymbolicTraits(.traitItalic) {
                        label.font = UIFont(descriptor: desc, size: 19)
                    }
                }
                break;
            default:
                currentlyPlayingLabel.text = " Nothing"
                if let label = currentlyPlayingLabel {
                    if let desc = UIFont.systemFont(ofSize: 19, weight: .light).fontDescriptor.withSymbolicTraits(.traitItalic) {
                        label.font = UIFont(descriptor: desc, size: 19)
                    }
                }
                break;
        }
    }
    func enableSliders() {
        brightSlider.isEnabled = true
        speedSlider.isEnabled = true
    }
    func disableSliders() {
        brightSlider.isEnabled = false
        speedSlider.isEnabled = false
    }
    // update arduino device view from globals
    func updateDeviceView() {
        if let dD = deviceData {
            statusLabel.text = dD.name
            if dD.lastEvent != "" {
                statusTimerTick()
            }
        } else {
            selectDevice(nil)
        }
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
    // timer tick
    @objc func statusTimerTick() {
        if let dD = deviceData {
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
    func selectDevice(_ _id: String?, save: Bool = true) {
        if _id == nil || _id == "" || deviceList[_id!] == nil {
            deviceData = nil
            currentItemType = "no_device"
            updateCurrentlyPlaying()
            disableSliders()
            if let colorsVC = bridge.colorsVC {
                colorsVC.hideSyncButtons()
            }
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.hidePlayButton();
            }
            if let musicVC = bridge.musicVC {
                musicVC.disableMenu()
            }
            if save {
                UserDefaults.standard.set("", forKey: "last_device")
            }
            deviceListLabel.isHidden = false
            statusIndicatorView.isHidden = true
            statusLabel.isHidden = true
            timeLabel.isHidden = true
            editDeviceNameButton.isHidden = true
        } else if let id = _id {
            deviceData = Device(id: id, name: id)
            deviceData?.lastEvent = "loading"
            deviceData?.lastTimestamp = 0
            statusLabel.text = id
            enableSliders()
            if let colorsVC = bridge.colorsVC {
                colorsVC.showSyncButtons()
            }
            if let patternEditVC = bridge.patternEditVC {
                patternEditVC.showPlayButton();
            }
            if let musicVC = bridge.musicVC {
                musicVC.enableMenu()
            }
            if save {
                UserDefaults.standard.set(id, forKey: "last_device")
            }
            deviceListLabel.isHidden = true
            statusIndicatorView.isHidden = false
            statusLabel.isHidden = false
            timeLabel.isHidden = false
            editDeviceNameButton.isHidden = false
            ws.getDeviceData()
        }
    }
    
}

class ControlsNavController : UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.controlsNavVC = self
    }
    func back(animated: Bool = true) {
        self.popViewController(animated: animated)
    }
}
