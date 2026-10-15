import Foundation

/// The felt button's Bluetooth LE protocol, v1. Spec: docs/smart-button.md. The firmware in
/// hardware/felt-button must send exactly this. Pure bytes, no CoreBluetooth, so it tests on Linux.
public enum ButtonProtocol {
    public static let serviceUUID = "FF99B917-77AF-4558-BE3A-83FC9956C417"
    /// Notify: one 12-byte `ButtonPacket` per press.
    public static let pressUUID = "57503ACF-0060-4E3F-B373-4F935BD362A1"
    /// Write: 4-byte ack (`bootID`, `seq`), so the button can drop that press from its queue.
    public static let ackUUID = "4536589B-25C4-46B0-8759-AA7CCC032E48"
    public static let version: UInt8 = 1
}

/// One press. All fields little-endian:
/// `[0] version · [1] cap · [2–3] bootID · [4–5] seq · [6–7] force · [8–11] ageMs`.
public struct ButtonPacket: Sendable, Equatable, Hashable {
    public enum Cap: UInt8, Sendable {
        /// Orange cap.
        case rescue = 1
        /// Teal cap: the standard (maintenance) inhaler.
        case standard = 2
    }

    public let cap: Cap
    /// Random per power-up, so `seq` restarting at 1 after a reboot isn't mistaken for a repeat.
    public let bootID: UInt16
    public let seq: UInt16
    /// Peak force from the optional FSR, 0–4095; 0 when the button has no FSR.
    public let force: UInt16
    /// How long ago the press happened when this packet was sent. The button has no clock, so the
    /// phone works out the time from this (presses queue while the phone is away).
    public let ageMs: UInt32

    public init(cap: Cap, bootID: UInt16, seq: UInt16, force: UInt16 = 0, ageMs: UInt32 = 0) {
        self.cap = cap
        self.bootID = bootID
        self.seq = seq
        self.force = force
        self.ageMs = ageMs
    }

    public init?(bytes: [UInt8]) {
        guard bytes.count >= 12, bytes[0] == ButtonProtocol.version, let cap = Cap(rawValue: bytes[1]) else { return nil }
        func u16(_ i: Int) -> UInt16 { UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8 }
        let age = UInt32(bytes[8]) | UInt32(bytes[9]) << 8 | UInt32(bytes[10]) << 16 | UInt32(bytes[11]) << 24
        self.init(cap: cap, bootID: u16(2), seq: u16(4), force: u16(6), ageMs: age)
    }

    public var bytes: [UInt8] {
        [ButtonProtocol.version, cap.rawValue,
         UInt8(bootID & 0xFF), UInt8(bootID >> 8),
         UInt8(seq & 0xFF), UInt8(seq >> 8),
         UInt8(force & 0xFF), UInt8(force >> 8),
         UInt8(ageMs & 0xFF), UInt8((ageMs >> 8) & 0xFF), UInt8((ageMs >> 16) & 0xFF), UInt8(ageMs >> 24)]
    }

    /// What the phone writes back once the press is saved.
    public var ack: [UInt8] {
        [UInt8(bootID & 0xFF), UInt8(bootID >> 8), UInt8(seq & 0xFF), UInt8(seq >> 8)]
    }

    /// Same press, however many times it's resent.
    public var key: String { "\(bootID)-\(seq)" }

    public func pressedAt(receivedAt: Date) -> Date {
        receivedAt.addingTimeInterval(-Double(ageMs) / 1000)
    }
}
