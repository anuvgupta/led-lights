// includes
#include "SoftwareSerialMod.h"

// LED PWM pins
#define REDPIN 9
#define GREENPIN 10
#define BLUEPIN 11

#define DEBUG false

// parsing data
int mb_i = 0;
char msgbuff[500]; // extra size just in case
char tokenbuff[20]; // 5(f) + 3(r) + 3(g) + 3(b) + 5(t) + 1(\0)
char databuff[6]; // 5(int dig max) + 1(\0)
bool ready = false;
SoftwareSerial ESP8266(6, 7);
unsigned long lastTimestamp = 0;
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
double brightness = 100; // brightness
double speedmult = 100; // speed mult
int fade = 0; // transition (ms)
#define PRECISION 5 // 5 millisecond precision for fades
#define RESET_INTERVAL 10 // reset ESP8266 every 5 minutes

void setup() {
  // init hardware and software serials
  Serial.begin(9600);
  ESP8266.begin(9600);

  if (DEBUG) Serial.println(F("LED Strip Driver"));

  // init LED PWM pins
  pinMode(REDPIN, OUTPUT);
  pinMode(GREENPIN, OUTPUT);
  pinMode(BLUEPIN, OUTPUT);
  red(0); green(0); blue(0);

  if (DEBUG) Serial.println(F("[nano] connecting to ESP8266"));
}

void loop() {
  // drive LED's
  red(r); green(g); blue(b);

  // check time interval and send reset message
  unsigned long newTimestamp = millis();
  unsigned long interval = 60000;
  interval *= RESET_INTERVAL;
  if (ready && newTimestamp - lastTimestamp >= interval) {
    if (lastTimestamp > 0) {
      Serial.println("[nano] resetting ESP8266");
      ready = false;
      ESP8266.println("reset");
    }
    lastTimestamp = newTimestamp;
  }
  
  // read serial
  if (ESP8266.available() || Serial.available()) {
    if (mb_i >= 500) {
      msgbuff[499] = '\0';
      if (DEBUG) writeBuffer();
      mb_i = 0;
    } else {
      char c;
      if (ESP8266.available())
        c = ESP8266.read();
      else c = Serial.read();
      if (c != -1) {
        if (c == '\n') {
          msgbuff[mb_i] = '\0';
          if (DEBUG) writeBuffer();
          if (/*!ready &&*/ mb_i >= 5 && memcmp(msgbuff + mb_i - 5, "ready", 5) == 0) {
            if (DEBUG) Serial.println(F("[nano] connected to ESP8266"));
            ready = true;
          } else if (ready) {
            if (msgbuff[0] == 'h') {
              if (DEBUG) Serial.print(F("[update] new hue: "));
              if (DEBUG) Serial.println(msgbuff);
              bool f = 1;
              while (ESP8266.available() <= 0) {
                hue(f && DEBUG);
                if (f) f = 0;
              }
            } else if (msgbuff[0] == 'p') {
              if (DEBUG) Serial.print(F("[update] new pattern: "));
              if (DEBUG) Serial.println(msgbuff);
              bool f = 1;
              while (ESP8266.available() <= 0) {
                pattern(f && DEBUG);
                if (f) f = 0;
              }
            } else if (msgbuff[0] == 'b') {
              if (DEBUG) Serial.print(F("[update] new brightness: "));
              if (DEBUG) Serial.println(msgbuff);
              bright(DEBUG);
            } else if (msgbuff[0] == 's') {
              if (DEBUG) Serial.print(F("[update] new speed: "));
              if (DEBUG) Serial.println(msgbuff);
              speedm(DEBUG);
            }
          }
          mb_i = 0;
        } else if (c != 0 && c >= 32 && c <= 126) {
          msgbuff[mb_i] = c;
          // Serial.println("[esp] msgbuff[" + String(mb_i) + "] " + String(msgbuff[mb_i]) + " (" + String((uint8_t) msgbuff[mb_i]) + ")");
          mb_i++;
        }
      }
    }
  }
}

// process brightness from msgbuff
void bright(bool v) {
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  brightness = atoi(databuff);
  if (v) { Serial.print("[nano] brightness – "); Serial.println(brightness); }
  red(r); green(g); blue(b);
}

// process speed from msgbuff
void speedm(bool v) {
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  speedmult = atoi(databuff);
  if (v) { Serial.print("[nano] speed – "); Serial.println(speedmult); }
  red(r); green(g); blue(b);
}

// process hue from msgbuff
void hue(bool v) {
  // parse message data
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_r = atoi(databuff);
  for (i = 4, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_g = atoi(databuff);
  for (i = 7, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_b = atoi(databuff);
  if (v) { Serial.print(F("[nano] hue – rgb(")); Serial.print(n_r); Serial.print(F(", ")); Serial.print(n_g); Serial.print(F(", ")); Serial.print(n_b); Serial.println(")"); }
  // change color
  while (ESP8266.available() <= 0) {
    r = n_r; red(r);
    g = n_g; green(g);
    b = n_b; blue(b);
  }
}

// process pattern from msgbuff
void pattern(bool v) {
  for (int z = 1; ESP8266.available() <= 0 && tokenize(tokenbuff, msgbuff + 1, ',', z); z++) {
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
    if (v) { Serial.print(F("[nano] fade – ")); Serial.print(fade); Serial.println(F("ms")); }
    if (v) { Serial.print(F("[nano] hue – rgb(")); Serial.print(n_r); Serial.print(F(", ")); Serial.print(n_g); Serial.print(F(", ")); Serial.print(n_b); Serial.print(")"); Serial.print(" – "); Serial.print(t); Serial.println("ms"); }
    // fade into color
    fadeColor();
    // hold color for time
    for (j = t / PRECISION / (speedmult / 100.0); ESP8266.available() <= 0 && j > 0; j--) {
      delay(PRECISION);
    }
  }
  if (v) Serial.println("[nano] repeat");
}

// fade into current color
void fadeColor() {
  // perform fade if exists
  if (fade != 0) {
    r_st = ((double) PRECISION) * (n_r - r) / ((double) fade);
    g_st = ((double) PRECISION) * (n_g - g) / ((double) fade);
    b_st = ((double) PRECISION) * (n_b - b) / ((double) fade);
    for (int z = fade / PRECISION / (speedmult / 100.0); ESP8266.available() <= 0 && z > 0; z--) {
      r += r_st; g += g_st; b += b_st;
      if (r < 0) r = 0; if (r > 255) r = 255;
      if (g < 0) g = 0; if (g > 255) g = 255;
      if (b < 0) b = 0; if (b > 255) b = 255;
      red(r); green(g); blue(b);
      delay(PRECISION);
    }
  }
  // change final color
  r = n_r; red(r);
  g = n_g; green(g);
  b = n_b; blue(b);
}

// LED PWM functions
void red(int v) {
  analogWrite(REDPIN, (int) (brightness / 100.0 * ((double) v)));
}
void green(int v) {
  analogWrite(GREENPIN, (int) (brightness / 100.0 * ((double) v)));
}
void blue(int v) {
  analogWrite(BLUEPIN, (int) (brightness / 100.0 * ((double) v)));
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

// write message buffer to output serial
void writeBuffer() {
  if (msgbuff[0] == '[') {
    Serial.print(F("[esp:"));
    Serial.println(msgbuff + 1);
  } else {
    Serial.print(F("[serial] "));
    Serial.println(msgbuff);
  }
}
