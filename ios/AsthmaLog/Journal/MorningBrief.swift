import Foundation
import UserNotifications

/// The morning look-ahead (owner, Oct 17): a notification at 8 with the day's air. Opening it brings the app
/// forward, which renews the Lock Screen card (so a felt button press can light it up all day) and fills in
/// baseline moments. Scheduled each time the app is open: tomorrow with tomorrow's look-ahead, the six
/// mornings after with a plain line, so it keeps coming if the app isn't opened for a while.
@MainActor
enum MorningBrief {
    static let prefix = "morningBrief."
    static let hour = 8

    static var enabled: Bool { UserDefaults.standard.object(forKey: Prefs.morningBrief) as? Bool ?? true }

    /// `title`/`body`: tomorrow's look-ahead, worded for the morning it arrives ("This afternoon…").
    static func schedule(title: String?, body: String?) {
        guard enabled else { return }
        let center = UNUserNotificationCenter.current()
        cancel()
        let cal = Calendar.current
        for offset in 1...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: .now),
                  let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { continue }
            let c = UNMutableNotificationContent()
            if offset == 1, let title, let body {
                c.title = title
                c.body = body
            } else {
                c.title = "Today's air"
                c.body = "See what the day looks like next to your flare days."
            }
            c.sound = .default
            c.threadIdentifier = "morning"
            let when = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            center.add(UNNotificationRequest(identifier: prefix + String(offset), content: c,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (1...7).map { prefix + String($0) })
    }
}
