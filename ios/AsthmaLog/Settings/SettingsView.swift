import AsthmaCore
import SwiftData
import SwiftUI

/// Settings: what the real app has, top to bottom; demo, design and test tools behind one row at the bottom.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @AppStorage(Prefs.quickRecord) private var quickRecord = true
    @AppStorage(Prefs.lockScreenReady) private var lockScreenReady = true
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.morningBrief) private var morningBrief = true
    @AppStorage(Prefs.appearance) private var appearance = "system"
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @AppStorage(Prefs.sounds) private var sounds = true

    var body: some View {
        NavigationStack {
            Form {
                // Demos, design reviews and testing, first for now (owner, Oct 23: MVP demos). Move back to the bottom
                // before TestFlight.
                Section {
                    NavigationLink("Demo and development") { DeveloperSettings(close: { dismiss() }) }
                } footer: {
                    Text("The presentation steps, whose data is showing, and things to stage. Not part of felt air.")
                }

                Section {
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
                    Toggle("Sounds", isOn: $sounds)
                        .onChange(of: sounds) { _, on in if on { Sounds.play(.log) } }
                } header: {
                    Text("Logging")
                } footer: {
                    Text("The Lock Screen asks right after a press, so you can answer without unlocking. The morning look-ahead is a notification at 8 with the day's air.")
                }

                Section {
                    NavigationLink("Devices") { DevicesView() }
                    Toggle("Save inhaler uses to Apple Health", isOn: $writeToHealth)
                } header: {
                    Text("Inhalers and Health")
                } footer: {
                    Text("Your inhalers, the felt button on each cap, Apple Watch, and whether each use goes into Health.")
                }

                Section {
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
                    Text("Baseline moments")
                } footer: {
                    Text("Ordinary hours, filled in a day later with that hour's air, for your inhaler moments to be compared against. “Use where you've been” places them where you were. Otherwise, at home. Places stay on this iPhone.")
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("Match iPhone").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Picker("Rail", selection: $railLeft) {
                        Text("Right").tag(false)
                        Text("Left").tag(true)
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Light prints the sky on warm paper, dark on black. The rail goes on the side of the hand you hold the phone with.")
                }

                Section {
                    NavigationLink("Where your data comes from") { SourcesView() }
                } header: {
                    Text("About")
                } footer: {
                    Text("felt air is a diary, not a medical device. It compares the outdoor air when you used your inhaler with your baseline moments. It can't see indoor air, doesn't diagnose, and never says a flare will happen.")
                }

            }
            .tint(Theme.standard) // switches in the app's own blue (the neutral tint would be white-on-white)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Demo and development: data sets, demo moments, design crit switches, type, onboarding reset, prototypes.
/// Data sets and demo moments are in every build (for demos on TestFlight); the rest is Debug only.
struct DeveloperSettings: View {
    /// Closes the Settings sheet (this page is pushed inside it, so its own `dismiss` would only pop).
    /// Onboarding is a full-screen cover under the sheet: it can't show until the sheet is gone.
    let close: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(ButtonLink.self) private var button
    @Environment(LogService.self) private var services
    @AppStorage(Prefs.useDemoData) private var demo = false
    @AppStorage(DataSets.activeKey) private var activeDataSet: String?
    @AppStorage(Prefs.didOnboard) private var didOnboard = true
    @State private var naming = false
    @State private var setName = "Andrew"
    @State private var confirmFresh = false
    @State private var demoNote: String?
    @State private var tutorialNote: String?
    @AppStorage(Crit.performanceHUD) private var perfHUD = false
    @AppStorage(Crit.InsightsState.key) private var critInsightsState = Crit.InsightsState.auto
    @AppStorage(Crit.DemoEvent.key) private var critEvent = Crit.DemoEvent.none
    @AppStorage(DemoPollen.Season.key) private var demoPollen = DemoPollen.Season.off
    @AppStorage(DemoScenario.key) private var demoScenario = DemoScenario.off
    @AppStorage(Crit.Inks.key) private var critInks = Crit.Inks.print
    @AppStorage(Crit.TimelineLook.key) private var critTimeline = Crit.TimelineLook.track
    @AppStorage(Crit.AppLook.key) private var critAppLook = Crit.AppLook.fallback
    @AppStorage(Crit.MenusSky.key) private var critMenusSky = Crit.MenusSky.combined
    @AppStorage(DemoCalendar.key) private var demoCalendar = false
    @AppStorage("demo.care") private var demoCare = ""
    @AppStorage("demo.priming") private var demoPriming = false
    @AppStorage("demo.active") private var demoActive = false
    @AppStorage(EveningLookBack.demoKey) private var demoEvening = false

    var body: some View {
        Form {
            // 1 · The presentation, one tap per step.
            LoadoutsSection(groups: ["Presentation"], close: close)

            // 2 · Who is on the phone.
            Section {
                LabeledContent("Showing", value: activeDataSet ?? "Your own data")
                NavigationLink("Load a data set") { DataSetsView() }
                Button("Save current as…") { naming = true }
            } header: {
                Text("Whose data")
            } footer: {
                Text("The navigator on real air, a made-up person, or a Journal saved on this phone. Loading replaces the Journal; your own data is kept as “My data” first.")
            }
            .alert("Save the Journal as", isPresented: $naming) {
                TextField("Name", text: $setName)
                Button("Save") { DataSets.save(as: setName.trimmingCharacters(in: .whitespaces).isEmpty ? "Saved" : setName, context: context) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Kept on this phone, not shared anywhere.")
            }

            // 3 · Things to stage on cue.
            Section {
                Button("Log an inhaler press") {
                    close()
                    Task { _ = await services.press(.rescue, device: .button, in: context) }
                }
                Toggle("Evening look-back at any hour", isOn: $demoEvening)
                Picker("Air on Now", selection: $demoScenario) {
                    ForEach(DemoScenario.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: demoScenario) { _, s in s.choose() }
                Picker("Rescue-use check", selection: $demoCare) {
                    Text("Off (real moments)").tag("")
                    Text("Again within 4 hours").tag("again")
                    Text("More than 2 days this week").tag("week")
                }
                Toggle("Presses look like test sprays", isOn: $demoPriming)
                Toggle("New moments count as active", isOn: $demoActive)
                Toggle("Demo calendar", isOn: $demoCalendar)
            } header: {
                Text("Stage a moment")
            } footer: {
                Text("Log an inhaler press stands in for the felt button or the watch: the + only makes manual moments. Evening look-back opens when you close Settings, and each time felt air comes to the front, until you turn it off. Air on Now stages a day (smoke, a storm, a cold snap, a pollen day); its readings never count toward patterns. Demo calendar stands in for your own events.")
            }

            // 4 · Everything else, one level down.
            Section {
                NavigationLink("Earlier demos and loadouts") {
                    Form { LoadoutsSection(groups: Loadout.earlier, close: close) }
                        .navigationTitle("Earlier demos").navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Design switches") { designSwitches }
                NavigationLink("Demo week and tools") { tools }
            } header: {
                Text("More")
            }

            Section {
                Button("Fresh start", role: .destructive) { confirmFresh = true }
            } footer: {
                Text("Erases everything and opens onboarding. Your own data is saved as “My data” first. iOS keeps granted permissions until the app is deleted (ios/scripts/fresh-install.sh).")
            }
            .confirmationDialog("Erase everything and start onboarding?", isPresented: $confirmFresh, titleVisibility: .visible) {
                Button("Fresh start", role: .destructive) {
                    close()
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        DataSets.freshStart(context: context, button: button)
                    }
                }
            } message: {
                Text("Moments, voice notes, settings and the paired button are erased. Your own data is saved as “My data” first, and saved data sets stay.")
            }
        }
        .tint(Theme.standard)
        .navigationTitle("Demo and development")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Open design questions and the looks kept for comparison.
    private var designSwitches: some View {
        Form {
            Section {
                NavigationLink("What we’re testing") { ABTestsView() }
            } footer: {
                Text("Each open design question, by screen: what it asks, the options, and which one is on.")
            }
            Section {
                Picker("App look", selection: $critAppLook) {
                    ForEach(Crit.AppLook.allCases) { Text($0.title).tag($0) }
                }
                Picker("Home picture", selection: $critMenusSky) {
                    ForEach(Crit.MenusSky.allCases) { Text($0.title).tag($0) }
                }
                Picker("Timeline", selection: $critTimeline) {
                    ForEach(Crit.TimelineLook.allCases) { Text($0.title).tag($0) }
                }
                Picker("Inks", selection: $critInks) {
                    ForEach(Crit.Inks.allCases) { Text($0.title).tag($0) }
                }
                Picker("Insights state", selection: $critInsightsState) {
                    ForEach(Crit.InsightsState.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Looks")
            } footer: {
                Text("The default look is felt air with the flowers. The others are kept for comparison. Insights state forces learning or learned.")
            }
        }
        .tint(Theme.standard)
        .navigationTitle("Design switches")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The labelled demo week, onboarding replays and test tools.
    private var tools: some View {
        Form {
            Section {
                Button("Add a demo week to the Journal") { demoNote = "Added \(DemoSeeder.add(in: context)) demo moments." }
                Button("Remove demo moments", role: .destructive) {
                    let n = DemoSeeder.remove(in: context)
                    demoNote = n == 0 ? nil : "Removed \(n) demo moments."
                }
                Toggle("Show demo data in Insights", isOn: $demo)
            } header: {
                Text("Demo week")
            } footer: {
                Text(demoNote ?? "Made up for showing felt air, never used for patterns.")
            }
            Section {
                Button("Play onboarding") {
                    close()
                    // Let the sheet finish closing, or SwiftUI drops the full-screen onboarding.
                    Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                }
                Button("Replay tutorial") {
                    UserDefaults.standard.set(true, forKey: AppTips.resetKey)
                    tutorialNote = "Close felt air (swipe it away) and open it again to see the tutorial."
                }
                if let tutorialNote { Text(tutorialNote).font(.footnote).foregroundStyle(Theme.secondaryText) }
                Button("Reset onboarding and button", role: .destructive) {
                    button.resetForOnboarding()
                    UserDefaults.standard.set(true, forKey: AppTips.resetKey)
                    close()
                    Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                }
            } header: {
                Text("Onboarding")
            } footer: {
                Text("Reset forgets the paired button and brings the tips back; your moments stay.")
            }
            #if DEBUG
            Section {
                NavigationLink("Exertion check") { ExertionCheckView() }
                Toggle("Performance readout", isOn: $perfHUD)
                NavigationLink("Prototypes") { PrototypesView() }
            } header: {
                Text("Tools")
            } footer: {
                Text("Exertion check shows what Health and Motion return. Prototypes are early sketches, not the app. Debug builds only.")
            }
            #endif
        }
        .tint(Theme.standard)
        .navigationTitle("Demo week and tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
/// Settings › Demo and development › Tools › Prototypes: early sketches kept for reference.
struct PrototypesView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink("Voice effect") { VoiceOrbPrototype() }
                link("Strand", "The week as a necklace: spikier beads for worse air, flowers for pollen.") { StrandPrototype() }
                link("Bouquet", "Each day's pollen as a bouquet; haze and sway for pollution.") { BouquetPrototype() }
                link("Airways v2 · horizon", "You're the breathing line; the air is the sky above.") { BreathHorizonPrototype() }
                link("Aura", "One day as a clock, you in the middle, air in rings around you.") { AuraPrototype() }
                link("Sampler", "The week as cross-stitch: denser where the air was higher.") { SamplerPrototype() }
                link("Overprint", "Three riso inks as hills through the week.") { OverprintPrototype() }
                link("Airways v1 · tubes", "April's first sketch: one tube per day.") { AirwaysPrototype() }
            } footer: {
                Text("Early sketches, not the app.")
            }
        }
        .navigationTitle("Prototypes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func link<D: View>(_ title: String, _ note: String, @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(note).font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
#endif

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
