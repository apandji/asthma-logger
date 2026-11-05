import AsthmaCore
import SwiftUI
import WatchConnectivity

/// Settings › Devices: your inhalers, each with the felt button on its cap (owner, Oct 19: the button goes
/// on the inhaler's cap, so they're one thing on screen). A button's inhaler is learned from its first press;
/// one that hasn't been pressed yet waits under the inhalers. Then the Apple Watch, when there is one. An
/// unknown button is never logged until it's added here.
struct DevicesView: View {
    @Environment(ButtonLink.self) private var button
    @State private var newName = ""
    @State private var adding = false
    @State private var inhalers = Inhaler.load()
    @State private var renamingInhaler: Inhaler?

    var body: some View {
        List {
            // An inhaler and its felt button are one thing: the button sits on the inhaler's cap.
            Section {
                ForEach(inhalers) { i in
                    VStack(alignment: .leading, spacing: 10) {
                        Button { renamingInhaler = i; newName = i.name } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lungs.fill").foregroundStyle(i.kind == .rescue ? Theme.rescue : Theme.standard)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i.name).font(.body.weight(.medium))
                                    Text(i.kind == .rescue ? "Rescue · orange cap" : "Daily · teal cap")
                                        .font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "pencil").foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .foregroundStyle(.primary)
                        let caps = button.buttons.filter { $0.cap == Self.cap(for: i) }
                        ForEach(caps) { b in capRow(b) }
                        if caps.isEmpty { addCap(for: i) }
                    }
                    .padding(.vertical, 2)
                }
                // Paired, but not pressed yet: its cap (and so its inhaler) isn't known.
                ForEach(button.buttons.filter { $0.cap == nil }) { b in
                    VStack(alignment: .leading, spacing: 4) {
                        capRow(b)
                        Text("Press it once to put it on its inhaler.").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
            } header: {
                Text("Inhalers")
            } footer: {
                Text("Each inhaler's felt button sits on its cap: a press logs that inhaler. Presses within 2 minutes count as more puffs of the same use. A button that isn't here is ignored, so a neighbour's can't log for you. Swipe a button to forget it.")
            }

            Section("Apple Watch") {
                if WCSession.isSupported(), WCSession.default.isPaired {
                    HStack(spacing: 12) {
                        Circle().fill(WCSession.default.isWatchAppInstalled ? Verdict.connected : Theme.secondaryText.opacity(0.35)).frame(width: 9, height: 9)
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
        .alert("Rename this inhaler", isPresented: Binding(get: { renamingInhaler != nil }, set: { if !$0 { renamingInhaler = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let r = renamingInhaler, let i = inhalers.firstIndex(where: { $0.id == r.id }) {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { inhalers[i].name = name; Inhaler.save(inhalers) }
                }
                renamingInhaler = nil
            }
            Button("Cancel", role: .cancel) { renamingInhaler = nil }
        }
    }

    /// The cap a felt button reports for this inhaler's kind.
    static func cap(for i: Inhaler) -> ButtonPacket.Cap { i.kind == .rescue ? .rescue : .standard }

    private func capRow(_ b: PairedButton) -> some View {
        HStack(spacing: 10) {
            Circle().fill(button.connectedIDs.contains(b.id) ? Verdict.connected : Theme.secondaryText.opacity(0.35))
                .frame(width: 8, height: 8)
            Text("felt button").font(.subheadline)
            Text(detail(b)).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            Spacer()
        }
        .padding(.leading, 34)
        .swipeActions { Button("Forget", role: .destructive) { button.forget(b.id) } }
    }

    @ViewBuilder private func addCap(for i: Inhaler) -> some View {
        if adding {
            HStack(spacing: 10) {
                ProgressView()
                Text(addingStatus).font(.subheadline).foregroundStyle(Theme.secondaryText)
                Spacer()
                Button("Cancel") { adding = false; button.stopPairing() }.font(.subheadline)
            }
            .padding(.leading, 34)
        } else {
            Button { adding = true; button.pair() } label: {
                Label("Add its felt button", systemImage: "plus.circle").font(.subheadline)
            }
            .padding(.leading, 34)
        }
    }

    private var addingStatus: String {
        switch button.status {
        case .bluetoothOff: "Turn on Bluetooth."
        case .notAllowed: "Bluetooth is off for felt air in Settings."
        case .connecting: "Connecting…"
        default: "Press the button on the cap once."
        }
    }

    private func detail(_ b: PairedButton) -> String {
        if button.connectedIDs.contains(b.id) { return "Connected" }
        if let seen = b.lastSeen { return "Last press \(seen.formatted(.relative(presentation: .named)))" }
        return "Added \(b.addedAt.formatted(.dateTime.month(.abbreviated).day())), not heard from yet"
    }
}
