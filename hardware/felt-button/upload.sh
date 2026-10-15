#!/usr/bin/env bash
# Compiles felt-button.ino and uploads it to an Arduino Nano ESP32 plugged in over USB.
# Uses the arduino-cli that ships inside the Arduino IDE app. Run: hardware/felt-button/upload.sh
set -euo pipefail
cd "$(dirname "$0")"
CLI="/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli"
[ -x "$CLI" ] || CLI="$(command -v arduino-cli || true)"
[ -n "$CLI" ] || { echo "Install the Arduino IDE first."; exit 1; }
FQBN="arduino:esp32:nano_nora"

"$CLI" core list | grep -q "^arduino:esp32 " || "$CLI" core install arduino:esp32

PORT="${1:-$("$CLI" board list | awk '/nano_nora|Nano ESP32/ {print $1; exit}')}"
[ -n "$PORT" ] || PORT="$(ls /dev/cu.usbmodem* 2>/dev/null | head -1 || true)"
[ -n "$PORT" ] || { echo "No Nano ESP32 found. Plug it in with a data USB-C cable (not charge-only)."; exit 1; }

echo "Uploading to $PORT…"
"$CLI" compile --fqbn "$FQBN" .
"$CLI" upload --fqbn "$FQBN" --port "$PORT" .
echo "Done. It's saved on the board: unplug it and power it from any USB power bank."
echo "To watch presses: \"$CLI\" monitor --port $PORT --config baudrate=115200"
