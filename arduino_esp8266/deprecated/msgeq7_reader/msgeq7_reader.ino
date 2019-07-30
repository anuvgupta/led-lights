#define DEBUG true

#define REDPIN 9
#define GREENPIN 10
#define BLUEPIN 11
#define STROBEPIN 2
#define RESETPIN 4
#define OUTRPIN A6
#define OUTLPIN A5

#define PREAMP 1.5 // double 1 - 2, 1 (2 for low volume)
#define POSTAMP 1 // int 1 - 20, 1 (10 if inverted)
#define NOISE 30 // int 0 - 50, 15
#define INVERT false // boolean, false
#define SMOOTHING 94 // int 0 - 99, 0

int bands[7];
int record[7];

void setup() {
  Serial.begin(9600);

  // pin modes
  pinMode(REDPIN, OUTPUT);
  pinMode(GREENPIN, OUTPUT);
  pinMode(BLUEPIN, OUTPUT);
  pinMode(STROBEPIN, OUTPUT);
  pinMode(RESETPIN, OUTPUT);
  pinMode(OUTRPIN, INPUT);
  pinMode(OUTLPIN, INPUT);

  // initial pin state
  red(0); green(0); blue(0);
  digitalWrite(RESETPIN, LOW);
  digitalWrite(STROBEPIN, LOW);
  delay(1);

  // reset MSGEQ7
  digitalWrite(RESETPIN,  HIGH);
  delay(1);
  digitalWrite(RESETPIN,  LOW);
  digitalWrite(STROBEPIN, HIGH);
  delay(1);
}

void loop() {
  // pulse strobe to cycle bands
  for (int i = 0; i < 7; i++) {
    digitalWrite(STROBEPIN, LOW);
    delayMicroseconds(100);
    bands[i] = analogRead(OUTRPIN) + analogRead(OUTLPIN);
    digitalWrite(STROBEPIN, HIGH);
    delayMicroseconds(1);
  }
  
  for (int i = 0; i < 7; i++) {
    double level = bands[i];
    // pre-amplify
    level *= PREAMP;
    // correct
    level /= 2.0;
    level *= 255.0 / 1023.0;
    // round
    level /= 5.0;
    level = (int) level;
    level *= 5.0;
    // post-amplify
    level *= POSTAMP;
    // bound
    if (level <= NOISE) level = 0;
    if (level > 255) level = 255;
    // smooth
    if (SMOOTHING > 0) {
      double weight = (SMOOTHING / 100.0);
      level = (level * (1.0 - weight)) + (record[i] * weight);
    }
    // save
    record[i] = level;
    // invert
    if (INVERT) level = 255 - level;
    // display
    if (i == 0) {
      blue(level);
       if (DEBUG) {
        int l = level;
         Serial.println(l, DEC);
       }
    }
//    
//    if (DEBUG) {
//      if (bands[i] > 160) Serial.print(i, DEC);
//      else Serial.print(" ");
//      Serial.print("   ");
//    }
  }
//  if (DEBUG) Serial.println();
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
