import Foundation

/// A moment logged on Apple Watch, sent to the phone with WatchConnectivity `transferUserInfo`
/// (queued and delivered even if the phone is away). Compiled into both the iOS app and the watch app.
nonisolated struct WatchLog: Sendable, Equatable {
    enum Kind: String, Sendable {
        /// Orange button.
        case rescue
        /// Blue button: the standard (maintenance) inhaler.
        case standard
    }

    let id: UUID
    let kind: Kind
    let at: Date

    init(id: UUID = UUID(), kind: Kind, at: Date = .now) {
        self.id = id
        self.kind = kind
        self.at = at
    }

    var userInfo: [String: Any] {
        ["id": id.uuidString, "kind": kind.rawValue, "at": at.timeIntervalSince1970]
    }

    init?(userInfo: [String: Any]) {
        guard let idString = userInfo["id"] as? String, let id = UUID(uuidString: idString),
              let kindRaw = userInfo["kind"] as? String, let kind = Kind(rawValue: kindRaw),
              let at = userInfo["at"] as? TimeInterval else { return nil }
        self.init(id: id, kind: kind, at: Date(timeIntervalSince1970: at))
    }
}
