# felt button (Bluetooth LE)

The felt button is a small Arduino device with two caps. **Orange logs a rescue moment; teal logs a standard moment.** A press goes to the iPhone over Bluetooth LE, and the phone treats it like a tap on the Rescue or Standard button: it saves the moment and stamps the outdoor air, place and Apple Health.

Not having a button is a complete path. The app never asks for Bluetooth until someone taps **Settings › felt button › Pair a felt button**.

| Part | Where |
|------|-------|
| Firmware (Arduino Nano ESP32) | [`hardware/felt-button/felt-button.ino`](../hardware/felt-button/felt-button.ino) |
| Packet format, shared constants, tests | `ios/AsthmaCore/Sources/AsthmaCore/Journal/ButtonPacket.swift` |
| Connection (CoreBluetooth) | `ios/AsthmaLog/App/ButtonLink.swift` |
| Saving the press | `LogService.logFromButton` |
| Settings screen | `ios/AsthmaLog/Settings/ButtonSection.swift` |

## Protocol v1

Advertised name `felt button`, with one GATT service.

| | UUID | Properties |
|---|---|---|
| Service | `FF99B917-77AF-4558-BE3A-83FC9956C417` | |
| Press | `57503ACF-0060-4E3F-B373-4F935BD362A1` | read, notify |
| Ack | `4536589B-25C4-46B0-8759-AA7CCC032E48` | write |

**Press packet**: 12 bytes, little-endian.

| Bytes | Field | Meaning |
|---|---|---|
| 0 | `version` | `1` |
| 1 | `cap` | `1` rescue (orange), `2` standard (teal) |
| 2–3 | `bootID` | Random each power-up |
| 4–5 | `seq` | Counts up from 1 each power-up |
| 6–7 | `force` | Peak FSR reading 0–4095, `0` without an FSR |
| 8–11 | `ageMs` | Milliseconds since the press, at send time |

**Ack**: the phone writes 4 bytes back: `bootID` then `seq`, both little-endian.

### Why it's shaped this way

- **The button has no clock.** It sends how long ago the press happened, and the phone subtracts that from its own clock.
- **Nothing is lost when the phone is away.** The button keeps up to 32 presses until the phone acks them, resending every 3 s while connected. A press that arrives more than 15 minutes late is saved without an air reading: the air is fetched for "now", so it would be wrong (same rule as the Apple Watch).
- **Nothing is logged twice.** The phone remembers `bootID-seq` for the last 500 presses and ignores repeats, but always acks them so the button stops resending. `bootID` keeps `seq` restarting at 1 after a power cycle from looking like a repeat.
- **It works in the background.** The app uses the `bluetooth-central` background mode and state restoration. Once paired, iOS reconnects whenever the button is back in range, even with the app closed.

Changing the packet means a new `version`, plus updates to the firmware, `ButtonPacket`, its tests and this page.

## Build the button

**Parts**: an Arduino Nano ESP32, two 12 mm tactile buttons (orange and teal caps), jumper wires, a half-size breadboard, a data USB-C cable. Optional: the FSR and a 10 kΩ resistor.

**Wiring**: no resistors are needed for the buttons; the firmware uses the board's internal pull-ups.

```
Orange (rescue)   D2 ── button ── GND
Teal (standard)   D3 ── button ── GND
FSR (optional)    3V3 ── FSR ── A1 ── 10 kΩ ── GND
```

Put each button across the breadboard's middle gap so its two legs are on different rows.

**Flash it (once)**

Plug the board into the Mac with a data USB-C cable and run:

```bash
hardware/felt-button/upload.sh
```

It installs the board package if needed (**Arduino ESP32 Boards**, tested with 2.0.18-arduino.5), compiles, and uploads. Or, in the Arduino IDE: Tools › Board › **Arduino Nano ESP32**, pick the port, open `felt-button.ino`, Upload.

The program is saved in the board's flash memory, so it stays there after you unplug it and runs every time the board gets power. A USB power bank is enough; the Mac and the IDE are only needed to change the code. If an upload can't find the board, double-tap its reset button (the LED pulses green) and run it again.

**Check it**: open the Serial Monitor at 115200 (the script prints the command). You should see `felt button ready`. Press each button: it prints `press cap=1` or `cap=2` and the LED flashes warm or teal. No buttons yet? Type `r` (rescue) or `s` (standard) in the Serial Monitor, or touch a jumper from D2 or D3 to GND.

The LED blinks blue slowly while it's waiting for the phone and stops once connected.

To use the FSR on the inhaler as well, set `USE_FSR = true`. Watch the Serial Monitor while pressing and adjust `FSR_ON` / `FSR_OFF`.

## Pair it

1. Power the button (USB or a power bank) and keep it near the iPhone.
2. felt air › Settings › **felt button › Pair a felt button**. Allow Bluetooth when iOS asks.
3. Status turns **Connected to felt button**. Press orange: a rescue moment appears in the Journal.

**Forget this button** disconnects it and stops reconnecting. Pairing again picks the first felt button in range.

## Not yet

- Battery level (the Nano ESP32 is on USB for now; the nRF52840 is the low-power option later).
- Showing the FSR force in the app. It's sent, but not saved yet.
- Pairing from onboarding (the "felt button" choice in onboarding doesn't pair yet).
- More than one button per phone.
