// felt button: firmware v1 for the Arduino Nano ESP32.
// Two tactile buttons (orange cap = rescue, teal cap = standard), plus an optional FSR on the inhaler.
// Each press goes to the felt air iPhone app over Bluetooth LE. Protocol: docs/smart-button.md.
//
// Wiring (each button has two legs across the gap; no resistors needed, the board's pull-ups are used):
//   Orange (rescue) button:   D2 ── button ── GND
//   Teal (standard) button:   D3 ── button ── GND
//   Optional FSR:             3V3 ── FSR ── A1 ── 10 kΩ ── GND   (then set USE_FSR to true)
//
// Arduino IDE: Boards Manager → "Arduino ESP32 Boards" (tested with 2.0.18-arduino.5), board "Arduino Nano ESP32".
// Or skip the IDE: plug the board in and run hardware/felt-button/upload.sh.

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>

// Must match ButtonProtocol in ios/AsthmaCore/Sources/AsthmaCore/Journal/ButtonPacket.swift.
#define SERVICE_UUID "ff99b917-77af-4558-be3a-83fc9956c417"
#define PRESS_UUID   "57503acf-0060-4e3f-b373-4f935bd362a1"
#define ACK_UUID     "4536589b-25c4-46b0-8759-aa7ccc032e48"
const uint8_t PROTOCOL_VERSION = 1;
const uint8_t CAP_RESCUE = 1;
const uint8_t CAP_STANDARD = 2;

const int RESCUE_PIN = D2;
const int STANDARD_PIN = D3;
const int FSR_PIN = A1;
const bool USE_FSR = false;          // true: pressing the inhaler (FSR) also logs a rescue moment
const int FSR_ON = 1500;             // 0–4095; tune with the Serial Monitor
const int FSR_OFF = 1000;            // must drop below this before the next press counts

const unsigned long DEBOUNCE_MS = 30;
const unsigned long LOCKOUT_MS = 600; // two real puffs are further apart than this
const unsigned long RESEND_MS = 3000; // unacked presses are re-sent this often while connected

// Presses wait here until the phone acks them, so nothing is lost while the phone is away.
struct Press { bool used; uint8_t cap; uint16_t seq; uint16_t force; unsigned long at; };
const int QUEUE_SIZE = 32;
Press queue[QUEUE_SIZE];

uint16_t bootId;                     // random per power-up, so seq restarting at 1 isn't a repeat
uint16_t nextSeq = 1;
BLECharacteristic *pressChar;
volatile bool connected = false;
unsigned long lastResend = 0;
unsigned long connectedAt = 0;

// ---------- Queue ----------

void enqueue(uint8_t cap, uint16_t force) {
  int slot = -1;
  for (int i = 0; i < QUEUE_SIZE; i++) if (!queue[i].used) { slot = i; break; }
  if (slot < 0) {                    // full: drop the oldest
    slot = 0;
    for (int i = 1; i < QUEUE_SIZE; i++) if (queue[i].at < queue[slot].at) slot = i;
  }
  queue[slot] = { true, cap, nextSeq++, force, millis() };
}

void sendPress(const Press &p) {
  uint32_t age = millis() - p.at;
  uint8_t b[12] = {
    PROTOCOL_VERSION, p.cap,
    (uint8_t)(bootId & 0xFF), (uint8_t)(bootId >> 8),
    (uint8_t)(p.seq & 0xFF), (uint8_t)(p.seq >> 8),
    (uint8_t)(p.force & 0xFF), (uint8_t)(p.force >> 8),
    (uint8_t)(age & 0xFF), (uint8_t)((age >> 8) & 0xFF), (uint8_t)((age >> 16) & 0xFF), (uint8_t)(age >> 24)
  };
  pressChar->setValue(b, sizeof(b));
  pressChar->notify();
}

void sendQueued() {
  // Oldest first, with a short gap so the phone keeps up.
  int order[QUEUE_SIZE];
  int n = 0;
  for (int i = 0; i < QUEUE_SIZE; i++) if (queue[i].used) order[n++] = i;
  for (int i = 1; i < n; i++) {        // insertion sort by press time
    int k = order[i], j = i - 1;
    while (j >= 0 && queue[order[j]].at > queue[k].at) { order[j + 1] = order[j]; j--; }
    order[j + 1] = k;
  }
  for (int i = 0; i < n; i++) {
    if (!connected) return;
    sendPress(queue[order[i]]);
    delay(60);
  }
}

int pending() {
  int n = 0;
  for (int i = 0; i < QUEUE_SIZE; i++) if (queue[i].used) n++;
  return n;
}

// ---------- Bluetooth ----------

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    connected = true;
    connectedAt = millis();
  }
  void onDisconnect(BLEServer *server) override {
    connected = false;
    BLEDevice::startAdvertising();   // be findable again right away
  }
};

class AckCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    auto v = c->getValue();           // String or std::string depending on the core; both index the same
    if (v.length() < 4) return;
    uint16_t boot = (uint8_t)v[0] | ((uint8_t)v[1] << 8);
    uint16_t seq = (uint8_t)v[2] | ((uint8_t)v[3] << 8);
    if (boot != bootId) return;
    for (int i = 0; i < QUEUE_SIZE; i++) {
      if (queue[i].used && queue[i].seq == seq) queue[i].used = false;
    }
  }
};

// ---------- LED (the Nano ESP32's RGB LED is active LOW) ----------

void led(bool r, bool g, bool b) {
  digitalWrite(LED_RED, r ? LOW : HIGH);
  digitalWrite(LED_GREEN, g ? LOW : HIGH);
  digitalWrite(LED_BLUE, b ? LOW : HIGH);
}

void flash(uint8_t cap) {
  if (cap == CAP_RESCUE) led(true, true, false);   // warm (red + green)
  else led(false, true, true);                     // teal (green + blue)
  delay(120);
  led(false, false, false);
}

// ---------- Buttons ----------

struct Button { int pin; uint8_t cap; bool stable; bool lastRead; unsigned long changedAt; unsigned long lastPress; };
Button buttons[] = {
  { RESCUE_PIN, CAP_RESCUE, HIGH, HIGH, 0, 0 },
  { STANDARD_PIN, CAP_STANDARD, HIGH, HIGH, 0, 0 },
};
bool fsrDown = false;
unsigned long fsrLastPress = 0;

void press(uint8_t cap, uint16_t force) {
  enqueue(cap, force);
  flash(cap);
  Serial.printf("press cap=%d seq=%d force=%d connected=%d pending=%d\n", cap, nextSeq - 1, force, connected, pending());
  if (connected) sendQueued();
}

void readButtons() {
  unsigned long now = millis();
  for (Button &b : buttons) {
    bool r = digitalRead(b.pin);
    if (r != b.lastRead) { b.lastRead = r; b.changedAt = now; }
    if (now - b.changedAt > DEBOUNCE_MS && r != b.stable) {
      b.stable = r;
      if (r == LOW && now - b.lastPress > LOCKOUT_MS) {  // pressed (pulled to GND)
        b.lastPress = now;
        press(b.cap, USE_FSR ? analogRead(FSR_PIN) : 0);
      }
    }
  }
  if (USE_FSR) {
    int f = analogRead(FSR_PIN);
    if (!fsrDown && f > FSR_ON && now - fsrLastPress > LOCKOUT_MS) {
      fsrDown = true;
      fsrLastPress = now;
      press(CAP_RESCUE, f);
    } else if (fsrDown && f < FSR_OFF) {
      fsrDown = false;
    }
  }
}

// ---------- Setup and loop ----------

void setup() {
  Serial.begin(115200);
  pinMode(RESCUE_PIN, INPUT_PULLUP);
  pinMode(STANDARD_PIN, INPUT_PULLUP);
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  led(false, false, false);

  bootId = (uint16_t)(esp_random() & 0xFFFF);

  BLEDevice::init("felt button");
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService *service = server->createService(SERVICE_UUID);

  pressChar = service->createCharacteristic(PRESS_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pressChar->addDescriptor(new BLE2902());
  BLECharacteristic *ackChar = service->createCharacteristic(ACK_UUID, BLECharacteristic::PROPERTY_WRITE);
  ackChar->setCallbacks(new AckCallbacks());
  service->start();

  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.printf("felt button ready, boot %u\n", bootId);
}

void loop() {
  readButtons();

  unsigned long now = millis();
  // Give the phone a moment to subscribe after connecting, then resend anything not yet acked.
  if (connected && now - connectedAt > 1500 && now - lastResend > RESEND_MS && pending() > 0) {
    lastResend = now;
    sendQueued();
  }

  // Slow blue blink while waiting for the phone; off once connected.
  digitalWrite(LED_BLUE, !connected && (now / 500) % 4 == 0 ? LOW : HIGH);

  delay(5);
}
