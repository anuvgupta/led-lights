var app = {
    id: 0,
    block: Block("div", "app"),
    socket: null,
    wsurl:
        "ws://" +
        document.domain +
        ":" +
        (document.domain == "leds.anuv.me" ? 3003 : 30003),
    password: "",
    rgb: {
        r: 0,
        g: 0,
        b: 0,
        id: ""
    },
    direct: {
        brightness: 100,
        speed: 100,
        brightnessAllowed: true,
        brightnessInterval: 100,
        speedAllowed: true,
        speedInterval: 100
    },
    trackLiveUpdates: false,
    encodeMSG: function(e, d) {
        return JSON.stringify({
            event: e,
            data: d
        });
    },
    decodeMSG: function(m) {
        try {
            m = JSON.parse(m);
        } catch (e) {
            console.log("[wss] invalid json msg ", e);
            m = null;
        }
        return m;
    },
    initblock: function(callback) {
        app.block.fill(document.body);
        $(document.body).on("DOMNodeInserted", function(e) {
            if (e.target.parentNode == document.body) {
                e.target.style.top = "65px";
                $(e.target)
                    .children()
                    .css({
                        borderRadius: "1px",
                        boxShadow: "none"
                    });
            }
        });
        setInterval(function() {
            var currentDetected = app.util.rgbstring(
                app.rgb.r,
                app.rgb.g,
                app.rgb.b
            );
            if (
                app.trackLiveUpdates &&
                app.testColorData.lastDetected == currentDetected &&
                app.testColorData.lastSent != currentDetected
            ) {
                app.testColorData.lastSent = currentDetected;
                app.socket.send(
                    app.encodeMSG("testcolor", {
                        r: app.rgb.r,
                        g: app.rgb.g,
                        b: app.rgb.b
                    })
                );
            }
            app.testColorData.lastDetected = currentDetected;
        }, app.testColorData.detectInterval);
        setTimeout(function() {
            app.block.css("opacity", "1");
        }, 50);
        Block.queries();
        setTimeout(function() {
            Block.queries();
        }, 500);
        if (app.util.mobile() || app.util.mobileAndTablet()) {
            Block.queries("off");
            $(window).on("orientationchange", function() {
                setTimeout(function() {
                    Block.queries();
                }, 250);
                setTimeout(function() {
                    Block.queries();
                }, 500);
                Block.queries();
            });
        }
        jscolor.installByClassName("jscolor");
        callback();
    },
    connect: function() {
        var socket = new WebSocket(app.wsurl);
        socket.addEventListener("open", function(e) {
            console.log("socket connected");
            app.initblock(function() {
                if (app.util.cookie("password") != null)
                    app.login(app.util.cookie("password"));
            });
        });
        socket.addEventListener("error", function(e) {
            console.log("socket error ", e.data);
        });
        socket.addEventListener("message", function(e) {
            var d = app.decodeMSG(e.data);
            if (d != null) {
                console.log("message from server:", d.event, d.data);
                switch (d.event) {
                    case "auth":
                        app.util.cookie("password", app.password);
                        app.block.on("panel");
                        break;
                    case "colorpalette":
                        app.block
                            .child("controlpanel/colors/presets")
                            .on("clear", {
                                callback: function() {
                                    for (var colorID in d.data) {
                                        if (d.data.hasOwnProperty(colorID)) {
                                            app.block
                                                .child(
                                                    "controlpanel/colors/presets"
                                                )
                                                .data({
                                                    newpreset: {
                                                        r: d.data[colorID].r,
                                                        g: d.data[colorID].g,
                                                        b: d.data[colorID].b,
                                                        id: colorID
                                                    }
                                                });
                                        }
                                    }
                                }
                            });
                        break;
                    case "newcolor":
                        app.block.child("controlpanel/colors/presets").data({
                            newpreset: {
                                r: d.data.r,
                                g: d.data.g,
                                b: d.data.b,
                                id: d.data.id,
                                sw: d.data.switch
                            }
                        });
                        break;
                    case "updatecolor":
                        app.block.child("controlpanel/colors/presets").data({
                            updatepreset: {
                                r: d.data.r,
                                g: d.data.g,
                                b: d.data.b,
                                id: d.data.id
                            }
                        });
                        break;
                    case "deletecolor":
                        app.block.child("controlpanel/colors/presets").data({
                            deletepreset: {
                                id: d.data.id
                            }
                        });
                        break;
                    case "patternlist":
                        app.block
                            .child("controlpanel/patterns")
                            .on("clearlist");
                        for (var p in d.data) {
                            app.block.child("controlpanel/patterns").data({
                                newpattern: {
                                    id: d.data[p].id,
                                    name: d.data[p].name
                                }
                            });
                        }
                        // var patterns = app.block.child('controlpanel/patterns/menu/list').children();
                        // patterns[Object.keys(patterns)[0]].on('click');
                        break;
                    case "newpattern":
                        app.block.child("controlpanel/patterns").data({
                            newpattern: {
                                id: d.data.id,
                                name: d.data.name
                            }
                        });
                        break;
                    case "loadpattern":
                        app.block.child("controlpanel/patterns").data({
                            patternname: {
                                id: d.data.id,
                                name: d.data.name
                            }
                        });
                        app.block
                            .child("controlpanel/patterns/area/editor")
                            .on("show");
                        app.block
                            .child("controlpanel/patterns/area/editor/colors")
                            .data({
                                list: d.data.list
                            });
                        app.currentPattern.list = d.data.list;
                        Block.queries();
                        break;
                    case "renamepattern":
                        app.block.child("controlpanel/patterns").data({
                            patternname: {
                                id: d.data.id,
                                name: d.data.name
                            }
                        });
                        break;
                    case "updatepattern":
                        if (app.currentPattern.id == d.data.id) {
                            app.block
                                .child(
                                    "controlpanel/patterns/area/editor/colors"
                                )
                                .data({
                                    list: d.data.list
                                });
                            app.currentPattern.list = d.data.list;
                        }
                        break;
                    case "deletepattern":
                        app.block.child("controlpanel/patterns").data({
                            deletepattern: {
                                id: d.data.id
                            }
                        });
                        if (app.currentPattern.id == d.data.id) {
                            app.block
                                .child("controlpanel/patterns/area/placeholder")
                                .on("show");
                            app.currentPattern.id = "";
                            app.currentPattern.name = "";
                            app.currentPattern.list = null;
                        }
                        break;
                    case "arduinostatus":
                        app.block
                            .child("controlpanel/patterns/directpanel/status")
                            .data({
                                statusevent: {
                                    event: d.data.lastEvent,
                                    time: d.data.lastTimestamp
                                }
                            });
                        break;
                    case "current":
                        var type = d.data.type;
                        if (type == "music") {
                            app.currentItem.type = "music";
                            app.currentItem.data = null;
                        } else if (type == "pattern") {
                            app.currentItem.type = "pattern";
                            app.currentItem.data = {
                                id: d.data.data.id,
                                name: d.data.data.name
                            };
                        } else if (type == "hue") {
                            app.currentItem.type = "hue";
                            app.currentItem.data = {
                                r: d.data.data.r,
                                g: d.data.data.g,
                                b: d.data.data.b
                            };
                        } else {
                            app.currentItem.type = "none";
                            app.currentItem.data = null;
                        }
                        app.block
                            .child("controlpanel/patterns/directpanel/current")
                            .data({
                                current: app.currentItem
                            });
                        break;
                    case "brightness":
                        app.direct.brightness = parseInt(d.data);
                        app.block
                            .child(
                                "controlpanel/patterns/directpanel/brightness"
                            )
                            .data({
                                update: app.direct.brightness
                            });
                        break;
                    case "speed":
                        app.direct.speed = parseInt(d.data);
                        app.block
                            .child("controlpanel/patterns/directpanel/speed")
                            .data({
                                update: app.direct.speed
                            });
                        break;
                    default:
                        console.log("unknown event", d.event);
                        break;
                }
            } else {
                console.log("message from server:", "invalid message", e.data);
            }
        });
        socket.addEventListener("close", function(e) {
            console.log("socket disconnected");
            // alert('disconnected from server');
            app.logout();
        });
        window.addEventListener("beforeunload", function(e) {
            // socket.close(1001);
        });
        app.socket = socket;
    },
    newColor: function() {
        if (app.socket.readyState == 1) {
            app.socket.send(
                app.encodeMSG("newcolor", {
                    r: app.rgb.r,
                    g: app.rgb.g,
                    b: app.rgb.b
                })
            );
        }
    },
    updateColor: function(latent) {
        if (latent == undefined) latent = false;
        if (app.socket.readyState == 1 && app.rgb.id.trim().length > 1) {
            app.socket.send(
                app.encodeMSG("updatecolor", {
                    r: app.rgb.r,
                    g: app.rgb.g,
                    b: app.rgb.b,
                    id: app.rgb.id,
                    latent: latent
                })
            );
        }
    },
    deleteColor: function() {
        if (app.socket.readyState == 1 && app.rgb.id.trim().length > 1) {
            app.socket.send(app.encodeMSG("deletecolor", { id: app.rgb.id }));
        }
    },
    testColorData: {
        delayInterval: 100,
        detectInterval: 500,
        allowed: true,
        lastDetected: "",
        lastSent: ""
    },
    testColor: function(override) {
        if (app.socket.readyState == 1) {
            // console.log("testing color")
            if (override == undefined) override = false;
            if (app.testColorData.allowed) {
                app.testColorData.allowed = false;
                setTimeout(function() {
                    app.testColorData.allowed = true;
                }, app.testColorData.delayInterval);
                app.socket.send(
                    app.encodeMSG("testcolor_silent", {
                        r: app.rgb.r,
                        g: app.rgb.g,
                        b: app.rgb.b
                    })
                );
            } else if (override) {
                app.socket.send(
                    app.encodeMSG("testcolor", {
                        r: app.rgb.r,
                        g: app.rgb.g,
                        b: app.rgb.b
                    })
                );
            }
        }
    },
    currentPattern: {
        id: "",
        name: "",
        list: null
    },
    currentItem: {
        type: "",
        data: null
    },
    trackPatternColorBlock: null,
    newPattern: function() {
        if (app.socket.readyState == 1) {
            app.socket.send(app.encodeMSG("newpattern", {}));
        }
    },
    loadPattern: function(id, name) {
        if (app.socket.readyState == 1) {
            app.currentPattern.id = id;
            app.currentPattern.name = name;
            app.block.child("controlpanel/patterns/area/editor").data({
                name: name
            });
            app.socket.send(app.encodeMSG("loadpattern", { id: id }));
        }
    },
    renamePattern: function(name) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            app.socket.send(
                app.encodeMSG("renamepattern", {
                    id: app.currentPattern.id,
                    name: name
                })
            );
        }
    },
    addPatternColor: function() {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            app.socket.send(
                app.encodeMSG("addpatterncolor", { id: app.currentPattern.id })
            );
        }
    },
    updatePatternColor: function(colorID, colorData) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            app.socket.send(
                app.encodeMSG("updatepatterncolor", {
                    id: app.currentPattern.id,
                    colorID: colorID,
                    colorData: colorData
                })
            );
        }
    },
    movePatternColor: function(colorID, newPos) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            app.socket.send(
                app.encodeMSG("movepatterncolor", {
                    id: app.currentPattern.id,
                    colorID: colorID,
                    newPos: newPos
                })
            );
        }
    },
    deletePatternColor: function(colorID) {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            app.socket.send(
                app.encodeMSG("deletepatterncolor", {
                    id: app.currentPattern.id,
                    colorID: colorID
                })
            );
        }
    },
    playPattern: function() {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            app.socket.send(
                app.encodeMSG("playpattern", { id: app.currentPattern.id })
            );
        }
    },
    deletePattern: function() {
        if (app.socket.readyState == 1 && app.currentPattern.id.trim() != "") {
            var conf = confirm(
                "Delete pattern " + app.currentPattern.name + "?"
            );
            if (conf) {
                app.socket.send(
                    app.encodeMSG("deletepattern", {
                        id: app.currentPattern.id
                    })
                );
            }
        }
    },
    playCurrent: function() {
        if (app.socket.readyState == 1) {
            if (app.currentItem.type == "pattern") {
                app.playPattern();
            } else if (app.currentItem.type == "hue") {
                app.socket.send(
                    app.encodeMSG("testcolor", {
                        r: app.rgb.r,
                        g: app.rgb.g,
                        b: app.rgb.b
                    })
                );
            }
        }
    },
    sendBrightness: function() {
        if (app.socket.readyState == 1) {
            if (app.direct.brightnessAllowed) {
                app.direct.brightnessAllowed = false;
                setTimeout(function() {
                    app.direct.brightnessAllowed = true;
                }, app.direct.brightnessInterval);
                app.socket.send(
                    app.encodeMSG("setbrightness", {
                        brightness: app.direct.brightness
                    })
                );
            }
        }
    },
    sendSpeed: function() {
        if (app.socket.readyState == 1) {
            if (app.direct.speedAllowed) {
                app.direct.speedAllowed = false;
                setTimeout(function() {
                    app.direct.speedAllowed = true;
                }, app.direct.speedInterval);
                app.socket.send(
                    app.encodeMSG("setspeed", { speed: app.direct.speed })
                );
            }
        }
    },
    playMusic: function () {
        app.socket.send(app.encodeMSG("music", ""));
    },
    login: function(pass) {
        app.password = pass;
        app.socket.send(app.encodeMSG("auth", { password: pass }));
    },
    logout: function() {
        app.util.deleteCookie("password");
        // window.location.reload();
        window.location.href = String(window.location.href);
    },
    loadImages: function(callback) {
        var check = function() {
            for (var name in app.img) {
                if (!app.img[name].loaded) return false;
            }
            return true;
        };
        app.img.icon.$ = new Image();
        app.img.icon.$.onload = function() {
            app.img.icon.loaded = true;
            if (check()) callback();
        };
        app.img.icon.$.src = "img/icon.png";
    },
    colorPickerUpdate: function(picker, update) {
        app.rgb.r = picker.rgb[0];
        app.rgb.g = picker.rgb[1];
        app.rgb.b = picker.rgb[2];
        app.block.child("controlpanel/colors/picker").data({
            color: {
                hex: picker.toHEXString(),
                r: app.rgb.r,
                g: app.rgb.g,
                b: app.rgb.b
            }
        });
        if (update == undefined || update == true) app.updateColor();
        if (app.trackLiveUpdates) {
            app.testColor();
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
        mobile: function() {
            var check = false;
            (function(a) {
                if (
                    /(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino|android|ipad|playbook|silk/i.test(
                        a
                    ) ||
                    /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(
                        a.substr(0, 4)
                    )
                )
                    check = true;
            })(navigator.userAgent || navigator.vendor || window.opera);
            return check;
        }, // https://stackoverflow.com/questions/11381673/detecting-a-mobile-browser
        mobileAndTablet: function() {
            var check = false;
            (function(a) {
                if (
                    /(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino|android|ipad|playbook|silk/i.test(
                        a
                    ) ||
                    /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(
                        a.substr(0, 4)
                    )
                )
                    check = true;
            })(navigator.userAgent || navigator.vendor || window.opera);
            return check;
        }, // https://stackoverflow.com/questions/11381673/detecting-a-mobile-browser
        cookie: function(id, val, date) {
            if (Block.is.unset(val))
                document.cookie.split("; ").forEach(function(cookie) {
                    if (cookie.substring(0, id.length) == id)
                        val = cookie.substring(id.length + 1);
                });
            else
                document.cookie =
                    id +
                    "=" +
                    val +
                    (Block.is.set(date) ? "; expires=" + date : "");
            return Block.is.unset(val) ? null : val;
        },
        deleteCookie: function(id) {
            app.util.cookie(id, "", "Thu, 01 Jan 1970 00:00:00 GMT");
        },
        lpad: function(s, width, char) {
            return s.length >= width
                ? s
                : (new Array(width).join(char) + s).slice(-width);
        }, // https://stackoverflow.com/questions/10841773/javascript-format-number-to-day-with-always-3-digits
        rgbcss: function(r, g, b) {
            return (
                "rgb(" +
                parseInt(r) +
                "," +
                parseInt(g) +
                "," +
                parseInt(b) +
                ")"
            );
        },
        rgbstring: function(r, g, b) {
            return (
                app.util.lpad(String(parseInt(r)), 3, "0") +
                app.util.lpad(String(parseInt(g)), 3, "0") +
                app.util.lpad(String(parseInt(b)), 3, "0")
            );
        }
    },
    img: {
        icon: { $: null, loaded: false }
    }
};

window.addEventListener("load", function() {
    console.log("loading...");
    setTimeout(function() {
        app.block.load(
            function() {
                console.log("blocks loaded");
                app.loadImages(function() {
                    console.log("images loaded");
                    console.log("socket connecting");
                    app.connect();
                });
            },
            "app",
            "jQuery"
        );
    }, 300);
});

console.clear();
