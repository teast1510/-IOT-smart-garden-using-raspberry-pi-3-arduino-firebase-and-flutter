#include <DHT.h>

#define DHTPIN       2
#define DHTTYPE      DHT11
#define WATER_PIN    A0
#define GREEN_LED    7
#define RED_LED      6
#define YELLOW_LED   5
#define BLUE_LED     4
#define WHITE_LED    3
#define BUZZER       8
#define MOTOR_PIN    9
#define RELAY_PIN   10

#define WATER_LOW_THRESHOLD   300
#define WATER_HIGH_THRESHOLD  700
#define TEMP_LOW_THRESHOLD    15.0
#define TEMP_HIGH_THRESHOLD   35.0
#define HUMIDITY_LOW_THRESHOLD 30.0
#define HUMIDITY_HIGH_THRESHOLD 80.0

DHT dht(DHTPIN, DHTTYPE);

int mode     = 0;
int pumpCmd  = 0;
int motorCmd = 0;

unsigned long lastSendSerial = 0;
unsigned long buzzerStartTime = 0;
bool buzzerActive = false;

void setup() {
  Serial.begin(115200);
  dht.begin();

  pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(BLUE_LED, OUTPUT);
  pinMode(WHITE_LED, OUTPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(MOTOR_PIN, OUTPUT);
  pinMode(RELAY_PIN, OUTPUT);

  digitalWrite(GREEN_LED, LOW);
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(BLUE_LED, LOW);
  digitalWrite(WHITE_LED, LOW);
  digitalWrite(BUZZER, LOW);
  digitalWrite(MOTOR_PIN, LOW);
  digitalWrite(RELAY_PIN, LOW);

  Serial.println("Arduino ready - Waiting for RPi commands...");
}

void loop() {
  unsigned long currentMillis = millis();

  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    Serial.print("RAW CMD: ["); Serial.print(cmd); Serial.println("]");

    if (cmd.startsWith("CMD:")) {
      int modePos  = cmd.indexOf("mode=");
      int pumpPos  = cmd.indexOf("pump=");
      int motorPos = cmd.indexOf("motor=");

      int oldMode = mode;

      if (modePos >= 0) {
        int nextComma = cmd.indexOf(',', modePos);
        mode = cmd.substring(modePos + 5, nextComma >= 0 ? nextComma : cmd.length()).toInt();
      }
      if (pumpPos >= 0) {
        int nextComma = cmd.indexOf(',', pumpPos);
        pumpCmd = cmd.substring(pumpPos + 5, nextComma >= 0 ? nextComma : cmd.length()).toInt();
      }
      if (motorPos >= 0) {
        int nextComma = cmd.indexOf(',', motorPos);
        motorCmd = cmd.substring(motorPos + 6, nextComma >= 0 ? nextComma : cmd.length()).toInt();
      }

      Serial.print("Parsed → Mode: "); Serial.print(mode);
      Serial.print(" | Pump: "); Serial.print(pumpCmd);
      Serial.print(" | Motor: "); Serial.println(motorCmd);

      // Chỉ áp dụng nếu có pump hoặc motor trong lệnh
      if (pumpPos >= 0) digitalWrite(RELAY_PIN, pumpCmd);
      if (motorPos >= 0) digitalWrite(MOTOR_PIN, motorCmd);

      // Gửi DATA ngay nếu mode thay đổi
      if (mode != oldMode) {
        sendData();
      }
    }
  }

  if (currentMillis - lastSendSerial >= 1000) {
    lastSendSerial = currentMillis;
    sendData();
  }
}

void sendData() {
  float humidity    = dht.readHumidity();
  float temperature = dht.readTemperature();
  int waterLevel    = analogRead(WATER_PIN);

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Failed to read from DHT sensor!");
    return;
  }

  bool alert = false;
  int wateralert   = 0;
  int tempalert    = 0;
  int humidityalert = 0;

  if (waterLevel < WATER_LOW_THRESHOLD) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW);
    wateralert = 1;
    alert = true;
  } else if (waterLevel > WATER_HIGH_THRESHOLD) {
    digitalWrite(RED_LED, HIGH);
    digitalWrite(GREEN_LED, LOW);
    alert = true;
  } else {
    digitalWrite(RED_LED, LOW);
    digitalWrite(GREEN_LED, HIGH);
  }

  if (temperature < TEMP_LOW_THRESHOLD || temperature > TEMP_HIGH_THRESHOLD) {
    digitalWrite(YELLOW_LED, HIGH);
    tempalert = 1;
    alert = true;
  } else {
    digitalWrite(YELLOW_LED, LOW);
  }

  if (humidity < HUMIDITY_LOW_THRESHOLD || humidity > HUMIDITY_HIGH_THRESHOLD) {
    digitalWrite(BLUE_LED, HIGH);
    humidityalert = 1;
    alert = true;
  } else {
    digitalWrite(BLUE_LED, LOW);
  }

  if (alert) {
    if (!buzzerActive) {
      digitalWrite(BUZZER, HIGH);
      buzzerStartTime = millis();
      buzzerActive = true;
    }
  }

  if (buzzerActive && millis() - buzzerStartTime >= 100) {
    digitalWrite(BUZZER, LOW);
    buzzerActive = false;
  }

  if (mode == 0) {
    digitalWrite(RELAY_PIN, (wateralert == 1) ? HIGH : LOW);
    digitalWrite(MOTOR_PIN, (humidityalert || tempalert) ? HIGH : LOW);
  }

  Serial.print("DATA:");
  Serial.print(temperature, 1); Serial.print(",");
  Serial.print(humidity, 1); Serial.print(",");
  Serial.print(waterLevel); Serial.print(",");
  Serial.print(digitalRead(RELAY_PIN)); Serial.print(",");
  Serial.print(digitalRead(MOTOR_PIN)); Serial.print(",");
  Serial.print(mode); Serial.print(",");
  Serial.print((wateralert + tempalert + humidityalert > 0) ? 1 : 0);
  Serial.println();
}