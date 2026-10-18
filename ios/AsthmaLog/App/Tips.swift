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

/// Once, the first time a sentence carries felt air's sparkle: what the mark means. Now only draws its
/// TipView while a sentence with a mark is on screen, so it needs no rule of its own.
struct SparkleTip: Tip {
    var title: Text { Text("\(Image(systemName: "sparkles")) Shows up on your flare days") }
    // The marks themselves, as a key, instead of describing them in words.
    var message: Text? { Self.key }
    /// Shared with the popover you get by tapping a sentence's sparkle.
    static var key: Text { Text("\(Image(systemName: "sparkles")) often   \(Image(systemName: "sparkle")) sometimes\nWhat felt air has noticed, not a cause.") }
    var options: [any TipOption] { [Tips.MaxDisplayCount(1)] }
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
