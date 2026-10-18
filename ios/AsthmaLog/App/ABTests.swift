import SwiftUI

/// The open design decisions we want to settle with people rather than in a crit (docs/design/ab-tests.md).
/// Each test is one setting with two or three arms; a facilitator sets the arms before a session on
/// Settings › Demo and development › A/B tests, and the arms in force are shown there for the notes.
/// Nothing here is measured or sent anywhere: the measure is what the facilitator watches and asks.
struct ABTest: Identifiable {
    let id: String          // "A1"
    let question: String    // what we're deciding
    let watch: String       // what to observe in the session
    let arms: [(value: String, label: String)]
    let defaultArm: String
    let get: () -> String
    let set: (String) -> Void

    /// A string-valued setting (the crit enums' raw values).
    static func string(_ id: String, _ question: String, watch: String, key: String, arms: [(String, String)], default d: String) -> ABTest {
        ABTest(id: id, question: question, watch: watch, arms: arms.map { (value: $0.0, label: $0.1) }, defaultArm: d,
               get: { UserDefaults.standard.string(forKey: key) ?? d },
               set: { UserDefaults.standard.set($0, forKey: key) })
    }

    /// An on/off setting.
    static func bool(_ id: String, _ question: String, watch: String, key: String, on: String, off: String, default d: Bool) -> ABTest {
        ABTest(id: id, question: question, watch: watch, arms: [(value: "on", label: on), (value: "off", label: off)],
               defaultArm: d ? "on" : "off",
               get: { (UserDefaults.standard.object(forKey: key) as? Bool ?? d) ? "on" : "off" },
               set: { UserDefaults.standard.set($0 == "on", forKey: key) })
    }

    static let all: [ABTest] = [
        .string("A1", "Is a note a conversation or a journal entry?",
                watch: "Time to a saved note; how many of the four domains get answered; whether they talk or tap; whether it feels like talking to someone (ask).",
                key: Crit.CaptureStyle.key,
                arms: Crit.CaptureStyle.allCases.map { ($0.rawValue, $0.title) }, default: Crit.CaptureStyle.chat.rawValue),
        .string("A2", "Should heard tags be ticked for you, or only suggested?",
                watch: "How often a ticked tag gets unticked (wrong) vs a suggestion left unconfirmed (missed); trust (ask).",
                key: Crit.AutoSelect.key,
                arms: Crit.AutoSelect.allCases.map { ($0.rawValue, $0.title) }, default: Crit.AutoSelect.ticked.rawValue),
        .string("A3", "Should the first question rotate, or always be the same?",
                watch: "Whether people answer the opener or skip to what they wanted to say; repeat-note fatigue over a week.",
                key: "crit.opener",
                arms: [("rotate", "Rotates (doing / breathing / around)"), ("fixed", "Always \"What were you doing?\"")], default: "rotate"),
        .string("A4", "Is the sparkle understood without words?",
                watch: "Ask what ✦ means without the tip; whether \"shows up often on your flare days\" reads as cause.",
                key: "crit.patternMark",
                arms: [("mark", "Sparkle mark (✦✦ / ✦)"), ("words", "Spelled out")], default: "mark"),
        ABTest(id: "A5", question: "How should a puff be logged on the phone?",
               watch: "Time to log; wrong-kind logs; first-try success without the tip; one-handed mid-flare (role-play).",
               arms: [(value: "pull", label: "Pull the + (glass well)"), (value: "menu", label: "System menu on the +"),
                      (value: "buttons", label: "Two labelled buttons")],
               defaultArm: "pull",
               get: {
                   if UserDefaults.standard.bool(forKey: Prefs.logButtons) { return "buttons" }
                   return UserDefaults.standard.string(forKey: Crit.LogStyle.key) ?? "pull"
               },
               set: { v in
                   UserDefaults.standard.set(v == "buttons", forKey: Prefs.logButtons)
                   if v != "buttons" { UserDefaults.standard.set(v, forKey: Crit.LogStyle.key) }
               }),
        .string("A6", "In the pull, which is nearest the thumb?",
                watch: "Wrong-kind logs; whether people who use a daily inhaler more often expect it first.",
                key: Crit.CaptureOrder.key,
                arms: Crit.CaptureOrder.allCases.map { ($0.rawValue, $0.title) }, default: Crit.CaptureOrder.rescueFirst.rawValue),
        .bool("A7", "Do the sounds help, or get in the way?",
              watch: "Whether people notice the log tick; whether it bothers them in public (ask).",
              key: Prefs.sounds, on: "On", off: "Off", default: true),
        .string("A8", "Which face for the sentence?",
                watch: "Read the sentence aloud; which feels like felt air talking (ask); legibility at a glance.",
                key: Prefs.statementTypeface,
                arms: Theme.Typeface.allCases.map { ($0.rawValue, $0.title) }, default: Theme.Typeface.recursive.rawValue),
    ]

    /// `-ab "A1=journal,A2=suggested"` (Debug): set arms from the launch, for recordings and quick setup.
    static func applyLaunchArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-ab"), i + 1 < args.count else { return }
        for pair in args[i + 1].split(separator: ",") {
            let kv = pair.split(separator: "=").map(String.init)
            guard kv.count == 2, let t = all.first(where: { $0.id == kv[0] }), t.arms.contains(where: { $0.value == kv[1] }) else { continue }
            t.set(kv[1])
        }
        #endif
    }
}

/// Settings › Demo and development › A/B tests: each open decision, the arm in force, and what to watch.
struct ABTestsView: View {
    /// Bumped on every change so the rows re-read their settings.
    @State private var version = 0

    var body: some View {
        Form {
            Section {
                Text(summary).font(.subheadline.monospaced()).textSelection(.enabled)
                Button("All to defaults") {
                    for t in ABTest.all { t.set(t.defaultArm) }
                    version += 1
                }
            } header: {
                Text("This session")
            } footer: {
                Text("Copy this line into the session notes. Changes take effect at once; nothing is recorded or sent.")
            }
            ForEach(ABTest.all) { t in
                Section {
                    Picker(t.id, selection: Binding(get: { _ = version; return t.get() }, set: { t.set($0); version += 1 })) {
                        ForEach(t.arms, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("\(t.id) · \(t.question)")
                } footer: {
                    Text("Watch: \(t.watch)")
                }
            }
        }
        .navigationTitle("A/B tests")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: String {
        _ = version
        return ABTest.all.map { "\($0.id)=\($0.get())" }.joined(separator: " ")
    }
}
