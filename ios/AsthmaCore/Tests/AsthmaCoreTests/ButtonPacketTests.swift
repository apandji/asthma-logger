import Foundation
import Testing
@testable import AsthmaCore

@Suite struct ButtonPacketTests {
    @Test func decodesLittleEndianFields() {
        let bytes: [UInt8] = [1, 1, 0x34, 0x12, 0x07, 0x00, 0xFF, 0x0F, 0x10, 0x27, 0x00, 0x00]
        let p = ButtonPacket(bytes: bytes)
        #expect(p == ButtonPacket(cap: .rescue, bootID: 0x1234, seq: 7, force: 4095, ageMs: 10_000))
    }

    @Test func roundTrips() {
        let p = ButtonPacket(cap: .standard, bootID: 65535, seq: 300, force: 12, ageMs: 4_000_000_000)
        #expect(ButtonPacket(bytes: p.bytes) == p)
        #expect(p.bytes.count == 12)
    }

    @Test(arguments: [
        [UInt8](),
        [1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],          // too short
        [2, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],       // unknown version
        [1, 3, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],       // unknown cap
    ])
    func rejectsBadPackets(_ bytes: [UInt8]) {
        #expect(ButtonPacket(bytes: bytes) == nil)
    }

    @Test func ackIsBootIDThenSeq() {
        let p = ButtonPacket(cap: .rescue, bootID: 0xABCD, seq: 0x0102)
        #expect(p.ack == [0xCD, 0xAB, 0x02, 0x01])
    }

    @Test func pressTimeComesFromAge() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let p = ButtonPacket(cap: .rescue, bootID: 1, seq: 1, ageMs: 90_500)
        #expect(p.pressedAt(receivedAt: now) == now.addingTimeInterval(-90.5))
    }

    @Test func resendsShareAKeyButRebootsDont() {
        let a = ButtonPacket(cap: .rescue, bootID: 9, seq: 1, ageMs: 0)
        let resent = ButtonPacket(cap: .rescue, bootID: 9, seq: 1, ageMs: 5_000)
        let afterReboot = ButtonPacket(cap: .rescue, bootID: 10, seq: 1)
        #expect(a.key == resent.key)
        #expect(a.key != afterReboot.key)
    }
}
