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
    /// Two labelled Rescue / Standard buttons instead of the pull-up +.
    static let logButtons = "logButtons"
    /// After a felt-button or watch press, a notification to add a note (Quick Record). On by default.
    static let quickRecord = "quickRecord"
    /// A felt air card waits on the Lock Screen: a press lights it up, its mic logs a rescue and listens.
    static let lockScreenReady = "lockScreenReady"
    /// Big-statement typeface: `system` (New York), `recursive` (default), or `funnelSans`.
    /// UI chrome stays SF. Legacy bool `useFunnelSans` is still read once for migration.
    static let statementTypeface = "statementTypeface"
    /// Legacy (bool). Migrated into `statementTypeface` on first read.
    static let useFunnelSans = "useFunnelSans"
}
