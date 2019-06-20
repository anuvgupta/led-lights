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
// h{32767,255255255}
char msgbuff[19]; // long enough for standard message format
char databuff[6]; // 5(int dig max) + 1(\0)
// rgb data
double r = 0; // hue red
double g = 0; // hue green
double b = 0; // hue blue
double n_r = 0; // new hue red
double n_g = 0; // new hue green
double n_b = 0; // new hue blue
double r_st = 0; // hue red fade
double g_st = 0; // hue green fade
double b_st = 0; // hue blue fade
int fade = 0; // transition (ms)

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
    red(r); green(g); blue(b);
    
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
    int msgstatus = client.parseMessage();
    if (msgstatus > 0) {
      // load data into buffer
      int bytesRead = client.read((uint8_t *) msgbuff, 19);
      if (bytesRead < 19) msgbuff[bytesRead] = '\0';
      msgbuff[18] = '\0';
      if (msgbuff[0] == 'h' && msgbuff[1] == '{') {
        Serial.print(F("Message: "));
        Serial.println(msgbuff);
        fade = 0; // reset fade to default (none)
        // parse message data
        int i, j;
        for (i = 2, j = 0; j < 5; i++, j++)
          databuff[j] = msgbuff[i];
        databuff[7] = '\0';
        fade = atoi(databuff);
        for (i = 8, j = 0; j < 3; i++, j++)
          databuff[j] = msgbuff[i];
        databuff[3] = '\0';
        n_r = atoi(databuff);
        for (i = 11, j = 0; j < 3; i++, j++)
          databuff[j] = msgbuff[i];
        databuff[3] = '\0';
        n_g = atoi(databuff);
        for (i = 14, j = 0; j < 3; i++, j++)
          databuff[j] = msgbuff[i];
        databuff[3] = '\0';
        n_b = atoi(databuff);
        Serial.print(F("fade – ")); Serial.print(fade); Serial.println(F("ms"));
        Serial.print(F("rgb(")); Serial.print(n_r); Serial.print(F(", ")); Serial.print(n_g); Serial.print(F(", ")); Serial.print(n_b); Serial.println(")");
        // perform fade if exists
        if (fade != 0) {
          r_st = 10.0 * (n_r - r) / ((double) fade);
          g_st = 10.0 * (n_g - g) / ((double) fade);
          b_st = 10.0 * (n_b - b) / ((double) fade);
          for (int z = fade / 10; z > 0; z--) {
            r += r_st; g += g_st; b += b_st;
            if (r < 0) r = 0; if (r > 255) r = 255;
            if (g < 0) g = 0; if (g > 255) g = 255;
            if (b < 0) b = 0; if (b > 255) b = 255;
            red(r); green(g); blue(b);
            delay(10);
          }
        }
        // change final color
        r = n_r; red(r);
        g = n_g; green(g);
        b = n_b; blue(b);
      } else Serial.println("non-arduino msg received");
    } else Serial.println("waiting...");
    delay(250);
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
