//
//  WebSocketWrapper.swift
//  LEDLights
//
//  Created by Anuv Gupta on 6/16/19.
//  Copyright © 2019 Anuv Gupta. All rights reserved.
//

import UIKit
import Foundation
import Starscream
import SwiftyJSON

class WSWrapper : WebSocketDelegate {
    
    // WebSocket client connection
    var socket: WebSocket = WebSocket(url: URL(string: "ws://10.204.204.168:30003")!)
//    var socket: WebSocket = WebSocket(url: URL(string: "ws://10.0.1.40:30003")!)
    
    // WebSocket client delegate handlers
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket connected")
        if let loginVC = bridge.loginVC {
            let saved_password = ws.getSavedPassword()
            if (saved_password.count > 0) {
                ws.login(password: saved_password)
            } else {
                loginVC.showLoginStack()
            }
        }
    }
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket disconnected", error ?? "")
    }
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("websocket received message: ", text)
        let json : JSON = decode(data: text)
        let event : String = json["event"].stringValue
        switch (event) {
            case "auth": // authentication accepted
                // save/remember password, switch to colors view
                let data: Bool = json["data"].boolValue;
                if (data == true) {
                    if let loginVC = bridge.loginVC {
                        UserDefaults.standard.set(lastPassword, forKey: "password")
                        loginVC.performSegue(withIdentifier: "loginSegue", sender: self)
                    }
                }
                break;
            case "colorpalette": // color palette received
                // sort and load color presets as views
                if let colorsVC = bridge.colorsVC {
                    colorsVC.clearColorPresets()
                    var colorPresets : [ColorPreset] = []
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
                    for preset : ColorPreset in colorPresets {
                        colorsVC.addColorView(preset: preset)
                    }
                }
                break;
            case "newcolor": // new color preset received
                // load color preset as view
                if let colorsVC = bridge.colorsVC {
                    colorsVC.addColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: json["data"]["d"].intValue,
                        id: json["data"]["id"].stringValue
                    ))
                }
                break;
            case "deletecolor": // color preset deleted
                // re-request and reload color palette
                // (instead of deleting from and rearranging existing palette)
                requestColorPalette()
                break;
            case "updatecolor": // color preset updated
                // update color's view with updated preset
                if let colorsVC = bridge.colorsVC {
                    colorsVC.updateColorView(preset: ColorPreset(
                        red: json["data"]["r"].intValue,
                        green: json["data"]["g"].intValue,
                        blue: json["data"]["b"].intValue,
                        timestamp: 0, id: json["data"]["id"].stringValue
                    ))
                }
                break;
            case "patternlist": // pattern list received
                // load patterns as views
                if let patternsVC = bridge.patternsVC {
                    patternsVC.clearPatternList()
                    for (key, data) : (String, JSON) in json["data"] {
                        patternsVC.addPattern(pattern: Pattern(
                            id: data["id"].stringValue,
                            name: data["name"].stringValue
                        ))
                    }
                }
                break;
            default: // unknown event received
                print("unknown event: " + event)
                break;
        }
    }
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("websocket received data: ", data)
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
        var decoded : JSON = JSON("null")
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
    func updateColor(id: String, interval : Bool) {
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastUpdateColorIntervalTickMS >= 50) {
                lastUpdateColorIntervalTickMS = nowMS
                send(event: "updatecolor", data: [
                    "r": r, "g": g, "b": b, "id": id
                    ])
            }
        } else {
            send(event: "updatecolor", data: [
                "r": r, "g": g, "b": b, "id": id
                ])
        }
    }
    // send color preset to arduino through server
    var lastTestColorIntervalTickMS = 0;
    func testColor(interval : Bool) {
        if (interval) {
            let nowMS = msTimeStamp()
            if (nowMS - lastTestColorIntervalTickMS >= 100) {
                lastTestColorIntervalTickMS = nowMS
                send(event: "direct_silent", data: "@h-" + rgbstring(r: r, g: g, b: b))
            }
        } else {
            // print(rgbstring(r: r, g: g, b: b))
            send(event: "direct", data: "@h-" + rgbstring(r: r, g: g, b: b))
        }
    }
    
}

