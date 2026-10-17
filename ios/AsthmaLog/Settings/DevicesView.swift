import AsthmaCore
import SwiftUI
import WatchConnectivity

/// Settings › Devices: every felt button this phone knows, with a name you can edit, when it last
/// spoke, and Forget; Add a button runs the same pairing moment as onboarding; the Apple Watch when
/// there is one. An unknown button is never logged until it's added here.
struct DevicesView: View {
    @Environment(ButtonLink.self) private var button
    @State private var renaming: PairedButton?
    @State private var newName = ""
    @State private var adding = false

    var body: some View {
        List {
            Section {
                if button.buttons.isEmpty {
                    Text("No felt button yet.").foregroundStyle(Theme.secondaryText)
                }
                ForEach(button.buttons) { b in
                    HStack(spacing: 12) {
                        Circle().fill(button.connectedIDs.contains(b.id) ? Verdict.green : Theme.secondaryText.opacity(0.35))
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.name).font(.body.weight(.medium))
                            Text(detail(b)).font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Button { renaming = b; newName = b.name } label: { Image(systemName: "pencil") }
                            .buttonStyle(.plain).foregroundStyle(Theme.secondaryText)
                    }
                    .swipeActions { Button("Forget", role: .destructive) { button.forget(b.id) } }
                }
                if adding {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(addingStatus).font(.subheadline).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Button("Cancel") { adding = false; button.stopPairing() }.font(.subheadline)
                    }
                } else {
                    Button { adding = true; button.pair() } label: { Label("Add a button", systemImage: "plus.circle") }
                }
            } header: {
                Text("felt buttons")
            } footer: {
                Text("The orange cap logs Rescue, the teal cap Standard. A press from a button that isn't on this list is ignored, so a neighbour's button can't log for you. Swipe a button to forget it.")
            }

            Section("Apple Watch") {
                if WCSession.isSupported(), WCSession.default.isPaired {
                    HStack(spacing: 12) {
                        Circle().fill(WCSession.default.isWatchAppInstalled ? Verdict.green : Theme.secondaryText.opacity(0.35)).frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Watch").font(.body.weight(.medium))
                            Text(WCSession.default.isWatchAppInstalled ? "felt air is on your watch. Its Rescue and Standard buttons log here." : "Install felt air on the watch to log from your wrist.")
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                } else {
                    Text("No Apple Watch paired with this iPhone.").foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .navigationTitle("Devices")
        .onChange(of: button.buttons.count) { old, new in if new > old { adding = false } }
        .onChange(of: button.status) { _, s in if adding, s != .searching, s != .connecting { adding = false } }
        .alert("Name this button", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") { if let r = renaming { button.rename(r.id, to: newName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("For example \"Orange cap, kitchen\".")
        }
    }

    private var addingStatus: String {
        switch button.status {
        case .bluetoothOff: "Turn on Bluetooth."
        case .notAllowed: "Bluetooth is off for felt air in Settings."
        case .connecting: "Connecting…"
        default: "Press the new button once."
        }
    }

    private func detail(_ b: PairedButton) -> String {
        let id = b.id.uuidString.prefix(8)
        if button.connectedIDs.contains(b.id) { return "Connected · \(id)" }
        if let seen = b.lastSeen { return "Last press \(seen.formatted(.relative(presentation: .named))) · \(id)" }
        return "Added \(b.addedAt.formatted(.dateTime.month(.abbreviated).day())) · not heard from yet · \(id)"
    }
}
