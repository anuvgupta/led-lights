//
//  WebSocketWrapper.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Starscream
import SwiftyJSON
import Foundation

// WebSocket client interface
class WSWrapper: WebSocketDelegate {
    
    // WebSocket connection
    var socket: WebSocket = WebSocket(url: URL(string: serverURL)!)
    
    // WebSocket delegate handlers
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket connected")
        if let loginVC = bridge.loginVC {
            // attempt login with saved password
            let saved_password = ws.getSavedPassword()
            if (saved_password.count > 0) {
                ws.login(password: saved_password)
            } else {
                // or show login form
                loginVC.showLoginStack()
            }
        }
    }
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket disconnected", error ?? "")
        dismissAlerts(callback: { () -> Void in
            if let loginVC = bridge.loginVC {
                if let currentVC = bridge.currentVC() {
                    bridge.lastVC = currentVC
                    loginVC.hideLoginStack()
                    if currentVC != loginVC {
                        currentVC.performSegue(withIdentifier: "logoutSegue", sender: self)
                    }
                    self.reconnect()
                }
            }
        })
    }
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        // print("websocket received message: ", text)
        // messages have to be JSON: {"event": "event_name", "data": { ... } }
        let json: JSON = decode(data: text)
        let event: String = json["event"].stringValue
        if (true) {
            print("websocket message: " + event)
            print(json)
            print()
        }
        // handle various events
        switch (event) {
            // authentication accepted
            case "auth":
                let data: Bool = json["data"].boolValue;
                if (data == true) {
                    if let loginVC = bridge.loginVC {
                        // save/remember password
                        UserDefaults.standard.set(lastPassword, forKey: "password")
                        // switch to colors view
                        loginVC.performSegue(withIdentifier: "loginSegue", sender: self)
                    }
                }
                break;
            // color palette received
            case "color_palette":
                // sort and load color presets as views
                var colorPresets: [ColorPreset] = []
                for (key, data) : (String, JSON) in json["data"] {
                    colorPresets.append(ColorPreset(
                        red: data["r"].intValue,
                        green: data["g"].intValue,
                        blue: data["b"].intValue,
                        timestamp: data["d"].intValue,
                        id: key,
                        name: data["name"].stringValue
                    ))
                }
                colorPresets.sort(by: { $0.timestamp < $1.timestamp })
                if let colorsVC = bridge.colorsVC {
                    let editingColor = String(colorsVC.editingColor)
                    colorsVC.clearColorPresets()
                    for preset: ColorPreset in colorPresets {
                        colorsVC.addColorView(preset: preset)
                    }
                    if editingColor != "" {
                        if let editingColorButton = colorsVC.colorViews[editingColor] {
                            colorsVC.colorPresetEdit(editingColorButton)
                        }
                    }
                }
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.clearColorPresets()
                    for preset: ColorPreset in colorPresets {
                        colorPickVC.addColorView(preset: preset)
                    }
                }
                break;
            // new color preset received
            case "color_new":
                // load color preset as view
                if let colorsVC = bridge.colorsVC {
                    colorsVC.addColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: json["data"]["d"].intValue,
                        id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                    if /*colorsVC.editingColor != "" &&*/ json["data"]["switch"].boolValue {
                        if let presetButton = colorsVC.colorViews[json["data"]["id"].stringValue] {
                            colorsVC.colorPresetEdit(presetButton)
                        }
                    }
                }
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.addColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: json["data"]["d"].intValue,
                        id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                }
                break;
            // color preset deleted
            case "color_delete":
                // re-request and reload color palette
                // (instead of deleting from and rearranging existing palette)
                requestColorPalette()
                break;
            // color preset updated
            case "color_update":
                // update color's view with updated preset
                if let colorsVC = bridge.colorsVC {
                    colorsVC.updateColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: 0, id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                }
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.updateColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: 0, id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                }
                break;
            // pattern list received
            case "pattern_list":
                // load patterns as views
                if let patternsVC = bridge.patternsVC {
                    patternsVC.clearPatternList()
                    for (_, data) : (String, JSON) in json["data"] {
                        patternsVC.addPattern(pattern: Pattern(
                            id: data["id"].stringValue,
                            name: data["name"].stringValue
                        ))
                    }
                }
                break;
            // new pattern received
            case "pattern_new":
                // add pattern as view
                if let patternsVC = bridge.patternsVC {
                    patternsVC.addPattern(pattern: Pattern(
                        id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                }
                break;
            // pattern color data received
            case "pattern_load":
                // load pattern colors as views
                loadPatternData(id: json["data"]["id"].stringValue, json: json["data"]["list"])
                break;
            // new pattern name received
            case "pattern_name":
                // rename pattern in view
                if let patternsVC = bridge.patternsVC {
                    patternsVC.renamePattern(pattern: Pattern(
                        id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                }
                if let patternEditVC = bridge.patternEditVC {
                    if let currentpattern = editingPattern {
                        if currentpattern.id == json["data"]["id"].stringValue {
                            patternEditVC.reloadTitle()
                        }
                    }
                }
                break;
            // pattern color data updated
            case "pattern_update":
                // reload pattern colors as views
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.exit()
                }
                loadPatternData(id: json["data"]["id"].stringValue, json: json["data"]["list"])
                break;
            // pattern deleted
            case "pattern_delete":
                // reload view
                requestPatternList()
                dismissAlerts(callback: { () -> Void in
                    if let patternEditVC = bridge.patternEditVC {
                        if let currentpattern = editingPattern {
                            if currentpattern.id == json["data"]["id"].stringValue {
                                patternEditVC.exit()
                                editingPattern = nil
                            }
                        }
                    }
                })
                break;
            // device list received
            case "device_list":
                var devices: [String: Device] = [:]
                for (d, device) in json["data"] {
                    let dev = Device(id: d, name: device["name"].stringValue)
                    dev.lastEvent = device["last_event"].stringValue
                    dev.lastTimestamp = device["last_timestamp"].intValue
                    devices[d] = dev
                }
                deviceList = devices
                if let devicesVC = bridge.devicesVC {
                    devicesVC.refresh()
                }
                if let dD = deviceData {
                    if let controlsVC = bridge.controlsVC {
                        if devices[dD.id] == nil {
                            deviceData = nil
                        } else if let d = devices[dD.id] {
                            deviceData?.name = d.name
                            deviceData?.lastEvent = d.lastEvent
                            deviceData?.lastTimestamp = d.lastTimestamp
                        }
                        controlsVC.updateDeviceView()
                    }
                }
                break;
            // currently playing changed
            case "current":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        var data: JSON = json["data"]["data"]["data"]
                        let type: String = json["data"]["data"]["type"].stringValue
                        if (type == "music") {
                            currentItemType = "music"
                            currentItemCData = (
                                (data["left"]["r"].intValue, data["left"]["g"].intValue, data["left"]["b"].intValue),
                                (data["right"]["r"].intValue, data["right"]["g"].intValue, data["right"]["b"].intValue)
                            )
                            currentItemPData = nil
                            musicEnabled = true
                        } else if (type == "pattern") {
                            currentItemType = "pattern"
                            currentItemCData = nil
                            currentItemPData = (data["id"].stringValue, data["name"].stringValue)
                            musicEnabled = false
                        } else if (type == "hue") {
                            currentItemType = "hue"
                            currentItemCData = (
                                (data["left"]["r"].intValue, data["left"]["g"].intValue, data["left"]["b"].intValue),
                                (data["right"]["r"].intValue, data["right"]["g"].intValue, data["right"]["b"].intValue)
                            )
                            currentItemPData = nil
                            if let music = json["data"]["music"].string {
                                if music == "off" {
                                    musicEnabled = false
                                }
                            }
                        } else {
                            currentItemType = "none"
                            currentItemCData = nil
                            currentItemPData = nil
                            musicEnabled = false
                        }
                        if let musicVC = bridge.musicVC {
                            musicVC.setEnable(musicEnabled)
                        }
                        if let controlsVC = bridge.controlsVC {
                            controlsVC.updateCurrentlyPlaying()
                        }
                    }
                }
                break;
            // brightness changed
            case "brightness":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let controlsVC = bridge.controlsVC {
                            var b: Int = json["data"]["level"].intValue
                            if b < 0 {
                                b = 0
                            }
                            if b > 100 {
                                b = 100
                            }
                            controlsVC.setBrightness(b)
                        }
                    }
                }
                break;
            // speed changed
            case "speed":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let controlsVC = bridge.controlsVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 0 {
                                s = 0
                            }
                            if s > 500 {
                                s = 500
                            }
                            controlsVC.setSpeed(s)
                        }
                    }
                }
                break;
            // music settings
            case "smoothing":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 0 {
                                s = 0
                            }
                            if s > 99 {
                                s = 99
                            }
                            musicVC.setSmoothing(s)
                        }
                    }
                }
                break;
            case "noise_gate":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 0 {
                                s = 0
                            }
                            if s > 50 {
                                s = 50
                            }
                            musicVC.setNoiseGate(s)
                        }
                    }
                }
                break;
            case "left_channel":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue + 1
                            if s < 1 {
                                s = 1
                            }
                            if s > 7 {
                                s = 7
                            }
                            musicVC.setLeftChannel(s)
                        }
                    }
                }
                break;
            case "left_invert":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            let s: Bool = json["data"]["level"].intValue == 1 ? true : false
                            musicVC.setLeftInvert(s)
                        }
                    }
                }
                break;
            case "left_preamp":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 20 {
                                s = 20
                            }
                            if s > 200 {
                                s = 200
                            }
                            musicVC.setLeftPreamp(s)
                        }
                    }
                }
                break;
            case "left_postamp":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 1 {
                                s = 1
                            }
                            if s > 10 {
                                s = 10
                            }
                            musicVC.setLeftPostamp(s)
                        }
                    }
                }
                break;
            case "right_channel":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue + 1
                            if s < 1 {
                                s = 1
                            }
                            if s > 7 {
                                s = 7
                            }
                            musicVC.setRightChannel(s)
                        }
                    }
                }
                break;
            case "right_invert":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            let s: Bool = json["data"]["level"].intValue == 1 ? true : false
                            musicVC.setRightInvert(s)
                        }
                    }
                }
                break;
            case "right_preamp":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 20 {
                                s = 20
                            }
                            if s > 200 {
                                s = 200
                            }
                            musicVC.setRightPreamp(s)
                        }
                    }
                }
                break;
            case "right_postamp":
                if let dD = deviceData {
                    if dD.id == json["data"]["device_id"].stringValue {
                        if let musicVC = bridge.musicVC {
                            var s: Int = json["data"]["level"].intValue
                            if s < 1 {
                                s = 1
                            }
                            if s > 10 {
                                s = 10
                            }
                            musicVC.setRightPostamp(s)
                        }
                    }
                }
                break;
            // unknown event received
            default:
                print("unknown event: " + event)
                break;
        }
    }
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("websocket received data: ", data)
    }
    
    // convenience function for loading list
    private func loadPatternData(id: String, json: JSON) {
        if let patternEditVC = bridge.patternEditVC {
            if let currentpattern = editingPattern {
                if currentpattern.id == id {
                    // save scroll data
                    let scrollOffset: CGPoint? = patternEditVC.getScroll()
                    let scrollHeightPrevious: CGFloat? = patternEditVC.getScrollHeight()
                    let scrollFrameHeight: CGFloat? = patternEditVC.getScrollFrameHeight()
                    patternEditVC.clearPatternColorList()
                    var list: [PatternItem] = []
                    for (_, data) : (String, JSON) in json {
                        list.append(PatternItem(
                            red: data["r"].intValue,
                            green: data["g"].intValue,
                            blue: data["b"].intValue,
                            fade: data["fade"].intValue,
                            hold: data["time"].intValue
                        ))
                    }
                    patternEditVC.refresh(items: list)
                    // correct and apply scroll
                    let scrollHeightNew: CGFloat? = patternEditVC.getScrollHeight()
                    if let sO = scrollOffset, let sHP = scrollHeightPrevious, let sHN = scrollHeightNew, let sFH = scrollFrameHeight {
                        var newScrollOffset = sO
                        // print("scrollOffset: " + String(Int(sO.y)))
                        // print("prevScrollHeight: " + String(Int(sHP)))
                        // print("newScrollHeight: " + String(Int(sHN)))
                        // print("scrollFrameHeight: " + String(Int(sFH)))
                        if Int(sHP) - Int(sO.y) >= Int(sFH) && Int(sHN) < Int(sHP) {
                            newScrollOffset.y = sHN - sFH
                        }
                        if newScrollOffset.y < 0.0 {
                            newScrollOffset.y = 0.0
                        }
                        patternEditVC.setScroll(newScrollOffset)
                    }
                }
            }
        }
    }
    
    // WebSocket client begin connection
    func connect() {
        socket.delegate = self
        socket.connect()
    }
    // accessor for connectedness
    func connected() -> Bool {
        return socket.isConnected
    }
    // reconnect repeatedly
    func reconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            if !self.connected() {
                self.connect()
                self.reconnect()
            }
        })
    }
    // get password saved in user data
    func getSavedPassword() -> String {
        let saved_password = UserDefaults.standard.string(forKey: "password") ?? ""
        print("saved password: " + saved_password)
        return saved_password
    }
    // convert event+data to JSON message
    func encode(event: String, data: Any) -> String {
        let obj = try? JSONSerialization.data(withJSONObject: [
            "event": event,
            "data": data
            ], options: [])
        if let string = String(data: obj!, encoding: .utf8) {
            return string
        }
        return ""
    }
    // convert raw string JSON data to readable JSON object
    func decode(data: String) -> JSON {
        var decoded: JSON = JSON("null")
        if let string_data = data.data(using: .utf8, allowLossyConversion: false) {
            do {
                decoded = try JSON(data: string_data)
            } catch  { }
        }
        return decoded
    }
    // encode and send message to server
    func send(event: String, data: Any) {
        if connected() {
            socket.write(string: encode(event: event, data: data))
        }
    }
    // login with password
    func login(password: String) {
        lastPassword = password
        send(event: "auth", data: [
            "password": password
        ])
    }
    // logout and callback
    func logout(callback: () -> Void) {
        UserDefaults.standard.set("", forKey: "password")
        callback()
    }
    // request color palette from server
    func requestColorPalette() {
        send(event: "get_color_palette", data: "")
    }
    // request pattern list from server
    func requestPatternList() {
        send(event: "get_pattern_list", data: "")
    }
    // create new color preset on server
    func newPreset(red: Int, green: Int, blue: Int) {
        send(event: "color_new", data: [
            "r": r, "g": g, "b": b
        ])
    }
    // delete color preset from server
    func deletePreset(id: String) {
        send(event: "color_delete", data: [
            "id": id
        ])
    }
    // name color preset
    func namePreset(id: String, name: String) {
        send(event: "color_name", data: [
            "id": id,
            "name": name
        ])
    }
    // update color preset
    var lastUpdateColorIntervalTickMS = 0;
    func updateColor(id: String, interval: Bool) {
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastUpdateColorIntervalTickMS >= 200) {
                lastUpdateColorIntervalTickMS = nowMS
                send(event: "color_update", data: [
                    "r": r, "g": g, "b": b, "id": id,
                    "latent": false
                ])
            }
        } else {
            send(event: "color_update", data: [
                "r": r, "g": g, "b": b, "id": id,
                "latent": true
            ])
        }
    }
    // send color preset to arduino through server
    var lastTestColorIntervalTickMS = 0;
    func testColor(interval: Bool) {
        if let dD = deviceData {
            var c_d: [String: Any]? = nil
            if trackLeft && trackRight {
                c_d = [
                    "left": [ "r": r, "g": g, "b": b, ],
                    "right": [ "r": r, "g": g, "b": b, ]
                ]
            } else if trackLeft {
                c_d = [
                    "left": [ "r": r, "g": g, "b": b, ]
                ]
            } else if trackRight {
                c_d = [
                    "right": [ "r": r, "g": g, "b": b, ]
                ]
            }
            if let color_data = c_d {
                if (interval) {
                    let nowMS = msTimeStamp()
                    if (nowMS - lastTestColorIntervalTickMS >= 200) {
                        lastTestColorIntervalTickMS = nowMS
                        send(event: "color_test", data: [
                            "color": color_data,
                            "latent": false,
                            "device_id": dD.id,
                            "music": false
                        ])
                    }
                } else {
                    // print(rgbstring(r: r, g: g, b: b))
                    send(event: "color_test", data: [
                        "color": color_data,
                        "latent": true,
                        "device_id": dD.id,
                        "music": musicEnabled
                    ])
                }
            }
        }
    }
    // send global brightness to arduino through server
    var lastBrightnessIntervalTickMS = 0;
    func setBrightness(_ brightness: Int, interval: Bool) {
        if let dD = deviceData {
            var b = brightness
            if b < 0 {
                b = 0
            }
            if b > 100 {
                b = 100
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastBrightnessIntervalTickMS >= 150) {
                    lastBrightnessIntervalTickMS = nowMS
                    send(event: "set_brightness", data: [
                        "brightness": b, "latent": false,
                        "device_id": dD.id
                    ])
                }
            } else {
                send(event: "set_brightness", data: [
                    "brightness": b, "latent": true,
                    "device_id": dD.id
                ])
            }
        }
    }
    // get global brightness setting
    func getBrightness() {
        send(event: "get_brightness", data: "")
    }
    // send global pattern speed to arduino through server
    var lastSpeedIntervalTickMS = 0;
    func setSpeed(_ speed: Int, interval: Bool) {
        if let dD = deviceData {
            var s = speed
            if s < 0 {
                s = 0
            }
            if s > 500 {
                s = 500
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastSpeedIntervalTickMS >= 150) {
                    lastSpeedIntervalTickMS = nowMS
                    send(event: "set_speed", data: [
                        "speed": s, "latent": false,
                        "device_id": dD.id
                    ])
                }
            } else {
                send(event: "set_speed", data: [
                    "speed": s, "latent": true,
                    "device_id": dD.id
                ])
            }
        }
    }
    // get global pattern speed setting
    func getSpeed() {
        if let dD = deviceData {
            send(event: "get_speed", data: [
                "device_id": dD.id
            ])
        }
    }
    // create new blank pattern
    func newPattern() {
        send(event: "pattern_new", data: [ ])
    }
    // load current pattern data
    func loadPattern(id: String) {
        send(event: "pattern_load", data: [
            "id": id
        ])
    }
    // rename pattern
    func renamePattern(id: String, name: String) {
        send(event: "pattern_name", data: [
            "id": id, "name": name
        ])
    }
    // delete pattern
    func deletePattern(id: String) {
        send(event: "pattern_delete", data: [
            "id": id
        ])
    }
    // play pattern
    func playPattern(id: String) {
        if let dD = deviceData {
            send(event: "pattern_play", data: [
                "id": id,
                "device_id": dD.id
            ])
        }
    }
    // add pattern color
    func addPatternColor(id: String) {
        send(event: "pattern_add_color", data: [
            "id": id
        ])
    }
    // update pattern color
    func updatePatternColor(id: String, colorID: Int, colorData: PatternItem) {
        let c_d = [
            "id": colorID,
            "fade": colorData.fade,
            "r": colorData.red,
            "g": colorData.green,
            "b": colorData.blue,
            "time": colorData.hold
        ];
        send(event: "pattern_update_color", data: [
            "id": id,
            "color": c_d
        ])
    }
    // move pattern color
    func movePatternColor(id: String, colorID: Int, newPos: Int) {
        send(event: "pattern_move_color", data: [
            "id": id,
            "color":  [
                "id": colorID
            ],
            "new_pos": newPos
        ])
    }
    // delete pattern color
    func deletePatternColor(id: String, colorID: Int) {
        send(event: "pattern_delete_color", data: [
            "id": id,
            "color": [
                "id": colorID
            ]
        ])
    }
    // play music
    func playMusic() {
        if let dD = deviceData {
            send(event: "music", data: [
                "device_id": dD.id
            ])
        }
    }
    func playMusic(afterTime dt: Double) {
        if let dD = deviceData {
            DispatchQueue.main.asyncAfter(deadline: .now() + dt, execute: {
                self.send(event: "music", data: [
                    "device_id": dD.id
                ])
            })
        }
    }
    // play none
    func playNone() {
        if let dD = deviceData {
            send(event: "play_none", data: [
                "device_id": dD.id
            ])
        }
    }
    // get device data
    func getDeviceData() {
        if let dD = deviceData {
            send(event: "get_device_data", data: [
                "device_id": dD.id
            ])
        }
    }
    // get currently playing
    func getCurrentlyPlaying() {
        if let dD = deviceData {
            send(event: "get_current", data: [
                "device_id": dD.id
            ])
        }
    }
    // play current
    func playCurrent() {
        if let dD = deviceData {
            send(event: "play_current", data: [
                "device_id": dD.id
            ])
        }
    }
    // name device
    func nameDevice(_ name: String) {
        if let dD = deviceData {
            if name != "" {
                send(event: "device_name", data: [
                    "device_id": dD.id,
                    "name": name
                ])
            }
        }
    }
    // remove device
    func removeDevice(d_id: String) {
        if deviceList[d_id] != nil {
            send(event: "device_delete", data: [
                "device_id": d_id
            ])
        }
    }
    
    // update music settings
    var lastSmoothingIntervalTickMS = 0;
    func setSmoothing(_ smoothing: Int, interval: Bool) {
        if let dD = deviceData {
            var s = smoothing
            if s < 0 {
                s = 0
            }
            if s > 99 {
                s = 99
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastSmoothingIntervalTickMS >= 150) {
                    lastSmoothingIntervalTickMS = nowMS
                    send(event: "set_smoothing", data: [
                        "smoothing": s, "latent": false,
                        "device_id": dD.id
                    ])
                }
            } else {
                send(event: "set_smoothing", data: [
                    "smoothing": s, "latent": true,
                    "device_id": dD.id
                ])
                if musicEnabled {
                    ws.playMusic(afterTime: 0.15)
                }
            }
        }
    }
    var lastNoiseGateIntervalTickMS = 0;
    func setNoiseGate(_ noiseGate: Int, interval: Bool) {
        if let dD = deviceData {
            var s = noiseGate
            if s < 0 {
                s = 0
            }
            if s > 50 {
                s = 50
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastNoiseGateIntervalTickMS >= 150) {
                    lastNoiseGateIntervalTickMS = nowMS
                    send(event: "set_noise_gate", data: [
                        "noise_gate": s, "latent": false,
                        "device_id": dD.id
                    ])
                }
            } else {
                send(event: "set_noise_gate", data: [
                    "noise_gate": s, "latent": true,
                    "device_id": dD.id
                ])
                if musicEnabled {
                    ws.playMusic(afterTime: 0.15)
                }
            }
        }
    }
    func setLeftChannel(_ channel: Int) {
        if let dD = deviceData {
            var s = channel
            if s < 0 {
                s = 0
            }
            if s > 6 {
                s = 6
            }
            print(s)
            send(event: "set_left_channel", data: [
                "left_channel": s,
                "device_id": dD.id
            ])
            if musicEnabled {
                ws.playMusic(afterTime: 0.15)
            }
        }
    }
    func setLeftInvert(_ b: Bool) {
        if let dD = deviceData {
            send(event: "set_left_invert", data: [
                "left_invert": b,
                "device_id": dD.id
            ])
            if musicEnabled {
                ws.playMusic(afterTime: 0.15)
            }
        }
    }
    var lastLeftPreampIntervalTickMS = 0;
    func setLeftPreamp(_ leftPreamp: Int, interval: Bool) {
        if let dD = deviceData {
            var s = leftPreamp
            if s < 20 {
                s = 20
            }
            if s > 200 {
                s = 200
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastLeftPreampIntervalTickMS >= 150) {
                    lastLeftPreampIntervalTickMS = nowMS
                    send(event: "set_left_preamp", data: [
                        "left_preamp": s, "latent": false,
                        "device_id": dD.id
                    ])
                }
            } else {
                send(event: "set_left_preamp", data: [
                    "left_preamp": s, "latent": true,
                    "device_id": dD.id
                ])
                if musicEnabled {
                    ws.playMusic(afterTime: 0.15)
                }
            }
        }
    }
    var lastLeftPostampIntervalTickMS = 0;
    func setLeftPostamp(_ leftPostamp: Int, interval: Bool) {
        if let dD = deviceData {
            var s = leftPostamp
            if s < 1 {
                s = 1
            }
            if s > 10 {
                s = 10
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastLeftPostampIntervalTickMS >= 150) {
                    lastLeftPostampIntervalTickMS = nowMS
                    send(event: "set_left_postamp", data: [
                        "left_postamp": s, "latent": false,
                        "device_id": dD.id
                    ])
                }
            } else {
                send(event: "set_left_postamp", data: [
                    "left_postamp": s, "latent": true,
                    "device_id": dD.id
                ])
                if musicEnabled {
                    ws.playMusic(afterTime: 0.15)
                }
            }
        }
    }
    func setRightChannel(_ channel: Int) {
        if let dD = deviceData {
            var s = channel
            if s < 0 {
                s = 0
            }
            if s > 6 {
                s = 6
            }
            send(event: "set_right_channel", data: [
                "right_channel": s,
                "device_id": dD.id
            ])
            if musicEnabled {
                ws.playMusic(afterTime: 0.15)
            }
        }
    }
    func setRightInvert(_ b: Bool) {
        if let dD = deviceData {
            send(event: "set_right_invert", data: [
                "right_invert": b,
                "device_id": dD.id
            ])
            if musicEnabled {
                ws.playMusic(afterTime: 0.15)
            }
        }
    }
    var lastRightPreampIntervalTickMS = 0;
    func setRightPreamp(_ rightPreamp: Int, interval: Bool) {
        if let dD = deviceData {
            var s = rightPreamp
            if s < 20 {
                s = 20
            }
            if s > 200 {
                s = 200
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastRightPreampIntervalTickMS >= 150) {
                    lastRightPreampIntervalTickMS = nowMS
                    send(event: "set_right_preamp", data: [
                        "right_preamp": s, "latent": false,
                        "device_id": dD.id
                        ])
                }
            } else {
                send(event: "set_right_preamp", data: [
                    "right_preamp": s, "latent": true,
                    "device_id": dD.id
                ])
                if musicEnabled {
                    ws.playMusic(afterTime: 0.15)
                }
            }
        }
    }
    var lastRightPostampIntervalTickMS = 0;
    func setRightPostamp(_ rightPostamp: Int, interval: Bool) {
        if let dD = deviceData {
            var s = rightPostamp
            if s < 1 {
                s = 1
            }
            if s > 10 {
                s = 10
            }
            if (interval) {
                let nowMS = msTimeStamp()
                if (nowMS - lastRightPostampIntervalTickMS >= 150) {
                    lastRightPostampIntervalTickMS = nowMS
                    send(event: "set_right_postamp", data: [
                        "right_postamp": s, "latent": false,
                        "device_id": dD.id
                        ])
                }
            } else {
                send(event: "set_right_postamp", data: [
                    "right_postamp": s, "latent": true,
                    "device_id": dD.id
                ])
                if musicEnabled {
                    ws.playMusic(afterTime: 0.15)
                }
            }
        }
    }
    
}
