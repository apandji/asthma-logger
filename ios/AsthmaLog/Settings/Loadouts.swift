import AsthmaCore
import SwiftData
import SwiftUI

/// One tap to a demo: a data set, every design question back to its default plus the few this demo needs, the
/// staged situation, and where to land (an hour on the timeline, Insights, or onboarding). Settings › Demo and
/// development › Loadouts. `-loadout riskAD` (Debug) applies one at launch.
struct Loadout: Identifiable {
    enum Land { case now, insights, onboarding, pair, lastRescue, evening }

    let id: String
    let group: String
    let title: String
    let note: String
    /// Nil keeps whatever is loaded; `mine` goes back to your own data.
    var dataSet: DataSetPreset? = nil
    var mine = false
    /// The navigator on real air (`NavigatorSet`) instead of a made-up preset.
    var navigator = false
    /// Crit and A/B settings on top of the defaults (key → raw value).
    var settings: [String: String] = [:]
    var ring: Crit.InsightsState = .auto
    var scenario: DemoScenario = .off
    /// Tomorrow at this hour, on the timeline.
    var tomorrowAt: Int? = nil
    var land: Land = .now

    /// Read by Now once Settings has closed: "focus=14", "open=insights".
    static let pendingKey = "loadout.pending"
    static let pairKey = "loadout.startAtPair"

    private static func risk(_ c: Crit.RiskColor, _ title: String, _ note: String) -> Loadout {
        Loadout(id: "risk-\(c.rawValue)", group: "Risk colour", title: title, note: note, dataSet: .stillLearning,
                settings: [Crit.RiskColor.key: c.rawValue], ring: .learned, tomorrowAt: 14)
    }

    /// The Nov 20 presentation, in order (docs/demo-runbook.md): one person, the navigator, on real air.
    static let presentation: [Loadout] = [
        Loadout(id: "talk-1", group: "Presentation", title: "1 · Now, then log a moment",
                note: "The navigator, two weeks into St. Louis. Press the watch or the felt button for an inhaler moment (or Stage a moment › Log an inhaler press). The + adds a manual moment and its journal.", navigator: true),
        Loadout(id: "talk-2", group: "Presentation", title: "2 · Look back at a moment",
                note: "Her last rescue that fits her pattern. Tap the picture for the details and where each reading came from.",
                navigator: true, land: .lastRescue),
        Loadout(id: "talk-3", group: "Presentation", title: "3 · Timeline to calendar",
                note: "Lands on Now. Open Moments for Day, Month, Year: three cities in six weeks. Then Map.", navigator: true),
        Loadout(id: "talk-4", group: "Presentation", title: "4 · Insights",
                note: "What her inhaler days share, in every city: fine particles.", navigator: true, land: .insights),
        Loadout(id: "talk-5", group: "Presentation", title: "5 · Evening look-back",
                note: "What felt air recorded today, and the ask for what it couldn't see. Keeps the Journal as it is, so a puff from step 1 is the moment it asks about.",
                land: .evening),
        Loadout(id: "talk-6", group: "Presentation", title: "Fallback · Still learning",
                note: "A week in, made up: the ring filling, when and where so far.", dataSet: .stillLearning, land: .insights),
    ]

    /// Friday's MVP walk-through, in the order of the journey (docs/design/mvp-demo.md).
    static let demoRun: [Loadout] = [
        Loadout(id: "demo-1", group: "Demo run", title: "1 · Pair your inhaler",
                note: "Onboarding at the press-the-cap step. Press the cap on screen: the first press brings in the air.", land: .pair),
        Loadout(id: "demo-2", group: "Demo run", title: "2 · Now, then log a puff",
                note: "Someone a few weeks in, on a hot, high-ozone day: both their patterns are in the air, so the sky is orange. Hold the rail, pull the + for a rescue, then Quick journal.",
                dataSet: .hotHazy, scenario: .heat),
        Loadout(id: "demo-3", group: "Demo run", title: "3 · Look back at a moment",
                note: "Their last rescue: “It was hot and ozone was high”, the orange dots are theirs. Tap the sky for details.",
                dataSet: .hotHazy, land: .lastRescue),
        Loadout(id: "demo-4", group: "Demo run", title: "4 · Still learning",
                note: "A week in: the ring filling, when and where so far.", dataSet: .stillLearning, land: .insights),
        Loadout(id: "demo-5", group: "Demo run", title: "5 · Your archetype",
                note: "Hot, hazy days: the five families, what shows up on their flare days.", dataSet: .hotHazy, land: .insights),
        Loadout(id: "demo-6", group: "Demo run", title: "6 · Cold, for you",
                note: "Someone who flares below about 40°F. Scroll to the Weather card.",
                dataSet: .coldBelow40, settings: [Crit.PersonalEdgeStyle.key: Crit.PersonalEdgeStyle.dots.rawValue], land: .insights),
        Loadout(id: "demo-7", group: "Demo run", title: "7 · Look ahead",
                note: "Tomorrow at 2 PM looks more like their flare days. Drag the timeline to see the hours.",
                dataSet: .stillLearning, ring: .learned, tomorrowAt: 14),
    ]

    static let all: [Loadout] = presentation + demoRun + [
        Loadout(id: "mine", group: "Start", title: "My data, as designed",
                note: "Your own moments, real air, every switch at its default.", mine: true),
        Loadout(id: "onboarding", group: "Start", title: "Onboarding",
                note: "From the first screen. Your moments stay.", land: .onboarding),
        Loadout(id: "pair", group: "Start", title: "Pair your inhaler",
                note: "Onboarding, straight to the press-the-cap step.", land: .pair),

        risk(.today, "Today", "Green, gold, red. Tomorrow at 2 PM, a rough afternoon."),
        risk(.warmInk, "A · One warm ink", "Graphite to bright orange. Tomorrow at 2 PM."),
        risk(.warmTexture, "A + D · Warm ink + texture", "The family behind each hour as a mark shape. Tomorrow at 2 PM."),
        risk(.coverage, "C · Coverage", "No hue: more marks the more it looks like flare days. Tomorrow at 2 PM."),
        risk(.twoPalettes, "E · Two palettes", "Cool family hues, warm status for risk. Tomorrow at 2 PM."),

        Loadout(id: "cold-season", group: "Insights", title: "Cold season",
                note: "The five-family radar with Colds and flu and Weather leading.", dataSet: .coldSeason, land: .insights),
        Loadout(id: "hot-hazy", group: "Insights", title: "Hot, hazy days",
                note: "Weather and Irritants together, on a smoky day.", dataSet: .hotHazy, scenario: .smoke, land: .insights),
        Loadout(id: "cold-for-you", group: "Insights", title: "Cold for you · the dots",
                note: "Flares below about 40°F, shown as the tally. Scroll to the Weather card.",
                dataSet: .coldBelow40, settings: [Crit.PersonalEdgeStyle.key: Crit.PersonalEdgeStyle.dots.rawValue], land: .insights),
        Loadout(id: "cold-for-you-sentence", group: "Insights", title: "Cold for you · the sentence",
                note: "The same person, said with the number.", dataSet: .coldBelow40, land: .insights),
    ]

    static let groups = ["Presentation", "Demo run", "Start", "Risk colour", "Insights"]
    /// The groups behind "Earlier demos and loadouts".
    static let earlier = ["Demo run", "Start", "Risk colour", "Insights"]

    /// Everything back to default, then this loadout. `close` dismisses Settings; Now finishes the landing.
    @MainActor func apply(context: ModelContext) {
        let d = UserDefaults.standard
        for t in ABTest.all { t.set(t.defaultArm) }
        for (k, v) in settings { d.set(v, forKey: k) }
        d.set(ring.rawValue, forKey: Crit.InsightsState.key)
        scenario.choose()
        for k in ["demo.care", "demo.priming", "demo.active"] { d.removeObject(forKey: k) }
        d.set(land == .evening, forKey: EveningLookBack.demoKey)
        // A loadout lands where it says: the evening look-back doesn't come up on its own over it tonight.
        EveningLookBack.markShown(now: .now)
        if mine {
            if let own = DataSets.saved().first(where: { $0.name == DataSets.ownData }) { DataSets.load(own, context: context) }
        } else if navigator {
            DataSets.loadNavigator(context: context)
        } else if let dataSet {   // always fresh: a puff logged in an earlier step must not become "the last rescue"
            DataSets.load(dataSet, context: context)
        }
        var pending: [String] = []
        if let tomorrowAt { pending.append("focus=\(tomorrowAt)") }
        if land == .insights { pending.append("open=insights") }
        if land == .lastRescue { pending.append("focus=last") }
        if land == .evening { pending.append("open=evening") }
        d.set(pending.isEmpty ? "" : pending.joined(separator: ";") + ";\(UUID().uuidString.prefix(6))", forKey: Self.pendingKey)
        if land == .pair { d.set(true, forKey: Self.pairKey) }
    }

    /// Tomorrow at an hour, local time.
    static func tomorrow(at hour: Int) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    /// `-loadout <id>` at launch (Debug).
    @MainActor static func applyLaunchArgument(context: ModelContext) -> Loadout? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-loadout"), i + 1 < args.count,
              let l = all.first(where: { $0.id == args[i + 1] }) else { return nil }
        l.apply(context: context)
        return l
        #else
        return nil
        #endif
    }
}

/// The Loadouts section: one row per loadout, grouped. A tap applies it and closes Settings.
struct LoadoutsSection: View {
    var groups = Loadout.groups
    let close: () -> Void
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.didOnboard) private var didOnboard = true
    @AppStorage("loadout.last") private var last = ""

    var body: some View {
        ForEach(groups, id: \.self) { g in
            Section {
                ForEach(Loadout.all.filter { $0.group == g }) { l in
                    Button {
                        l.apply(context: context)
                        last = l.id
                        close()
                        if l.land == .onboarding || l.land == .pair {
                            // Let the sheet finish closing, or SwiftUI drops the full-screen onboarding.
                            Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.title).foregroundStyle(Color.primary)
                                Text(l.note).font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer(minLength: 8)
                            if last == l.id { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText) }
                        }
                    }
                }
            } header: {
                Text(g == "Start" ? "Loadouts" : g)
            } footer: {
                if g == "Presentation" { Text("Nov 20, in order. Each step loads the navigator fresh and lands you on the right screen. Every design switch goes back to its default first.") }
                if g == "Demo run" { Text("The MVP walk-through, in order. Each step loads its person and lands you on the right screen.") }
                if g == "Start" { Text("One tap sets the data set, the switches and the staged day, then lands you there. Every switch goes back to its default first.") }
            }
        }
    }
}
