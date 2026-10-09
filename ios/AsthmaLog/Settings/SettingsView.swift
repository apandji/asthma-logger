import AsthmaCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.narratorStyle) private var styleScore = NarratorStyle.defaultScore
    @AppStorage(Prefs.useOnDeviceModel) private var useModel = true
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.useDemoData) private var demo = false
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.didOnboard) private var didOnboard = true
    @State private var demoNote: String?

    var body: some View {
        NavigationStack {
            Form {
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
                    Toggle("Save inhaler uses to Apple Health", isOn: $writeToHealth)
                    Toggle("Add I'm okay moments automatically", isOn: $autoBaseline)
                } header: {
                    Text("Logging")
                } footer: {
                    Text("I'm okay moments are what the times you used your inhaler are compared against. For now felt air adds one when you open the app, if there's been none in 20 hours and no inhaler use in the last 2.")
                }

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
                    NavigationLink("Voice effect (prototype)") { VoiceOrbPrototype() }
                } header: {
                    Text("Prototypes")
                } footer: {
                    Text("Debug builds only. Simulated sound; doesn't use the microphone.")
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
