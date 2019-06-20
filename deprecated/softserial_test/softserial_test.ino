
#include "SoftwareSerial.h"

SoftwareSerial ESP8266(6, 7);

void setup() {
  Serial.begin(9600);
  ESP8266.begin(9600);
}

void loop() {
  if (ESP8266.available()) {
    Serial.write(ESP8266.read());
  }
  if (Serial.available()) {
    ESP8266.write(Serial.read());
  }
}
