// libraries
const http = require('http');
const express = require('express');
const rn = require('random-number');
const WebSocket = require('ws');
const arrayMove = require('array-move');
const fs = require('fs');

// constants
var wss_port = 3003;
var http_port = 3002;
if (process.argv.slice(2)[0] == 'test') {
    wss_port = 30003;
    http_port = 30002;
}
const password = 'password';

// ws server
const wss = new WebSocket.Server({ port: wss_port });
function encodeMSG(e, d) {
    return JSON.stringify({
        event: e,
        data: d
    });
}
function decodeMSG(m) {
    try {
        m = JSON.parse(m);
    } catch(e) {
        console.log('[ws] invalid json msg ', e);
        m = null;
    }
    return m;
}
function randID(length = 10) {
    key = '';
    chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var i = 0; i < length; i++)
        key += chars[rn({
            min: 0, max: chars.length - 1, integer: true
        })];
    return key;
}
function lpad(s, width, char) {
    return (s.length >= width) ? s : (new Array(width).join(char) + s).slice(-width);
} // https://stackoverflow.com/questions/10841773/javascript-format-number-to-day-with-always-3-digits
function rgbstring(r, g, b) {
    return lpad(String(parseInt(r)), 3, '0') + lpad(String(parseInt(g)), 3, '0') + lpad(String(parseInt(b)), 3, '0');
}

var clients = {};
var database;
try {
    fs.readFile('database.json', function (err, data) {
      if (err) throw err;
      database = JSON.parse(data);
    });
} catch (e) {
    console.log(e);
    database = {
        colors: {

        },
        patterns: {

        },
        current: ''
    };
}
function sendToAll(event, data) {
    for (var c_id in clients) {
        if (clients.hasOwnProperty(c_id) && c_id != 'arduino' && clients[c_id] !== null && clients[c_id].auth) {
            clients[c_id].socket.send(encodeMSG(event, data));
        }
    }
}
function sendToAllBut(event, data, client) {
    for (var c_id in clients) {
        if (clients.hasOwnProperty(c_id) && c_id != 'arduino' && c_id != client.id && clients[c_id] !== null && clients[c_id].auth) {
            clients[c_id].socket.send(encodeMSG(event, data));
        }
    }
}
function sendToArduino(data) {
    if (clients.hasOwnProperty('arduino') && clients['arduino'] !== null && clients['arduino'].auth)
        clients['arduino'].socket.send(data);
}
function playCurrentPattern() {
    if (database.current.trim() != '') {
        var currentPattern = database.patterns[database.current];
        var pattern_string = '';
        for (var p_c in currentPattern.list) {
            var pattern_color = currentPattern.list[p_c];
            pattern_string += lpad(pattern_color.fade, 5, '0') + rgbstring(pattern_color.r, pattern_color.g, pattern_color.b) + lpad(pattern_color.time, 5, '0') + ',';
        }
        pattern_string = pattern_string.substring(0, pattern_string.length - 1);
        console.log('[ws] playing pattern ' + database.current);
        sendToArduino('@p-' + pattern_string);
    }
}
function saveDB() {
    var dbjson = JSON.stringify(database);
    fs.writeFile('database.json', dbjson, function (err) {
        if (err) {
            return console.log(err);
        }
        console.log('[db] file saved');
    });
}
wss.on('connection', function (ws) {
    var client = {
        socket: ws,
        id: randID(),
        auth: false
    };
    console.log('[ws] client ' + client.id + ' – connected');
    ws.addEventListener('message', function (m) {
        // console.log('[ws] client ' + client.id + ' – message: ');
        var d = decodeMSG(m.data);
        if (d != null) {
            // console.log('    ', d.event, d.data);
            switch (d.event) {
                case 'arduinosync':
                    console.log('[ws] client ' + client.id + ' – identified as ARDUINO');
                    var oldid = client.id;
                    client.id = 'arduino';
                    clients['arduino'] = client;
                    clients[oldid] = null;
                    delete clients[oldid];
                    ws.send('@arduinosync');
                    break;
                case 'auth':
                    if (d.data.password == password) {
                        console.log('[ws] client ' + client.id + ' – authenticated');
                        client.auth = true;
                        if (client.id == 'arduino') {
                            ws.send('@auth');
                            // ws.send('@h-00000' + lpad(rgb.r) + '' + lpad(rgb.g) + '' + lpad(rgb.b) + '01000');
                            // send current pattern to arduino here
                        } else {
                            ws.send(encodeMSG('auth', 'true'));
                            ws.send(encodeMSG('colorpalette', database.colors));
                            console.log('[ws] color palette update sent to client ' + client.id);
                            var names = [];
                            for (var p in database.patterns) {
                                if (database.patterns.hasOwnProperty(p)) {
                                    names.push({
                                        id: p, name: database.patterns[p].name
                                    });
                                }
                            }
                            ws.send(encodeMSG('patternlist', names));
                            console.log('[ws] pattern list update sent to client ' + client.id);
                        }
                    }
                    break;
                case 'direct':
                    if (!client.auth) break;
                    console.log('[ws] direct', d.data);
                    sendToArduino(d.data);
                    break;
                case 'direct_silent':
                    if (!client.auth) break;
                    sendToArduino(d.data);
                    break;
                case 'newcolor':
                    if (!client.auth) break;
                    var colorID = randID();
                    while (database.colors.hasOwnProperty(colorID)) colorID = randID();
                    console.log('[ws] client ' + client.id + ' adding new color with id ' + colorID + ' – rgb(' + d.data.r + ', ' + d.data.g + ', ' + d.data.b + ')');
                    database.colors[colorID] = {
                        r: d.data.r,
                        g: d.data.g,
                        b: d.data.b
                    };
                    sendToAllBut('newcolor', { r: d.data.r, g: d.data.g, b: d.data.b, id: colorID, switch: false }, client);
                    ws.send(encodeMSG('newcolor', { r: d.data.r, g: d.data.g, b: d.data.b, id: colorID, switch: true }));
                    saveDB();
                    break;
                case 'updatecolor':
                    if (!client.auth) break;
                    console.log('[ws] client ' + client.id + ' updating color ' + d.data.id + ' – rgb(' + d.data.r + ', ' + d.data.g + ', ' + d.data.b + ')');
                    database.colors[d.data.id].r = d.data.r;
                    database.colors[d.data.id].g = d.data.g;
                    database.colors[d.data.id].b = d.data.b;
                    sendToAll('updatecolor', { r: d.data.r, g: d.data.g, b: d.data.b, id: d.data.id });
                    if (d.data.latent) saveDB();
                    break;
                case 'deletecolor':
                    if (!client.auth) break;
                    console.log('[ws] client ' + client.id + ' deleting color ' + d.data.id);
                    database.colors[d.data.id] = null;
                    delete database.colors[d.data.id];
                    sendToAll('deletecolor', { id: d.data.id });
                    saveDB();
                    break;
                case 'newpattern':
                    if (!client.auth) break;
                    var patternID = randID();
                    while (database.patterns.hasOwnProperty(patternID)) patternID = randID();
                    console.log('[ws] client ' + client.id + ' adding new pattern with id ' + patternID);
                    database.patterns[patternID] = {
                        name: 'untitled', list: []
                    };
                    sendToAllBut('newpattern', { id: patternID, name: 'untitled', switch: false }, client);
                    ws.send(encodeMSG('newpattern', { id: patternID, name: 'untitled' }));
                    saveDB();
                    break;
                case 'loadpattern':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        ws.send(encodeMSG('loadpattern', {
                            id: d.data.id,
                            name: database.patterns[d.data.id].name,
                            list: database.patterns[d.data.id].list
                        }));
                    }
                    break;
                case 'renamepattern':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        d.data.name = String(d.data.name).trim();
                        console.log('[ws] client ' + client.id + ' renaming pattern ' + d.data.id + 'to ' + d.data.name);
                        database.patterns[d.data.id].name = d.data.name;
                        sendToAll('renamepattern', {
                            id: d.data.id, name: d.data.name
                        });
                    }
                    saveDB();
                    break;
                case 'playpattern':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        database.current = d.data.id;
                        playCurrentPattern();
                        saveDB();
                    }
                    break;
                case 'addpatterncolor':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        console.log('[ws] client ' + client.id + ' adding color to pattern ' + d.data.id);
                        database.patterns[d.data.id].list.push({
                            fade: 0, r: 0, g: 0, b: 0, time: 0
                        });
                        sendToAll('updatepattern', { id: d.data.id, list: database.patterns[d.data.id].list });
                        saveDB();
                    }
                    break;
                case 'updatepatterncolor':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        console.log('[ws] client ' + client.id + ' updating color ' + d.data.colorID + ' of pattern ' + d.data.id);
                        var colorID = parseInt(d.data.colorID);
                        database.patterns[d.data.id].list[colorID].fade = d.data.colorData.fade;
                        database.patterns[d.data.id].list[colorID].r = d.data.colorData.r;
                        database.patterns[d.data.id].list[colorID].g = d.data.colorData.g;
                        database.patterns[d.data.id].list[colorID].b = d.data.colorData.b;
                        database.patterns[d.data.id].list[colorID].time = d.data.colorData.time;
                        sendToAll('updatepattern', { id: d.data.id, list: database.patterns[d.data.id].list });
                        saveDB();
                    }
                    break;
                case 'movepatterncolor':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        console.log('[ws] client ' + client.id + ' moving color ' + d.data.colorID + ' (to ' + d.data.newPos + ') of pattern ' + d.data.id);
                        var colorID = parseInt(d.data.colorID);
                        arrayMove.mutate(database.patterns[d.data.id].list, d.data.colorID, d.data.newPos);
                        sendToAll('updatepattern', { id: d.data.id, list: database.patterns[d.data.id].list });
                        saveDB();
                    }
                    break;
                case 'deletepatterncolor':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        console.log('[ws] client ' + client.id + ' deleting color ' + d.data.colorID + ' of pattern ' + d.data.id);
                        database.patterns[d.data.id].list.splice(d.data.colorID, 1);
                        sendToAll('updatepattern', { id: d.data.id, list: database.patterns[d.data.id].list });
                        saveDB();
                    }
                    break;
                case 'deletepattern':
                    if (!client.auth) break;
                    if (database.patterns.hasOwnProperty(d.data.id)) {
                        console.log('[ws] client ' + client.id + ' deleting pattern ' + d.data.id);
                        database.patterns[d.data.id] = null;
                        delete database.patterns[d.data.id];
                        sendToAllBut('deletepattern', { id: d.data.id }, client);
                        ws.send(encodeMSG('deletepattern', { id: d.data.id }));
                        saveDB();
                    }
                    break;
                case 'setbrightness':
                    if (!client.auth) break;
                    console.log('[ws] client ' + client.id + ' setting brightness to ' + d.data.brightness);
                    sendToArduino('@b-' + lpad(d.data.brightness, 3, '0'));
                    break;
                case 'setspeed':
                    if (!client.auth) break;
                    console.log('[ws] client ' + client.id + ' setting speed to ' + d.data.speed);
                    sendToArduino('@s-' + lpad(d.data.speed, 3, '0'));
                    break;
                default:
                    console.log('[ws] unknown event', d.event);
                    break;
            }
        } else {
            // console.log('[ws] invalid message', m.data)
        }
    });
    ws.addEventListener('error', function (e) {
        console.log('[ws] client ' + client.id + ' – error: ', e);
    });
    ws.addEventListener('close', function (c, r) {
        console.log('[ws] client ' + client.id + ' – disconnected');
        delete clients[client.id];
    });
    clients[client.id] = client;
});
wss.on('listening', function () {
    console.log('[ws] listening on ' + wss_port);
});
wss.on('error', function (e) {
    console.log('[ws] server error ', e);
});
wss.on('close', function () {
    console.log('[ws] server closed');
});


// http server
var app = express();
var server = http.Server(app);
app.get('/', function (req, res) {
    res.sendFile(__dirname + '/html/index.html');
});
app.use(express.static('html'));
server.listen(http_port, function () {
    console.log('[http] listening on ' + http_port);
});

console.log('RGB Lights Control');
