const Alexa = require("ask-sdk-core");
const fetch = require("node-fetch");

const api_url = "leds.anuv.me/api";
const api_auth = "password";
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
    handle(handlerInput) {
        const speechText = "Lights";
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
            "Commands: status, colors, set color, patterns, play pattern, brightness, brightness up/down, speed, speed up/down";

        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt(speechText)
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
        // Any cleanup logic goes here.
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
        const speechText =
            data.event.substring(0, 1).toUpperCase() +
            data.event.substring(1) +
            ", " +
            data.humantime +
            ".";
        return handlerInput.responseBuilder.speak(speechText).getResponse();
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
        return handlerInput.responseBuilder.speak(speechText).getResponse();
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
        return handlerInput.responseBuilder.speak(speechText).getResponse();
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
        return handlerInput.responseBuilder.speak(speechText).getResponse();
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

        return (
            handlerInput.responseBuilder
                .speak(speechText)
                //.reprompt('add a reprompt if you want to keep the session open for the user to respond')
                .getResponse()
        );
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
            .reprompt(speechText)
            .getResponse();
    }
};

// This handler acts as the entry point for your skill, routing all request and response
// payloads to the handlers above. Make sure any new handlers or interceptors you've
// defined are included below. The order matters - they're processed top to bottom.
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        ArduinoStatusIntent,
        ColorListIntentHandler,
        TestColorIntentHandler,
        PatternListIntentHandler,

        HelpIntentHandler,
        CancelAndStopIntentHandler,
        SessionEndedRequestHandler,
        IntentReflectorHandler
    ) // make sure IntentReflectorHandler is last so it doesn't override your custom intent handlers
    .addErrorHandlers(ErrorHandler)
    .lambda();
