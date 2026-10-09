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
                    Button("Show onboarding again") { dismiss(); didOnboard = false }
                } header: {
                    Text("Demo moments")
                } footer: {
                    Text(demoNote ?? "Made-up moments for showing the Journal, labelled Demo in their sources. They don't count toward your patterns.")
                }

                Section {
                    Text("felt air is a diary, not a medical device. It compares outdoor conditions when you used your inhaler with your I'm okay moments. It can't see indoor air and doesn't diagnose or predict attacks.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addDemoWeek() {
        removeDemo()
        let week = DemoWeek.moments(endingAt: .now)
        for m in week {
            let e = LogEvent(moment: m.kind, loggedAt: m.at)
            e.conditions = m.conditions
            e.envStatus = .ready
            e.note = LogEvent.demoNote
            context.insert(e)
        }
        try? context.save()
        demoNote = "Added \(week.count) demo moments."
    }

    private func removeDemo() {
        let tag = LogEvent.demoNote
        let demo = (try? context.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.note == tag }))) ?? []
        demo.forEach(context.delete)
        try? context.save()
        demoNote = demo.isEmpty ? nil : "Removed \(demo.count) demo moments."
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
