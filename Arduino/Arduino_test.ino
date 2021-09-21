#include <AltSoftSerial.h>

AltSoftSerial remoteSerial;

byte position1[7] = {2, 0, 0, 0, 180, 0, 90};
byte position2[7] = {2, 0, 60, 0, 180, 0, 180};
byte position3[7] = {2, 0, 60, 0, 150, 1, 90};
byte position4[7] = {2, 0, 30, 0, 150, 0, 180};
byte position5[7] = {2, 0, 30, 0, 60, 0, 180};

byte slot1[9] = {3, 0, 1, 1, 20, 30, 1, 20, 57};
byte slot2[9] = {3, 0, 2, 0, 5, 200, 0, 32, 200};
byte slot3[9] = {3, 1, 3, 0, 50, 120, 0, 50, 93};

byte status1[2] = {4, 1};
byte status2[2];

int pos = 1;
boolean flag = true;

void setup() {
  remoteSerial.begin(9600);
  Serial.begin(9600);
}

void loop() {
  if (remoteSerial.available()) {
    remoteSerial.readBytes(status2, 2);

    Serial.println("#################################");
    Serial.print((String)status2[0] + (String)status2[1]);
    Serial.println();
  }
  //Serial.println(pos);

  delay(10000);
  switch (pos) {
    case 1:
      remoteSerial.write(position1, 7);
      break;
    case 2:
      remoteSerial.write(position2, 7);
      break;
    case 3:
      remoteSerial.write(position3, 7);
      break;
    case 4:
      remoteSerial.write(position4, 7);
      break;
    case 5:
      remoteSerial.write(position5, 7);
      break;
    case 6:
      remoteSerial.write(slot1, 9);
      break;
    case 7:
      remoteSerial.write(slot2, 9);
      break;
    case 8:
      remoteSerial.write(slot3, 9);
      break;
    case 9:
      remoteSerial.write(status1, 2);
      break;
    default:
      break;
  }
  pos++;
}
