//
//  MusicController.swift
//  LEDLights
//
//  Created by Anuv Gupta on 7/29/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation

class MusicController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // ib ui elements
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var enableSwitch: UISwitch!
    @IBOutlet weak var smoothingSlider: UISlider!
    @IBOutlet weak var smoothingLabel: UILabel!
    @IBOutlet weak var noiseGateSlider: UISlider!
    @IBOutlet weak var noiseGateLabel: UILabel!
    @IBOutlet weak var leftChannelInput: UITextField!
    @IBOutlet weak var leftInvertSwitch: UISwitch!
    @IBOutlet weak var leftPreampSlider: UISlider!
    @IBOutlet weak var leftPreampLabel: UILabel!
    @IBOutlet weak var leftPostampSlider: UISlider!
    @IBOutlet weak var leftPostampLabel: UILabel!
    @IBOutlet weak var rightChannelInput: UITextField!
    @IBOutlet weak var rightInvertSwitch: UISwitch!
    @IBOutlet weak var rightPreampSlider: UISlider!
    @IBOutlet weak var rightPreampLabel: UILabel!
    @IBOutlet weak var rightPostampSlider: UISlider!
    @IBOutlet weak var rightPostampLabel: UILabel!
    // code ui elements
    let leftChannelPicker: UIPickerView = UIPickerView()
    let leftChannelPickerToolbar: UIToolbar = UIToolbar()
    let rightChannelPicker: UIPickerView = UIPickerView()
    let rightChannelPickerToolbar: UIToolbar = UIToolbar()
    // ui globals
    let channelOptions: [Int] = [1, 2, 3, 4, 5, 6, 7]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        enableSwitch.isOn = deviceData != nil && currentItemType == "music"
        
        leftChannelPicker.backgroundColor = UIColor.white
        leftChannelPicker.showsSelectionIndicator = true
        leftChannelPicker.delegate = self
        leftChannelPicker.dataSource = self
        leftChannelPickerToolbar.barStyle = .default
        leftChannelPickerToolbar.isTranslucent = true
        leftChannelPickerToolbar.tintColor = self.view.tintColor
        leftChannelPickerToolbar.sizeToFit()
        leftChannelPickerToolbar.setItems([
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(leftChannelPickerDone))
            ], animated: false)
        leftChannelPickerToolbar.isUserInteractionEnabled = true
        leftChannelInput.inputView = leftChannelPicker
        leftChannelInput.inputAccessoryView = leftChannelPickerToolbar
        
        rightChannelPicker.backgroundColor = UIColor.white
        rightChannelPicker.showsSelectionIndicator = true
        rightChannelPicker.delegate = self
        rightChannelPicker.dataSource = self
        rightChannelPickerToolbar.barStyle = .default
        rightChannelPickerToolbar.isTranslucent = true
        rightChannelPickerToolbar.tintColor = self.view.tintColor
        rightChannelPickerToolbar.sizeToFit()
        rightChannelPickerToolbar.setItems([
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(rightChannelPickerDone))
            ], animated: false)
        rightChannelPickerToolbar.isUserInteractionEnabled = true
        rightChannelInput.inputView = rightChannelPicker
        rightChannelInput.inputAccessoryView = rightChannelPickerToolbar
        
        if deviceData == nil {
            disableMenu()
        } else {
            ws.getDeviceData()
        }
        bridge.musicVC = self
    }
    
    // ib ui actions
    @IBAction func signOutClicked(_ sender: UIButton) {
        ws.logout(callback: { () -> Void in
            self.performSegue(withIdentifier: "logoutSegue", sender: self)
        })
    }
    @IBAction func enableSwitchChanged(_ sender: UISwitch) {
        let val: Bool = sender.isOn
        if val {
            ws.playMusic()
        } else {
            ws.playNone()
        }
    }
    @IBAction func smoothingSliderChanged(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        smoothingLabel.text = String(val)
        ws.setSmoothing(val, interval: true)
    }
    @IBAction func smoothingSliderUp(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        smoothingLabel.text = String(val)
        ws.setSmoothing(val, interval: false)
    }
    @IBAction func noiseGateChanged(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        noiseGateLabel.text = String(val)
        ws.setNoiseGate(val, interval: true)
    }
    @IBAction func noiseGateSliderUp(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        noiseGateLabel.text = String(val)
        ws.setNoiseGate(val, interval: false)
    }
    @IBAction func leftChannelChanged(_ sender: UITextField) {
        let val: Int = (Int(sender.text ?? "1") ?? 1) - 1
        ws.setLeftChannel(val)
    }
    @IBAction func leftInvertSwitchChanges(_ sender: UISwitch) {
        let val: Bool = sender.isOn
        ws.setLeftInvert(val)
    }
    @IBAction func leftPreampSliderChanged(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        leftPreampLabel.text = String(val)
        ws.setLeftPreamp(val, interval: true)
    }
    @IBAction func leftPreampSliderUp(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        leftPreampLabel.text = String(val)
        ws.setLeftPreamp(val, interval: false)
    }
    @IBAction func leftPostampSliderChanged(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        leftPostampLabel.text = String(val)
        ws.setLeftPostamp(val, interval: true)
    }
    @IBAction func leftPostampSliderUp(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        leftPostampLabel.text = String(val)
        ws.setLeftPostamp(val, interval: false)
    }
    @IBAction func rightChannelChanged(_ sender: UITextField) {
        let val: Int = (Int(sender.text ?? "1") ?? 1) - 1
        ws.setRightChannel(val)
    }
    @IBAction func rightInvertSwitchChanges(_ sender: UISwitch) {
        let val: Bool = sender.isOn
        ws.setRightInvert(val)
    }
    @IBAction func rightPreampSliderChanged(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        rightPreampLabel.text = String(val)
        ws.setRightPreamp(val, interval: true)
    }
    @IBAction func rightPreampSliderUp(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        rightPreampLabel.text = String(val)
        ws.setRightPreamp(val, interval: false)
    }
    @IBAction func rightPostampSliderChanged(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        rightPostampLabel.text = String(val)
        ws.setRightPostamp(val, interval: true)
    }
    @IBAction func rightPostampSliderUp(_ sender: UISlider) {
        let val: Int = Int(sender.value)
        rightPostampLabel.text = String(val)
        ws.setRightPostamp(val, interval: false)
    }
    
    // picker delegate methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return channelOptions.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(channelOptions[row])
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == leftChannelPicker {
            leftChannelInput.text = String(channelOptions[row])
            leftChannelChanged(leftChannelInput)
        } else if pickerView == rightChannelPicker {
            rightChannelInput.text = String(channelOptions[row])
            rightChannelChanged(rightChannelInput)
        }
    }
    @objc func leftChannelPickerDone() {
        leftChannelInput.resignFirstResponder()
        leftChannelChanged(leftChannelInput)
    }
    @objc func rightChannelPickerDone() {
        rightChannelInput.resignFirstResponder()
        rightChannelChanged(rightChannelInput)
    }
    // enable/disable menu
    func enableMenu() {
        enableSwitch.isEnabled = true
        smoothingSlider.isEnabled = true
        noiseGateSlider.isEnabled = true
        leftChannelInput.isEnabled = true
        leftInvertSwitch.isEnabled = true
        leftPreampSlider.isEnabled = true
        leftPostampSlider.isEnabled = true
        rightChannelInput.isEnabled = true
        rightInvertSwitch.isEnabled = true
        rightPreampSlider.isEnabled = true
        rightPostampSlider.isEnabled = true
        scrollView.alpha = 1
    }
    func disableMenu() {
        enableSwitch.isEnabled = false
        smoothingSlider.isEnabled = false
        noiseGateSlider.isEnabled = false
        leftChannelInput.isEnabled = false
        leftInvertSwitch.isEnabled = false
        leftPreampSlider.isEnabled = false
        leftPostampSlider.isEnabled = false
        rightChannelInput.isEnabled = false
        rightInvertSwitch.isEnabled = false
        rightPreampSlider.isEnabled = false
        rightPostampSlider.isEnabled = false
        scrollView.alpha = 0.7
    }
    
    // set menu option values
    func setEnable(_ l: Bool) {
        enableSwitch.setOn(l, animated: true)
    }
    func setSmoothing(_ l: Int) {
        smoothingSlider.setValue(Float(l), animated: false)
        smoothingLabel.text = String(l)
    }
    func setNoiseGate(_ l: Int) {
        noiseGateSlider.setValue(Float(l), animated: false)
        noiseGateLabel.text = String(l)
    }
    func setLeftChannel(_ l: Int) {
        leftChannelInput.text = String(l)
        leftChannelPicker.selectRow(l - 1, inComponent: 0, animated: true)
    }
    func setLeftInvert(_ l: Bool) {
        leftInvertSwitch.setOn(l, animated: true)
    }
    func setLeftPreamp(_ l: Int) {
        leftPreampSlider.setValue(Float(l), animated: false)
        leftPreampLabel.text = String(l)
    }
    func setLeftPostamp(_ l: Int) {
        leftPostampSlider.setValue(Float(l), animated: false)
        leftPostampLabel.text = String(l)
    }
    func setRightChannel(_ l: Int) {
        rightChannelInput.text = String(l)
        rightChannelPicker.selectRow(l - 1, inComponent: 0, animated: true)
    }
    func setRightInvert(_ l: Bool) {
        rightInvertSwitch.setOn(l, animated: true)
    }
    func setRightPreamp(_ l: Int) {
        rightPreampSlider.setValue(Float(l), animated: false)
        rightPreampLabel.text = String(l)
    }
    func setRightPostamp(_ l: Int) {
        rightPostampSlider.setValue(Float(l), animated: false)
        rightPostampLabel.text = String(l)
    }
    
}
