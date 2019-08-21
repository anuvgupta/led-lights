# led-lights

IoT audio-reactive LED strip lights driven by Arduino, ESP8266 WebSockets, &amp; MSGEQ7 beat detection, with web & iOS control panels.

## overview

iOS control panel app (or online webpage) uses WebSocket client APIs to send custom color presets & patterns as well as audio react settings to node.js WebSocket server.
ESP8266 connects to node.js server as a WebSocket client (from behind firewall). Server forwards presets, patterns & settings sent by iOS/web clients to ESP8266.
ESP8266 forwards this data to Arduino over hardware serial. Arduino receives data over SoftwareSerial, and then parses. Arduino drives RGB LED strip according to settings, using PWM, transistors, and external power.
MSGEQ7 takes an audio jack input from any source and filters frequencies into bass, treble, & 5 other bands. If audio reactive mode enabled, Arduino will read & transform MSGEQ7 output according to settings, and drive LEDs based on amplitude.

## schematic

![Fritzing Schematic](https://rawcdn.githack.com/anuvgupta/led-lights/c14cc283c60d811c712debd8daacecd9c4bc2f68/circuit_schematics/esp_led_lights_bb.png)

## audio react

Audio reactive mode – recommended settings:

**Global**

-   Smoothing: `85-95`
-   Noise Gate: `30-40`

**Bass**

-   Channel: `1`
-   Invert: `off`
-   Pre-Amp: `70-120`
-   Post-Amp: `1`

**Treble**

-   Channel: `7`
-   Invert: `off`
-   Pre-Amp: `70-120`
-   Post-Amp: `1`

**Inverted Bass**

-   Channel: `1`
-   Invert: `on`
-   Pre-Amp: `60-90`
-   Post-Amp: `5-7`

## components

#### ESP8266

-   Model: [DIYmall ESP8266 ESP-01S](https://www.amazon.com/gp/product/B00O34AGSU/) with 1MB flash
-   Built with Arduino IDE instead of standard AT firmware
-   Uses standard ESP8266WiFi libraries and [arduinoWebSockets by Links2004](https://github.com/Links2004/arduinoWebSockets) client
-   Uses external 3V breadboard power source
-   NodeMCU is also compatible

#### Arduino

-   Model: [Elegoo Uno R3](https://www.amazon.com/Elegoo-EL-CB-001-ATmega328P-ATMEGA16U2-Arduino/dp/B01EWOE0UU) ([kit](https://www.elegoo.com/product/elegoo-uno-project-super-starter-kit/))
-   Uses SoftwareSerial (modified slightly to hold longer messages) on pins 6-7 to read patterns from ESP8266
-   Uses PWM on digital pins 9-11 to write color values to LED strip
    -   Pins connected to LED strip through N-channel MOSFET [TO-220](https://www.amazon.com/gp/product/B07CTJFG7M) transistors
    -   LED strip connected to external +12V power source
-   Arduino Nano is also compatible

#### WebSocket/HTTP Server

-   Runs on [anuv.me:3002/3003](http://anuv.me) (behind [leds.anuv.me](http://leds.anuv.me))
-   Built with node.js (express & WebSocket)

#### Control Panel

-   Hosted at [leds.anuv.me](http://leds.anuv.me)
-   Built with [block.js](https://github.com/anuvgupta/block.js), jQuery, WebSocket
