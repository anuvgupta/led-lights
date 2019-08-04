/* LIBRARIES */
const websocket = require("ws");
const http = require("http");
const express = require("express");
const random_number = require("random-number");
const array_move = require("array-move");
const body_parser = require("body-parser");
const read_line = require('readline');
const file_system = require("fs");
const secrets = require("./secrets");

/* CONSTANTS */
const debug = process.argv.slice(2)[0] == "debug";
const wss_port = debug ? 30003 : 3003;
const http_port = debug ? 30002 : 3002;
const password = secrets.password;

/* UTILITIES */
var util = {
    // log levels (0 = top priority)
    ERR: 0, // errors
    IMP: 1, // important info
    INF: 2, // unimportant info
    REP: 3, // repetitive info
    EXT: 4, // extra info
    LEVEL: debug ? 2 : 1,
    log: function (category, level, message1, message2 = "") {
        if (level <= util.LEVEL) {
            console.log("[" + category + "]", message1, message2);
        }
    },
    input: read_line.createInterface({
        input: process.stdin,
        output: process.stdout
    }),
    // generate random alphanumeric key
    rand_id: function (length = 10) {
        var key = "";
        var chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
        for (var i = 0; i < length; i++)
            key += chars[random_number({
                min: 0,
                max: chars.length - 1,
                integer: true
            })];
        return key;
    },
    // left pad string
    lpad: function (s, width, char) {
        return s.length >= width
            ? s
            : (new Array(width).join(char) + s).slice(-width);
    },
    // validate/correct bounded integer
    validate_int: function (n, l_b, u_b) {
        n = parseInt(Math.round(parseFloat(n)));
        if (n < l_b) n = l_b;
        else if (n > u_b) n = u_b;
        return n;
    },
    // convert RGB values to padded RGB string
    rgb_string: function (r, g, b) {
        return (
            util.lpad(String(parseInt(r)), 3, "0") +
            util.lpad(String(parseInt(g)), 3, "0") +
            util.lpad(String(parseInt(b)), 3, "0")
        );
    },
    // validate/correct rgb integer
    rgb_validate: function (n) {
        return util.validate_int(n, 0, 255);
    },
    condense_pattern: function (p) {
        // condense pattern into fRGBh strings
        var pattern_string = "";
        for (var p_c in p.list) {
            var pattern_color = p.list[p_c];
            pattern_string +=
                util.lpad(pattern_color.fade, 5, "0") +
                util.rgb_string(pattern_color.r, pattern_color.g, pattern_color.b) +
                util.lpad(pattern_color.time, 5, "0") +
                ",";
        }
        pattern_string = pattern_string.substring(0, pattern_string.length - 1);
        return pattern_string;
    }
};

/* DATABASE */
var database = {
    data: {
        colors: {},
        patterns: {},
        devices: {}
    },
    // save database async (for while running)
    save: function (pretty = debug) {
        var db_json = pretty ? JSON.stringify(database.data, null, 3) : JSON.stringify(database.data);
        file_system.writeFile("database.json", db_json, function (e) {
            if (e) {
                util.log("db", util.ERR, "file save error", e, true);
            } else util.log("db", util.INF, "file saved");
        });
    },
    // save database sync (for on quit)
    save_sync: function () {
        var db_json = JSON.stringify(database.data);
        file_system.writeFileSync("database.json", db_json);
        util.log("db", util.INF, "file saved");
    },
    load: function () {
        try {
            // load from file
            file_system.readFile("database.json", function (err, data) {
                try {
                    if (err) throw err;
                    data = JSON.parse(data);
                    database.data = data;
                } catch (e) {
                    util.log("db", util.ERR, "file read error", e, true);
                }
            });
        } catch (e) {
            util.log("db", util.ERR, "file read error", e, true);
        }
    }
};
// exit handler
// process.stdin.resume();
// function exitHandler(options, code) {
//     // if (options.cleanup) console.log("clean");
//     database.save_sync(); // save db on exit
//     // if (code || code === 0) console.log(code);
//     if (options.exit) process.exit();
// }
// process.on("exit", exitHandler.bind(null, { cleanup: true })); // app exit
// process.on("SIGINT", exitHandler.bind(null, { exit: true })); // ctrl+c
// process.on("SIGUSR1", exitHandler.bind(null, { exit: true })); // kill pid
// process.on("SIGUSR2", exitHandler.bind(null, { exit: true })); // kill pid
// process.on("uncaughtException", exitHandler.bind(null, { exit: true })); // catch exception

/* WEBSOCKET SERVER */
var wss = {
    socket: new websocket.Server({ port: wss_port }),
    online: false,
    clients: {}, // client sockets
    events: {}, // event handlers
    // encode event+data to JSON
    encode_msg: function (e, d) {
        return JSON.stringify({
            event: e,
            data: d
        });
    },
    // decode event+data from JSON
    decode_msg: function (m) {
        try {
            m = JSON.parse(m);
        } catch (e) {
            util.log("ws", util.ERR, "invalid json msg", e);
            m = null;
        }
        return m;
    },
    // send data to specific authenticated non-arduino client
    send_to_client: function (event, data, client) {
        client.socket.send(wss.encode_msg(event, data));
    },
    // send data to all authenticated non-arduino clients
    send_to_clients: function (event, data) {
        for (var c_id in wss.clients) {
            if (
                wss.clients.hasOwnProperty(c_id) &&
                c_id.substring(0, 7) != "arduino" &&
                wss.clients[c_id] !== null &&
                wss.clients[c_id].auth
            ) {
                wss.clients[c_id].socket.send(wss.encode_msg(event, data));
            }
        }
    },
    // send data to almost all authenticated non-arduino clients (excluding one)
    send_to_clients_but: function (event, data, client) {
        for (var c_id in wss.clients) {
            if (
                wss.clients.hasOwnProperty(c_id) &&
                c_id.substring(0, 7) != "arduino" &&
                c_id != client.id &&
                wss.clients[c_id] !== null &&
                wss.clients[c_id].auth
            ) {
                wss.clients[c_id].socket.send(wss.encode_msg(event, data));
            }
        }
    },
    // send color palette to client
    send_color_palette: function (client) {
        wss.send_to_client("color_palette", database.data.colors, client);
        util.log("ws", util.INF, `color palette update sent to client ${client.id}`);
    },
    // send pattern list to client
    send_pattern_list: function (client) {
        var patterns = database.data.patterns;
        var pattern_list = [];
        // summarize pattern IDs and names
        for (var p in patterns) {
            if (patterns.hasOwnProperty(p)) {
                pattern_list.push({
                    id: p,
                    name: patterns[p].name
                });
            }
        }
        wss.send_to_client("pattern_list", pattern_list, client);
        util.log("ws", util.INF, `pattern list update sent to client ${client.id}`);
    },
    // send data to arduino client
    send_to_arduino: function (device_id, data) {
        if (
            wss.clients.hasOwnProperty(device_id) &&
            wss.clients[device_id] !== null
        )
            wss.clients[device_id].socket.send(data);
    },
    test_color: function (device_id, color, latent = true) {
        var db = database.data;
        if (db.devices.hasOwnProperty(device_id)) {
            // convert color RGB values to RGB string
            if (!color.hasOwnProperty('left')) {
                if (db.devices[device_id].current.type == "hue") {
                    color.left = db.devices[device_id].current.data.left;
                } else {
                    color.left = {
                        r: 0, g: 0, b: 0,
                        string: "000000000"
                    };
                }
            } else {
                color.left.r = util.rgb_validate(color.left.r);
                color.left.g = util.rgb_validate(color.left.g);
                color.left.b = util.rgb_validate(color.left.b);
                color.left.string = util.rgb_string(color.left.r, color.left.g, color.left.b);
            }
            if (!color.hasOwnProperty('right')) {
                if (db.devices[device_id].current.type == "hue") {
                    color.right = db.devices[device_id].current.data.right;
                } else {
                    color.right = {
                        r: 0, g: 0, b: 0,
                        string: "000000000"
                    };
                }
            } else {
                color.right.r = util.rgb_validate(color.right.r);
                color.right.g = util.rgb_validate(color.right.g);
                color.right.b = util.rgb_validate(color.right.b);
                color.right.string = util.rgb_string(color.right.r, color.right.g, color.right.b);
            }
            util.log("ws", latent ? util.INF : util.REP, `testing color ${color.left.string}–${color.right.string} on device ${device_id}`);
            // update current hue
            db.devices[device_id].current.type = "hue";
            db.devices[device_id].current.data = {
                left: color.left,
                right: color.right
            };
            // send RGB string to arduino
            wss.play_current(device_id);
            // send currently playing to all
            wss.send_to_clients("current", {
                device_id: device_id,
                data: db.devices[device_id].current
            });
            // save database if update is latent
            if (latent) database.save();
        }
    },
    play_pattern: function (device_id, pattern_id) {
        var db = database.data;
        if (db.devices.hasOwnProperty(device_id) && db.patterns.hasOwnProperty(pattern_id)) {
            // update current pattern
            db.devices[device_id].current.type = "pattern";
            db.devices[device_id].current.data = {
                id: pattern_id,
                name: db.patterns[pattern_id].name
            };
            // summarize and send current pattern to arduino
            util.log("ws", util.INF, `playing pattern ${pattern_id} on device ${device_id}`);
            wss.play_current(device_id);
            // send currently playing
            wss.send_to_clients("current", {
                device_id: device_id,
                data: db.devices[device_id].current
            });
            database.save();
        }
    },
    play_current: function (device_id) {
        if (database.data.devices.hasOwnProperty(device_id)) {
            var current = database.data.devices[device_id].current;
            if (current.type == "pattern")
                wss.send_to_arduino(device_id, "@p-" + util.condense_pattern(database.data.patterns[current.data.id]));
            else if (current.type == "hue")
                wss.send_to_arduino(device_id, "@h-" + "l" + current.data.left.string + "r" + current.data.right.string);
            else if (current.type == 'music')
                wss.send_to_arduino(device_id, "@music");
        }
    },
    // arduino status tracking
    arduino_tracker: {
        heartbeat_interval: 2700, // how often to send heartbeats
        heartbeat_monitor_interval: 1000, // how often to check arduino statuses
        heartbeat_monitor_threshold: 4000, // how much time arduinos have to respond to heartbeat
        log: function (device_id, event_name) {
            if (!database.data.devices.hasOwnProperty(device_id)) {
                wss.create_device(device_id);
            }
            var rep_ol = event_name == 'online' && database.data.devices[device_id].last_event == 'online';
            database.data.devices[device_id].last_event = event_name;
            database.data.devices[device_id].last_timestamp = Date.now();
            if (rep_ol) util.log("ws", util.REP, "ARDUINO: " + device_id, event_name);
            else util.log("ws", util.INF, "ARDUINO: " + device_id, event_name);
            wss.send_to_clients("device_list", database.data.devices);
        },
        loop: function () {
            for (var d in database.data.devices) {
                if (database.data.devices.hasOwnProperty(d)) {
                    if (
                        database.data.devices[d].last_event != "disconnected" &&
                        Date.now() - database.data.devices[d].last_timestamp >=
                        wss.arduino_tracker.heartbeat_monitor_threshold
                    ) {
                        wss.arduino_tracker.log(d, "disconnected");
                    }
                }
            }
            wss.arduino_tracker.reloop();
        },
        reloop: function () {
            setTimeout(function () {
                wss.arduino_tracker.loop();
            }, wss.arduino_tracker.heartbeat_monitor_interval);
        }
    },
    create_device: function (device_id) {
        if (!database.data.devices.hasOwnProperty(device_id)) {
            database.data.devices[device_id] = {
                name: device_id,
                last_event: "",
                last_timestamp: 0,
                current: {
                    type: "none",
                    data: null
                },
                brightness: 100,
                speed: 100
            };
        }
    },
    // bind handler to client event
    bind: function (event, handler, auth_req = true) {
        wss.events[event] = function (client, req, db) {
            if (!auth_req || client.auth)
                handler(client, req, db);
        };
    },
    // initialize & attach events
    initialize: function () {
        // attach server socket events
        wss.socket.on("connection", function (client_socket) {
            // create client object on new connection
            var client = {
                socket: client_socket,
                id: util.rand_id(),
                auth: false,
                type: "app"
            };
            util.log("ws", util.INF, `client ${client.id} – connected`);
            // client socket event handlers
            client.socket.addEventListener("message", function (m) {
                var d = wss.decode_msg(m.data); // parse message
                if (d != null) {
                    // console.log('    ', d.event, d.data);
                    util.log("ws", util.EXT, `client ${client.id} – message: ${d.event}`, d.data);
                    // handle various events
                    if (wss.events.hasOwnProperty(d.event))
                        wss.events[d.event](client, d.data, database.data);
                    else util.log("ws", util.ERR, "unknown event", d.event);
                } else {
                    util.log("ws", util.ERR, `client ${client.id} – invalid message: `, m.data);
                }
            });
            client.socket.addEventListener("error", function (e) {
                util.log("ws", util.ERR, "client " + client.id + " – error", e);
            });
            client.socket.addEventListener("close", function (c, r) {
                util.log("ws", util.INF, `client ${client.id} – disconnected`);
                if (client.id.substring(0, 7) == "arduino")
                    wss.arduino_tracker.log(client.id, "disconnected");
                delete wss.clients[client.id]; // remove client object on disconnect
            });
            // add client object to client object list
            wss.clients[client.id] = client;
        });
        wss.socket.on("listening", function () {
            util.log("ws", util.IMP, "listening on", wss_port);
            wss.online = true;
            wss.arduino_tracker.reloop();
        });
        wss.socket.on("error", function (e) {
            util.log("ws", util.ERR, "server error", e);
            wss.online = false;
        });
        wss.socket.on("close", function () {
            util.log("ws", util.IMP, "server closed");
            wss.online = false;
        });

        // attach client socket events
        wss.bind('auth', function (client, req, db) {
            // validate password
            if (req.password == password) {
                util.log("ws", util.INF, `client ${client.id} – authenticated`);
                // set auth in client object
                client.auth = true;
                if (client.id.substring(0, 7) == "arduino") {
                    // if arduino 
                    client.socket.send("@auth"); // confirm auth with client
                    wss.arduino_tracker.log(client.id, "authenticated");
                    // send current brightness & speed
                    client.socket.send("@b-" + util.lpad(db.devices[client.id].brightness, 3, "0"));
                    client.socket.send("@s-" + util.lpad(db.devices[client.id].speed, 3, "0"));
                    setTimeout(function () {
                        // send currently playing pattern or hue, if any
                        wss.play_current(client.id);
                        // begin heartbeat
                        setTimeout(function () {
                            client.socket.send("@hb");
                        }, 1000);
                    }, 500);
                } else {
                    // if regular client
                    wss.send_to_client("auth", true, client); // confirm auth with client
                    // send full color palette and pattern list
                    wss.send_color_palette(client);
                    wss.send_pattern_list(client);
                    // send device list
                    wss.send_to_client("device_list", db.devices, client);
                }
            }
        }, false);
        // [color]
        wss.bind('get_color_palette', function (client, req, db) {
            wss.send_color_palette(client);
        });
        wss.bind('color_new', function (client, req, db) {
            // generate color ID
            var color_id = util.rand_id();
            while (db.colors.hasOwnProperty(color_id))
                color_id = util.rand_id();
            req.r = util.rgb_validate(req.r);
            req.g = util.rgb_validate(req.g);
            req.b = util.rgb_validate(req.b);
            util.log("ws", util.INF, `client ${client.id} adding new color with id ${color_id} - rgb(${req.r}, ${req.g}, ${req.b})`);
            // add new color preset to database with RGB values
            db.colors[color_id] = {
                r: req.r, g: req.g, b: req.b,
                d: Date.now(), name: ""
            };
            // send new preset to all other clients
            wss.send_to_clients_but(
                "color_new",
                {
                    r: req.r, g: req.g, b: req.b,
                    id: color_id, name: "",
                    switch: false
                },
                client
            );
            // send new preset back to original client
            wss.send_to_client('color_new', {
                r: req.r, g: req.g, b: req.b,
                id: color_id, name: "",
                switch: true // tells client to switch currently editing preset to the new preset
            }, client);
            database.save();
        });
        wss.bind('color_name', function (client, req, db) {
            req.name = ("" + req.name).trim();
            if (req.name != "") {
                util.log("ws", util.INF, `client ${client.id} naming color ${req.id}, to ${req.name}`);
                db.colors[req.id].name = req.name;
                wss.send_to_clients("color_update", {
                    r: db.colors[req.id].r,
                    g: db.colors[req.id].g,
                    b: db.colors[req.id].b,
                    name: req.name,
                    id: req.id
                });
                database.save();
            }
        });
        wss.bind('color_delete', function (client, req, db) {
            util.log("ws", util.INF, `client ${client.id} deleting color ${req.id}`);
            // remove color preset from database
            db.colors[req.id] = null;
            delete db.colors[req.id];
            // send delete update to clients
            wss.send_to_clients("color_delete", { id: req.id });
            database.save();
        });
        wss.bind('color_update', function (client, req, db) {
            req.r = util.rgb_validate(req.r);
            req.g = util.rgb_validate(req.g);
            req.b = util.rgb_validate(req.b);
            util.log("ws", req.latent ? util.INF : util.REP, `client ${client.id} updating color ${req.id} - rgb(${req.r}, ${req.g}, ${req.b})`);
            // update color preset RGB values in database
            db.colors[req.id].r = req.r;
            db.colors[req.id].g = req.g;
            db.colors[req.id].b = req.b;
            // send color update to clients
            wss.send_to_clients("color_update", {
                r: req.r, g: req.g, b: req.b,
                name: db.colors[req.id].name,
                id: req.id
            });
            // save database if update is latent
            // (latent = not part of a heavy series of immediate realtime updates)
            if (req.latent) database.save();
        });
        wss.bind('color_test', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                req.latent = req.latent ? true : false;
                util.log("ws", req.latent ? util.INF : util.REP, `client ${client.id} testing color`);
                wss.test_color(req.device_id, req.color, req.latent);
            }
        });
        // [pattern]
        wss.bind('get_pattern_list', function (client, req, db) {
            wss.send_pattern_list(client);
        });
        wss.bind('pattern_new', function (client, req, db) {
            // generate new pattern ID
            var pattern_id = util.rand_id();
            while (db.patterns.hasOwnProperty(pattern_id))
                pattern_id = util.rand_id();
            util.log("ws", util.INF, `client ${client.id} adding new pattern with id ${pattern_id}`);
            // add pattern to database
            db.patterns[pattern_id] = {
                name: "untitled",
                list: []
            };
            // send new pattern to clients
            wss.send_to_clients_but(
                "pattern_new",
                {
                    id: pattern_id,
                    name: "untitled",
                    switch: false
                },
                client
            );
            wss.send_to_client(
                "pattern_new",
                {
                    id: pattern_id,
                    name: "untitled",
                    switch: true
                },
                client
            );
            database.save();
        });
        wss.bind('pattern_name', function (client, req, db) {
            // check database for pattern
            if (db.patterns.hasOwnProperty(req.id)) {
                req.name = ("" + req.name).trim();
                util.log("ws", util.INF, `client ${client.id} naming pattern ${req.id} to ${req.name}`);
                // set pattern name in database
                db.patterns[req.id].name = req.name;
                // send name update to clients
                wss.send_to_clients("pattern_name", {
                    id: req.id,
                    name: req.name
                });
                database.save();
            }
        });
        wss.bind('pattern_delete', function (client, req, db) {
            // check database for pattern
            if (db.patterns.hasOwnProperty(req.id)) {
                util.log("ws", util.INF, `client ${client.id} deleting pattern ${req.id}`);
                // remove pattern from database
                db.patterns[req.id] = null;
                delete db.patterns[req.id];
                // update currently playing
                for (var d in db.devices) {
                    if (db.devices.hasOwnProperty(d)) {
                        if (db.devices[d].current.type == "pattern" && req.id == db.devices[d].current.data.id) {
                            db.devices[d].current.type = "none";
                            db.devices[d].current.data = null;
                            wss.send_to_clients("current", {
                                device_id: d,
                                data: db.devices[d].current
                            });
                        }
                    }
                }
                // send deleted pattern id to clients
                wss.send_to_clients(
                    "pattern_delete",
                    { id: req.id }
                );
                database.save();
            }
        });
        wss.bind('pattern_add_color', function (client, req, db) {
            if (db.patterns.hasOwnProperty(req.id)) {
                util.log("ws", util.INF, `client ${client.id} adding color to pattern ${req.id}`);
                // add fRGBh color object to pattern in database
                db.patterns[req.id].list.push({
                    fade: 0,
                    r: 0, g: 0, b: 0,
                    time: 0
                });
                // send full updated pattern to clients
                wss.send_to_clients("pattern_update", {
                    id: req.id,
                    list: db.patterns[req.id].list
                });
                database.save();
            }
        });
        wss.bind('pattern_update_color', function (client, req, db) {
            var color_id = parseInt(req.color.id);
            if (db.patterns.hasOwnProperty(req.id) && color_id >= 0 && color_id < db.patterns[req.id].list.length) {
                util.log("ws", util.INF, `client ${client.id} updating color ${color_id} of pattern ${req.id}`);
                // update fRGBh color object in pattern in database
                db.patterns[req.id].list[color_id].fade = req.color.fade;
                db.patterns[req.id].list[color_id].r = req.color.r;
                db.patterns[req.id].list[color_id].g = req.color.g;
                db.patterns[req.id].list[color_id].b = req.color.b;
                db.patterns[req.id].list[color_id].time = req.color.time;
                // send full updated pattern to clients
                wss.send_to_clients("pattern_update", {
                    id: req.id,
                    list: db.patterns[req.id].list
                });
                database.save();
            }
        });
        wss.bind('pattern_move_color', function (client, req, db) {
            var color_id = parseInt(req.color.id);
            var new_pos = parseInt(req.new_pos);
            if (db.patterns.hasOwnProperty(req.id) && color_id >= 0 && color_id < db.patterns[req.id].list.length) {
                util.log("ws", util.INF, `client ${client.id} moving color ${color_id} (to ${new_pos} of pattern ${req.id})`);
                // shift fRGBh color object position in list in preset in database
                array_move.mutate(
                    db.patterns[req.id].list,
                    color_id, new_pos
                );
                // send full updated pattern to clients
                wss.send_to_clients("pattern_update", {
                    id: req.id,
                    list: db.patterns[req.id].list
                });
                database.save();
            }
        });
        wss.bind('pattern_delete_color', function (client, req, db) {
            var color_id = parseInt(req.color.id);
            if (db.patterns.hasOwnProperty(req.id) && color_id >= 0 && color_id < db.patterns[req.id].list.length) {
                util.log("ws", util.INF, `client ${client.id} deleting color ${color_id} of pattern ${req.id}`);
                // remove color from pattern in database
                db.patterns[req.id].list.splice(color_id, 1);
                // send full updated pattern to clients
                wss.send_to_clients("pattern_update", {
                    id: req.id,
                    list: db.patterns[req.id].list
                });
                database.save();
            }
        });
        wss.bind('pattern_load', function (client, req, db) {
            // check database for pattern
            if (db.patterns.hasOwnProperty(req.id)) {
                // send pattern data to client
                wss.send_to_client("pattern_load", {
                    id: req.id,
                    name: db.patterns[req.id].name,
                    list: db.patterns[req.id].list
                }, client)
            }
        });
        wss.bind('pattern_play', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                // check database for pattern
                if (db.patterns.hasOwnProperty(req.id)) {
                    util.log("ws", util.INF, `client ${client.id} playing pattern`);
                    wss.play_pattern(req.device_id, req.id);
                }
            }
        });
        // [arduino]
        wss.bind('arduino_sync', function (client, req, db) {
            var device_id = "arduino_" + ("" + req).trim();
            util.log("ws", util.INF, `client ${client.id} – identified as ARDUINO: ${device_id}`);
            // rename client in client list
            var old_id = client.id;
            client.id = device_id;
            wss.clients[device_id] = client;
            wss.clients[old_id] = null;
            delete wss.clients[old_id];
            if (!db.devices.hasOwnProperty(device_id)) {
                wss.create_device(device_id);
            }
            wss.send_to_arduino(device_id, "@arduinosync");
            wss.arduino_tracker.log(device_id, "connected")
            database.save();
        }, false);
        wss.bind('arduino_heartbeat', function (client, req, db) {
            wss.arduino_tracker.log(client.id, "online");
            setTimeout(function () {
                wss.send_to_arduino(client.id, "@hb");
            }, wss.arduino_tracker.heartbeat_interval);
        });
        wss.bind('arduino_direct', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                util.log("ws", req.silent === true ? util.REQ : util.INF, `direct to ${req.device_id}: ${req.data}`);
                wss.send_to_arduino(req.device_id, req.data);
            }
        });
        // [control]
        wss.bind('get_device_list', function (client, req, db) {
            wss.send_to_client("device_list", db.devices, client);
        });
        wss.bind('get_device_data', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                // send currently playing
                wss.send_to_client("current", {
                    data: db.devices[req.device_id].current,
                    device_id: req.device_id
                }, client);
                // send current brightness & speed
                wss.send_to_client("brightness", {
                    device_id: req.device_id,
                    level: db.devices[req.device_id].brightness,
                }, client);
                wss.send_to_client("speed", {
                    device_id: req.device_id,
                    level: db.devices[req.device_id].speed,
                }, client);
            }
        });
        wss.bind('device_name', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                req.name = ("" + req.name).trim();
                if (req != "") {
                    db.devices[req.device_id].name = req.name;
                    wss.send_to_clients("device_list", db.devices);
                    database.save();
                }
            }
        });
        wss.bind('device_delete', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                db.devices[req.device_id] = null;
                delete db.devices[req.device_id];
                wss.send_to_clients("device_list", db.devices);
                database.save();
            }
        });
        wss.bind('get_brightness', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                wss.send_to_client("brightness", {
                    device_id: req.device_id,
                    level: db.devices[req.device_id].brightness,
                }, client);
            }
        });
        wss.bind('set_brightness', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                util.log("ws", req.latent ? util.INF : util.REP, `client ${client.id} setting brightness to ${req.brightness} for device ${req.device_id}`);
                // correct brightness
                req.brightness = parseInt(req.brightness);
                if (isNaN(req.brightness)) req.brightness = 100;
                req.brightness = util.validate_int(req.brightness, 0, 100);
                // send brightness to all clients except sender
                db.devices[req.device_id].brightness = req.brightness;
                wss.send_to_clients_but("brightness", {
                    device_id: req.device_id,
                    level: db.devices[req.device_id].brightness,
                }, client);
                // send brightness to arduino
                wss.send_to_arduino(req.device_id, "@b-" + util.lpad(db.devices[req.device_id].brightness, 3, "0"));
                if (req.latent) database.save();
            }
        });
        wss.bind('get_speed', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                wss.send_to_client("speed", {
                    device_id: req.device_id,
                    level: db.devices[req.device_id].speed,
                }, client);
            }
        });
        wss.bind('set_speed', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                util.log("ws", req.latent ? util.INF : util.REP, `client ${client.id} setting speed to ${req.speed} for device ${req.device_id}`);
                // correct speed
                req.speed = parseInt(req.speed);
                if (isNaN(req.speed)) req.speed = 100;
                req.speed = util.validate_int(req.speed, 0, 500);
                // send speed to all clients except sender
                db.devices[req.device_id].speed = req.speed;
                wss.send_to_clients_but("speed", {
                    device_id: req.device_id,
                    level: db.devices[req.device_id].speed,
                }, client);
                // send speed to arduino
                wss.send_to_arduino(req.device_id, "@s-" + util.lpad(db.devices[req.device_id].speed, 3, "0"));
                if (req.latent) database.save();
            }
        });
        wss.bind('get_current', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                wss.send_to_clients("current", {
                    device_id: req.device_id,
                    data: db.devices[req.device_id].current
                });
            }
        });
        wss.bind('play_current', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                wss.play_current(req.device_id);
            }
        });
        // [music]
        wss.bind('music', function (client, req, db) {
            if (db.devices.hasOwnProperty(req.device_id)) {
                util.log('ws', util.INF, `music reactive mode (beta) for device ${req.device_id}`);
                db.devices[req.device_id].current.type = "music";
                db.devices[req.device_id].current.data = true;
                // send currently playing to all
                wss.send_to_clients("current", {
                    device_id: req.device_id,
                    data: db.devices[req.device_id].current
                });
                // send to arduino
                wss.send_to_arduino(req.device_id, "@music");
            }
        });
    }
};

/* HTTP SERVER */
var app = express();
var server = http.Server(app);
app.use(body_parser.json());
app.use(
    body_parser.urlencoded({
        extended: true
    })
);
app.use(function (req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header(
        "Access-Control-Allow-Headers",
        "Origin, X-Requested-With, Content-Type, Accept"
    );
    next();
});
app.use(express.static("html"));
app.get("/", function (req, res) {
    res.sendFile(__dirname + "/html/index.html");
});
/*
var api = {
    auth: function (req, res, next) {
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
    ws_server.online: function(req, res, next) {
        if (ws_server.online) {
            next(req, res);
        } else {
            res.send({
                success: false,
                message: "websocket service offline",
                payload: {}
            });
        }
    },
    require: function (param_name, req, res, next, fail = null) {
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
    },
    fade_time: 750,
    fade_interval: 50
};

app.get("/api", function (req, res) {
    api.auth(req, res, function (req, res) {
        res.send({
            success: true,
            message: "led-lights api",
            payload: {}
        });
    });
});
app.get("/api/arduinostatus", function (req, res) {
    api.auth(req, res, function (req, res) {
        api.ws_server.online(req, res, function (req, res) {
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
app.get("/api/colorlist", function (req, res) {
    api.auth(req, res, function (req, res) {
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
app.post("/api/testcolor", function (req, res) {
    api.auth(req, res, function (req, res) {
        api.ws_server.online(req, res, function (req, res) {
            api.require("name", req, res, function (name, req, res) {
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
                    var colorstring = rgb_string(color.r, color.g, color.b);
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
                    send_to_clients("current", get_currently_playing());
                    database.save();
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
app.get("/api/patternlist", function (req, res) {
    api.auth(req, res, function (req, res) {
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
app.post("/api/playpattern", function (req, res) {
    api.auth(req, res, function (req, res) {
        api.ws_server.online(req, res, function (req, res) {
            api.require("name", req, res, function (name, req, res) {
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
                    play_current_pattern();
                    // send currently playing
                    send_to_clients("current", get_currently_playing());
                    database.save();
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
app.post("/api/playcurrent", function (req, res) {
    api.auth(req, res, function (req, res) {
        api.ws_server.online(req, res, function (req, res) {
            var current = get_currently_playing();
            if (current.type == "pattern") play_current_pattern();
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
app.get("/api/brightness", function (req, res) {
    api.auth(req, res, function (req, res) {
        res.send({
            success: true,
            message: "brightness retrieved",
            payload: { level: database.brightness }
        });
    });
});
app.post("/api/brightness", function (req, res) {
    api.auth(req, res, function (req, res) {
        api.ws_server.online(req, res, function (req, res) {
            api.require(
                "level",
                req,
                res,
                function (level, req, res) {
                    log("http", "alexa client setting brightness to " + level);
                    // correct brightness
                    level = parseInt(level);
                    if (isNaN(level)) level = 100;
                    if (level < 0) level = 0;
                    if (level > 100) level = 100;
                    var fade_val = ("" + req.body["fade"]).trim();
                    if (
                        req.body.hasOwnProperty("fade") &&
                        fade_val &&
                        fade_val != "" &&
                        fade_val == "true"
                    ) {
                        var fadeFuncTemp;
                        var delta = level - database.brightness;
                        var interval = 50;
                        var step = delta / (api.fade_time / api.fade_interval);
                        var brightness_float = parseFloat(database.brightness);
                        fadeFuncTemp = function () {
                            brightness_float += step;
                            database.brightness = parseInt(brightness_float);
                            if (
                                delta == 0 ||
                                (delta < 0 && database.brightness < level) ||
                                (delta > 0 && database.brightness > level)
                            ) {
                                database.brightness = level;
                            }
                            send_to_clients("brightness", database.brightness);
                            sendToArduino(
                                "@b-" + lpad(database.brightness, 3, "0")
                            );
                            if (database.brightness != level)
                                setTimeout(fadeFuncTemp, api.fade_interval);
                            else database.save();
                        };
                        fadeFuncTemp();
                    } else {
                        // send brightness to all clients
                        database.brightness = level;
                        send_to_clients("brightness", database.brightness);
                        // send brightness to arduino
                        sendToArduino(
                            "@b-" + lpad(database.brightness, 3, "0")
                        );
                        database.save();
                    }
                    res.send({
                        success: true,
                        message: "brightness updated",
                        payload: { level: level }
                    });
                },
                function (req, res) {
                    api.require(
                        "increment",
                        req,
                        res,
                        function (increment, req, res) {
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
                            log(
                                "http",
                                "alexa client setting brightness to " +
                                newbrightness
                            );

                            var fade_val = ("" + req.body["fade"]).trim();
                            if (
                                req.body.hasOwnProperty("fade") &&
                                fade_val &&
                                fade_val != "" &&
                                fade_val == "true"
                            ) {
                                var fadeFuncTemp;
                                var delta = newbrightness - database.brightness;
                                var step =
                                    delta / (api.fade_time / api.fade_interval);
                                var brightness_float = parseFloat(
                                    database.brightness
                                );
                                fadeFuncTemp = function () {
                                    brightness_float += step;
                                    database.brightness = parseInt(
                                        brightness_float
                                    );
                                    if (
                                        delta == 0 ||
                                        (delta < 0 &&
                                            database.brightess <
                                            newbrightness) ||
                                        (delta > 0 &&
                                            database.brightess > newbrightness)
                                    ) {
                                        database.brightness = newbrightness;
                                    }
                                    send_to_clients(
                                        "brightness",
                                        database.brightness
                                    );
                                    sendToArduino(
                                        "@b-" +
                                        lpad(database.brightness, 3, "0")
                                    );
                                    if (database.brightness != newbrightness)
                                        setTimeout(
                                            fadeFuncTemp,
                                            api.fade_interval
                                        );
                                    else database.save();
                                };
                                fadeFuncTemp();
                            } else {
                                // send brightness to all clients
                                database.brightness = newbrightness;
                                send_to_clients("brightness", database.brightness);
                                // send brightness to arduino
                                sendToArduino(
                                    "@b-" + lpad(database.brightness, 3, "0")
                                );
                                database.save();
                            }
                            res.send({
                                success: true,
                                message: "brightness updated",
                                payload: {
                                    level: database.brightness
                                }
                            });
                        },
                        function (req, res) {
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
app.get("/api/speed", function (req, res) {
    api.auth(req, res, function (req, res) {
        res.send({
            success: true,
            message: "speed retrieved",
            payload: { level: database.speed }
        });
    });
});
app.post("/api/speed", function (req, res) {
    api.auth(req, res, function (req, res) {
        api.ws_server.online(req, res, function (req, res) {
            api.require(
                "level",
                req,
                res,
                function (level, req, res) {
                    log("http", "alexa client setting speed to " + level);
                    // correct speed
                    level = parseInt(level);
                    if (isNaN(level)) level = 500;
                    if (level < 0) level = 0;
                    if (level > 500) level = 500;
                    // send speed to all clients
                    database.speed = level;
                    send_to_clients("speed", database.speed);
                    // send speed to arduino
                    sendToArduino("@s-" + lpad(database.speed, 3, "0"));
                    database.save();
                    res.send({
                        success: true,
                        message: "speed updated",
                        payload: {
                            level: database.speed
                        }
                    });
                },
                function (req, res) {
                    api.require(
                        "increment",
                        req,
                        res,
                        function (increment, req, res) {
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
                            log(
                                "http",
                                "alexa client setting speed to " + newspeed
                            );
                            database.speed = newspeed;
                            send_to_clients("speed", database.speed);
                            sendToArduino("@s-" + lpad(database.speed, 3, "0"));
                            database.save();
                            res.send({
                                success: true,
                                message: "speed updated",
                                payload: {
                                    level: database.speed
                                }
                            });
                        },
                        function (req, res) {
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
*/

/* CLI */
util.input.on('line', function (line) {
    line = line.trim();
    if (line != '') {
        line = line.split(' ');
        if (line[0] == "db" || line[0] == "database") {
            if (line[1] == "save") {
                database.save(line[2] && line[2] == "pretty");
            }
        }
    }
});

/* MAIN */
console.log("RGB Lights Control");
database.load();
wss.initialize();
server.listen(http_port, function () {
    util.log("http", util.IMP, "listening on", http_port);
});
