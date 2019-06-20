#include <CmdMessenger.h>
#include <SoftPWM_timer.h>
#include <SoftPWM.h>

enum { receive_frameL, receive_frameR };
const int num_pins = 18; // must be even
const int BAUD_RATE = 9600;
CmdMessenger c = CmdMessenger(Serial,',',';','/');

void on_receive_frameL(void) {
  uint16_t intensities[num_pins/2] = {0};
  for (int i = 0; i < num_pins/2; i++) {
    intensities[i] = c.readBinArg<int>();
  }
  for (int i = 0; i < num_pins/2; i++) {
    SoftPWMSetPercent(i + 2, intensities[i]);
  }
}

void on_receive_frameR(void) {
  uint16_t intensities[num_pins/2] = {0};
  for (int i = 0; i < num_pins/2; i++) {
    intensities[i] = c.readBinArg<int>();
  }
  for (int i = 0; i < num_pins/2; i++) {
    SoftPWMSetPercent((num_pins/2) + i + 2, intensities[i]);
  }
}

void setup() {
  Serial.begin(BAUD_RATE);
  Serial.setTimeout(1);
  SoftPWMBegin();
  for (int i = 0; i < num_pins; i++) {
    SoftPWMSet(i + 2, 0);
    SoftPWMSetFadeTime(i + 2, 50, 50);
  }
  c.attach(receive_frameL, on_receive_frameL);
  c.attach(receive_frameR, on_receive_frameR);
}

void loop() {
  c.feedinSerialData();
}
