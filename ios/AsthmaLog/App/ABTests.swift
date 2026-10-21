import SwiftUI

/// Every open design question in one list (docs/design/ab-tests.md), grouped by screen: A-numbers are tested with
/// people in a session (the facilitator sets the arms and watches), C-numbers are decided in a design crit.
/// Settings › Demo and development › What we're testing. Nothing here is measured or sent anywhere.
struct ABTest: Identifiable {
    let id: String          // "A1", "C1"
    let question: String    // what we're deciding
    var group: String = "Logging and notes"   // the screen it's about
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

    /// The groups, in the order the page shows them.
    static let groups = ["Colour", "Now", "Insights", "Logging and notes", "Words and type"]

    /// A crit question: decided in review, so there's no "watch" line, just what each option does.
    static func crit(_ id: String, _ group: String, _ question: String, note: String, key: String, arms: [(String, String)], default d: String) -> ABTest {
        var t = string(id, question, watch: note, key: key, arms: arms, default: d)
        t.group = group
        return t
    }

    var isCrit: Bool { id.hasPrefix("C") }

    static let all: [ABTest] = [
        .crit("C1", "Colour", "How should risk be coloured?",
              note: "Risk is how much an hour looks like your flare days: the forecast strip, the verdict pill, the sky's highlight. docs/design/risk-color.md",
              key: Crit.RiskColor.key, arms: Crit.RiskColor.allCases.map { ($0.rawValue, $0.title) }, default: Crit.RiskColor.today.rawValue),
        .crit("C2", "Colour", "Which inks for the air families?",
              note: "Print is three inks, one per family (current). The others are earlier rounds.",
              key: Crit.Inks.key, arms: Crit.Inks.allCases.map { ($0.rawValue, $0.title) }, default: Crit.Inks.print.rawValue),
        .crit("C3", "Now", "Weather on the rail: one stop or three?",
              note: "Three is by what the weather does: cold and dry, heat and humidity, sudden change. docs/design/weather-grouping.md",
              key: Crit.WeatherRail.key, arms: Crit.WeatherRail.allCases.map { ($0.rawValue, $0.title) }, default: Crit.WeatherRail.oneStop.rawValue),
        .crit("C4", "Insights", "How do we say where cold starts for you?",
              note: "Under the Weather card, when your moments show it. Load the data set “Cold, below about 40°F” to see it.",
              key: Crit.PersonalEdgeStyle.key, arms: Crit.PersonalEdgeStyle.allCases.map { ($0.rawValue, $0.title) }, default: Crit.PersonalEdgeStyle.sentence.rawValue),
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
                arms: [("mark", "Sparkle mark (✦✦ / ✦)"), ("words", "Spelled out")], default: "mark").in("Words and type"),
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
                arms: Theme.Typeface.allCases.map { ($0.rawValue, $0.title) }, default: Theme.Typeface.recursive.rawValue).in("Words and type"),
    ]

    func `in`(_ g: String) -> ABTest { var t = self; t.group = g; return t }

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

/// Settings › Demo and development › What we're testing: every open question by screen, the option in force,
/// and either what to watch (with people) or what the options do (crit).
struct ABTestsView: View {
    /// Bumped on every change so the rows re-read their settings.
    @State private var version = 0

    var body: some View {
        Form {
            Section {
                Text(summary).font(.subheadline.monospaced()).textSelection(.enabled)
                Button("All back to the current design") {
                    for t in ABTest.all { t.set(t.defaultArm) }
                    version += 1
                }
            } header: {
                Text("This session")
            } footer: {
                Text("A-numbers are tested with people: set them before a session and copy this line into the notes. C-numbers are design crits we decide in review. Changes take effect at once; nothing is recorded or sent.")
            }
            ForEach(ABTest.groups, id: \.self) { g in
                Section {
                    ForEach(ABTest.all.filter { $0.group == g }) { t in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(t.id).font(.caption.monospaced().weight(.semibold)).foregroundStyle(Theme.secondaryText)
                                Text(t.question).font(.subheadline.weight(.semibold))
                            }
                            Picker(t.question, selection: Binding(get: { _ = version; return t.get() }, set: { t.set($0); version += 1 })) {
                                ForEach(t.arms, id: \.value) { Text($0.label + ($0.value == t.defaultArm ? " (current)" : "")).tag($0.value) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            Text(t.isCrit ? t.watch : "Watch: \(t.watch)").font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(g)
                }
            }
        }
        .navigationTitle("What we’re testing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: String {
        _ = version
        return ABTest.all.map { "\($0.id)=\($0.get())" }.joined(separator: " ")
    }
}
