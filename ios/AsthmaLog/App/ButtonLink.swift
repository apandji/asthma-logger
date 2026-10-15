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

    var isPaired: Bool { UserDefaults.standard.string(forKey: Self.pairedKey) != nil }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var ackCharacteristic: CBCharacteristic?
    @ObservationIgnored private var onPress: ((ButtonPacket, Date) -> Void)?
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var scanTimeout: Task<Void, Never>?

    private static let pairedKey = "feltButtonID"
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

    /// Look for a nearby felt button and connect to the first one found.
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

    func forget() {
        wantsScan = false
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        ackCharacteristic = nil
        name = nil
        UserDefaults.standard.removeObject(forKey: Self.pairedKey)
        status = .notPaired
    }

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
        guard let central, let idString = UserDefaults.standard.string(forKey: Self.pairedKey),
              let id = UUID(uuidString: idString),
              let p = peripheral ?? central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        use(p)
        if p.state != .connected {
            status = .away
            central.connect(p)   // never times out: iOS connects whenever the button comes back in range
        }
    }

    private func use(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        name = p.name
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
        if !alreadyHandled(packet.key) {
            markHandled(packet.key)
            lastPress = packet.pressedAt(receivedAt: received)
            onPress?(packet, received)
        }
        // Ack every time, even repeats, so the button stops resending.
        if let ack = ackCharacteristic {
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
        if let p = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first { use(p) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard wantsScan else { return }
        wantsScan = false
        central.stopScan()
        scanTimeout?.cancel()
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.pairedKey)
        use(peripheral)
        status = .connecting
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
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
        ackCharacteristic = nil
        guard isPaired else { return }
        status = .away
        central.connect(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] where s.uuid == service {
            peripheral.discoverCharacteristics([pressUUID, ackUUID], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            if c.uuid == ackUUID { ackCharacteristic = c }
            if c.uuid == pressUUID { peripheral.setNotifyValue(true, for: c) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == pressUUID, let data = characteristic.value else { return }
        receive(data, from: peripheral)
    }
}
