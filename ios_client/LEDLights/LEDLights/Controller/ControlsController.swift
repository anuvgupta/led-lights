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
    @IBOutlet weak var statusIndicatorView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var currentPlayingWrap: UIView!
    @IBOutlet weak var currentlyPlayingLabel: UILabel!
    @IBOutlet weak var hueIndicatorView: UIView!
    @IBOutlet weak var patternNameLabel: UILabel!
    @IBOutlet weak var brightSliderWrap: UIView!
    @IBOutlet weak var brightSlider: UISlider!
    @IBOutlet weak var brightLabel: UILabel!
    @IBOutlet weak var speedSliderWrap: UIView!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var musicWrapView: UIView!
    @IBOutlet weak var musicButtonWrapView: UIView!
    @IBOutlet weak var musicButton: UIButton!
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
        timeLabel.text = ""
        
        let border2 = CALayer()
        border2.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border2.frame = CGRect(x: 0, y: currentPlayingWrap.frame.size.height - 1, width: currentPlayingWrap.frame.size.width, height: 1.0)
        border2.borderWidth = 1.0
        currentPlayingWrap.layer.addSublayer(border2)
        currentPlayingWrap.layer.masksToBounds = true
        hueIndicatorView.addBorder(borderColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75), borderWidth: 1, borderCornerRadius: 8)
        hueIndicatorView.layer.masksToBounds = true
        hueIndicatorView.isHidden = true
        patternNameLabel.isHidden = true
        
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
        
        let border5 = CALayer()
        border5.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        border5.frame = CGRect(x: 0, y: musicWrapView.frame.size.height - 1, width: musicWrapView.frame.size.width, height: 1.0)
        border5.borderWidth = 1.0
        musicWrapView.layer.addSublayer(border5)
        musicWrapView.layer.masksToBounds = true
        musicButtonWrapView.backgroundColor = buttonBlue
        musicButtonWrapView.layer.roundCorners(radius: 5)
        musicButtonWrapView.layer.addShadow(radius: 4, opacity: 0.2, offset: CGSize(width: -1, height: 1), color: UIColor.black)
        musicButton.roundCorners(corners: [.topLeft, .topRight, .bottomRight, .bottomLeft], radius: 5)

        bridge.controlsVC = self
        ws.getCurrentlyPlaying();
        ws.getBrightness();
        ws.getSpeed();
        ws.getArduinoStatus();
        enableTimer()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                ws.sendCurrent()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                ws.sendCurrent()
            })
        }
    }
    @IBAction func musicButtonClicked(_ sender: UIButton) {
        ws.playMusic()
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
        hueIndicatorView.isHidden = true
        patternNameLabel.isHidden = true
        switch currentItemType {
            case "music":
                currentlyPlayingLabel.text = "Music Reactive"
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
                if let hueData: (Int, Int, Int) = currentItemCData {
                    currentlyPlayingLabel.text = " Hue"
                    hueIndicatorView.backgroundColor = getUIColor(red: hueData.0, green: hueData.1, blue: hueData.2)
                    hueIndicatorView.isHidden = false
                }
                break;
            default:
                currentlyPlayingLabel.text = "Nothing"
                break;
        }
    }
    // update arduino status from globals
    func updateStatus() {
        let prefix: String = "Arduino "
        if arduinoStatusEvent != "" {
            if arduinoStatusEvent == "disconnected" {
                statusLabel.text = prefix + "Offline"
                statusIndicatorView.backgroundColor = deleteRed
            } else if arduinoStatusEvent == "connected" {
                statusLabel.text = prefix + "Syncing"
                statusIndicatorView.backgroundColor = buttonBlue
            } else if arduinoStatusEvent == "authenticated" {
                statusLabel.text = prefix + "Syncing"
                statusIndicatorView.backgroundColor = buttonBlue
            } else if arduinoStatusEvent == "online" {
                statusLabel.text = prefix + "Online"
                statusIndicatorView.backgroundColor = statusGreen
            }
            statusTimerTick()
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
        if arduinoStatusEvent != "" && arduinoStatusTime > 0 {
            var deltaSec: Int = Int(NSDate().timeIntervalSince1970) - Int(arduinoStatusTime / 1000)
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
            timeLabel.text = outputString
        }
    }
    
}
