import SwiftUI

/// Settings › felt button: pair, see whether it's connected, forget it.
struct ButtonSection: View {
    @Environment(ButtonLink.self) private var button

    var body: some View {
        Section {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    Circle().fill(dot).frame(width: 8, height: 8)
                    Text(statusText)
                }
            }
            if let last = button.lastPress {
                LabeledContent("Last press", value: last.formatted(date: .omitted, time: .shortened))
            }
            if button.isPaired {
                Button("Forget this button", role: .destructive) { button.forget() }
            } else {
                Button(button.status == .searching ? "Looking for your button…" : "Pair a felt button") { button.pair() }
                    .disabled(button.status == .searching)
            }
        } header: {
            Text("felt button")
        } footer: {
            Text(footer)
        }
    }

    private var statusText: String {
        switch button.status {
        case .notPaired: "Not paired"
        case .searching: "Searching"
        case .connecting: "Connecting"
        case .connected: button.name.map { "Connected to \($0)" } ?? "Connected"
        case .away: "Paired, out of range"
        case .bluetoothOff: "Bluetooth is off"
        case .notAllowed: "Bluetooth not allowed"
        }
    }

    private var dot: Color {
        switch button.status {
        case .connected: .green
        case .searching, .connecting: .yellow
        case .away: .orange
        default: .secondary
        }
    }

    private var footer: String {
        switch button.status {
        case .notAllowed: "Turn on Bluetooth for felt air in the Settings app › felt air."
        case .searching: "Keep the button powered and near your iPhone."
        default: "Orange cap logs a rescue moment, teal logs standard. Presses made while your iPhone is away are saved on the button and arrive when it's back, without an air reading. The app works the same without a button."
        }
    }
}
