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
        print("websocket received message: ", text)
        // messages have to be JSON: {"event": "event_name", "data": { ... } }
        let json: JSON = decode(data: text)
        let event: String = json["event"].stringValue
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
            case "colorpalette":
                // sort and load color presets as views
                var colorPresets: [ColorPreset] = []
                for (key, data) : (String, JSON) in json["data"] {
                    colorPresets.append(ColorPreset(
                        red: data["r"].intValue,
                        green: data["g"].intValue,
                        blue: data["b"].intValue,
                        timestamp: data["d"].intValue,
                        id: key
                    ))
                }
                colorPresets.sort(by: { $0.timestamp < $1.timestamp })
                if let colorsVC = bridge.colorsVC {
                    colorsVC.clearColorPresets()
                    for preset: ColorPreset in colorPresets {
                        colorsVC.addColorView(preset: preset)
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
            case "newcolor":
                // load color preset as view
                if let colorsVC = bridge.colorsVC {
                    colorsVC.addColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: json["data"]["d"].intValue,
                        id: json["data"]["id"].stringValue
                    ))
                    if colorsVC.editingColor != "" && json["data"]["switch"].boolValue {
                        if let presetButton = colorsVC.colorViews[json["data"]["id"].stringValue] {
                            colorsVC.colorPresetClicked(presetButton)
                        }
                    }
                }
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.addColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: json["data"]["d"].intValue,
                        id: json["data"]["id"].stringValue
                    ))
                }
                break;
            // color preset deleted
            case "deletecolor":
                // re-request and reload color palette
                // (instead of deleting from and rearranging existing palette)
                requestColorPalette()
                break;
            // color preset updated
            case "updatecolor":
                // update color's view with updated preset
                if let colorsVC = bridge.colorsVC {
                    colorsVC.updateColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: 0, id: json["data"]["id"].stringValue
                    ))
                }
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.updateColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: 0, id: json["data"]["id"].stringValue
                    ))
                }
                break;
            // pattern list received
            case "patternlist":
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
            case "newpattern":
                // add pattern as view
                if let patternsVC = bridge.patternsVC {
                    patternsVC.addPattern(pattern: Pattern(
                        id: json["data"]["id"].stringValue,
                        name: json["data"]["name"].stringValue
                    ))
                }
                break;
            // new pattern name received
            case "renamepattern":
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
            // pattern deleted
            case "deletepattern":
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
            // pattern color data received
            case "loadpattern":
                // load pattern colors as views
                loadPatternData(id: json["data"]["id"].stringValue, json: json["data"]["list"])
                break;
            // pattern color data updated
            case "updatepattern":
                // reload pattern colors as views
                if let colorPickVC = bridge.colorPickVC {
                    colorPickVC.exit()
                }
                loadPatternData(id: json["data"]["id"].stringValue, json: json["data"]["list"])
                break;
            // brightness changed
            case "brightness":
                if let controlsVC = bridge.controlsVC {
                    var b: Int = json["data"].intValue
                    if b < 0 {
                        b = 0
                    }
                    if b > 100 {
                        b = 100
                    }
                    controlsVC.setBrightness(b);
                }
                break;
            // speed changed
            case "speed":
                if let controlsVC = bridge.controlsVC {
                    var s: Int = json["data"].intValue
                    if s < 0 {
                        s = 0
                    }
                    if s > 500 {
                        s = 500
                    }
                    controlsVC.setSpeed(s);
                }
                break;
            // currently playing changed
            case "current":
                let type: String = json["data"]["type"].stringValue
                if (type == "music") {
                    currentItemType = "music"
                    currentItemCData = nil
                    currentItemPData = nil
                } else if (type == "pattern") {
                    currentItemType = "pattern"
                    currentItemCData = nil
                    let patternJSON: JSON = json["data"]["data"]
                    currentItemPData = (patternJSON["id"].stringValue, patternJSON["name"].stringValue)
                } else if (type == "hue") {
                    currentItemType = "hue"
                    let hueJSON: JSON = json["data"]["data"]
                    currentItemCData = ( hueJSON["r"].intValue, hueJSON["g"].intValue, hueJSON["b"].intValue)
                    currentItemPData = nil
                } else {
                    currentItemType = "none"
                    currentItemCData = nil
                    currentItemPData = nil
                }
                if let controlsVC = bridge.controlsVC {
                    controlsVC.updateCurrentlyPlaying();
                }
                break;
            // arduino status changed
            case "arduinostatus":
                arduinoStatusEvent = json["data"]["lastEvent"].stringValue
                arduinoStatusTime = json["data"]["lastTimestamp"].intValue
                if let controlsVC = bridge.controlsVC {
                    controlsVC.updateStatus()
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
//                        print("scrollOffset: " + String(Int(sO.y)))
//                        print("prevScrollHeight: " + String(Int(sHP)))
//                        print("newScrollHeight: " + String(Int(sHN)))
//                        print("scrollFrameHeight: " + String(Int(sFH)))
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
        socket.write(string: encode(event: event, data: data))
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
        send(event: "getcolorpalette", data: "")
    }
    // request pattern list from server
    func requestPatternList() {
        send(event: "getpatternlist", data: "")
    }
    // create new color preset on server
    func newPreset(red: Int, green: Int, blue: Int) {
        send(event: "newcolor", data: [
            "r": r, "g": g, "b": b
        ])
    }
    // delete color preset from server
    func deletePreset(id: String) {
        send(event: "deletecolor", data: [
            "id": id
        ])
    }
    // update color preset
    var lastUpdateColorIntervalTickMS = 0;
    func updateColor(id: String, interval: Bool) {
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastUpdateColorIntervalTickMS >= 50) {
                lastUpdateColorIntervalTickMS = nowMS
                send(event: "updatecolor", data: [
                    "r": r, "g": g, "b": b, "id": id, "latent": false
                ])
            }
        } else {
            send(event: "updatecolor", data: [
                "r": r, "g": g, "b": b, "id": id, "latent": true
            ])
        }
    }
    // send color preset to arduino through server
    var lastTestColorIntervalTickMS = 0;
    func testColor(interval: Bool) {
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastTestColorIntervalTickMS >= 100) {
                lastTestColorIntervalTickMS = nowMS
                send(event: "testcolor_silent", data: [
                    "r": r, "g": g, "b": b
                ])
            }
        } else {
            // print(rgbstring(r: r, g: g, b: b))
            send(event: "testcolor", data: [
                "r": r, "g": g, "b": b
            ])
        }
    }
    // send global brightness to arduino through server
    var lastBrightnessIntervalTickMS = 0;
    func setBrightness(_ brightness: Int, interval: Bool) {
        var b = brightness
        if b < 0 {
            b = 0
        }
        if b > 100 {
            b = 100
        }
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastBrightnessIntervalTickMS >= 100) {
                lastBrightnessIntervalTickMS = nowMS
                send(event: "setbrightness", data: [
                    "brightness": b
                ])
            }
        } else {
            send(event: "setbrightness", data: [
                "brightness": b
            ])
        }
    }
    // get global brightness setting
    func getBrightness() {
        send(event: "getbrightness", data: "")
    }
    // send global pattern speed to arduino through server
    var lastSpeedIntervalTickMS = 0;
    func setSpeed(_ speed: Int, interval: Bool) {
        var s = speed
        if s < 0 {
            s = 0
        }
        if s > 500 {
            s = 500
        }
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastSpeedIntervalTickMS >= 100) {
                lastSpeedIntervalTickMS = nowMS
                send(event: "setspeed", data: [
                    "speed": s
                ])
            }
        } else {
            send(event: "setspeed", data: [
                "speed": s
            ])
        }
    }
    // get global pattern speed setting
    func getSpeed() {
        send(event: "getspeed", data: "")
    }
    // create new blank pattern
    func newPattern() {
        send(event: "newpattern", data: [ ])
    }
    // load current pattern data
    func loadPattern(id: String) {
        send(event: "loadpattern", data: [
            "id": id
        ])
    }
    // rename pattern
    func renamePattern(id: String, name: String) {
        send(event: "renamepattern", data: [
            "id": id, "name": name
        ])
    }
    // delete pattern
    func deletePattern(id: String) {
        send(event: "deletepattern", data: [
            "id": id
        ])
    }
    // play pattern
    func playPattern(id: String) {
        send(event: "playpattern", data: [
            "id": id
        ])
    }
    // add pattern color
    func addPatternColor(id: String) {
        send(event: "addpatterncolor", data: [
            "id": id
        ])
    }
    // update pattern color
    func updatePatternColor(id: String, colorID: Int, colorData: PatternItem) {
        send(event: "updatepatterncolor", data: [
            "id": id,
            "colorID": colorID,
            "colorData": [
                "fade": colorData.fade,
                "r": colorData.red,
                "g": colorData.green,
                "b": colorData.blue,
                "time": colorData.hold
            ]
        ])
    }
    // move pattern color
    func movePatternColor(id: String, colorID: Int, newPos: Int) {
        send(event: "movepatterncolor", data: [
            "id": id,
            "colorID": colorID,
            "newPos": newPos
        ])
    }
    // delete pattern color
    func deletePatternColor(id: String, colorID: Int) {
        send(event: "deletepatterncolor", data: [
            "id": id,
            "colorID": colorID
        ])
    }
    // play music
    func playMusic() {
        send(event: "music", data: "")
    }
    // get currently playing
    func getCurrentlyPlaying() {
        send(event: "getcurrent", data: "")
    }
    // get arduino status
    func getArduinoStatus() {
        send(event: "getarduinostatus", data: "")
    }
    // send back currently playing, if any
    func sendCurrent() {
        if currentItemType == "hue" {
            if let currentColor = currentItemCData {
                send(event: "testcolor", data: [
                    "r": currentColor.0, "g": currentColor.1, "b": currentColor.2
                ])
            }
        } else if currentItemType == "pattern" {
            if let currentPattern = currentItemPData {
                playPattern(id: currentPattern.0)
            }
        }
    }
    
}
