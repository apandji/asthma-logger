import AsthmaCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.narratorStyle) private var styleScore = NarratorStyle.defaultScore
    @AppStorage(Prefs.useOnDeviceModel) private var useModel = true
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.useDemoData) private var demo = false

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
                    Toggle("Save puffs to Apple Health", isOn: $writeToHealth)
                    Toggle("Log a usual moment on app open", isOn: $autoBaseline)
                } header: {
                    Text("Logging")
                } footer: {
                    Text("Usual moments are what your inhaler logs are compared against. When on, opening the app logs one if there's been none in 20 hours and no puff in the last 2.")
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
                    Text("Asthma Log is a diary, not a medical device. It compares outdoor conditions on your inhaler days with your usual days. It can't see indoor air and doesn't diagnose or predict attacks.")
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
