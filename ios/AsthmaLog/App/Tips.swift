import TipKit

/// First-use hints in Apple's own tip style (TipKit). Each shows a couple of times, then stays away.
struct PullToLogTip: Tip {
    var title: Text { Text("Pull up to log") }
    var message: Text? { Text("Pull a little for Rescue, all the way for Standard. Let go early to cancel.") }
    var image: Image? { Image(systemName: "hand.draw") }
    /// For anyone who'd rather tap: switches the + to two labelled buttons (also in Settings).
    var actions: [Action] { [Action(id: "buttons", title: "Use buttons instead")] }
}

struct MomentsTip: Tip {
    var title: Text { Text("Drag the timeline") }
    var message: Text? { Text("Each dot is a moment. Tap or pinch the sky for details, pinch closed for the calendar.") }
    var image: Image? { Image(systemName: "hand.draw") }
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

struct SkyTip: Tip {
    var title: Text { Text("Hold to read the sky") }
    var message: Text? { Text("Drag to see what each color is.") }
    var image: Image? { Image(systemName: "hand.point.up.left") }
}
