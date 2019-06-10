# led-lights
IoT RGB LED strip lights driven by Arduino &amp; ESP8266 WebSockets, with online control panel

## Overview
Online control panel webpage uses JavaScript WebSocket client to send custom fRGBt patterns (fade time, red, green, blue, hold time) to node.js WebSocket server. When ESP8266 connects to WiFi, server forwards pattern to ESP8266's WebSocket client. ESP8266 forwards pattern to Arduino over hardware serial. Arduino receives pattern over SoftwareSerial and parses into series of fRGBt settings. Arduino drives RGB LED strip according to pattern, using PWM, transistors, and external power.

## Schematic


## ESP8266
 - Model: [DIYmall ESP8266 ESP-01S](https://www.amazon.com/gp/product/B00O34AGSU/) with 1MB flash
 - Built with Arduino IDE instead of standard AT firmware
 - Uses standard ESP8266WiFi libraries and [arduinoWebSockets by Links2004](https://github.com/Links2004/arduinoWebSockets) client
 - Uses external 3V breadboard power source

## Arduino
 - Model: [Elegoo Uno R3](https://www.amazon.com/Elegoo-EL-CB-001-ATmega328P-ATMEGA16U2-Arduino/dp/B01EWOE0UU) ([kit](https://www.elegoo.com/product/elegoo-uno-project-super-starter-kit/))
 - Uses SoftwareSerial (modified slightly to hold longer messages) on pins 6-7 to read patterns from ESP8266
 - Uses PWM on digital pins 9-11 to write color values to LED strip
    - Pins connected to LED strip through N-channel MOSFET [TO-220](https://www.amazon.com/gp/product/B07CTJFG7M) transistors
    - LED strip connected to external +12V power source

## WebSocket/HTTP Server
 - Runs on [anuv.me:3002&nbsp;&amp;&nbsp;3003](http://anuv.me)
 - Built with node.js (express & WebSocket)

## Control Panel
 - Hosted at [leds.anuv.me](http://leds.anuv.me)
 - Built with [block.js](https://github.com/anuvgupta/block.js), jQuery, WebSocket
