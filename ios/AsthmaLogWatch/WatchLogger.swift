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
    /// Presses not yet handed to WatchConnectivity (session still activating, or a transfer failed).
    private var waiting: [WatchLog] = []

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
        if WCSession.default.activationState == .activated {
            flushWaiting()
            send(entry)
        } else {
            // Right after launch the session may still be activating; transfers made now can be dropped.
            waiting.append(entry)
        }
        let time = entry.at.formatted(date: .omitted, time: .shortened)
        let name = kind == .rescue ? "Rescue" : "Standard"
        show(WCSession.default.isReachable ? "\(name) logged · \(time)" : "\(name) saved · sends to iPhone")
    }

    private func send(_ entry: WatchLog) {
        let session = WCSession.default
        if session.isReachable {
            // Phone is nearby: deliver now. If that fails, fall back to the queued transfer.
            // `@Sendable` because WatchConnectivity calls this off the main actor.
            session.sendMessage(entry.userInfo, replyHandler: nil) { @Sendable _ in
                WCSession.default.transferUserInfo(entry.userInfo)
            }
        } else {
            session.transferUserInfo(entry.userInfo)
        }
    }

    private func show(_ message: String) {
        status = message
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { status = "Press to log a moment" }
        }
    }

    private func flushWaiting() {
        guard WCSession.default.activationState == .activated else { return }
        let entries = waiting
        waiting.removeAll()
        entries.forEach(send)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.flushWaiting() }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error != nil, let entry = WatchLog(userInfo: userInfoTransfer.userInfo) else { return }
        // Keep the press instead of losing it silently. It goes again with the next press or activation,
        // not straight away, so a transfer that keeps failing can't loop.
        Task { @MainActor in
            self.waiting.append(entry)
            self.show("Couldn't reach iPhone · will retry")
        }
    }
}
