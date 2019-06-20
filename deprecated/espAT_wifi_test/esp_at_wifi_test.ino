
#include "SoftwareSerial.h"

#define Console Serial

String ssid = "ssid";
String pass = "password";
SoftwareSerial ESP8266(6, 7);

String host = "postman-echo.com";
String file = "get?foo1=bar1&foo2=bar2";

int ci = 0;
int ci_m = 7;
String commands[7] = {
  "AT",
  //"AT+UART?",
  //"AT+GMR",
  "AT+CWMODE=1",
  "AT+CWJAP=\"" + (ssid + "\",\"" + pass + "\""),
  //"AT+CIFSR",
  "AT+CIPMUX=0",
  "AT+CIPSTART=\"TCP\",\"" + host + "\",80",
  "AT+CIPSEND=",
  "GET /" + file + " HTTP/1.1\r\nHost: " + host + "\r\nConnection: close\r\nAccept: */*\r\n\r\n"
};

void setup() {
  // open console (hardware) serial
  Console.begin(9600);
  // open ESP8266 (software) serial
  ESP8266.begin(9600);
  // init button
  pinMode(13, INPUT);
  // modify command
  commands[5] += String(commands[6].length());
  // print instructions
  Console.write("press button 13 to send next command\r\n");
}

// button press & release detector
int bstate = LOW;
boolean pressAndRelease() {
  int nbstate = digitalRead(13);
  boolean ret = (nbstate == LOW && bstate == HIGH);
  bstate = nbstate;
  return ret;
}

void loop() {
  // send next command on press & release
  if (pressAndRelease()) {
    if (ci < ci_m) {
      Console.write("\r\n");
      ESP8266.write(commands[ci].c_str());
      ESP8266.write("\r\n");
      ci++;
    }
    delay(100); // debounce
  }
  
  // indefinitely display ESP8266 output on console
  if (ESP8266.available()) {
    Console.write(ESP8266.read());
  }
  // indefinitely send console input to ESP8266
  if (Console.available()) {
    ESP8266.write(Console.read());
  }
}
