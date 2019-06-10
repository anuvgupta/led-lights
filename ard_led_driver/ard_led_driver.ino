// includes
#include "SoftwareSerialMod.h"

// LED PWM pins
#define REDPIN 9
#define GREENPIN 10
#define BLUEPIN 11

// parsing data
int mb_i = 0;
char msgbuff[500]; // extra size just in case
char tokenbuff[20]; // 5(f) + 3(r) + 3(g) + 3(b) + 5(t) + 1(\0)
char databuff[6]; // 5(int dig max) + 1(\0)
bool ready = false;
SoftwareSerial ESP8266(6, 7);
// rgb data
double r = 0; // hue red
double g = 0; // hue green
double b = 0; // hue blue
double t = 0; // hue time
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

  Serial.println(F("LED Strip Driver"));

  // init LED PWM pins
  pinMode(REDPIN, OUTPUT);
  pinMode(GREENPIN, OUTPUT);
  pinMode(BLUEPIN, OUTPUT);
  red(0); green(0); blue(0);

  Serial.println(F("connecting to ESP8266"));
}

void loop() {
  // drive LED's
  red(r); green(g); blue(b);
  
  // read serial
  if (ESP8266.available() > 0 || Serial.available()) {
    // Serial.write(ESP8266.read());
    if (mb_i >= 500) {
      msgbuff[499] = '\n';
      Serial.println(msgbuff);
      mb_i = 0;
    } else {
      char c;
      if (ESP8266.available())
        c = ESP8266.read();
      else c = Serial.read();
      if (c != -1) {
        if (c == '\n') {
          msgbuff[mb_i] = '\0';
          if (!ready && mb_i >= 5 && memcmp(msgbuff + mb_i - 5, "ready", 5) == 0) {
            Serial.println(F("connected to ESP8266"));
            ready = true;
          } else if (ready) {
            Serial.print(F("new hue pattern: "));
            Serial.println(msgbuff);
            bool f = 1;
            while (ESP8266.available() <= 0) {
              pattern(f);
              if (f) f = 0;
            }
            n_r = 0; n_g = 0; n_b = 0; t = 10;
            fade = 50;
            fadeColor();
          }
          mb_i = 0;
        } else if (c != 0) {
          msgbuff[mb_i] = c;
          // Serial.println("msgbuff[" + String(mb_i) + "] " + String(msgbuff[mb_i]) + " (" + String((uint8_t) msgbuff[mb_i]) + ")");
          mb_i++;
        }
      }
    }
  }
}

// process pattern from msgbuff
void pattern(bool v) {
  for (int z = 1; ESP8266.available() <= 0 && tokenize(tokenbuff, msgbuff, ',', z); z++) {
    fade = 0; // reset fade to default (none)
    // parse message data
    int i, j;
    for (i = 0, j = 0; j < 5; i++, j++)
      databuff[j] = tokenbuff[i];
    databuff[5] = '\0';
    fade = atoi(databuff);
    for (i = 5, j = 0; j < 3; i++, j++)
      databuff[j] = tokenbuff[i];
    databuff[3] = '\0';
    n_r = atoi(databuff);
    for (i = 8, j = 0; j < 3; i++, j++)
      databuff[j] = tokenbuff[i];
    databuff[3] = '\0';
    n_g = atoi(databuff);
    for (i = 11, j = 0; j < 3; i++, j++)
      databuff[j] = tokenbuff[i];
    databuff[3] = '\0';
    n_b = atoi(databuff);
    for (i = 14, j = 0; j < 5; i++, j++)
      databuff[j] = tokenbuff[i];
    databuff[5] = '\0';
    t = atoi(databuff);
    if (v) { Serial.print(F("fade – ")); Serial.print(fade); Serial.println(F("ms")); }
    if (v) { Serial.print(F("rgb(")); Serial.print(n_r); Serial.print(F(", ")); Serial.print(n_g); Serial.print(F(", ")); Serial.print(n_b); Serial.print(")"); Serial.print(" – "); Serial.print(t); Serial.println("ms"); }
    // fade into color
    fadeColor();
    // hold color for time
    for (j = t / 10; j > 0; j--) {
      delay(10);
    }
  }
}

// fade into current color
void fadeColor() {
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
