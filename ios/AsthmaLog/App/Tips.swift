import TipKit

/// First-use hints in Apple's own tip style (TipKit). Each shows a couple of times, then stays away.
struct PullToLogTip: Tip {
    var title: Text { Text("Log with the +") }
    var message: Text? { Text("Press and slide onto Rescue or Standard, then lift. Or tap, then tap a choice.") }
    var image: Image? { Image(systemName: "hand.draw") }
    /// For anyone who'd rather tap: switches the + to two labelled buttons (also in Settings).
    var actions: [Action] { [Action(id: "buttons", title: "Use buttons instead")] }
}

struct MomentsTip: Tip {
    var title: Text { Text("Drag the timeline") }
    var message: Text? { Text("Each mark is a moment. Swipe the map or drag here to move through time. Tap the map for details.") }
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
    var title: Text { Text("Drag across the sky") }
    var message: Text? { Text("Your finger reads each color as it passes.") }
    var image: Image? { Image(systemName: "hand.point.up.left") }
}
