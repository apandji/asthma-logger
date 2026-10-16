import AsthmaCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.narratorStyle) private var styleScore = NarratorStyle.defaultScore
    @AppStorage(Prefs.useOnDeviceModel) private var useModel = true
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @AppStorage(Prefs.logButtons) private var useButtons = false
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.useDemoData) private var demo = false
    @Environment(\.modelContext) private var context
    @Environment(ButtonLink.self) private var button
    @AppStorage(Prefs.didOnboard) private var didOnboard = true
    @State private var demoNote: String?
    @AppStorage(LevelStyle.key) private var levelStyle = LevelStyle.signal
    @AppStorage(Crit.Header.key) private var critHeader = Crit.Header.moment
    @AppStorage(Crit.CardStyle.key) private var critCard = Crit.CardStyle.panel
    @AppStorage(Crit.InsightsState.key) private var critInsightsState = Crit.InsightsState.auto
    @AppStorage(Crit.CardMarker.key) private var critMarker = Crit.CardMarker.quietTab
    @AppStorage(Crit.FieldStyle.key) private var critField = Crit.FieldStyle.weather
    @AppStorage(DemoPollen.Season.key) private var demoPollen = DemoPollen.Season.off
    @AppStorage(Crit.LayerStrength.key) private var critStrength = Crit.LayerStrength.smooth
    @AppStorage(Crit.InsightsEntry.key) private var critInsights = Crit.InsightsEntry.ringButton
    @AppStorage(Crit.CaptureOrder.key) private var critOrder = Crit.CaptureOrder.rescueFirst

    var body: some View {
        NavigationStack {
            Form {
                #if DEBUG
                Section {
                    Picker("Header", selection: $critHeader) {
                        ForEach(Crit.Header.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Colour field", selection: $critField) {
                        ForEach(Crit.FieldStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Colour strength", selection: $critStrength) {
                        ForEach(Crit.LayerStrength.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Pollen (demo)", selection: $demoPollen) {
                        ForEach(DemoPollen.Season.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Moment style", selection: $critCard) {
                        ForEach(Crit.CardStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Card label", selection: $critMarker) {
                        ForEach(Crit.CardMarker.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Good / OK / Not good", selection: $levelStyle) {
                        ForEach(LevelStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Insights", selection: $critInsights) {
                        ForEach(Crit.InsightsEntry.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Insights state", selection: $critInsightsState) {
                        ForEach(Crit.InsightsState.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("+ pull order", selection: $critOrder) {
                        ForEach(Crit.CaptureOrder.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Design crit")
                } footer: {
                    Text("Debug builds only. Switch variants live to compare them in a review. Demo pollen is made up (realistic Midwest seasons), labelled Demo, and never used for patterns. \(levelStyle.note)")
                }
                #endif

                Section {
                    Slider(
                        value: Binding(get: { Double(styleScore) }, set: { styleScore = NarratorStyle.clamp($0) }),
                        in: 0...100
                    ) {
                        Text("Voice")
                    } minimumValueLabel: {
                        Text("Clinical").font(Theme.caption)
                    } maximumValueLabel: {
                        Text("Poetic").font(Theme.caption)
                    }
                    LabeledContent("Current", value: NarratorStyle(score: styleScore).label)
                } header: {
                    Text("Insight voice")
                } footer: {
                    Text("How the on-device model words your pattern. The numbers never change. Without Apple Intelligence you get a plain template sentence.")
                }

                Section("On-device model") {
                    Toggle("Use Apple Intelligence", isOn: $useModel)
                    LabeledContent("Status", value: OnDeviceModel.status)
                }

                Section {
                    Toggle("Log with two buttons instead of the +", isOn: $useButtons)
                    Toggle("Save inhaler uses to Apple Health", isOn: $writeToHealth)
                    Toggle("Add I'm okay moments automatically", isOn: $autoBaseline)
                } header: {
                    Text("Logging")
                } footer: {
                    Text("I'm okay moments are what the times you used your inhaler are compared against. For now felt air adds one when you open the app, if there's been none in 20 hours and no inhaler use in the last 2.")
                }

                ButtonSection()

                Section("Data sources") {
                    LabeledContent("Apple Weather", value: "On")
                    LabeledContent("OpenAQ (PM2.5, ozone)", value: Secrets.openAQ == nil ? "No key" : "On")
                    LabeledContent("AirNow (AQI, forecast)", value: Secrets.airNow == nil ? "No key" : "On")
                    LabeledContent("Pollen", value: "Not yet")
                }

                Section {
                    Toggle("Show demo data in Insights", isOn: $demo)
                } footer: {
                    Text("A made-up late-summer diary, so you can see Insights before you have enough logs.")
                }

                Section {
                    Button("Add a demo week to the Journal") { addDemoWeek() }
                    Button("Remove demo moments", role: .destructive) { removeDemo() }
                    Button("Play onboarding demo") {
                        dismiss()
                        // Let the sheet finish closing, or SwiftUI drops the full-screen onboarding.
                        Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                    }
                } header: {
                    Text("Demo moments")
                } footer: {
                    Text(demoNote ?? "Made-up moments for showing the Journal, labelled Demo in their sources. They don't count toward your patterns.")
                }

                #if DEBUG
                Section {
                    Button("Reset onboarding and button", role: .destructive) {
                        button.resetForOnboarding()
                        UserDefaults.standard.set(true, forKey: AppTips.resetKey)
                        dismiss()
                        Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                    }
                } header: {
                    Text("Onboarding (debug)")
                } footer: {
                    Text("Forgets the paired button, starts onboarding again and brings the tips back next launch. Your moments stay. iOS only shows each permission sheet once per install: to see them again, reinstall with ios/scripts/fresh-install.sh (this erases the Journal).")
                }

                Section {
                    NavigationLink("Voice effect") { VoiceOrbPrototype() }
                } header: {
                    Text("Prototypes")
                } footer: {
                    Text("Debug builds only. The voice effect uses simulated sound.")
                }

                Section {
                    prototypeLink("Strand", "The week as a necklace: spikier beads for worse air, flowers for pollen.") { StrandPrototype() }
                    prototypeLink("Bouquet", "Each day's pollen as a bouquet; haze and sway for pollution.") { BouquetPrototype() }
                    prototypeLink("Airways v2 · horizon", "You're the breathing line; the air is the sky above.") { BreathHorizonPrototype() }
                    prototypeLink("Aura", "One day as a clock, you in the middle, air in rings around you.") { AuraPrototype() }
                    prototypeLink("Sampler", "The week as cross-stitch: denser where the air was higher.") { SamplerPrototype() }
                    prototypeLink("Overprint", "Three riso inks as hills through the week.") { OverprintPrototype() }
                    prototypeLink("Airways v1 · tubes", "April's first sketch: one tube per day.") { AirwaysPrototype() }
                } header: {
                    Text("Air visualizations")
                } footer: {
                    Text("Debug builds only. PM2.5 and ozone are from your moments; PM10, NO₂, pollen and breathing scores are examples.")
                }
                #endif

                Section {
                    Text("felt air is a diary, not a medical device. It compares outdoor conditions when you used your inhaler with your I'm okay moments. It can't see indoor air and doesn't diagnose or predict attacks.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .tint(.green) // switches keep the system green; the app's neutral tint would make them white-on-white
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    #if DEBUG
    private func prototypeLink<D: View>(_ title: String, _ note: String, @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(note).font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }
    #endif

    private func addDemoWeek() {
        let n = DemoSeeder.add(in: context)
        demoNote = "Added \(n) demo moments."
    }

    private func removeDemo() {
        let n = DemoSeeder.remove(in: context)
        demoNote = n == 0 ? nil : "Removed \(n) demo moments."
    }
}

private struct SettingsToolbar: ViewModifier {
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { isShowing = true }
                }
            }
            .sheet(isPresented: $isShowing) { SettingsView() }
    }
}

extension View {
    func settingsToolbar() -> some View { modifier(SettingsToolbar()) }
}

/// Adds or removes the labelled demo week (Settings → Demo moments, or launch with `-demoWeek` in Debug).
enum DemoSeeder {
    @discardableResult
    static func add(in context: ModelContext) -> Int {
        remove(in: context)
        let week = DemoWeek.moments(endingAt: .now)
        for m in week {
            let e = LogEvent(moment: m.kind, loggedAt: m.at)
            e.conditions = m.conditions
            e.envStatus = .ready
            e.isDemoMoment = true
            context.insert(e)
        }
        try? context.save()
        return week.count
    }

    @discardableResult
    static func remove(in context: ModelContext) -> Int {
        // Filtered in memory: a diary holds hundreds of moments, and this also catches legacy demo moments.
        let demo = ((try? context.fetch(FetchDescriptor<LogEvent>())) ?? []).filter(\.isDemo)
        demo.forEach(context.delete)
        try? context.save()
        return demo.count
    }
}
