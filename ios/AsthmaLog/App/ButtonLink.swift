import AsthmaCore
import CoreBluetooth
import Foundation
import Observation

/// Connects to the felt button over Bluetooth LE (protocol: docs/smart-button.md) and hands each press
/// to `onPress`. The Bluetooth permission prompt only appears when someone taps Pair, so people
/// without a button never see it. Once paired, iOS keeps the connection request open in the
/// background, so presses log with the app closed.
@Observable
final class ButtonLink: NSObject {
    enum Status: Equatable {
        case notPaired, searching, connecting, connected, away, bluetoothOff, notAllowed
    }

    private(set) var status: Status = .notPaired
    private(set) var lastPress: Date?
    private(set) var name: String?
    /// Every felt button this phone knows, newest last. Edited on the Devices page.
    private(set) var buttons: [PairedButton] = PairedButton.load()
    /// Which of them are connected right now.
    private(set) var connectedIDs: Set<UUID> = []
    /// Onboarding's "press to sync": presses confirm the link and aren't logged as inhaler use.
    private(set) var isSyncing = false
    private(set) var syncPresses = 0
    private(set) var lastSyncCap: ButtonPacket.Cap?

    var isPaired: Bool { !buttons.isEmpty }

    @ObservationIgnored private var central: CBCentralManager?
    /// Live peripherals by id, and each one's ack characteristic once found.
    @ObservationIgnored private var peripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var acks: [UUID: CBCharacteristic] = [:]
    @ObservationIgnored private var onPress: ((ButtonPacket, Date) -> Void)?
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var scanTimeout: Task<Void, Never>?

    private static let handledKey = "feltButtonHandled"
    private static let restoreID = "felt-button-central"
    private let service = CBUUID(string: ButtonProtocol.serviceUUID)
    private let pressUUID = CBUUID(string: ButtonProtocol.pressUUID)
    private let ackUUID = CBUUID(string: ButtonProtocol.ackUUID)

    /// Call at launch. Does nothing (and asks nothing) until a button has been paired.
    func start(onPress: @escaping (ButtonPacket, Date) -> Void) {
        self.onPress = onPress
        if isPaired { makeCentral() }
    }

    /// Look for a nearby felt button that isn't paired yet and connect to it.
    func pair() {
        wantsScan = true
        status = .searching
        if let central, central.state == .poweredOn { scan() } else { makeCentral() }
        scanTimeout?.cancel()
        scanTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, !Task.isCancelled, self.status == .searching else { return }
            self.central?.stopScan()
            self.wantsScan = false
            self.status = self.isPaired ? .away : .notPaired
        }
    }

    /// Start onboarding's sync: pair if needed, then count presses instead of logging them.
    func beginSync() {
        isSyncing = true
        syncPresses = 0
        if isPaired { makeCentral() } else if status != .searching { pair() }
    }

    func endSync() { isSyncing = false }

    /// Debug: forget every button and everything they sent, so onboarding's sync can run again.
    func resetForOnboarding() {
        for b in buttons { forget(b.id) }
        isSyncing = false
        syncPresses = 0
        lastSyncCap = nil
        lastPress = nil
        UserDefaults.standard.removeObject(forKey: Self.handledKey)
    }

    /// Forget one button: disconnect it and drop it from the list.
    func forget(_ id: UUID) {
        if let p = peripherals[id] { central?.cancelPeripheralConnection(p) }
        peripherals[id] = nil
        acks[id] = nil
        connectedIDs.remove(id)
        buttons.removeAll { $0.id == id }
        PairedButton.save(buttons)
        if buttons.isEmpty {
            wantsScan = false
            central?.stopScan()
            name = nil
            status = .notPaired
        }
    }

    func rename(_ id: UUID, to newName: String) {
        guard let i = buttons.firstIndex(where: { $0.id == id }) else { return }
        buttons[i].name = newName.trimmingCharacters(in: .whitespaces)
        PairedButton.save(buttons)
    }

    /// Stop looking for a new button (Devices page › cancel).
    func stopPairing() {
        wantsScan = false
        central?.stopScan()
        scanTimeout?.cancel()
        if status == .searching { status = isPaired ? (connectedIDs.isEmpty ? .away : .connected) : .notPaired }
    }

    #if DEBUG
    /// For recordings in the simulator, where no button can be pressed: a press as if from a paired button.
    func simulatePress(_ cap: ButtonPacket.Cap) {
        let packet = ButtonPacket(cap: cap, bootID: 1, seq: UInt16(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60_000)), force: 0, ageMs: 0)
        if buttons.isEmpty {
            buttons.append(PairedButton(id: UUID(), name: "felt button", addedAt: .now, lastSeen: .now))
            PairedButton.save(buttons)
        }
        status = .connected
        connectedIDs = Set(buttons.map(\.id))
        if isSyncing { syncPresses += 1; lastSyncCap = cap } else { lastPress = .now; onPress?(packet, .now) }
    }
    #endif

    // MARK: Private

    private func makeCentral() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreID])
    }

    private func scan() {
        central?.scanForPeripherals(withServices: [service])
    }

    private func reconnectPaired() {
        guard let central else { return }
        let ids = buttons.map(\.id)
        for p in central.retrievePeripherals(withIdentifiers: ids) {
            use(p)
            if p.state != .connected {
                central.connect(p)   // never times out: iOS connects whenever the button comes back in range
            }
        }
        if !ids.isEmpty, connectedIDs.isEmpty { status = .away }
    }

    private func use(_ p: CBPeripheral) {
        peripherals[p.identifier] = p
        p.delegate = self
        name = p.name
    }

    private func touch(_ id: UUID) {
        guard let i = buttons.firstIndex(where: { $0.id == id }) else { return }
        buttons[i].lastSeen = .now
        PairedButton.save(buttons)
    }

    /// Presses already logged, by `ButtonPacket.key`, so resends (no ack yet, reconnects) don't double-log.
    private func alreadyHandled(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? []).contains(key)
    }

    private func markHandled(_ key: String) {
        var keys = UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? []
        keys.append(key)
        UserDefaults.standard.set(Array(keys.suffix(500)), forKey: Self.handledKey)
    }

    private func receive(_ data: Data, from p: CBPeripheral) {
        guard let packet = ButtonPacket(bytes: [UInt8](data)) else { return }
        let received = Date()
        touch(p.identifier)
        if !alreadyHandled(packet.key) {
            markHandled(packet.key)
            if isSyncing {
                // Presses queued on the button before setup are dropped; only a fresh press confirms the link.
                guard packet.ageMs < 10_000 else { return ackOnly(packet, p) }
                syncPresses += 1
                lastSyncCap = packet.cap
            } else {
                lastPress = packet.pressedAt(receivedAt: received)
                onPress?(packet, received)
            }
        }
        ackOnly(packet, p)
    }

    /// Ack every time, even repeats, so the button stops resending.
    private func ackOnly(_ packet: ButtonPacket, _ p: CBPeripheral) {
        if let ack = acks[p.identifier] {
            p.writeValue(Data(packet.ack), for: ack, type: .withResponse)
        }
    }
}

// Delegate calls arrive on the main queue (`queue: nil`); @preconcurrency checks that at run time.
extension ButtonLink: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantsScan { scan() } else { reconnectPaired() }
        case .poweredOff: status = .bluetoothOff
        case .unauthorized: status = .notAllowed
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        for p in (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]) ?? [] { use(p) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Only while pairing, and only a button we don't have yet: an unknown button never logs on its own.
        guard wantsScan, !buttons.contains(where: { $0.id == peripheral.identifier }) else { return }
        wantsScan = false
        central.stopScan()
        scanTimeout?.cancel()
        let n = buttons.count + 1
        buttons.append(PairedButton(id: peripheral.identifier, name: n == 1 ? "felt button" : "felt button \(n)",
                                    addedAt: .now, lastSeen: nil))
        PairedButton.save(buttons)
        use(peripheral)
        status = .connecting
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedIDs.insert(peripheral.identifier)
        touch(peripheral.identifier)
        status = .connected
        name = peripheral.name
        peripheral.discoverServices([service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard isPaired else { return }
        status = .away
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        acks[peripheral.identifier] = nil
        connectedIDs.remove(peripheral.identifier)
        guard buttons.contains(where: { $0.id == peripheral.identifier }) else { return }
        if connectedIDs.isEmpty { status = .away }
        central.connect(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] where s.uuid == service {
            peripheral.discoverCharacteristics([pressUUID, ackUUID], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            if c.uuid == ackUUID { acks[peripheral.identifier] = c }
            if c.uuid == pressUUID { peripheral.setNotifyValue(true, for: c) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == pressUUID, let data = characteristic.value else { return }
        receive(data, from: peripheral)
    }
}

/// One felt button this phone has paired. Stored on the phone only.
nonisolated struct PairedButton: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var addedAt: Date
    var lastSeen: Date?

    static let key = "feltButtons"
    static let legacyKey = "feltButtonID"

    static func load() -> [PairedButton] {
        if let data = UserDefaults.standard.data(forKey: key), let list = try? JSONDecoder().decode([PairedButton].self, from: data) {
            return list
        }
        // Before the Devices page there was one id. Carry it over.
        if let old = UserDefaults.standard.string(forKey: legacyKey), let id = UUID(uuidString: old) {
            let list = [PairedButton(id: id, name: "felt button", addedAt: .now, lastSeen: nil)]
            save(list)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            return list
        }
        return []
    }

    static func save(_ list: [PairedButton]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }
}
