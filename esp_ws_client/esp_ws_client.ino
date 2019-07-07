// includes
#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WiFiMulti.h>
#include <WebSocketsClient.h>
#include <Hash.h>
#include "secrets.h"

// wifi bars
ESP8266WiFiMulti wifi;
WebSocketsClient ws;

// constants
#define SERIAL Serial
#define ESP_DEBUG_V false
#define DEBUG_MODE false
//#define SERVER "10.0.1.40"
//#define PORT 30003
#define SERVER "leds.anuv.me"
#define PORT 3003

// parsing data
int mb_i = 0;
char msgbuff[500]; // extra size just in case

void wsEventHandler(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_DISCONNECTED:
      if (DEBUG_MODE) SERIAL.printf("[ws] disconnected\n");
      break;
    case WStype_CONNECTED:
       if (DEBUG_MODE) SERIAL.printf("[ws] connected to %s\n", payload);
       if (DEBUG_MODE) SERIAL.printf("[ws] syncing as arduino\n");
      ws.sendTXT("{\"event\":\"arduinosync\",\"data\":true}");
      break;
    case WStype_TEXT:
      // SERIAL.printf("[ws] received text – %s\n", payload);
      if (memcmp(payload, "@arduinosync", 12) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] synced as arduino\n");
        if (DEBUG_MODE) SERIAL.printf("[ws] authenticating\n");
        ws.sendTXT(SECRET_AUTH_JSON); // authenticate with password
      } else if (memcmp(payload, "@auth", 5) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] authenticated\n");
        Serial.printf("ready\n");
      } else if (memcmp(payload, "@p-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new pattern - %s\n", payload + 3);
        Serial.printf("p%s\n", payload + 3);
      } else if (memcmp(payload, "@h-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new hue - %s\n", payload + 3);
        Serial.printf("h%s\n", payload + 3);
      } else if (memcmp(payload, "@b-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new brightness - %s\n", payload + 3);
        Serial.printf("b%s\n", payload + 3);
      } else if (memcmp(payload, "@s-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new speed mult - %s\n", payload + 3);
        Serial.printf("s%s\n", payload + 3);
      } else if (memcmp(payload, "@hb", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] heartbeat\n");
        ws.sendTXT("{\"event\":\"arduinoheartbeat\"}");
      } else if (memcmp(payload, "@music", 6) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] music mode\n");
        Serial.printf("music\n");
      }
      break;
    case WStype_BIN:
      if (DEBUG_MODE) SERIAL.printf("[ws] received binary data (length %u):\n", length);
      hexdump(payload, length);
      // ws.sendBIN(payload, length);
      break;
  }
}

void setup() {
  SERIAL.begin(9600);
  SERIAL.setDebugOutput(ESP_DEBUG_V);
  if (DEBUG_MODE) SERIAL.println("\n\n");
  if (DEBUG_MODE) SERIAL.println("ESP8266");
  for (uint8_t t = 2; t > 0; t--) {
    if (DEBUG_MODE) SERIAL.printf("[boot] wait %d\n", t);
    if (DEBUG_MODE) SERIAL.flush();
    delay(1000);
  }
  if (DEBUG_MODE) SERIAL.printf("[wifi] connecting to %s\n", &secret_ssid);
  wifi.addAP(SECRET_SSID, SECRET_PASS);
  while (wifi.run() != WL_CONNECTED) delay(50);
  if (DEBUG_MODE) SERIAL.printf("[wifi] connected\n");
  if (DEBUG_MODE) SERIAL.printf("[ws] connecting\n");
  ws.begin(SERVER, PORT, "/");
  ws.onEvent(wsEventHandler);
  // ws.setAuthorization("user", "Password");
  ws.setReconnectInterval(5000);
  
  // start heartbeat (optional)
  // ping server every 15000 ms
  // expect pong from server within 3000 ms
  // consider connection disconnected if pong is not received 2 times
   ws.enableHeartbeat(15000, 3000, 2);
}

void loop() {
  ws.loop();
  if (Serial.available()) {
    if (mb_i >= 500) {
      msgbuff[499] = '\n';
      if (DEBUG_MODE) Serial.println(msgbuff);
      mb_i = 0;
    } else {
      char c = Serial.read();
      if (c != -1) {
        // Serial.print(c);
        if (c == '\n') {
          msgbuff[mb_i] = '\0';
          if (memcmp(msgbuff + mb_i - 5, "reset", 5) == 0) {
            if (DEBUG_MODE) Serial.println(F("[boot] resetting...\n"));
            ESP.restart();
          }
          mb_i = 0;
        } else if (c != 0 && c > 32 && c < 126) {
          msgbuff[mb_i] = c;
          // Serial.println("msgbuff[" + String(mb_i) + "] " + String(msgbuff[mb_i]) + " (" + String((uint8_t) msgbuff[mb_i]) + ")");
          mb_i++;
        }
      }
    }
  }
}
