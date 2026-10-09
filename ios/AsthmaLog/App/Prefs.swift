import Foundation

/// UserDefaults keys for @AppStorage. Settings lives in SettingsView.
enum Prefs {
    static let narratorStyle = "narratorStyle"
    static let useOnDeviceModel = "useOnDeviceModel"
    static let writeToHealth = "writeToHealth"
    static let autoBaseline = "autoBaseline"
    static let useDemoData = "useDemoData"
    static let didOnboard = "didOnboard"
    /// How the person said they'll log: "watch", "button" or "app".
    static let logMethod = "logMethod"
}
