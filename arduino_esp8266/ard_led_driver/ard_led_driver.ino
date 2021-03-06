// includes
#include "SoftwareSerialMod.h"

// debug
#define DEBUG true

// LED PWM pins
#define REDPIN_L 9
#define GREENPIN_L 10
#define BLUEPIN_L 11
#define REDPIN_R 3
#define GREENPIN_R 5
#define BLUEPIN_R 6
// msgeq7 pins
#define STROBEPIN 2
#define RESETPIN 4
#define OUTRPIN A6
#define OUTLPIN A5

// msgeq7 settings
double l_preamp = 1.1; // double 0 - 2, (2 for low volume)
int l_postamp = 1; // int 1 - 20, (10 if inverted)
bool l_invert = false; // boolean
double r_preamp = 1.1;
int r_postamp = 1;
bool r_invert = false;
int noise = 20; // int 0 - 50
int smoothing = 95; // int 0 - 99
int l_channel = 0; // int 0 - 7
int r_channel = 1; // int 0 - 7
// esp8266 data
bool ready = false;
SoftwareSerial ESP8266(7, 8); // ARD 7 => ESP TX, ARD 8 => ESP RX
unsigned long lastTimestamp = 0;
// parsing data
int mb_i = 0;
char msgbuff[225]; // sufficient capacity (10 color limit for patterns)
char tokenbuff[20]; // 5(f) + 3(r) + 3(g) + 3(b) + 5(t) + 1(\0)
char databuff[6]; // 5(int dig max) + 1(\0)
// msgeq7 data
int bands[7];
int bands_record_l[7];
int bands_record_r[7];
// rgb data
double r_l = 0; // hue red (left)
double g_l = 0; // hue green (left)
double b_l = 0; // hue blue (left)
double r_r = 0; // hue red (right)
double g_r = 0; // hue green (right)
double b_r = 0; // hue blue (right)
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
#define RESET_INTERVAL 15 // check ESP8266 every 5 minutes

void setup() {
  // init hardware and software serials
  Serial.begin(9600);
  ESP8266.begin(9600);

  if (DEBUG) Serial.println(F("LED Strip Driver"));

  // init LED PWM pins
  pinMode(REDPIN_L, OUTPUT);
  pinMode(GREENPIN_L, OUTPUT);
  pinMode(BLUEPIN_L, OUTPUT);
  red_l(0); green_l(0); blue_l(0);
  pinMode(REDPIN_R, OUTPUT);
  pinMode(GREENPIN_R, OUTPUT);
  pinMode(BLUEPIN_R, OUTPUT);
  red_r(0); green_r(0); blue_r(0);

  // init msgeq7 pins
  pinMode(STROBEPIN, OUTPUT);
  pinMode(RESETPIN, OUTPUT);
  pinMode(OUTRPIN, INPUT);
  pinMode(OUTLPIN, INPUT);
  digitalWrite(RESETPIN, LOW);
  digitalWrite(STROBEPIN, LOW);
  delay(1);
  // reset sequence
  digitalWrite(RESETPIN,  HIGH);
  delay(1);
  digitalWrite(RESETPIN,  LOW);
  digitalWrite(STROBEPIN, HIGH);
  delay(1);

  // init esp8266
  if (DEBUG) Serial.println(F("[nano] connecting to ESP8266"));
  ESP8266.println("reset");
  lastTimestamp = millis();
}

void loop() {
  // drive LED's
  red_l(r_l); green_l(g_l); blue_l(b_l);
  red_r(r_r); green_r(g_r); blue_r(b_r);

  // check time interval/reset esp8266
  
  if (resetRequired()) {
    unsigned long newTimestamp = millis();
    if (lastTimestamp > 0) {
      if (DEBUG) Serial.println("[nano] resetting ESP8266");
      ready = false;
      ESP8266.println("reset");
    }
    lastTimestamp = newTimestamp;
  }
  
  // read serial
  while (ESP8266.available() || Serial.available()) {
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
              double bright_prev = brightness;
              if (msgbuff[1] == 'm') brightness = 0;
              hue(DEBUG);
              if (msgbuff[1] == 'm') {
                brightness = bright_prev;
                music(DEBUG);
              }
            } else if (msgbuff[0] == 'p') {
              if (DEBUG) Serial.print(F("[update] new pattern: "));
              if (DEBUG) Serial.println(msgbuff);
              bool f = 1;
              while (uninterrupted()) {
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
            } else if (msgbuff[0] == 'm') {
              if (DEBUG) Serial.println(F("[update] music mode"));
              music(DEBUG);
            } else if (msgbuff[0] == 'o') {
              smooth(DEBUG);
            } else if (msgbuff[0] == 'g') {
              noise_gate(DEBUG);
            } else if (msgbuff[0] == 'n') {
              if (DEBUG) Serial.println(F("[update] nil mode"));
            } else if (msgbuff[0] == 'l') {
              if (msgbuff[1] == 'p') {
                if (msgbuff[2] == 'r')
                  left_preamp(DEBUG);
                else if (msgbuff[2] == 'o')
                  left_postamp(DEBUG);
              } else if (msgbuff[1] == 'c')
                left_channel(DEBUG);
              else if (msgbuff[1] == 'i')
                left_invert(DEBUG);
            } else if (msgbuff[0] == 'r') {
              if (msgbuff[1] == 'p') {
                if (msgbuff[2] == 'r')
                  right_preamp(DEBUG);
                else if (msgbuff[2] == 'o')
                  right_postamp(DEBUG);
              } else if (msgbuff[1] == 'c')
                right_channel(DEBUG);
              else if (msgbuff[1] == 'i')
                right_invert(DEBUG);
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

// check if reset required
bool resetRequired() {
  // check time interval
  unsigned long newTimestamp = millis();
  unsigned long interval = 60000;
  interval *= RESET_INTERVAL;
  return ready && newTimestamp - lastTimestamp >= interval;
}

// check if current process should be interrupted
bool uninterrupted() {
  return ready && ESP8266.available() <= 0 && Serial.available() <= 0 && !resetRequired();
}

// process brightness from msgbuff
void bright(bool v) {
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  brightness = atoi(databuff);
  if (v) { Serial.print("[nano] brightness – "); Serial.println(brightness); }
  red_l(r_l); green_l(g_l); blue_l(b_l);
  red_r(r_r); green_r(g_r); blue_r(b_r);
}

// process speed from msgbuff
void speedm(bool v) {
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  speedmult = atoi(databuff);
  if (v) { Serial.print("[nano] speed – "); Serial.println(speedmult); }
  red_l(r_l); green_l(g_l); blue_l(b_l);
  red_r(r_r); green_r(g_r); blue_r(b_r);
}

// process hue from msgbuff
void hue(bool v) {
  // parse message data
  int i, j;
  // parse left
  for (i = 1 + 2, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_r = atoi(databuff);
  for (i = 1 + 5, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_g = atoi(databuff);
  for (i = 1 + 8, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_b = atoi(databuff);
  r_l = n_r; g_l = n_g; b_l = n_b;
  // parse right
  for (i = 1 + 2 + 10, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_r = atoi(databuff);
  for (i = 1 + 5 + 10, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_g = atoi(databuff);
  for (i = 1 + 8 + 10, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  n_b = atoi(databuff);
  r_r = n_r; g_r = n_g; b_r = n_b;
  if (v) {
    Serial.print(F("[nano] hue – LEFT  rgb(")); Serial.print(r_l); Serial.print(F(", ")); Serial.print(g_l); Serial.print(F(", ")); Serial.print(b_l); Serial.println(")");
    Serial.print(F("             RIGHT rgb(")); Serial.print(r_r); Serial.print(F(", ")); Serial.print(g_r); Serial.print(F(", ")); Serial.print(b_r); Serial.println(")");
  }
  // change color
  red_l(r_l); green_l(g_l); blue_l(b_l);
  red_r(r_r); green_r(g_r); blue_r(b_r);
}

// process pattern from msgbuff
void pattern(bool v) {
  // match left and right
  r_r = r_l; g_r = g_l; b_r = b_l;
  red_l(r_l); green_l(g_l); blue_l(b_l);
  red_r(r_r); green_r(g_r); blue_r(b_r);
  // loop through tokens
  for (int z = 1; uninterrupted() && tokenize(tokenbuff, msgbuff + 1, ',', z); z++) {
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
    for (j = t / PRECISION / (speedmult / 100.0); uninterrupted() && j > 0; j--) {
      delay(PRECISION);
    }
  }
  if (v) Serial.println("[nano] repeat");
}

// fade into current color
void fadeColor() {
  // perform fade if exists
  if (fade != 0) {
    r_st = ((double) PRECISION) * (n_r - r_l) / ((double) fade);
    g_st = ((double) PRECISION) * (n_g - g_l) / ((double) fade);
    b_st = ((double) PRECISION) * (n_b - b_l) / ((double) fade);
    for (int z = fade / PRECISION / (speedmult / 100.0); uninterrupted() && z > 0; z--) {
      r_l += r_st; g_l += g_st; b_l += b_st;
      if (r_l < 0) r_l = 0; if (r_l > 255) r_l = 255;
      if (g_l < 0) g_l = 0; if (g_l > 255) g_l = 255;
      if (b_l < 0) b_l = 0; if (b_l > 255) b_l = 255;
      r_r = r_l; g_r = g_l; b_r = b_l;
      red_l(r_l); green_l(g_l); blue_l(b_l);
      red_r(r_r); green_r(g_r); blue_r(b_r);
      delay(PRECISION);
    }
  }
  // change final color
  r_l = n_r; g_l = n_g; b_l = n_b;
  r_r = r_l; g_r = g_l; b_r = b_l;
  red_l(r_l); green_l(g_l); blue_l(b_l);
  red_r(r_r); green_r(g_r); blue_r(b_r);
}

// music reactive mode
void music(bool v) {
  while (uninterrupted()) {
    // pulse strobe to cycle bands
    for (int i = 0; i < 7; i++) {
      // cycle
      digitalWrite(STROBEPIN, LOW);
      delayMicroseconds(100);
      // read
      bands[i] = analogRead(OUTRPIN) + analogRead(OUTLPIN);
      digitalWrite(STROBEPIN, HIGH);
      delayMicroseconds(1);
      double level;
      if (i == l_channel) {
        level = bands[i];
        // pre-amplify
        level *= l_preamp;
        // correct
        level /= 2.0;
        level *= 255.0 / 1023.0;
        // round
        level /= 5.0;
        level = (int) level;
        level *= 5.0;
        // post-amplify
        level *= l_postamp;
        // bound
        if (level <= noise) level = 0;
        if (level > 255) level = 255;
        // smooth
        if (smoothing > 0) {
          double weight = (smoothing / 100.0);
          level = (level * (1.0 - weight)) + (bands_record_l[i] * weight);
        }
        // save
        bands_record_l[i] = level;
        // invert
        if (l_invert) level = 255 - level;
        level /=  255.0;
        red_l(((double) r_l) * level);
        green_l(((double) g_l) * level);
        blue_l(((double) b_l) * level);
      }
      if (i == r_channel) {
        level = bands[i];
        level *= r_preamp;
        level /= 2.0;
        level *= 255.0 / 1023.0;
        level /= 5.0;
        level = (int) level;
        level *= 5.0;
        level *= r_postamp;
        if (level <= noise) level = 0;
        if (level > 255) level = 255;
        if (smoothing > 0) {
          double weight = (smoothing / 100.0);
          level = (level * (1.0 - weight)) + (bands_record_r[i] * weight);
        }
        bands_record_r[i] = level;
        if (r_invert) level = 255 - level;
        level /=  255.0;
        red_r(((double) r_r) * level);
        green_r(((double) g_r) * level);
        blue_r(((double) b_r) * level);
      }
    }
  }
  if (!uninterrupted()) {
    red_l(0); green_l(0); blue_l(0);
    red_r(0); green_r(0); blue_r(0);
  }
}

// set smoothing
void smooth(int v) {
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  smoothing = atoi(databuff);
  if (v) { Serial.print("[nano] smoothing – "); Serial.println(smoothing); }
}

// set noise gate
void noise_gate(int v) {
  int i, j;
  for (i = 1, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  noise = atoi(databuff);
  if (v) { Serial.print("[nano] noise gate – "); Serial.println(noise); }
}

// set left channel
void left_channel(int v) {
  int i, j;
  for (i = 2, j = 0; j < 1; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[1] = '\0';
  l_channel = atoi(databuff);
  if (v) { Serial.print("[nano] left channel – "); Serial.println(l_channel); }
}
// set right channel
void right_channel(int v) {
  int i, j;
  for (i = 2, j = 0; j < 1; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[1] = '\0';
  r_channel = atoi(databuff);
  if (v) { Serial.print("[nano] right channel – "); Serial.println(r_channel); }
}

// set left invert
void left_invert(int v) {
  int i, j;
  for (i = 2, j = 0; j < 1; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[1] = '\0';
  l_invert = atoi(databuff);
  if (v) { Serial.print("[nano] left invert – "); Serial.println(l_invert); }
}
// set right invert
void right_invert(int v) {
  int i, j;
  for (i = 2, j = 0; j < 1; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[1] = '\0';
  r_invert = atoi(databuff);
  if (v) { Serial.print("[nano] right invert – "); Serial.println(r_invert); }
}

// set left preamp
void left_preamp(int v) {
  int i, j;
  for (i = 3, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  l_preamp = atoi(databuff);
  l_preamp /= 100.0;
  if (v) { Serial.print("[nano] left preamp – "); Serial.println(l_preamp); }
}
// set right preamp
void right_preamp(int v) {
  int i, j;
  for (i = 3, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  r_preamp = atoi(databuff);
  r_preamp /= 100;
  if (v) { Serial.print("[nano] right preamp – "); Serial.println(r_preamp); }
}

// set left postamp
void left_postamp(int v) {
  int i, j;
  for (i = 3, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  l_postamp = atoi(databuff);
  if (v) { Serial.print("[nano] left postamp – "); Serial.println(l_postamp); }
}
// set right postamp
void right_postamp(int v) {
  int i, j;
  for (i = 3, j = 0; j < 3; i++, j++)
    databuff[j] = msgbuff[i];
  databuff[3] = '\0';
  r_postamp = atoi(databuff);
  if (v) { Serial.print("[nano] right postamp – "); Serial.println(r_postamp); }
}

// LED PWM functions
void red_l(int v) {
  analogWrite(REDPIN_L, (int) (brightness / 100.0 * ((double) v)));
}
void green_l(int v) {
  analogWrite(GREENPIN_L, (int) (brightness / 100.0 * ((double) v)));
}
void blue_l(int v) {
  analogWrite(BLUEPIN_L, (int) (brightness / 100.0 * ((double) v)));
}
void red_r(int v) {
  analogWrite(REDPIN_R, (int) (brightness / 100.0 * ((double) v)));
}
void green_r(int v) {
  analogWrite(GREENPIN_R, (int) (brightness / 100.0 * ((double) v)));
}
void blue_r(int v) {
  analogWrite(BLUEPIN_R, (int) (brightness / 100.0 * ((double) v)));
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
