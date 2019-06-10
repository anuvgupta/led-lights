// libraries
const http = require('http');
const express = require('express');
const rn = require('random-number');
const WebSocket = require('ws');

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

var clients = {};
var rgb = {
    r: 100,
    g: 100,
    b: 100
};
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
                case 'rgbupdate':
                    if (!client.auth) break;
                    rgb.r = d.data.r;
                    rgb.g = d.data.g;
                    rgb.b = d.data.b;
                    console.log('[ws] rgb updated to', rgb.r, rgb.g, rgb.b);
                    for (var c_id in clients) {
                        if (clients.hasOwnProperty(c_id) && c_id != 'arduino' && c_id != client.id && clients[c_id] !== null && clients[c_id].auth) {
                            clients[c_id].socket.send(encodeMSG('rgbupdate', { r: rgb.r, g: rgb.g, b: rgb.b }));
                        }
                    }
                    if (clients.hasOwnProperty('arduino') && clients['arduino'] !== null && clients['arduino'].auth)
                        clients['arduino'].socket.send('@rgbupdate,' + rgb.r + ',' + rgb.g + ',' + rgb.b);
                    console.log('[ws] rgb update sent to all clients');
                    break;
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
                            ws.send('@h-00000' + lpad(rgb.r) + '' + lpad(rgb.g) + '' + lpad(rgb.b) + '01000');
                        } else {
                            ws.send(encodeMSG('auth', 'true'));
                            ws.send(encodeMSG('rgbupdate', { r: rgb.r, g: rgb.g, b: rgb.b }));
                            console.log('[ws] rgb update sent to client ' + client.id);
                        }
                    }
                    break;
                case 'direct':
                    console.log('direct', d.data);
                    if (clients.hasOwnProperty('arduino') && clients['arduino'] !== null && clients['arduino'].auth)
                        clients['arduino'].socket.send(d.data);
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
