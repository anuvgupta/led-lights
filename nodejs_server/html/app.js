var app = {
    id: 0,
    block: Block('div', 'app'),
    socket: null,
    wsurl:
        'ws://' +
        document.domain +
        ':' +
        (document.domain == 'leds.anuv.me' ? 3003 : 30003),
    password: '',
    rgb: {
        r: 0,
        g: 0,
        b: 0,
        id: ''
    },
    bwThreshold: 200,
    device_id: null,
    devices: {},
    direct: {
        brightness: 100,
        speed: 100,
        brightnessAllowed: true,
        brightnessInterval: 100,
        speedAllowed: true,
        speedInterval: 100
    },
    trackLiveUpdates: {
        left: false,
        right: false,
        testColorAllowed: true,
        testColorInterval: 200
    },
    music_settings: {
        enabled: false,
        smoothing: 95,
        smoothing_lock: false,
        noise_gate: 25,
        noise_gate_lock: false,
        l_ch: 0,
        l_invert: false,
        l_preamp: 1,
        l_preamp_lock: false,
        l_postamp: 1,
        l_postamp_lock: false,
        r_ch: 0,
        r_invert: false,
        r_preamp: 1,
        r_preamp_lock: false,
        r_postamp: 1,
        r_postamp_lock: false,
        slider_interval: 100
    },
    encode_msg: function (e, d) {
        return JSON.stringify({
            event: e,
            data: d
        });
    },
    decode_msg: function (m) {
        try {
            m = JSON.parse(m);
        } catch (e) {
            console.log('[wss] invalid json msg ', e);
            m = null;
        }
        return m;
    },
    init_block: function (callback) {
        app.block.fill(document.body);
        var scheme = app.util.cookie('scheme');
        if (scheme != null) app.setScheme(scheme);
        $(document.body).on('DOMNodeInserted', function (e) {
            if (e.target.parentNode == document.body) {
                e.target.style.top = '65px';
                $(e.target)
                    .children()
                    .css({
                        borderRadius: '1px',
                        boxShadow: 'none'
                    });
                $(e.target).off('click.updatecolor');
                $(e.target).on('click.updatecolor', function () {
                    app.updateColor(true);
                    if (app.trackLiveUpdates.left || app.trackLiveUpdates.right)
                        app.testColor(true);
                });
            }
        });
        Block.queries();
        setTimeout(function () {
            app.block.css('opacity', '1');
        }, 100);
        setTimeout(function () {
            Block.queries();
            setTimeout(function () {
                Block.queries();
            }, 200);
        }, 50);
        if (app.util.mobile()) {
            Block.queries('off');
            $(window).on('orientationchange', function () {
                setTimeout(function () {
                    Block.queries();
                }, 250);
                setTimeout(function () {
                    Block.queries();
                }, 500);
                Block.queries();
            });
        }
        jscolor.installByClassName('jscolor');
        callback();
    },
    connect: function () {
        var socket = new WebSocket(app.wsurl);
        socket.addEventListener('open', function (e) {
            console.log('socket connected');
            app.init_block(function () {
                app.selectDevice(null, false);
                if (app.util.cookie('password') != null)
                    app.login(app.util.cookie('password'));
            });
        });
        socket.addEventListener('error', function (e) {
            console.log('socket error ', e.data);
        });
        socket.addEventListener('message', function (e) {
            var d = app.decode_msg(e.data);
            if (d != null) {
                console.log('message from server:', d.event, d.data);
                switch (d.event) {
                    case 'auth':
                        app.util.hideKeyboard();
                        app.util.cookie('password', app.password);
                        Block.queries();
                        app.block.on('panel');
                        app.selectDevice(app.util.cookie('last_device'));
                        app.block.child('controlpanel/colors/picker/sync').data({
                            left: app.util.cookie('trackLeft'),
                            right: app.util.cookie('trackRight')
                        });
                        Block.queries();
                        setTimeout(function () {
                            Block.queries();
                            setTimeout(function () {
                                Block.queries();
                            }, 1000);
                        }, 10);
                        break;
                    case 'color_palette':
                        app.block
                            .child('controlpanel/colors/presets')
                            .on('clear', {
                                callback: function () {
                                    for (var colorID in d.data) {
                                        if (d.data.hasOwnProperty(colorID)) {
                                            app.block
                                                .child(
                                                    'controlpanel/colors/presets'
                                                )
                                                .data({
                                                    newpreset: {
                                                        r: d.data[colorID].r,
                                                        g: d.data[colorID].g,
                                                        b: d.data[colorID].b,
                                                        name:
                                                            d.data[colorID]
                                                                .name,
                                                        id: colorID
                                                    }
                                                });
                                        }
                                    }
                                }
                            });
                        break;
                    case 'color_new':
                        app.block.child('controlpanel/colors/presets').data({
                            newpreset: {
                                r: d.data.r,
                                g: d.data.g,
                                b: d.data.b,
                                id: d.data.id,
                                name: d.data.name,
                                sw: d.data.switch
                            }
                        });
                        break;
                    case 'color_update':
                        app.block.child('controlpanel/colors/presets').data({
                            updatepreset: {
                                r: d.data.r,
                                g: d.data.g,
                                b: d.data.b,
                                name: d.data.name,
                                id: d.data.id
                            }
                        });
                        break;
                    case 'color_delete':
                        app.block.child('controlpanel/colors/presets').data({
                            deletepreset: {
                                id: d.data.id
                            }
                        });
                        break;
                    case 'pattern_list':
                        app.block
                            .child('controlpanel/patterns')
                            .on('clearlist');
                        for (var p in d.data) {
                            app.block.child('controlpanel/patterns').data({
                                newpattern: {
                                    id: d.data[p].id,
                                    name: d.data[p].name
                                }
                            });
                        }
                        // var patterns = app.block.child('controlpanel/patterns/menu/list').children();
                        // patterns[Object.keys(patterns)[0]].on('click');
                        break;
                    case 'pattern_new':
                        app.block.child('controlpanel/patterns').data({
                            newpattern: {
                                id: d.data.id,
                                name: d.data.name
                            }
                        });
                        break;
                    case 'pattern_load':
                        app.block.child('controlpanel/patterns').data({
                            patternname: {
                                id: d.data.id,
                                name: d.data.name
                            }
                        });
                        app.block
                            .child('controlpanel/patterns/area/editor')
                            .on('show');
                        app.block
                            .child('controlpanel/patterns/area/editor/colors')
                            .data({
                                list: d.data.list
                            });
                        app.currentPattern.list = d.data.list;
                        Block.queries();
                        break;
                    case 'pattern_name':
                        app.block.child('controlpanel/patterns').data({
                            patternname: {
                                id: d.data.id,
                                name: d.data.name
                            }
                        });
                        break;
                    case 'pattern_update':
                        if (app.currentPattern.id == d.data.id) {
                            app.block
                                .child(
                                    'controlpanel/patterns/area/editor/colors'
                                )
                                .data({
                                    list: d.data.list
                                });
                            app.currentPattern.list = d.data.list;
                        }
                        break;
                    case 'pattern_delete':
                        app.block.child('controlpanel/patterns').data({
                            deletepattern: {
                                id: d.data.id
                            }
                        });
                        if (app.currentPattern.id == d.data.id) {
                            app.block
                                .child('controlpanel/patterns/area/placeholder')
                                .on('show');
                            app.currentPattern.id = '';
                            app.currentPattern.name = '';
                            app.currentPattern.list = null;
                        }
                        break;
                    case 'device_list':
                        app.devices = d.data;
                        app.block
                            .child('controlpanel/patterns/directpanel/devices')
                            .data({ device_list: d.data });
                        if (app.device_id != null && !app.devices.hasOwnProperty(app.device_id)) {
                            app.selectDevice(null);
                        }
                        break;
                    case 'current':
                        if (d.data.device_id == app.device_id) {
                            var current = d.data.data;
                            var type = current ? current.type : "none";
                            if (type == 'music') {
                                app.currentItem.type = 'music';
                                app.currentItem.data = {
                                    left: current.data.left,
                                    right: current.data.right
                                };
                                app.music_settings.enabled = true;
                                app.block.child('controlpanel/patterns/area/music/enable').on('on');
                            } else if (type == 'pattern') {
                                app.currentItem.type = 'pattern';
                                app.currentItem.data = {
                                    id: current.data.id,
                                    name: current.data.name
                                };
                                app.music_settings.enabled = false;
                                app.block.child('controlpanel/patterns/area/music/enable').key('templock', 'lock').on('off');
                            } else if (type == 'hue') {
                                app.currentItem.type = 'hue';
                                app.currentItem.data = {
                                    left: current.data.left,
                                    right: current.data.right
                                };
                            } else {
                                app.currentItem.type = 'none';
                                app.currentItem.data = null;
                                app.music_settings.enabled = false;
                                app.block.child('controlpanel/patterns/area/music/enable').on('off');
                            }
                            app.block
                                .child('controlpanel/patterns/directpanel/current')
                                .data({
                                    current: app.currentItem
                                });
                        }
                        break;
                    case 'brightness':
                        if (d.data.device_id == app.device_id) {
                            app.direct.brightness = parseInt(d.data.level);
                            app.block
                                .child(
                                    'controlpanel/patterns/directpanel/brightness'
                                )
                                .data({
                                    update: app.direct.brightness
                                });
                        }
                        break;
                    case 'speed':
                        if (d.data.device_id == app.device_id) {
                            app.direct.speed = parseInt(d.data.level);
                            app.block
                                .child(
                                    'controlpanel/patterns/directpanel/speed'
                                )
                                .data({
                                    update: app.direct.speed
                                });
                        }
                        break;
                    case 'smoothing':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.smoothing = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/smoothing').data(app.music_settings.smoothing);
                        }
                        break;
                    case 'noise_gate':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.noise_gate = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/noise_gate').data(app.music_settings.noise_gate);
                        }
                        break;
                    case 'left_channel':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.l_ch = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/left-channel/ch-selector').data({ select: app.music_settings.l_ch });
                        }
                        break;
                    case 'left_invert':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.l_invert = parseInt(d.data.level) ? true : false;
                            app.block.child('controlpanel/patterns/area/music/left-channel/i-sw/switch').data(app.music_settings.l_invert ? 'on' : 'off');
                        }
                        break;
                    case 'left_preamp':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.l_preamp = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/left-preamp').data(app.music_settings.l_preamp);
                        }
                        break;
                    case 'left_postamp':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.l_postamp = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/left-postamp').data(app.music_settings.l_postamp);
                        }
                        break;
                    case 'right_channel':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.r_ch = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/right-channel/ch-selector').data({ select: app.music_settings.r_ch });
                        }
                        break;
                    case 'right_invert':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.r_invert = parseInt(d.data.level) ? true : false;
                            app.block.child('controlpanel/patterns/area/music/right-channel/i-sw/switch').data(app.music_settings.r_invert ? 'on' : 'off');
                        }
                        break;
                    case 'right_preamp':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.r_preamp = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/right-preamp').data(app.music_settings.r_preamp);
                        }
                        break;
                    case 'right_postamp':
                        if (d.data.device_id == app.device_id) {
                            app.music_settings.r_postamp = parseInt(d.data.level);
                            app.block.child('controlpanel/patterns/area/music/right-postamp').data(app.music_settings.r_postamp);
                        }
                        break;
                    default:
                        console.log('unknown event', d.event);
                        break;
                }
            } else {
                console.log('message from server:', 'invalid message', e.data);
            }
        });
        socket.addEventListener('close', function (e) {
            console.log('socket disconnected');
            // alert('disconnected from server');
            app.logout();
        });
        window.addEventListener('beforeunload', function (e) {
            // socket.close(1001);
        });
        app.socket = socket;
    },
    newColor: function () {
        if (app.socket.readyState == 1) {
            app.socket.send(
                app.encode_msg('color_new', {
                    r: app.rgb.r,
                    g: app.rgb.g,
                    b: app.rgb.b
                })
            );
        }
    },
    updateColor: function (latent) {
        if (latent == undefined) latent = false;
        if (app.socket.readyState == 1 && app.rgb.id.trim().length > 1) {
            app.socket.send(
                app.encode_msg('color_update', {
                    r: app.rgb.r,
                    g: app.rgb.g,
                    b: app.rgb.b,
                    id: app.rgb.id,
                    latent: latent
                })
            );
        }
    },
    nameColor: function (name) {
        if (app.socket.readyState == 1 && app.rgb.id.trim().length > 1) {
            app.socket.send(
                app.encode_msg('color_name', {
                    id: app.rgb.id,
                    name: name
                })
            );
        }
    },
    deleteColor: function () {
        if (app.socket.readyState == 1 && app.rgb.id.trim().length > 1) {
            app.socket.send(app.encode_msg('color_delete', { id: app.rgb.id }));
        }
    },
    testColor: function (latent) {
        if (app.socket.readyState == 1) {
            // console.log("testing color")
            if (latent == undefined) latent = false;
            if (app.device_id !== null) {
                if (latent || app.trackLiveUpdates.testColorAllowed) {
                    app.trackLiveUpdates.testColorAllowed = false;
                    setTimeout(function () {
                        app.trackLiveUpdates.testColorAllowed = true;
                    }, app.trackLiveUpdates.testColorInterval);
                    var color = null;
                    if (app.trackLiveUpdates.left && app.trackLiveUpdates.right) {
                        color = {
                            left: {
                                r: app.rgb.r,
                                g: app.rgb.g,
                                b: app.rgb.b,
                            },
                            right: {
                                r: app.rgb.r,
                                g: app.rgb.g,
                                b: app.rgb.b,
                            }
                        };
                    } else if (app.trackLiveUpdates.left) {
                        color = {
                            left: {
                                r: app.rgb.r,
                                g: app.rgb.g,
                                b: app.rgb.b,
                            }
                        };
                    } else if (app.trackLiveUpdates.right) {
                        color = {
                            right: {
                                r: app.rgb.r,
                                g: app.rgb.g,
                                b: app.rgb.b,
                            }
                        };
                    }
                    if (color != null) {
                        app.socket.send(
                            app.encode_msg('color_test', {
                                color: color,
                                latent: latent,
                                device_id: app.device_id,
                                music: latent && app.music_settings.enabled
                            })
                        );
                    }
                }
            }
        }
    },
    currentPattern: {
        id: '',
        name: '',
        list: null
    },
    currentItem: {
        type: '',
        data: null
    },
    trackPatternColorBlock: null,
    newPattern: function () {
        if (app.socket.readyState == 1) {
            app.socket.send(app.encode_msg('pattern_new', {}));
        }
    },
    loadPattern: function (id, name) {
        if (app.socket.readyState == 1) {
            app.currentPattern.id = id;
            app.currentPattern.name = name;
            app.block.child('controlpanel/patterns/area/editor').data({
                name: name
            });
            app.socket.send(app.encode_msg('pattern_load', { id: id }));
        }
    },
    renamePattern: function (name) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            app.socket.send(
                app.encode_msg('pattern_name', {
                    id: app.currentPattern.id,
                    name: name
                })
            );
        }
    },
    addPatternColor: function () {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            app.socket.send(
                app.encode_msg('pattern_add_color', {
                    id: app.currentPattern.id
                })
            );
        }
    },
    updatePatternColor: function (colorID, colorData) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            colorData.id = colorID;
            app.socket.send(
                app.encode_msg('pattern_update_color', {
                    id: app.currentPattern.id,
                    color: colorData
                })
            );
        }
    },
    movePatternColor: function (colorID, newPos) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            app.socket.send(
                app.encode_msg('pattern_move_color', {
                    id: app.currentPattern.id,
                    color: { id: colorID },
                    new_pos: newPos
                })
            );
        }
    },
    deletePatternColor: function (colorID) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            app.socket.send(
                app.encode_msg('pattern_delete_color', {
                    id: app.currentPattern.id,
                    color: { id: colorID },
                })
            );
        }
    },
    playPattern: function () {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            if (app.device_id != null) {
                app.socket.send(
                    app.encode_msg('pattern_play', { id: app.currentPattern.id, device_id: app.device_id })
                );
            }
        }
    },
    deletePattern: function () {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != '') {
            var conf = confirm(
                'Delete pattern ' + app.currentPattern.name + '?'
            );
            if (conf) {
                app.socket.send(
                    app.encode_msg('pattern_delete', {
                        id: app.currentPattern.id
                    })
                );
            }
        }
    },
    selectDevice: function (device_id, cookie = true) {
        app.device_id = device_id;
        if (device_id == null) {
            app.block.child('controlpanel/patterns/directpanel')
                .child('brightness').on('disable')
                .sibling('speed').on('disable')
                .sibling('music').on('disable')
                .sibling('current').data({ current: { type: 'no_device', data: null } })
                .sibling('devices').on('refresh');
            app.block.child('controlpanel/patterns/area/editor/playbutton').on('disable');
            app.block.child('controlpanel/colors/picker/sync').on('disable');
            if (app.block.child('controlpanel/patterns/area/music').$().css('display') == 'block')
                app.block.child('controlpanel/patterns/area/placeholder').on('show');
            if (cookie) app.util.deleteCookie('last_device');
        } else {
            app.block.child('controlpanel/patterns/directpanel')
                .child('brightness').on('enable')
                .sibling('speed').on('enable')
                .sibling('music').on('enable')
                .sibling('devices').on('refresh');
            app.block.child('controlpanel/patterns/area/editor/playbutton').on('enable');
            app.block.child('controlpanel/colors/picker/sync').on('enable');
            app.getDeviceData(device_id, false);
            if (cookie) app.util.cookie('last_device', device_id);
        }
    },
    getDeviceData: function (device_id, precheck = true) {
        if (app.socket.readyState == 1 && device_id != null && (!precheck || app.devices.hasOwnProperty(device_id))) {
            app.socket.send(app.encode_msg("get_device_data", {
                device_id: device_id
            }));
        }
    },
    nameDevice: function (device_id, name) {
        if (app.socket.readyState == 1 && device_id != null && app.devices.hasOwnProperty(device_id) && name.trim() != "") {
            app.socket.send(app.encode_msg("device_name", {
                device_id: device_id,
                name: name
            }));
        }
    },
    deleteDevice: function (device_id) {
        if (app.socket.readyState == 1 && device_id != null && app.devices.hasOwnProperty(device_id)) {
            app.socket.send(app.encode_msg("device_delete", {
                device_id: device_id
            }));
        }
    },
    playCurrent: function () {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                app.socket.send(app.encode_msg('play_current', {
                    device_id: app.device_id
                }));
            }
        }
    },
    sendBrightness: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || app.direct.brightnessAllowed) {
                    app.direct.brightnessAllowed = false;
                    setTimeout(function () {
                        app.direct.brightnessAllowed = true;
                    }, app.direct.brightnessInterval);
                    app.socket.send(
                        app.encode_msg('set_brightness', {
                            device_id: app.device_id,
                            brightness: app.direct.brightness,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    sendSpeed: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || app.direct.speedAllowed) {
                    app.direct.speedAllowed = false;
                    setTimeout(function () {
                        app.direct.speedAllowed = true;
                    }, app.direct.speedInterval);
                    app.socket.send(
                        app.encode_msg('set_speed', {
                            device_id: app.device_id,
                            speed: app.direct.speed,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    playMusic: function () {
        if (app.device_id !== null) {
            app.socket.send(app.encode_msg('music', {
                device_id: app.device_id
            }));
        }
    },
    playNone: function () {
        if (app.device_id !== null) {
            app.socket.send(app.encode_msg('play_none', {
                device_id: app.device_id
            }));
        }
    },
    sendSmoothing: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || !app.music_settings.smoothing_lock) {
                    app.music_settings.smoothing_lock = true;
                    setTimeout(function () {
                        app.music_settings.smoothing_lock = false;
                    }, app.music_settings.slider_interval);
                    app.socket.send(
                        app.encode_msg('set_smoothing', {
                            device_id: app.device_id,
                            smoothing: app.music_settings.smoothing,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    sendNoiseGate: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || !app.music_settings.noise_gate_lock) {
                    app.music_settings.noise_gate_lock = true;
                    setTimeout(function () {
                        app.music_settings.noise_gate_lock = false;
                    }, app.music_settings.slider_interval);
                    app.socket.send(
                        app.encode_msg('set_noise_gate', {
                            device_id: app.device_id,
                            noise_gate: app.music_settings.noise_gate,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    sendLeftChannel: function () {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                app.socket.send(
                    app.encode_msg('set_left_channel', {
                        device_id: app.device_id,
                        left_channel: app.music_settings.l_ch
                    })
                );
            }
        }
    },
    sendLeftInvert: function () {
        if (app.socket && app.socket.readyState == 1) {
            if (app.device_id !== null) {
                app.socket.send(
                    app.encode_msg('set_left_invert', {
                        device_id: app.device_id,
                        left_invert: app.music_settings.l_invert
                    })
                );
            }
        }
    },
    sendLeftPreamp: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || !app.music_settings.l_preamp_lock) {
                    app.music_settings.l_preamp_lock = true;
                    setTimeout(function () {
                        app.music_settings.l_preamp_lock = false;
                    }, app.music_settings.slider_interval);
                    app.socket.send(
                        app.encode_msg('set_left_preamp', {
                            device_id: app.device_id,
                            left_preamp: app.music_settings.l_preamp,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    sendLeftPostamp: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || !app.music_settings.l_postamp_lock) {
                    app.music_settings.l_postamp_lock = true;
                    setTimeout(function () {
                        app.music_settings.l_postamp_lock = false;
                    }, app.music_settings.slider_interval);
                    app.socket.send(
                        app.encode_msg('set_left_postamp', {
                            device_id: app.device_id,
                            left_postamp: app.music_settings.l_postamp,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    sendRightChannel: function () {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                app.socket.send(
                    app.encode_msg('set_right_channel', {
                        device_id: app.device_id,
                        right_channel: app.music_settings.r_ch
                    })
                );
            }
        }
    },
    sendRightInvert: function () {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                app.socket.send(
                    app.encode_msg('set_right_invert', {
                        device_id: app.device_id,
                        right_invert: app.music_settings.r_invert
                    })
                );
            }
        }
    },
    sendRightPreamp: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || !app.music_settings.r_preamp_lock) {
                    app.music_settings.r_preamp_lock = true;
                    setTimeout(function () {
                        app.music_settings.r_preamp_lock = false;
                    }, app.music_settings.slider_interval);
                    app.socket.send(
                        app.encode_msg('set_right_preamp', {
                            device_id: app.device_id,
                            right_preamp: app.music_settings.r_preamp,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    sendRightPostamp: function (latent) {
        if (app.socket.readyState == 1) {
            if (app.device_id !== null) {
                if (latent == undefined) latent = false;
                if (latent || !app.music_settings.r_postamp_lock) {
                    app.music_settings.r_postamp_lock = true;
                    setTimeout(function () {
                        app.music_settings.r_postamp_lock = false;
                    }, app.music_settings.slider_interval);
                    app.socket.send(
                        app.encode_msg('set_right_postamp', {
                            device_id: app.device_id,
                            right_postamp: app.music_settings.r_postamp,
                            latent: latent
                        })
                    );
                }
            }
        }
    },
    login: function (pass) {
        app.password = pass;
        app.socket.send(app.encode_msg('auth', { password: pass }));
    },
    logout: function () {
        app.util.deleteCookie('password');
        // window.location.reload();
        window.location.href = String(window.location.href);
    },
    load_images: function (callback) {
        var num_images = app.img.length;
        var num_loaded = 0;
        for (var i in app.img) {
            var node = new Image();
            node.onload = function () {
                num_loaded++;
                if (num_loaded >= num_images)
                    callback();
            };
            node.src = "img/" + app.img[i];
        }
    },
    colorPickerUpdate: function (picker, update, latent = false) {
        app.rgb.r = picker.rgb[0];
        app.rgb.g = picker.rgb[1];
        app.rgb.b = picker.rgb[2];
        app.block.child('controlpanel/colors/picker').data({
            color: {
                hex: picker.toHEXString(),
                r: app.rgb.r,
                g: app.rgb.g,
                b: app.rgb.b
            }
        });
        if (update == undefined || update == true) app.updateColor();
        if (app.trackLiveUpdates.left || app.trackLiveUpdates.right) {
            app.testColor(latent);
        }
        if (app.trackPatternColorBlock != null && app.trackPatternColorBlock) {
            app.trackPatternColorBlock.data({
                r: app.rgb.r,
                g: app.rgb.g,
                b: app.rgb.b
            });
        }
    },
    util: {
        mobile: function () {
            return jQuery.browser.mobile;
        },
        cookie: function (id, val, date) {
            if (Block.is.unset(val))
                document.cookie.split('; ').forEach(function (cookie) {
                    if (cookie.substring(0, id.length) == id)
                        val = cookie.substring(id.length + 1);
                });
            else
                document.cookie =
                    id +
                    '=' +
                    val +
                    (Block.is.set(date) ? '; expires=' + date : '');
            return Block.is.unset(val) ? null : val;
        },
        deleteCookie: function (id) {
            app.util.cookie(id, '', 'Thu, 01 Jan 1970 00:00:00 GMT');
        },
        lpad: function (s, width, char) {
            return s.length >= width
                ? s
                : (new Array(width).join(char) + s).slice(-width);
        }, // https://stackoverflow.com/questions/10841773/javascript-format-number-to-day-with-always-3-digits
        rgbcss: function (r, g, b) {
            return (
                'rgb(' +
                parseInt(r) +
                ',' +
                parseInt(g) +
                ',' +
                parseInt(b) +
                ')'
            );
        },
        rgbstring: function (r, g, b) {
            return (
                app.util.lpad(String(parseInt(r)), 3, '0') +
                app.util.lpad(String(parseInt(g)), 3, '0') +
                app.util.lpad(String(parseInt(b)), 3, '0')
            );
        },
        capitalize: function (word) {
            return word.charAt(0).toUpperCase() + word.slice(1);
        },
        duration_desc: function (last_timestamp) {
            var deltaSec = parseInt(Date.now() / 1000) - parseInt(last_timestamp / 1000);
            if (deltaSec < 0) {
                deltaSec = 0;
            }
            var outputString = "";
            if (deltaSec < 5) {
                outputString += "now";
            } else if (deltaSec < 60) {
                outputString += "" + parseInt(Math.floor(parseFloat(deltaSec) / 5.0) * 5.0) + " seconds ago";
            } else if (deltaSec < 3600) {
                var mins = parseInt(deltaSec / 60);
                if (mins == 1) {
                    outputString += "" + mins + " minute ago";
                } else {
                    outputString += "" + mins + " minutes ago";
                }
            } else {
                var hrs = parseInt(deltaSec / 3600);
                if (hrs == 1) {
                    outputString += "" + hrs + " hour ago";
                } else {
                    outputString += "" + hrs + " hours ago";
                }
            }
            return outputString;
        },
        hideKeyboard: function () {
            setTimeout(function () {
                app.block.child('loginform/password').node().focus();
                setTimeout(function () {
                    app.block.child('loginform/password').css('display', 'none');
                    setTimeout(function () {
                        app.block.child('loginform/password').css('display', 'inline-block');
                    }, 200);
                }, 50);
            }, 50);
        }
    },
    img: [
        'icon.png',
        'bars3_b.png',
        'clock_b.png',
        'delete_b.png',
        'down_b.png',
        'edit_b.png',
        'exit_w.png',
        'github_w.png',
        'memory_b.png',
        'palette_b.png',
        'play_b.png',
        'play_w.png',
        'plus_b.png',
        'plus_bl.png',
        'speaker_b.png',
        'sun_b.png',
        'up_b.png',
        'x_b.png'
    ],
    scheme: 'chrome',
    setScheme: function (name) {
        if (app.colors.hasOwnProperty(name)) {
            app.scheme = name;
            app.util.cookie('scheme', name);
            app.block.child('controlpanel/patterns/directpanel/scheme').data({
                select: name
            });
            Block.queries();
        }
    },
    colors: {
        material: {
            navbar: {
                background: 'rgb(38, 118, 236)',
                border: 'rgb(50, 134, 255)'
            },
            button: {
                default: 'rgb(38, 118, 236)',
                inset: 'rgb(46, 126, 244)',
                mouseover: 'rgb(50, 130, 248)',
                mouseout: 'rgb(38, 118, 236)',
                mouseup: 'rgb(50, 130, 248)',
                mousedown: 'rgb(60, 140, 255)'
            }
        },
        chrome: {
            navbar: {
                background: 'rgb(62, 62, 62)',
                border: 'rgb(74, 74, 74)'
            },
            button: {
                default: 'rgb(76, 76, 76)',
                inset: 'rgb(84, 84, 84)',
                mouseover: 'rgb(88, 88, 88)',
                mouseout: 'rgb(76, 76, 76)',
                mouseup: 'rgb(88, 88, 88)',
                mousedown: 'rgb(98, 98, 98)'
            }
        }
    }
};

window.addEventListener('load', function () {
    console.log('loading...');
    setTimeout(function () {
        app.block.load(
            function () {
                console.log('blocks loaded');
                app.load_images(function () {
                    console.log('images loaded');
                    console.log('socket connecting');
                    app.connect();
                });
            },
            'app',
            'jQuery'
        );
    }, 50);
});

// http://detectmobilebrowsers.com/
(function (a) { (jQuery.browser = jQuery.browser || {}).mobile = /(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino/i.test(a) || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(a.substr(0, 4)) })(navigator.userAgent || navigator.vendor || window.opera);

console.clear();