// libraries
const http = require("http");
const express = require("express");
const rn = require("random-number");
const WebSocket = require("ws");
const arrayMove = require("array-move");
const bodyParser = require("body-parser");
const fs = require("fs");
const secrets = require("./secrets.js")

// constants
const test = process.argv.slice(2)[0] == "test";
const wss_port = test ? 30003 : 3003;
const http_port = test ? 30002 : 3002;
const password = secrets.password;

// convenience logger
const DEBUG = test;
function log(category, message1, message2 = "", override = false) {
    if (DEBUG || override) {
        console.log("[" + category + "]", message1, message2);
    }
}
// ws server
const wss = new WebSocket.Server({ port: wss_port });
var ws_online = false;
var clients = {}; // client socket list
var database; // database of color presets, patterns, currently playing
try {
    // load from file
    fs.readFile("database.json", function(err, data) {
        if (err) throw err;
        database = JSON.parse(data);
    });
} catch (e) {
    log("db", "file read error", e, true);
    // default empty database
    database = {
        colors: {},
        patterns: {},
        currentPattern: null,
        currentHue: null,
        currentMusic: false,
        brightness: 100,
        speed: 100
    };
}
// save database async (for while running)
function saveDB() {
    var dbjson = JSON.stringify(database);
    fs.writeFile("database.json", dbjson, function(e) {
        if (e) {
            log("db", "file save error", e, true);
        } else log("db", "file saved");
    });
}
// save database sync (for on quit)
function saveDBSync() {
    var dbjson = JSON.stringify(database);
    fs.writeFileSync("database.json", dbjson);
    log("db", "file saved");
}

// exit handler
// process.stdin.resume();
// function exitHandler(options, code) {
//     // if (options.cleanup) console.log("clean");
//     saveDBSync(); // save db on exit
//     // if (code || code === 0) console.log(code);
//     if (options.exit) process.exit();
// }
// process.on("exit", exitHandler.bind(null, { cleanup: true })); // app exit
// process.on("SIGINT", exitHandler.bind(null, { exit: true })); // ctrl+c
// process.on("SIGUSR1", exitHandler.bind(null, { exit: true })); // kill pid
// process.on("SIGUSR2", exitHandler.bind(null, { exit: true })); // kill pid
// process.on("uncaughtException", exitHandler.bind(null, { exit: true })); // catch exception

// encode event+data to JSON
function encodeMSG(e, d) {
    return JSON.stringify({
        event: e,
        data: d
    });
}
// decode event+data from JSON
function decodeMSG(m) {
    try {
        m = JSON.parse(m);
    } catch (e) {
        log("ws", "invalid json msg", e);
        m = null;
    }
    return m;
}
// generate random alphanumeric key
function randID(length = 10) {
    key = "";
    chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    for (var i = 0; i < length; i++)
        key +=
            chars[
                rn({
                    min: 0,
                    max: chars.length - 1,
                    integer: true
                })
            ];
    return key;
}
// left pad string
function lpad(s, width, char) {
    return s.length >= width
        ? s
        : (new Array(width).join(char) + s).slice(-width);
} // https://stackoverflow.com/questions/10841773/javascript-format-number-to-day-with-always-3-digits
// conver RGB values to padded RGB string
function rgbstring(r, g, b) {
    return (
        lpad(String(parseInt(r)), 3, "0") +
        lpad(String(parseInt(g)), 3, "0") +
        lpad(String(parseInt(b)), 3, "0")
    );
}
// send data to all non-arduino clients
function sendToAll(event, data) {
    for (var c_id in clients) {
        if (
            clients.hasOwnProperty(c_id) &&
            c_id != "arduino" &&
            clients[c_id] !== null &&
            clients[c_id].auth
        ) {
            clients[c_id].socket.send(encodeMSG(event, data));
        }
    }
}
// send data to almost all non-arduino clients (excluding one)
function sendToAllBut(event, data, client) {
    for (var c_id in clients) {
        if (
            clients.hasOwnProperty(c_id) &&
            c_id != "arduino" &&
            c_id != client.id &&
            clients[c_id] !== null &&
            clients[c_id].auth
        ) {
            clients[c_id].socket.send(encodeMSG(event, data));
        }
    }
}
// send data to arduino client
function sendToArduino(data) {
    if (
        clients.hasOwnProperty("arduino") &&
        clients["arduino"] !== null &&
        clients["arduino"].auth
    )
        clients["arduino"].socket.send(data);
}
// play current pattern
function playCurrentPattern() {
    // check for current pattern
    if (database.currentPattern != null) {
        // condense pattern into fRGBh strings
        var currentPattern = database.patterns[database.currentPattern.id];
        var pattern_string = "";
        for (var p_c in currentPattern.list) {
            var pattern_color = currentPattern.list[p_c];
            pattern_string +=
                lpad(pattern_color.fade, 5, "0") +
                rgbstring(pattern_color.r, pattern_color.g, pattern_color.b) +
                lpad(pattern_color.time, 5, "0") +
                ",";
        }
        pattern_string = pattern_string.substring(0, pattern_string.length - 1);
        // send pattern string to arduino
        log("ws", "playing pattern", database.currentPattern.id);
        sendToArduino("@p-" + pattern_string);
    }
}
// send currently playing to all
function getCurrentlyPlaying() {
    var current = {
        type: "none",
        data: null
    };
    if (database.currentMusic) current.type = "music";
    else if (database.currentPattern != null) {
        current.type = "pattern";
        current.data = database.currentPattern;
    } else if (database.currentHue != null) {
        current.type = "hue";
        current.data = database.currentHue;
    }
    return current;
}
// send color palette to client
function sendColorPalette(client) {
    client.socket.send(encodeMSG("colorpalette", database.colors));
    log("ws", "color palette update sent to client", client.id);
}
// send pattern list to client
function sendPatternList(client) {
    var names = [];
    // summarize pattern IDs and names
    for (var p in database.patterns) {
        if (database.patterns.hasOwnProperty(p)) {
            names.push({
                id: p,
                name: database.patterns[p].name
            });
        }
    }
    client.socket.send(encodeMSG("patternlist", names));
    log("ws", "pattern list update sent to client", client.id);
}
var arduinoTracker = {
    // arduino status tracking
    heartbeatInterval: 2700,
    heartbeatMonitorInterval: 1000,
    heartbeatMonitorThreshold: 4000,
    data: {
        lastEvent: "",
        lastTimestamp: 0
    },
    log: function(eventName) {
        arduinoTracker.data.lastEvent = eventName;
        arduinoTracker.data.lastTimestamp = Date.now();
        log("ws", "ARDUINO", eventName.toUpperCase());
        sendToAll("arduinostatus", arduinoTracker.data);
    },
    loop: function() {
        if (
            arduinoTracker.data.lastEvent != "disconnected" &&
            Date.now() - arduinoTracker.data.lastTimestamp >=
                arduinoTracker.heartbeatMonitorThreshold
        ) {
            arduinoTracker.log("disconnected");
        }
        setTimeout(function() {
            arduinoTracker.loop();
        }, arduinoTracker.heartbeatMonitorInterval);
    },
    sendTo: function(client) {
        client.socket.send(encodeMSG("arduinostatus", arduinoTracker.data));
    }
};

// websocket event handlers
wss.on("connection", function(ws) {
    // create client object on new connection
    var client = {
        socket: ws,
        id: randID(),
        auth: false
    };
    log("ws", "client " + client.id + " – connected");
    // client socket event handlers
    ws.addEventListener("message", function(m) {
        // console.log('[ws] client ' + client.id + ' – message: ');
        var d = decodeMSG(m.data); // parse message
        if (d != null) {
            // console.log('    ', d.event, d.data);
            // handle various events
            switch (d.event) {
                // client identifying as arduino
                case "arduinosync":
                    log(
                        "ws",
                        "client " + client.id + " – identified as ARDUINO"
                    );
                    // rename client in client list
                    var oldid = client.id;
                    client.id = "arduino";
                    clients["arduino"] = client;
                    clients[oldid] = null;
                    delete clients[oldid];
                    ws.send("@arduinosync");
                    arduinoTracker.log("connected");
                    break;
                // client arduino sending heartbeat
                case "arduinoheartbeat":
                    arduinoTracker.log("online");
                    setTimeout(function() {
                        sendToArduino("@hb");
                    }, arduinoTracker.heartbeatInterval);
                    break;
                // client authenticating
                case "auth":
                    // validate password
                    if (d.data.password == password) {
                        log("ws", "client " + client.id + " – authenticated");
                        // set auth in client list object
                        client.auth = true;
                        if (client.id == "arduino") {
                            // if arduino authenticated
                            ws.send("@auth"); // confirm auth with client
                            arduinoTracker.log("authenticated");
                            // send current brightness & speed
                            sendToArduino(
                                "@b-" + lpad(database.brightness, 3, "0")
                            );
                            sendToArduino("@s-" + lpad(database.speed, 3, "0"));
                            setTimeout(function() {
                                // send currently playing pattern or hue, if any
                                if (database.currentPattern != null) {
                                    playCurrentPattern();
                                } else if (database.currentHue != null) {
                                    sendToArduino(
                                        "@h-" + database.currentHue.colorstring
                                    );
                                } else if (database.currentMusic) {
                                    sendToArduino("@music");
                                }
                                // begin heartbeat
                                setTimeout(function() {
                                    sendToArduino("@hb");
                                }, 1000);
                            }, 500);
                        } else {
                            // if regular client
                            ws.send(encodeMSG("auth", "true")); // confirm auth with client
                            // send full color palette and pattern list
                            sendColorPalette(client);
                            sendPatternList(client);
                            // send currently playing
                            ws.send(
                                encodeMSG("current", getCurrentlyPlaying())
                            );
                            // send current brightness & speed
                            ws.send(
                                encodeMSG("brightness", database.brightness)
                            );
                            ws.send(encodeMSG("speed", database.speed));
                            // send arduino status
                            arduinoTracker.sendTo(client);
                        }
                    }
                    break;
                case "arduinostatus":
                    arduinoTracker.sendTo(client);
                    break;
                // client forwarding message directly to arduino
                case "direct":
                    if (!client.auth) break;
                    log("ws", "direct", d.data);
                    sendToArduino(d.data);
                    break;
                // client forwarding message directly to arduino (silent version)
                // meant for heavy series of realtime updates, reduces log clutter
                case "direct_silent":
                    if (!client.auth) break;
                    sendToArduino(d.data);
                    break;
                // client requesting color palette
                case "getcolorpalette":
                    if (!client.auth) break;
                    sendColorPalette(client);
                    break;
                // client requesting pattern list
                case "getpatternlist":
                    if (!client.auth) break;
                    sendPatternList(client);
                    break;
                // client creating new color preset
                case "newcolor":
                    if (!client.auth) break;
                    // generate color ID
                    var colorID = randID();
                    while (database.colors.hasOwnProperty(colorID))
                        colorID = randID();
                    d.data.r = parseInt(d.data.r);
                    d.data.g = parseInt(d.data.g);
                    d.data.b = parseInt(d.data.b);
                    log(
                        "ws",
                        "client " +
                            client.id +
                            " adding new color with id " +
                            colorID +
                            " – rgb(" +
                            d.data.r +
                            ", " +
                            d.data.g +
                            ", " +
                            d.data.b +
                            ")"
                    );
                    // add new color preset to database with current color RGB values
                    database.colors[colorID] = {
                        r: d.data.r,
                        g: d.data.g,
                        b: d.data.b,
                        d: Date.now(),
                        name: ""
                    };
                    // send new preset to all other clients
                    sendToAllBut(
                        "newcolor",
                        {
                            r: d.data.r,
                            g: d.data.g,
                            b: d.data.b,
                            id: colorID,
                            name: "",
                            switch: false
                        },
                        client
                    );
                    // send new preset back to original client
                    ws.send(
                        encodeMSG("newcolor", {
                            r: d.data.r,
                            g: d.data.g,
                            b: d.data.b,
                            id: colorID,
                            name: "",
                            switch: true // tells client to switch currently editing preset to the new preset
                        })
                    );
                    saveDB();
                    break;
                // client updating color preset
                case "updatecolor":
                    if (!client.auth) break;
                    d.data.r = parseInt(d.data.r);
                    d.data.g = parseInt(d.data.g);
                    d.data.b = parseInt(d.data.b);
                    log(
                        "ws",
                        "client " +
                            client.id +
                            " updating color " +
                            d.data.id +
                            " – rgb(" +
                            d.data.r +
                            ", " +
                            d.data.g +
                            ", " +
                            d.data.b +
                            ")"
                    );
                    // update color preset RGB values in database
                    database.colors[d.data.id].r = d.data.r;
                    database.colors[d.data.id].g = d.data.g;
                    database.colors[d.data.id].b = d.data.b;
                    // send color update to clients
                    sendToAll("updatecolor", {
                        r: d.data.r,
                        g: d.data.g,
                        b: d.data.b,
                        name: database.colors[d.data.id].name,
                        id: d.data.id
                    });
                    // save database if update is latent
                    // (latent = not part of a heavy series of immediate realtime updates)
                    if (d.data.latent) saveDB();
                    break;
                // client naming color preset
                case "namecolor":
                    if (!client.auth) break;
                    d.data.name = ("" + d.data.name).trim();
                    if (d.data.name == "") break;
                    log(
                        "ws",
                        "client " +
                            client.id +
                            " naming color " +
                            d.data.id +
                            " to " +
                            d.data.name
                    );
                    database.colors[d.data.id].name = d.data.name;
                    sendToAll("updatecolor", {
                        r: database.colors[d.data.id].r,
                        g: database.colors[d.data.id].g,
                        b: database.colors[d.data.id].b,
                        name: d.data.name,
                        id: d.data.id
                    });
                    saveDB();
                    break;
                // client deleting color preset
                case "deletecolor":
                    if (!client.auth) break;
                    log(
                        "ws",
                        "client " + client.id + " deleting color " + d.data.id
                    );
                    // remove color preset from database
                    database.colors[d.data.id] = null;
                    delete database.colors[d.data.id];
                    // send delete update to clients
                    sendToAll("deletecolor", { id: d.data.id });
                    saveDB();
                    break;
                // client testing color preset
                case "testcolor":
                    if (!client.auth) break;
                    d.data.r = parseInt(d.data.r);
                    d.data.g = parseInt(d.data.g);
                    d.data.b = parseInt(d.data.b);
                    // convert color RGB values ot RGB string
                    var colorstring = rgbstring(d.data.r, d.data.g, d.data.b);
                    log(
                        "ws",
                        "client " + client.id + " testing color " + colorstring
                    );
                    // update current hue
                    database.currentPattern = null;
                    database.currentHue = {
                        r: d.data.r,
                        g: d.data.g,
                        b: d.data.b,
                        colorstring: colorstring
                    };
                    database.currentMusic = false;
                    // send RGB string to arduino
                    sendToArduino("@h-" + colorstring);
                    // send currently playing to all
                    sendToAll("current", getCurrentlyPlaying());
                    break;
                // client testing color preset (silent version)
                // meant for heavy series of realtime updates, reduces log clutter
                case "testcolor_silent":
                    if (!client.auth) break;
                    d.data.r = parseInt(d.data.r);
                    d.data.g = parseInt(d.data.g);
                    d.data.b = parseInt(d.data.b);
                    var colorstring = rgbstring(d.data.r, d.data.g, d.data.b);
                    database.currentPattern = null;
                    database.currentHue = {
                        r: d.data.r,
                        g: d.data.g,
                        b: d.data.b,
                        colorstring: colorstring
                    };
                    database.currentMusic = false;
                    sendToArduino("@h-" + colorstring);
                    sendToAll("current", getCurrentlyPlaying());
                    break;
                // client creating new pattern
                case "newpattern":
                    if (!client.auth) break;
                    // generate new pattern ID
                    var patternID = randID();
                    while (database.patterns.hasOwnProperty(patternID))
                        patternID = randID();
                    log(
                        "ws",
                        "client " +
                            client.id +
                            " adding new pattern with id " +
                            patternID
                    );
                    // add pattern to database
                    database.patterns[patternID] = {
                        name: "untitled",
                        list: []
                    };
                    // send new pattern to clients
                    sendToAllBut(
                        "newpattern",
                        {
                            id: patternID,
                            name: "untitled",
                            switch: false
                        },
                        client
                    );
                    ws.send(
                        encodeMSG("newpattern", {
                            id: patternID,
                            name: "untitled"
                        })
                    );
                    saveDB();
                    break;
                // client loading pattern
                case "loadpattern":
                    if (!client.auth) break;
                    // check database for pattern
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        // send pattern data to client
                        ws.send(
                            encodeMSG("loadpattern", {
                                id: d.data.id,
                                name: database.patterns[d.data.id].name,
                                list: database.patterns[d.data.id].list
                            })
                        );
                    }
                    break;
                // client renaming pattern
                case "renamepattern":
                    if (!client.auth) break;
                    // check database for pattern
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        d.data.name = String(d.data.name).trim();
                        log(
                            "ws",
                            "client " +
                                client.id +
                                " renaming pattern " +
                                d.data.id +
                                "to " +
                                d.data.name
                        );
                        // set pattern name in database
                        database.patterns[d.data.id].name = d.data.name;
                        // send name update to clients
                        sendToAll("renamepattern", {
                            id: d.data.id,
                            name: d.data.name
                        });
                    }
                    saveDB();
                    break;
                // client playing pattern
                case "playpattern":
                    if (!client.auth) break;
                    // check database for pattern
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        // update current pattern
                        database.currentHue = null;
                        database.currentPattern = {
                            id: d.data.id,
                            name: database.patterns[d.data.id].name
                        };
                        database.currentMusic = false;
                        // summarize and send current pattern to arduino
                        playCurrentPattern();
                        // send currently playing
                        sendToAll("current", getCurrentlyPlaying());
                        saveDB();
                    }
                    break;
                // client adding color to pattern
                case "addpatterncolor":
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        log(
                            "ws",
                            "client " +
                                client.id +
                                " adding color to pattern " +
                                d.data.id
                        );
                        // add fRGBh color object to pattern in database
                        database.patterns[d.data.id].list.push({
                            fade: 0,
                            r: 0,
                            g: 0,
                            b: 0,
                            time: 0
                        });
                        // send full updated pattern to clients
                        sendToAll("updatepattern", {
                            id: d.data.id,
                            list: database.patterns[d.data.id].list
                        });
                        saveDB();
                    }
                    break;
                // client updating color in pattern
                case "updatepatterncolor":
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        log(
                            "ws",
                            "client " +
                                client.id +
                                " updating color " +
                                d.data.colorID +
                                " of pattern " +
                                d.data.id
                        );
                        // update fRGBh color object in pattern in database
                        var colorID = parseInt(d.data.colorID);
                        database.patterns[d.data.id].list[colorID].fade =
                            d.data.colorData.fade;
                        database.patterns[d.data.id].list[colorID].r =
                            d.data.colorData.r;
                        database.patterns[d.data.id].list[colorID].g =
                            d.data.colorData.g;
                        database.patterns[d.data.id].list[colorID].b =
                            d.data.colorData.b;
                        database.patterns[d.data.id].list[colorID].time =
                            d.data.colorData.time;
                        // send full updated pattern to clients
                        sendToAll("updatepattern", {
                            id: d.data.id,
                            list: database.patterns[d.data.id].list
                        });
                        saveDB();
                    }
                    break;
                // client moving color in pattern
                case "movepatterncolor":
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        log(
                            "ws",
                            "client " +
                                client.id +
                                " moving color " +
                                d.data.colorID +
                                " (to " +
                                d.data.newPos +
                                ") of pattern " +
                                d.data.id
                        );
                        // shift fRGBh color object position in list in preset in database
                        var colorID = parseInt(d.data.colorID);
                        arrayMove.mutate(
                            database.patterns[d.data.id].list,
                            d.data.colorID,
                            d.data.newPos
                        );
                        // send full updated pattern to clients
                        sendToAll("updatepattern", {
                            id: d.data.id,
                            list: database.patterns[d.data.id].list
                        });
                        saveDB();
                    }
                    break;
                // client deleting color from pattern
                case "deletepatterncolor":
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        log(
                            "ws",
                            "client " +
                                client.id +
                                " deleting color " +
                                d.data.colorID +
                                " of pattern " +
                                d.data.id
                        );
                        // remove color from pattern in database
                        database.patterns[d.data.id].list.splice(
                            d.data.colorID,
                            1
                        );
                        // send full updated pattern to clients
                        sendToAll("updatepattern", {
                            id: d.data.id,
                            list: database.patterns[d.data.id].list
                        });
                        saveDB();
                    }
                    break;
                // client deleting pattern
                case "deletepattern":
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        log(
                            "ws",
                            "client " +
                                client.id +
                                " deleting pattern " +
                                d.data.id
                        );
                        // remove pattern from database
                        database.patterns[d.data.id] = null;
                        delete database.patterns[d.data.id];
                        // update currently playing
                        if (d.data.id == database.currentPattern) {
                            database.currentPattern = null;
                            sendToAll("current", getCurrentlyPlaying());
                        }
                        // send deleted pattern id to clients
                        sendToAllBut(
                            "deletepattern",
                            {
                                id: d.data.id
                            },
                            client
                        );
                        ws.send(
                            encodeMSG("deletepattern", {
                                id: d.data.id
                            })
                        );
                        saveDB();
                    }
                    break;
                // client setting brightness
                case "setbrightness":
                    if (!client.auth) break;
                    log(
                        "ws",
                        "client " +
                            client.id +
                            " setting brightness to " +
                            d.data.brightness
                    );
                    // correct brightness
                    d.data.brightness = parseInt(d.data.brightness);
                    if (isNaN(d.data.brightness)) d.data.brightness = 100;
                    if (d.data.brightness < 0) d.data.brightness = 0;
                    if (d.data.brightness > 100) d.data.brightness = 100;
                    // send brightness to all clients
                    database.brightness = d.data.brightness;
                    sendToAllBut("brightness", database.brightness, client);
                    // send brightness to arduino
                    sendToArduino("@b-" + lpad(database.brightness, 3, "0"));
                    break;
                // client setting speed
                case "setspeed":
                    if (!client.auth) break;
                    log(
                        "ws",
                        "client " +
                            client.id +
                            " setting speed to " +
                            d.data.speed
                    );
                    // correct speed
                    d.data.speed = parseInt(d.data.speed);
                    if (isNaN(d.data.speed)) d.data.speed = 100;
                    if (d.data.speed < 0) d.data.speed = 0;
                    if (d.data.speed > 500) d.data.speed = 500;
                    // send speed to all clients
                    database.speed = d.data.speed;
                    sendToAllBut("speed", database.speed, client);
                    // send speed to arduino
                    sendToArduino("@s-" + lpad(d.data.speed, 3, "0"));
                    break;
                // client requesting global brightness
                case "getbrightness":
                    if (!client.auth) break;
                    ws.send(encodeMSG("brightness", database.brightness));
                    break;
                // client requesting global pattern speed
                case "getspeed":
                    if (!client.auth) break;
                    ws.send(encodeMSG("speed", database.speed));
                    break;
                // client requesting currently playing
                case "getcurrent":
                    if (!client.auth) break;
                    ws.send(encodeMSG("current", getCurrentlyPlaying()));
                    break;
                // client requesting arduino status
                case "getarduinostatus":
                    if (!client.auth) break;
                    arduinoTracker.sendTo(client);
                    break;
                // client playing music mode
                case "music":
                    log("ws", "play music (beta)");
                    database.currentHue = null;
                    database.currentPattern = null;
                    database.currentMusic = true;
                    // send currently playing to all
                    sendToAll("current", getCurrentlyPlaying());
                    // send to arduino
                    sendToArduino("@music");
                    break;
                // client sent unknown event
                default:
                    log("ws", "unknown event", d.event);
                    break;
            }
        } else {
            // console.log('[ws] invalid message', m.data)
        }
    });
    ws.addEventListener("error", function(e) {
        log("ws", "client " + client.id + " – error", e, true);
    });
    ws.addEventListener("close", function(c, r) {
        log("ws", "client " + client.id + " – disconnected");
        if (client.id == "arduino") arduinoTracker.log("disconnected");
        delete clients[client.id]; // remove client object on disconnect
    });
    // add client object to client object list
    clients[client.id] = client;
});
wss.on("listening", function() {
    log("ws", "listening on", wss_port, true);
    ws_online = true;
    arduinoTracker.loop();
});
wss.on("error", function(e) {
    log("ws", "server error", e, true);
    ws_online = false;
});
wss.on("close", function() {
    log("ws", "server closed", "", true);
    ws_online = false;
});

// http server
var app = express();
var server = http.Server(app);
app.use(bodyParser.json());
app.use(
    bodyParser.urlencoded({
        extended: true
    })
);
app.use(function(req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header(
        "Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept"
    );
    next();
});
app.use(express.static("html"));
app.get("/", function(req, res) {
    res.sendFile(__dirname + "/html/index.html");
});
var api = {
    auth: function(req, res, next) {
        if (
            req.headers.authorization &&
            req.headers.authorization.trim() == password
        ) {
            next(req, res);
        } else {
            res.send({
                success: false,
                message: "incorrect password",
                payload: {}
            });
        }
    },
    ws_online: function(req, res, next) {
        if (ws_online) {
            next(req, res);
        } else {
            res.send({
                success: false,
                message: "websocket service offline",
                payload: {}
            });
        }
    },
    require: function(param_name, req, res, next, fail = null) {
        var param_val = ("" + req.body[param_name]).trim();
        if (
            req.body.hasOwnProperty(param_name) &&
            param_val &&
            param_val != ""
        ) {
            next(param_val, req, res);
        } else {
            if (fail) fail(req, res);
            else {
                res.send({
                    success: false,
                    message: "parameter '" + param_name + "' required",
                    payload: {}
                });
            }
        }
    }
};

app.get("/api", function(req, res) {
    api.auth(req, res, function(req, res) {
        res.send({
            success: true,
            message: "led-lights api",
            payload: {}
        });
    });
});
app.get("/api/arduinostatus", function(req, res) {
    api.auth(req, res, function(req, res) {
        api.ws_online(req, res, function(req, res) {
            var lastEvent = arduinoTracker.data.lastEvent;
            var lastTimestamp = arduinoTracker.data.lastTimestamp;
            var deltaSec =
                parseInt(Date.now() / 1000) - parseInt(lastTimestamp / 1000);
            if (deltaSec < 0) deltaSec = 0;
            var humanReadableTime = "";
            if (deltaSec < 5) humanReadableTime += "now";
            else if (deltaSec < 60)
                humanReadableTime +=
                    "" +
                    parseInt(Math.floor(parseFloat(deltaSec) / 5.0) * 5.0) +
                    " seconds ago";
            else if (deltaSec < 3600) {
                var mins = parseInt(deltaSec / 60);
                if (mins == 1) {
                    humanReadableTime += "" + mins + " minute ago";
                } else {
                    humanReadableTime += "" + mins + " minutes ago";
                }
            } else {
                var hrs = parseInt(deltaSec / 3600);
                if (hrs == 1) {
                    humanReadableTime += "" + hrs + " hour ago";
                } else {
                    humanReadableTime += "" + hrs + " hours ago";
                }
            }
            res.send({
                success: true,
                message: "arduino status retrieved",
                payload: {
                    status: {
                        event: lastEvent,
                        timestamp: lastTimestamp,
                        humantime: humanReadableTime
                    }
                }
            });
        });
    });
});
app.get("/api/colorlist", function(req, res) {
    api.auth(req, res, function(req, res) {
        var colors = [];
        for (var c in database.colors) {
            if (database.colors.hasOwnProperty(c)) {
                colors.push({
                    id: c,
                    name: database.colors[c].name
                });
            }
        }
        res.send({
            success: true,
            message: "color list retrieved",
            payload: { colors: colors }
        });
    });
});
app.post("/api/testcolor", function(req, res) {
    api.auth(req, res, function(req, res) {
        api.ws_online(req, res, function(req, res) {
            api.require("name", req, res, function(name, req, res) {
                var id = "";
                for (var c in database.colors) {
                    if (database.colors[c].name == name) {
                        id = c;
                        break;
                    }
                }
                if (id != "") {
                    var color = database.colors[id];
                    // convert color RGB values to RGB string
                    var colorstring = rgbstring(color.r, color.g, color.b);
                    log("http", "alexa client testing color " + colorstring);
                    // update current hue
                    database.currentPattern = null;
                    database.currentHue = {
                        r: color.r,
                        g: color.g,
                        b: color.b,
                        colorstring: colorstring
                    };
                    database.currentMusic = false;
                    // send RGB string to arduino
                    sendToArduino("@h-" + colorstring);
                    // send currently playing to all
                    sendToAll("current", getCurrentlyPlaying());
                    saveDB();
                    res.send({
                        success: true,
                        message: "testing color " + name + " (" + id + ")",
                        payload: {
                            id: id,
                            name: name,
                            rgb: colorstring
                        }
                    });
                } else {
                    res.send({
                        success: false,
                        message: "color '" + name + "' does not exist",
                        payload: {}
                    });
                }
            });
        });
    });
});
app.get("/api/patternlist", function(req, res) {
    api.auth(req, res, function(req, res) {
        var patterns = [];
        for (var p in database.patterns) {
            if (database.patterns.hasOwnProperty(p)) {
                patterns.push({
                    id: p,
                    name: database.patterns[p].name
                });
            }
        }
        res.send({
            success: true,
            message: "pattern list retrieved",
            payload: {
                patterns: patterns
            }
        });
    });
});
app.post("/api/playpattern", function(req, res) {
    api.auth(req, res, function(req, res) {
        api.ws_online(req, res, function(req, res) {
            api.require("name", req, res, function(name, req, res) {
                var id = "";
                var realName = "";
                for (var p in database.patterns) {
                    if (
                        database.patterns[p].name.toLowerCase() ==
                        name.toLowerCase()
                    ) {
                        id = p;
                        realName = database.patterns[p].name;
                        break;
                    }
                }
                if (id != "") {
                    log("http", "alexa client playing pattern " + id);
                    // update current pattern
                    database.currentHue = null;
                    database.currentPattern = {
                        id: id,
                        name: database.patterns[p].name
                    };
                    database.currentMusic = false;
                    // summarize and send current pattern to arduino
                    playCurrentPattern();
                    // send currently playing
                    sendToAll("current", getCurrentlyPlaying());
                    saveDB();
                    res.send({
                        success: true,
                        message:
                            "playing pattern " + realName + " (" + id + ")",
                        payload: {
                            id: id,
                            name: realName
                        }
                    });
                } else {
                    res.send({
                        success: false,
                        message: "pattern '" + name + "' does not exist",
                        payload: {}
                    });
                }
            });
        });
    });
});
app.post("/api/playcurrent", function(req, res) {
    api.auth(req, res, function(req, res) {
        api.ws_online(req, res, function(req, res) {
            var current = getCurrentlyPlaying();
            if (current.type == "pattern") playCurrentPattern();
            else if (current.type == "hue")
                sendToArduino("@h-" + current.data.colorstring);
            res.send({
                success: true,
                message: "playing current",
                payload: { current: current }
            });
        });
    });
});
app.get("/api/brightness", function(req, res) {
    api.auth(req, res, function(req, res) {
        res.send({
            success: true,
            message: "brightness retrieved",
            payload: { level: database.brightness }
        });
    });
});
app.post("/api/brightness", function(req, res) {
    api.auth(req, res, function(req, res) {
        api.ws_online(req, res, function(req, res) {
            api.require(
                "level",
                req,
                res,
                function(level, req, res) {
                    log("http", "alexa client setting brightness to " + level);
                    // correct brightness
                    level = parseInt(level);
                    if (isNaN(level)) level = 100;
                    if (level < 0) level = 0;
                    if (level > 100) level = 100;
                    // send brightness to all clients
                    database.brightness = level;
                    sendToAll("brightness", database.brightness);
                    // send brightness to arduino
                    sendToArduino("@b-" + lpad(database.brightness, 3, "0"));
                    res.send({
                        success: true,
                        message: "brightness updated",
                        payload: { level: database.brightness }
                    });
                },
                function(req, res) {
                    api.require(
                        "increment",
                        req,
                        res,
                        function(increment, req, res) {
                            if (increment == "up") {
                                increment = 5;
                            } else if (increment == "down") {
                                increment = -5;
                            }
                            increment = parseInt(increment);
                            if (isNaN(increment)) increment = 5;
                            var newbrightness = database.brightness + increment;
                            if (newbrightness < 0) newbrightness = 0;
                            if (newbrightness > 100) newbrightness = 100;
                            database.brightness = newbrightness;
                            sendToAll("brightness", database.brightness);
                            sendToArduino(
                                "@b-" + lpad(database.brightness, 3, "0")
                            );
                            res.send({
                                success: true,
                                message: "brightness updated",
                                payload: {
                                    level: database.brightness
                                }
                            });
                        },
                        function(req, res) {
                            res.send({
                                success: false,
                                message:
                                    "parameter 'level' or 'increment' required",
                                payload: {}
                            });
                        }
                    );
                }
            );
        });
    });
});
app.get("/api/speed", function(req, res) {
    api.auth(req, res, function(req, res) {
        res.send({
            success: true,
            message: "speed retrieved",
            payload: { level: database.speed }
        });
    });
});
app.post("/api/speed", function(req, res) {
    api.auth(req, res, function(req, res) {
        api.ws_online(req, res, function(req, res) {
            api.require(
                "level",
                req,
                res,
                function(level, req, res) {
                    log("http", "alexa client setting speed to " + level);
                    // correct brightness
                    level = parseInt(level);
                    if (isNaN(level)) level = 500;
                    if (level < 0) level = 0;
                    if (level > 500) level = 500;
                    // send brightness to all clients
                    database.speed = level;
                    sendToAll("speed", database.speed);
                    // send brightness to arduino
                    sendToArduino("@s-" + lpad(database.speed, 3, "0"));
                    res.send({
                        success: true,
                        message: "speed updated",
                        payload: {
                            level: database.speed
                        }
                    });
                },
                function(req, res) {
                    api.require(
                        "increment",
                        req,
                        res,
                        function(increment, req, res) {
                            if (increment == "up") {
                                increment = 20;
                            } else if (increment == "down") {
                                increment = -20;
                            }
                            increment = parseInt(increment);
                            if (isNaN(increment)) increment = 10;
                            var newspeed = database.speed + increment;
                            if (newspeed < 0) newspeed = 0;
                            if (newspeed > 500) newspeed = 500;
                            database.speed = newspeed;
                            sendToAll("speed", database.speed);
                            sendToArduino("@s-" + lpad(database.speed, 3, "0"));
                            res.send({
                                success: true,
                                message: "speed updated",
                                payload: {
                                    level: database.speed
                                }
                            });
                        },
                        function(req, res) {
                            res.send({
                                success: true,
                                message:
                                    "parameter 'level' or 'increment' required",
                                payload: {}
                            });
                        }
                    );
                }
            );
        });
    });
});

server.listen(http_port, function() {
    log("http", "listening on", http_port, true);
});

console.log("RGB Lights Control");
