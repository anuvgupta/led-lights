
#define REDPIN 9
#define GREENPIN 10
#define BLUEPIN 11

char msgbuff[300] = "@pattern,$example_pattern,#2550000001000,%1000,#0000002551000";
char tokenbuff[15]; // max rgb digits = 3(r) + 3(g) + 3(b) + 5(t - int dig max) + 1(\0)
char databuff[6]; // 5(t - int dig max) + 1(\0)

double r = 0, g = 0, b = 0;
int t = 0, tr = 0;
 
void setup() {
  Serial.begin(9600);
  pinMode(REDPIN, OUTPUT);
  pinMode(GREENPIN, OUTPUT);
  pinMode(BLUEPIN, OUTPUT);
  red(0); green(0); blue(0);
}

void red(int v) {
  analogWrite(REDPIN, v);
}
void green(int v) {
  analogWrite(GREENPIN, v);
}
void blue(int v) {
  analogWrite(BLUEPIN, v);
}

void loop() {
  int i = 0;
  if (msgbuff[0] == '@') { // @ represents arduino-specific events
    Serial.println("message: " + String(msgbuff));
    strncpy(tokenbuff, strtok(msgbuff, ","), 15);
    if (memcmp(tokenbuff, "@pattern", 8) == 0) {
      Serial.print("pattern: ");
      while (1) {
        strncpy(tokenbuff, strtok(NULL, ","), 15);
        if (tokenbuff == NULL) break;
        if (memcmp(tokenbuff, "$", 1) == 0) {
          for (i = 1; tokenbuff[i] != '\0'; i++);
          strncpy(databuff, tokenbuff + 1, i - 1);
          databuff[i - 1] = '\0';
        } else if (memcmp(tokenbuff, "#", 1) == 0) {
          strncpy(databuff, tokenbuff + 1, 3);
          databuff[3] = '\0';
          double new_r = atoi(databuff);
          strncpy(databuff, tokenbuff + 4, 3);
          databuff[3] = '\0';
          double new_g = atoi(databuff);
          strncpy(databuff, tokenbuff + 7, 3);
          databuff[3] = '\0';
          double new_b = atoi(databuff);
          for (i = 10; tokenbuff[i] != '\0'; i++);
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
        } else if (memcmp(tokenbuff, "%", 1) == 0) {
          for (i = 1; tokenbuff[i] != '\0'; i++);
          strncpy(databuff, tokenbuff + 1, i - 1);
          databuff[i - 1] = '\0';
          tr = atoi(databuff);
          Serial.println("transition – " + String(tr) + "ms");
        }
      }
    }
  }
}
