import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// Sends each press to the phone: straight away with `sendMessage` when it's reachable, otherwise with
/// `transferUserInfo`, which queues and delivers once the phone is back. The phone saves the moment at the press time; it only notes the air if the moment
/// arrives within 15 minutes.
@Observable
final class WatchLogger: NSObject, WCSessionDelegate {
    private(set) var status = "Press to log a moment"
    private var resetTask: Task<Void, Never>?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func log(_ kind: WatchLog.Kind) {
        let entry = WatchLog(kind: kind)
        WKInterfaceDevice.current().play(.success)
        let session = WCSession.default
        if session.activationState == .activated && session.isReachable {
            // Phone is nearby: deliver now. If that fails, fall back to the queued transfer.
            session.sendMessage(entry.userInfo, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(entry.userInfo)
            }
        } else {
            session.transferUserInfo(entry.userInfo)
        }
        let time = entry.at.formatted(date: .omitted, time: .shortened)
        let name = kind == .rescue ? "Rescue" : "Standard"
        status = WCSession.default.isReachable ? "\(name) logged · \(time)" : "\(name) saved · sends to iPhone"
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { status = "Press to log a moment" }
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
