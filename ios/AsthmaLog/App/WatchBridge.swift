import Foundation
import WatchConnectivity

/// Receives moments logged on Apple Watch. The watch queues them with `transferUserInfo`, so they
/// arrive even if the phone was away; `LogService.logFromWatch` drops duplicates.
final class WatchBridge: NSObject, WCSessionDelegate {
    private var onLog: ((WatchLog) -> Void)?

    func start(onLog: @escaping (WatchLog) -> Void) {
        self.onLog = onLog
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let log = WatchLog(userInfo: userInfo) else { return }
        Task { @MainActor in self.onLog?(log) }
    }
}
