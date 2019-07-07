# led-lights
IoT RGB LED strip lights driven by Arduino &amp; ESP8266 WebSockets, with online control panel

## Overview
iOS control panel app (or online webpage) uses WebSocket client APIs to send custom color presets and fRGBh patterns (fade time, red, green, blue, hold time) to node.js WebSocket server. ESP8266 connects to WiFi and then the node.js WebSocket server. Server forwards presets & patterns sent by iOS/web clients to ESP8266's WebSocket client. ESP8266 forwards pattern to Arduino over hardware serial. Arduino receives pattern over SoftwareSerial and parses into series of fRGBh settings. Arduino drives RGB LED strip according to pattern, using PWM, transistors, and external power.

## Schematic
![Fritzing Schematic](https://rawcdn.githack.com/anuvgupta/led-lights/c14cc283c60d811c712debd8daacecd9c4bc2f68/circuit_schematics/esp_led_lights_bb.png)

## ESP8266
 - Model: [DIYmall ESP8266 ESP-01S](https://www.amazon.com/gp/product/B00O34AGSU/) with 1MB flash
 - Built with Arduino IDE instead of standard AT firmware
 - Uses standard ESP8266WiFi libraries and [arduinoWebSockets by Links2004](https://github.com/Links2004/arduinoWebSockets) client
 - Uses external 3V breadboard power source
 - NodeMCU is also compatible

## Arduino
 - Model: [Elegoo Uno R3](https://www.amazon.com/Elegoo-EL-CB-001-ATmega328P-ATMEGA16U2-Arduino/dp/B01EWOE0UU) ([kit](https://www.elegoo.com/product/elegoo-uno-project-super-starter-kit/))
 - Uses SoftwareSerial (modified slightly to hold longer messages) on pins 6-7 to read patterns from ESP8266
 - Uses PWM on digital pins 9-11 to write color values to LED strip
    - Pins connected to LED strip through N-channel MOSFET [TO-220](https://www.amazon.com/gp/product/B07CTJFG7M) transistors
    - LED strip connected to external +12V power source
 - Arduino Nano is also compatible

## WebSocket/HTTP Server
 - Runs on [anuv.me:3002&nbsp;&amp;&nbsp;3003](http://anuv.me)
 - Built with node.js (express & WebSocket)

## Control Panel
 - Hosted at [leds.anuv.me](http://leds.anuv.me)
 - Built with [block.js](https://github.com/anuvgupta/block.js), jQuery, WebSocket
