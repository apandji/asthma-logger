import TipKit

/// First-use hints in Apple's own tip style (TipKit). Each shows a couple of times, then stays away.
struct PullToLogTip: Tip {
    var title: Text { Text("Pull up to log") }
    var message: Text? { Text("A short pull logs Rescue. All the way up logs Standard. Let go low to cancel.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct MomentsTip: Tip {
    var title: Text { Text("Your moments") }
    var message: Text? { Text("Swipe between them. Tap one for details, or pinch in for the calendar.") }
    var image: Image? { Image(systemName: "hand.pinch") }
}

enum AppTips {
    static let resetKey = "resetTipsOnLaunch"

    /// Call once at launch. Settings › Reset onboarding asks for a reset on the next launch.
    static func configure() {
        if UserDefaults.standard.bool(forKey: resetKey) || ProcessInfo.processInfo.arguments.contains("-resetTips") {
            try? Tips.resetDatastore()
            UserDefaults.standard.set(false, forKey: resetKey)
        }
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}
