/*
 * led-lights
 * alexa skill hosted lambda endpoint
 */

// libraries
const Alexa = require("ask-sdk-core");
const fetch = require("node-fetch");
const secrets = require("./secrets");

// rest api access
const api_url = "leds.anuv.me/api";
const api_auth = secrets.password;
async function LEDS(endpoint, method, data = null) {
    var options = {
        method: method.toUpperCase(),
        headers: {
            Authorization: api_auth
        }
    };
    if (data !== null) {
        options.body = JSON.stringify(data);
        options.headers["Content-Type"] = "application/json";
    }
    var res = await fetch("http://" + api_url + "/" + endpoint, options);
    var output = await res.json();
    // if (!output.success)
    //     throw new Error(output.message ? output.message : "unknown error");
    return output;
}

// built-in intents/requests
const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return handlerInput.requestEnvelope.request.type === "LaunchRequest";
    },
    async handle(handlerInput) {
        var data = await LEDS("arduinostatus", "get");
        data = data.payload.status;
        if (data.event === "disconnected") data.event = "Offline";
        else if (data.event === "connected") data.event = "Syncing";
        else if (data.event === "authenticated") data.event = "Syncing";
        else if (data.event === "online") data.event = "Online";
        const speechText = data.event + ".";
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt(speechText)
            .getResponse();
    }
};
const HelpIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "AMAZON.HelpIntent"
        );
    },
    handle(handlerInput) {
        const speechText =
            "Commands: status, colors, set color, patterns, play pattern, brightness, brightness up or down, speed, speed up or down";

        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
const CancelAndStopIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            (handlerInput.requestEnvelope.request.intent.name ===
                "AMAZON.CancelIntent" ||
                handlerInput.requestEnvelope.request.intent.name ===
                    "AMAZON.StopIntent")
        );
    },
    handle(handlerInput) {
        const speechText = "Goodbye.";
        return handlerInput.responseBuilder.speak(speechText).getResponse();
    }
};
const SessionEndedRequestHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "SessionEndedRequest"
        );
    },
    handle(handlerInput) {
        // cleanup logic
        return handlerInput.responseBuilder.getResponse();
    }
};

// arduino status intent
const ArduinoStatusIntent = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "ArduinoStatusIntent"
        );
    },
    async handle(handlerInput) {
        var data = await LEDS("arduinostatus", "get");
        data = data.payload.status;
        if (data.event === "disconnected") data.event = "Offline";
        else if (data.event === "connected") data.event = "Syncing";
        else if (data.event === "authenticated") data.event = "Syncing";
        else if (data.event === "online") data.event = "Online";
        const speechText = data.event + ", " + data.humantime + ".";
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// color list intent
const ColorListIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "ColorListIntent"
        );
    },
    async handle(handlerInput) {
        var colorsText = "";
        var data = await LEDS("colorlist", "get");
        data = data.payload.colors;
        if (Array.isArray(data) && data.length > 0) {
            for (var p in data) {
                colorsText += data[p].name + ", ";
            }
        }
        const speechText = colorsText.substring(0, colorsText.length - 2) + ".";
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// test color intent
const TestColorIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "TestColorIntent"
        );
    },
    async handle(handlerInput) {
        var name = (
            "" + handlerInput.requestEnvelope.request.intent.slots.name.value
        )
            .trim()
            .toLowerCase();
        var data = await LEDS("testcolor", "post", { name: name });
        var speechText = "";
        if (data.success) {
            speechText = "Color " + name;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// pattern list intent
const PatternListIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "PatternListIntent"
        );
    },
    async handle(handlerInput) {
        var patternsText = "";
        var data = await LEDS("patternlist", "get");
        data = data.payload.patterns;
        if (Array.isArray(data) && data.length > 0) {
            for (var p in data) {
                patternsText += data[p].name + ", ";
            }
        }
        const speechText =
            patternsText.substring(0, patternsText.length - 2) + ".";
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// play pattern intent
const PlayPatternIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "PlayPatternIntent"
        );
    },
    async handle(handlerInput) {
        var name = (
            "" + handlerInput.requestEnvelope.request.intent.slots.name.value
        )
            .trim()
            .toLowerCase();
        var data = await LEDS("playpattern", "post", { name: name });
        var speechText = "";
        if (data.success) {
            speechText = "Pattern " + name;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// get brightness intent
const GetBrightnessIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "GetBrightnessIntent"
        );
    },
    async handle(handlerInput) {
        var data = await LEDS("brightness", "get");
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// set brightness intent
const SetBrightnessIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "SetBrightnessIntent"
        );
    },
    async handle(handlerInput) {
        var level = parseInt(
            (
                "" +
                handlerInput.requestEnvelope.request.intent.slots.level.value
            ).trim()
        );
        var data = await LEDS("brightness", "post", { level: level });
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// increase brightness intent
const IncBrightnessIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "IncBrightnessIntent"
        );
    },
    async handle(handlerInput) {
        var inc = handlerInput.requestEnvelope.request.intent.slots.inc.value
            ? parseInt(
                  (
                      "" +
                      handlerInput.requestEnvelope.request.intent.slots.inc
                          .value
                  ).trim()
              )
            : "up";
        var data = await LEDS("brightness", "post", { increment: inc });
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// decrease brightness intent
const DecBrightnessIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "DecBrightnessIntent"
        );
    },
    async handle(handlerInput) {
        var inc = handlerInput.requestEnvelope.request.intent.slots.inc.value
            ? parseInt(
                  (
                      "" +
                      handlerInput.requestEnvelope.request.intent.slots.inc
                          .value
                  ).trim()
              ) * -1
            : "down";
        var data = await LEDS("brightness", "post", { increment: inc });
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// get speed intent
const GetSpeedIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "GetSpeedIntent"
        );
    },
    async handle(handlerInput) {
        var data = await LEDS("speed", "get");
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// set speed intent
const SetSpeedIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "SetSpeedIntent"
        );
    },
    async handle(handlerInput) {
        var level = parseInt(
            (
                "" +
                handlerInput.requestEnvelope.request.intent.slots.level.value
            ).trim()
        );
        var data = await LEDS("speed", "post", { level: level });
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// increase speed intent
const IncSpeedIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "IncSpeedIntent"
        );
    },
    async handle(handlerInput) {
        var inc = handlerInput.requestEnvelope.request.intent.slots.inc.value
            ? parseInt(
                  (
                      "" +
                      handlerInput.requestEnvelope.request.intent.slots.inc
                          .value
                  ).trim()
              )
            : "up";
        var data = await LEDS("speed", "post", { increment: inc });
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};
// decrease speed intent
const DecSpeedIntentHandler = {
    canHandle(handlerInput) {
        return (
            handlerInput.requestEnvelope.request.type === "IntentRequest" &&
            handlerInput.requestEnvelope.request.intent.name ===
                "DecSpeedIntent"
        );
    },
    async handle(handlerInput) {
        var inc = handlerInput.requestEnvelope.request.intent.slots.inc.value
            ? parseInt(
                  (
                      "" +
                      handlerInput.requestEnvelope.request.intent.slots.inc
                          .value
                  ).trim()
              ) * -1
            : "down";
        var data = await LEDS("speed", "post", { increment: inc });
        var speechText = "";
        if (data.success) {
            speechText = "Level " + data.payload.level;
        } else {
            speechText = data.message;
        }
        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};

// intent reflector catch-all (repeats intent name)
const IntentReflectorHandler = {
    canHandle(handlerInput) {
        return handlerInput.requestEnvelope.request.type === "IntentRequest";
    },
    handle(handlerInput) {
        const intentName = handlerInput.requestEnvelope.request.intent.name;
        const speechText = `Triggered ${intentName}`;

        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};

// generic error handling (syntax or routing errors)
const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        console.log(`~~~~ Error handled: ${error.message}`);
        const speechText = `Sorry, An error occurred. Please try again.`;

        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt()
            .getResponse();
    }
};

// skill entry point
// (routes request & response payloads to intent handlers, processed top to bottom)
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        ArduinoStatusIntent,
        ColorListIntentHandler,
        TestColorIntentHandler,
        PatternListIntentHandler,
        PlayPatternIntentHandler,
        GetBrightnessIntentHandler,
        SetBrightnessIntentHandler,
        IncBrightnessIntentHandler,
        DecBrightnessIntentHandler,
        GetSpeedIntentHandler,
        SetSpeedIntentHandler,
        IncSpeedIntentHandler,
        DecSpeedIntentHandler,

        HelpIntentHandler,
        CancelAndStopIntentHandler,
        SessionEndedRequestHandler,
        IntentReflectorHandler
    ) // catch-all is last
    .addErrorHandlers(ErrorHandler)
    .lambda();
