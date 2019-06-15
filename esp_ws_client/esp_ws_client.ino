#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WiFiMulti.h>
#include <WebSocketsClient.h>
#include <Hash.h>
#include "secrets.h"

ESP8266WiFiMulti wifi;
WebSocketsClient ws;

#define SERIAL Serial
#define ESP_DEBUG_V false
#define DEBUG_MODE false
#define SERVER "10.0.1.36"
#define PORT 30003
//#define SERVER "leds.anuv.me"
//#define PORT 3003

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
        if (DEBUG_MODE) SERIAL.printf("[ws] new pattern – %s\n", payload + 3);
        Serial.printf("p%s\n", payload + 3);
      } else if (memcmp(payload, "@h-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new hue – %s\n", payload + 3);
        Serial.printf("h%s\n", payload + 3);
      } else if (memcmp(payload, "@b-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new brightness – %s\n", payload + 3);
        Serial.printf("b%s\n", payload + 3);
      } else if (memcmp(payload, "@s-", 3) == 0) {
        if (DEBUG_MODE) SERIAL.printf("[ws] new speed mult – %s\n", payload + 3);
        Serial.printf("s%s\n", payload + 3);
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
  for (uint8_t t = 4; t > 0; t--) {
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
  // ws.enableHeartbeat(15000, 3000, 2);
}

void loop() {
  ws.loop();
}
