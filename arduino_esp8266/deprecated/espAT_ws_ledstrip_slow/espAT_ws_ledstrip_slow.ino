// includes
#include <WiFiEsp.h>
#include <ArduinoHttpClient.h>
#include <SoftwareSerial.h>
#include "secrets.h"

// LED PWM pins
#define REDPIN 9
#define GREENPIN 10
#define BLUEPIN 11

// WiFi connection constants
char ssid[] = SECRET_SSID;
char pass[] = SECRET_PASS;
char serverAddress[] = "10.0.1.36";
int port = 30003;

// ESP8266 WiFi & WebSocket client
SoftwareSerial ESP8266(6, 7); // RX, TX
WiFiEspClient wifi;
WebSocketClient client = WebSocketClient(wifi, serverAddress, port);
int status = WL_IDLE_STATUS;

// parsing data
char msgbuff[300]; // long enough without running out of memory
char tokenbuff[16]; // max rgb digits = 1(#) + 3(r) + 3(g) + 3(b) + 5(t - int dig max) + 1(\0)
char databuff[6]; // 5(t - int dig max) + 1(\0)
int msgstatus = 0;
// rgb data
double r = 0; // hue red
double g = 0; // hue green
double b = 0; // hue blue
int t = 0; // hue time (ms)
int tr = 0; // transition (ms)

void setup() {
  // init hardware and software serials
  Serial.begin(9600);
  ESP8266.begin(9600);

  // init LED PWM pins
  pinMode(REDPIN, OUTPUT);
  pinMode(GREENPIN, OUTPUT);
  pinMode(BLUEPIN, OUTPUT);
  red(0); green(0); blue(0);

  // init ESP8266 and connect to wifi
  WiFi.init(&ESP8266);
  while (status != WL_CONNECTED) {
    Serial.print(F("Attempting to connect to "));
    Serial.println(ssid);
    status = WiFi.begin(ssid, pass);
  }
  Serial.print(F("SSID: "));
  Serial.println(WiFi.SSID());
  IPAddress ip = WiFi.localIP();
  Serial.print(F("IP Address: "));
  Serial.println(ip);
}

void loop() {
  // connect to WebSocket Server
  Serial.println(F("Starting WebSocket client"));
  boolean first = true;
  client.begin();
  while (client.connected()) {
    // drive LED's
    red(r);
    green(g);
    blue(b);
    
    // on first iteration, authenticate and establish as arduino client
    if (first) {
      Serial.println(F("Connected to WebSocket server"));
      client.beginMessage(TYPE_TEXT);
      client.print(F("{\"event\":\"auth\",\"data\":{\"password\":\""));
      client.print(F(SECRET_APP_PASS));
      client.print(F("\"}}"));
      client.endMessage();
      client.beginMessage(TYPE_TEXT);
      client.print(F("{\"event\":\"arduinosync\",\"data\":true}"));
      client.endMessage();
      first = false;
    }

    // check websocket for data
    msgstatus = client.parseMessage();
    if (msgstatus > 0) {
      // strncpy(msgbuff, client.readString().c_str(), 300);
      int bytesRead = client.read((uint8_t*) msgbuff, 300);
      if (bytesRead < 300) msgbuff[bytesRead] = 0;
      msgbuff[299] = '\0';
      Serial.println(msgbuff);
      if (msgbuff[0] == '@') { // @ represents arduino-specific events
        Serial.print(F("Received message: "));
        Serial.println(msgbuff);
        tokenize(tokenbuff, msgbuff, ',', 1);
        if (memcmp(tokenbuff, "@rgbupdate", 10) == 0) {
          for (int z = 2; tokenize(tokenbuff, msgbuff, ',', z); z++) {
            if (z == 2) r = atoi(tokenbuff);
            if (z == 3) g = atoi(tokenbuff);
            if (z == 4) b = atoi(tokenbuff);
          }
        } else if (memcmp(tokenbuff, "@pattern", 8) == 0) {
          int i = 0;
          Serial.println(F("pattern"));
          while (true) {
            for (int z = 2; tokenize(tokenbuff, msgbuff, ',', z); z++) {
              if (tokenbuff[0] == '$') {
                for (i = 1; tokenbuff[i] != '\0'; i++);
                strncpy(databuff, tokenbuff + 1, i - 1);
                databuff[i - 1] = '\0';
                Serial.print("name: ");
                Serial.println(msgbuff);
              } else if (tokenbuff[0] == '#') {
                strncpy(databuff, tokenbuff + 1, 3);
                databuff[3] = '\0';
                double new_r = atoi(databuff);
                strncpy(databuff, tokenbuff + 4, 3);
                databuff[3] = '\0';
                double new_g = atoi(databuff);
                strncpy(databuff, tokenbuff + 7, 3);
                databuff[3] = '\0';
                double new_b = atoi(databuff);
                for (i = 0; tokenbuff[i] != '\0'; i++);
                strncpy(databuff, tokenbuff + 10, i - 10);
                databuff[i - 10] = '\0';
                t = atoi(databuff);
                Serial.println("rgb(" + String(new_r) + ", " + String(new_g) + ", " + String(new_b) + ") – " + String(t) + "ms");
                double r_step = 10.0 * (new_r - ((double) r)) / ((double) tr);
                double g_step = 10.0 * (new_g - ((double) g)) / ((double) tr);
                double b_step = 10.0 * (new_b - ((double) b)) / ((double) tr);
                for (int j = tr / 10; j > 0; j--) {
                  r += r_step;
                  g += g_step;
                  b += b_step;
                  if (r < 0) r = 0; if (r > 255) r = 255;
                  if (g < 0) r = 0; if (g > 255) g = 255;
                  if (b < 0) r = 0; if (b > 255) b = 255;
                  red(r);
                  green(g);
                  blue(b);
                  delay(10);
                }
                tr = 0;
                r = new_r; red(r);
                g = new_g; green(g);
                b = new_b; blue(b);
                for (int j = t / 10; j > 0; j--) {
                  delay(10);
                }
              } else if (tokenbuff[0] == '%') {
                for (i = 1; tokenbuff[i] != '\0'; i++);
                strncpy(databuff, tokenbuff + 1, i - 1);
                databuff[i - 1] = '\0';
                tr = atoi(databuff);
                Serial.print(F("transition – "));
                Serial.print(tr);
                Serial.println(F("ms"));
              }
            }
            if (client.peek() != -1) break;
            Serial.println(F("repeat"));
          }
        }
      }
    }
  }
  Serial.println(F("Disconnected from WebSocket server"));
}

// LED PWM functions
void red(int v) {
  analogWrite(REDPIN, v);
}
void green(int v) {
  analogWrite(GREENPIN, v);
}
void blue(int v) {
  analogWrite(BLUEPIN, v);
}

// convenience custom tokenizer
int tokenize(char* dst, char* src, char delim, int occ) {
  int o, b, e;
  e = -1;
  for (o = 0; o < occ; o++) {
      if (e > 0 && src[e] == '\0' && o < occ) return 0;
    b = e + 1;
    for (e = b; src[e] != '\0' && src[e] != delim; e++);
  }
  if (b == e) return 0;
  strncpy(dst, src + b, e - b);
  dst[e - b] = '\0';
  return 1;
}
