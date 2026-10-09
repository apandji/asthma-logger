import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// Sends each press to the phone with `transferUserInfo`, which queues and delivers even when the phone
/// is out of reach. The phone saves the moment at the press time; it only notes the air if the moment
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
        WCSession.default.transferUserInfo(entry.userInfo)
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
