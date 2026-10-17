import TipKit

/// First-use hints in Apple's own tip style (TipKit). Each shows a couple of times, then stays away.
struct PullToLogTip: Tip {
    var title: Text { Text("Log with the +") }
    var message: Text? { Text("Press and slide to Rescue or Standard, then let go. Or tap, then choose.") }
    var image: Image? { Image(systemName: "hand.draw") }
    /// For anyone who'd rather tap: switches the + to two labelled buttons (also in Settings).
    var actions: [Action] { [Action(id: "buttons", title: "Use buttons instead")] }
}

struct MomentsTip: Tip {
    var title: Text { Text("Drag the timeline") }
    var message: Text? { Text("Each mark is a moment. Drag here, or swipe the map, to move through time. Tap the map for details.") }
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
    var title: Text { Text("Read the air") }
    var message: Text? { Text("Slide along the icons on the right to see each layer and how much is in the air.") }
    var image: Image? { Image(systemName: "hand.point.up.left") }
}
