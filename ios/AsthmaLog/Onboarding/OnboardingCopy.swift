import Foundation

/// Every word onboarding says, in one place, for a human pass (Pandji, Oct 19). Edit here; the screens read
/// from it. House rules (AGENTS.md › UI › Copy): short, concrete, plain; no semicolons; say what happens.
/// The top of each screen is the air itself (the first capture's readings), so the titles live in the panel.
enum OnboardingCopy {
    // MARK: Welcome
    static let welcomeTitle = "Welcome to felt air"
    static let welcomeBody = "Each time you use your inhaler, felt air saves the air and weather around you. After a few weeks, you'll see what your flare days have in common."
    static let welcomeFine = "Outdoor air only. Not medical advice."
    static let welcomeAction = "Get started"
    /// The top of the screen before there's a place.
    static let welcomeTop = "Your inhaler, and the air around it."

    // MARK: Where you are
    static let hereTitle = "Where you are"
    static let hereBody = "felt air checks the air right where you are each time you log. Weather and air services get the location, never who you are, and never your history."
    static let hereNoLocation = "Turn on location in Settings to add the air to each moment."
    static let hereWaiting = "Look for the location prompt."
    static let next = "Next"
    /// The top of the screen once you're found: the air isn't read yet, the first press brings it in.
    static let hereFoundTop = "Your first press brings in the air here."
    static let hereLocatingTop = "Finding you…"
    static let hereNoLocationTop = "You can still log without it."
    static let noLocation = "No location"

    // MARK: Pair your inhaler
    static let pairTitle = "Pair your inhaler"
    static let buttonHint = "Orange cap is Rescue, teal is Standard. This first press is a test, not a rescue."
    static let buttonSkip = "I don't have a felt button"
    static let buttonListening = "Press the felt button on your inhaler. Keep it close to your iPhone."
    static let buttonConnecting = "Connecting…"
    static let buttonConnected = "Connected. Press either cap."
    static let buttonBluetoothOff = "Turn on Bluetooth to connect."
    static let buttonNotAllowed = "Bluetooth is off for felt air. Turn it on in Settings › felt air."
    /// Without a felt button: the cap on screen.
    static let softBody = "Press and hold the cap, the way you'd press your inhaler."
    static let softFine = "This first press is a test, not a rescue."
    static let softHaveButton = "I have a felt button"
    static let capLabel = "Inhaler cap"
    static let capHint = "Press and hold to take a test press."
    static let capWaitingLabel = "Waiting for a press on your felt button"
    /// Between the press and the readings landing.
    static let fetchingTop = "Checking the air here…"
    static let fetchingBody = "Saving the air where you are."

    // MARK: Your first moment
    static let firstTitle = "Your first moment"
    static let firstBodyButton = "That press saved the air here, right now. It's a test, so it's kept as your first moment, not a rescue."
    static let firstBodyApp = "That press saved the air here, right now. It's a test, so it's kept as your first moment, not a rescue. From now on, log with the +."
    static let firstTag = "First moment"

    // MARK: Inhalers
    static let inhalersTitle = "Name your inhalers"
    static let inhalersBody = "So each moment says which one you used. You can rename them later in Settings."
    static let inhalerRescueLabel = "Rescue · orange cap"
    static let inhalerRescuePlaceholder = "e.g. Ventolin"
    static let inhalerDailyLabel = "Daily · teal cap"
    static let inhalerDailyPlaceholder = "e.g. Flovent"

    // MARK: Data
    static let dataTitle = "What felt air uses"
    static let dataBody = "And where it goes. Everything here is optional. Logging works without it."

    // MARK: What happens next
    static let learnTitle = "It gets better with time"
    static let learnBody = "Each press saves a moment. felt air also saves ordinary moments on its own. With enough of both, Insights shows what your flare days have in common."
    static let learnAction = "Start"
}
