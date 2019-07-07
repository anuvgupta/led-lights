
#define REDPIN 9
#define GREENPIN 10
#define BLUEPIN 11
 
#define FADESPEED 5
 
void setup() {
  pinMode(REDPIN, OUTPUT);
  pinMode(GREENPIN, OUTPUT);
  pinMode(BLUEPIN, OUTPUT);
}

void red(double percentage) {
  analogWrite(REDPIN, (int) ((percentage / 100.0) * 255.0));
}

void green(double percentage) {
  analogWrite(GREENPIN, (int) ((percentage / 100.0) * 255.0));
}

void blue(double percentage) {
  analogWrite(BLUEPIN, (int) ((percentage / 100.0) * 255.0));
}
 
void loop() {
  red(100);
  green(100);
  blue(100);
}
