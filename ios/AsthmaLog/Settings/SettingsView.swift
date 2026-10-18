import AsthmaCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.narratorStyle) private var styleScore = NarratorStyle.defaultScore
    @AppStorage(Prefs.useOnDeviceModel) private var useModel = true
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @AppStorage(Prefs.quickRecord) private var quickRecord = true
    @AppStorage(Prefs.lockScreenReady) private var lockScreenReady = true
    @AppStorage(Prefs.logButtons) private var useButtons = false
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.morningBrief) private var morningBrief = true
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @AppStorage(Prefs.useDemoData) private var demo = false
    @AppStorage(Prefs.statementTypeface) private var statementTypeface = Theme.Typeface.recursive.rawValue
    @Environment(\.modelContext) private var context
    @Environment(ButtonLink.self) private var button
    @AppStorage(DataSets.activeKey) private var activeDataSet: String?
    @State private var naming = false
    @State private var setName = "Andrew"
    @State private var confirmFresh = false
    @AppStorage(Prefs.didOnboard) private var didOnboard = true
    @State private var demoNote: String?
    @State private var tutorialNote: String?
    @AppStorage(Crit.performanceHUD) private var perfHUD = false
    @AppStorage(Crit.InsightsState.key) private var critInsightsState = Crit.InsightsState.auto
    @AppStorage(Crit.DemoEvent.key) private var critEvent = Crit.DemoEvent.none
    @AppStorage(DemoPollen.Season.key) private var demoPollen = DemoPollen.Season.off

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Statement", selection: $statementTypeface) {
                        ForEach(Theme.Typeface.allCases) { face in
                            Text(face.title).tag(face.rawValue)
                        }
                    }
                    Text("Ozone was high on 8 of the 14 times you used your inhaler.")
                        .font(Theme.Typeface.sentence(size: 22, voice: NarratorStyle(score: styleScore)))
                        .kerning(Theme.serifKerning)
                } header: {
                    Text("Type")
                } footer: {
                    Text("Only the big statement changes. Everything else stays SF. System uses New York for the sentence.")
                }

                #if DEBUG
                Section {
                    NavigationLink { DevicesView() } label: {
                        Label { Text("Devices") } icon: { Image(systemName: "button.programmable") }
                    }
                } footer: {
                    Text("Your felt buttons and Apple Watch.")
                }

                Section {
                    Toggle("Performance readout", isOn: $perfHUD)
                    Button("Replay tutorial") {
                        UserDefaults.standard.set(true, forKey: AppTips.resetKey)
                        tutorialNote = "Close felt air (swipe it away) and open it again to see the tutorial."
                    }
                    if let tutorialNote {
                        Text(tutorialNote).font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                    Picker("Pollen (demo)", selection: $demoPollen) {
                        ForEach(DemoPollen.Season.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Air event (demo)", selection: $critEvent) {
                        ForEach(Crit.DemoEvent.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Insights state", selection: $critInsightsState) {
                        ForEach(Crit.InsightsState.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Design crit")
                } footer: {
                    Text("Debug builds only. Switch variants live to compare them in a review. Demo pollen is made up (realistic Midwest seasons), labelled Demo, and never used for patterns.")
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
                    // Sample wording; Recursive casual axes follow this slider when Type is Recursive.
                    Text("Ozone was high on 8 of the 14 times you used your inhaler.")
                        .font(Theme.Typeface.sentence(size: 22, voice: NarratorStyle(score: styleScore)))
                        .kerning(Theme.serifKerning)
                } header: {
                    Text("Insight voice")
                } footer: {
                    Text("How the on-device model words your pattern. With Recursive as the statement type, this also softens the letters a little toward poetic. The numbers never change. Without Apple Intelligence you get a plain template sentence.")
                }

                Section("On-device model") {
                    Toggle("Use Apple Intelligence", isOn: $useModel)
                    LabeledContent("Status", value: OnDeviceModel.status)
                }

                Section {
                    Picker("Rail", selection: $railLeft) {
                        Text("Right").tag(false)
                        Text("Left").tag(true)
                    }
                    Toggle("Log with two buttons instead of the +", isOn: $useButtons)
                    Toggle("Save inhaler uses to Apple Health", isOn: $writeToHealth)
                    Toggle("After a press, ask what was going on", isOn: $quickRecord)
                        .onChange(of: quickRecord) { _, on in
                            if on { Task { _ = await QuickRecordCenter.shared.requestPermission() } }
                            QuickRecordLive.shared.standby()
                        }
                    if quickRecord {
                        Toggle("Keep felt air on the Lock Screen", isOn: $lockScreenReady)
                            .onChange(of: lockScreenReady) { _, _ in QuickRecordLive.shared.standby() }
                    }
                    Toggle("Morning look-ahead", isOn: $morningBrief)
                        .onChange(of: morningBrief) { _, on in if !on { MorningBrief.cancel() } }
                    Toggle("Fill in baseline moments", isOn: $autoBaseline)
                    if autoBaseline {
                        Button {
                            VisitLog.shared.requestAlways()
                        } label: {
                            LabeledContent("Use where you've been", value: VisitLog.shared.isAlways ? "On" : "Allow…")
                        }
                        .disabled(VisitLog.shared.isAlways)
                    }
                } header: {
                    Text("Logging")
                } footer: {
                    Text("On the Lock Screen, a press on your felt button lights up felt air so you can say what's going on, and its mic logs a rescue and listens, all without unlocking. The morning look-ahead is a notification at 8 with the day's air; opening it also keeps the Lock Screen card ready. Baseline moments are what your inhaler moments are compared against: felt air fills them in a day later, a few hours across each day, with that hour's air from history. With “Use where you've been” (Always location) they're placed where you actually were; otherwise at home. Places stay on this iPhone.")
                }


                Section("Data sources") {
                    LabeledContent("Apple Weather", value: "On")
                    LabeledContent("OpenAQ (PM2.5, ozone)", value: Secrets.openAQ == nil ? "No key" : "On")
                    LabeledContent("AirNow (AQI, forecast)", value: Secrets.airNow == nil ? "No key" : "On")
                    LabeledContent("Ambee (pollen, air, history)", value: Secrets.ambee == nil ? "Demo data" : "On")
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
                    LabeledContent("Showing", value: activeDataSet ?? "Your own data")
                    NavigationLink("Load a data set") { DataSetsView() }
                    Button("Save current as…") { naming = true }
                    Button("Fresh start", role: .destructive) { confirmFresh = true }
                } header: {
                    Text("Data sets (debug)")
                } footer: {
                    Text("Load your saved usage or a made-up person (Still learning, Allergen-led, Hot hazy days…). Loading replaces the Journal; your own data is kept as “My data” first. Fresh start erases everything and opens onboarding. iOS keeps permissions you've granted until the app is deleted: to see those prompts again, reinstall with ios/scripts/fresh-install.sh.")
                }
                .alert("Save the Journal as", isPresented: $naming) {
                    TextField("Name", text: $setName)
                    Button("Save") { DataSets.save(as: setName.trimmingCharacters(in: .whitespaces).isEmpty ? "Saved" : setName, context: context) }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Kept on this phone, not shared anywhere.")
                }
                .confirmationDialog("Erase everything and start onboarding?", isPresented: $confirmFresh, titleVisibility: .visible) {
                    Button("Fresh start", role: .destructive) {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            DataSets.freshStart(context: context, button: button)
                        }
                    }
                } message: {
                    Text("Moments, voice notes, settings and the paired button are erased. Your own data is saved as “My data” first, and saved data sets stay.")
                }

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
                    Text("felt air is a diary, not a medical device. It compares outdoor conditions when you used your inhaler with your baseline moments. It can't see indoor air, doesn't diagnose, and never says a flare will happen.")
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
            let place = DemoRoute.place(at: m.at)
            (e.latitude, e.longitude) = DemoRoute.coordinate(for: place, at: m.at)
            e.horizontalAccuracy = 15
            e.placeName = place.name
            e.indoorGuessRaw = (place.outdoor ? IndoorOutdoor.outdoor : .indoor).rawValue
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
