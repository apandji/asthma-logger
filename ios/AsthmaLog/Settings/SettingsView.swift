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
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @AppStorage(Prefs.sounds) private var sounds = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                    Toggle("Sounds", isOn: $sounds)
                        .onChange(of: sounds) { _, on in if on { Sounds.play(.log) } }
                } header: {
                    Text("Logging")
                } footer: {
                    Text("After a press, the Lock Screen asks what was going on, so you can say it without unlocking. The morning look-ahead is a notification at 8 with the day's air. Sounds: a quiet tick when a moment is logged, silent with the ringer off.")
                }

                Section {
                    NavigationLink("Devices") { DevicesView() }
                } footer: {
                    Text("Your inhalers, felt buttons and Apple Watch.")
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
                    Text("What your inhaler moments are compared against. felt air fills them in a day later, a few hours across each day, with that hour's air. With “Use where you've been” they're placed where you actually were. Otherwise, at home. Places stay on this iPhone.")
                }

                Section {
                    Picker("Rail", selection: $railLeft) {
                        Text("Right").tag(false)
                        Text("Left").tag(true)
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("Put the rail on the side of the hand you hold your phone with.")
                }

                Section("Data sources") {
                    LabeledContent("Apple Weather", value: "On")
                    LabeledContent("OpenAQ (PM2.5, ozone)", value: Secrets.openAQ == nil ? "No key" : "On")
                    LabeledContent("AirNow (AQI, forecast)", value: Secrets.airNow == nil ? "No key" : "On")
                    LabeledContent("Ambee (pollen)", value: Secrets.ambee == nil ? "Not yet" : "On")
                }

                Section {
                    Text("felt air is a diary, not a medical device. It compares outdoor conditions when you used your inhaler with your baseline moments. It can't see indoor air, doesn't diagnose, and never says a flare will happen.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                // Everything for demos, design reviews and testing: one row, at the very bottom.
                Section {
                    NavigationLink("Demo and development") { DeveloperSettings(close: { dismiss() }) }
                } footer: {
                    Text("Data sets, demo moments, design switches and prototypes. Not part of felt air.")
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
    @AppStorage(Prefs.logButtons) private var useButtons = false
    @AppStorage(Prefs.useDemoData) private var demo = false
    @AppStorage(Prefs.statementTypeface) private var statementTypeface = Theme.Typeface.recursive.rawValue
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

    var body: some View {
        Form {
            Section {
                LabeledContent("Showing", value: activeDataSet ?? "Your own data")
                NavigationLink("Load a data set") { DataSetsView() }
                Button("Save current as…") { naming = true }
                Button("Fresh start", role: .destructive) { confirmFresh = true }
            } header: {
                Text("Data sets")
            } footer: {
                Text("Your own profile, saved, or a made-up person for a demo (Still learning, Allergen-led, Hot hazy days…). Loading replaces the Journal; your own data is kept as “My data” first. Fresh start erases everything and opens onboarding; iOS keeps granted permissions until the app is deleted (ios/scripts/fresh-install.sh).")
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
                    close()
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        DataSets.freshStart(context: context, button: button)
                    }
                }
            } message: {
                Text("Moments, voice notes, settings and the paired button are erased. Your own data is saved as “My data” first, and saved data sets stay.")
            }

            Section {
                Button("Add a demo week to the Journal") { demoNote = "Added \(DemoSeeder.add(in: context)) demo moments." }
                Button("Remove demo moments", role: .destructive) {
                    let n = DemoSeeder.remove(in: context)
                    demoNote = n == 0 ? nil : "Removed \(n) demo moments."
                }
                Toggle("Show demo data in Insights", isOn: $demo)
                Button("Play onboarding") {
                    close()
                    // Let the sheet finish closing, or SwiftUI drops the full-screen onboarding.
                    Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                }
            } header: {
                Text("Demo moments")
            } footer: {
                Text(demoNote ?? "Made-up moments for showing the Journal. They don't count toward your patterns.")
            }

            #if DEBUG
            Section {
                Toggle("Performance readout", isOn: $perfHUD)
                Button("Replay tutorial") {
                    UserDefaults.standard.set(true, forKey: AppTips.resetKey)
                    tutorialNote = "Close felt air (swipe it away) and open it again to see the tutorial."
                }
                if let tutorialNote { Text(tutorialNote).font(.footnote).foregroundStyle(Theme.secondaryText) }
                Picker("Pollen (demo)", selection: $demoPollen) {
                    ForEach(DemoPollen.Season.allCases) { Text($0.title).tag($0) }
                }
                Picker("Air event (demo)", selection: $critEvent) {
                    ForEach(Crit.DemoEvent.allCases) { Text($0.title).tag($0) }
                }
                Picker("Insights state", selection: $critInsightsState) {
                    ForEach(Crit.InsightsState.allCases) { Text($0.title).tag($0) }
                }
                Picker("Statement type", selection: $statementTypeface) {
                    ForEach(Theme.Typeface.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Log with two buttons instead of the +", isOn: $useButtons)
            } header: {
                Text("Design crit")
            } footer: {
                Text("Switch variants live to compare them in a review. Demo pollen is made up and never used for patterns.")
            }

            Section {
                Button("Reset onboarding and button", role: .destructive) {
                    button.resetForOnboarding()
                    UserDefaults.standard.set(true, forKey: AppTips.resetKey)
                    close()
                    Task { try? await Task.sleep(for: .milliseconds(450)); didOnboard = false }
                }
            } header: {
                Text("Onboarding")
            } footer: {
                Text("Forgets the paired button, starts onboarding again and brings the tips back. Your moments stay.")
            }

            Section {
                NavigationLink("Voice effect") { VoiceOrbPrototype() }
                prototypeLink("Strand", "The week as a necklace: spikier beads for worse air, flowers for pollen.") { StrandPrototype() }
                prototypeLink("Bouquet", "Each day's pollen as a bouquet; haze and sway for pollution.") { BouquetPrototype() }
                prototypeLink("Airways v2 · horizon", "You're the breathing line; the air is the sky above.") { BreathHorizonPrototype() }
                prototypeLink("Aura", "One day as a clock, you in the middle, air in rings around you.") { AuraPrototype() }
                prototypeLink("Sampler", "The week as cross-stitch: denser where the air was higher.") { SamplerPrototype() }
                prototypeLink("Overprint", "Three riso inks as hills through the week.") { OverprintPrototype() }
                prototypeLink("Airways v1 · tubes", "April's first sketch: one tube per day.") { AirwaysPrototype() }
            } header: {
                Text("Prototypes")
            } footer: {
                Text("Debug builds only.")
            }
            #endif
        }
        .tint(Theme.standard)
        .navigationTitle("Demo and development")
        .navigationBarTitleDisplayMode(.inline)
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
