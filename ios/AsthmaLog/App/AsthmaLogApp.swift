import SwiftData
import SwiftUI

@main
struct AsthmaLogApp: App {
    @State private var services = LogService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .tint(Theme.accent)
        }
        .modelContainer(for: LogEvent.self)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(LogService.self) private var services
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @State private var isLogging = false
    @State private var logCount = 0

    var body: some View {
        TabView {
            Tab("Journal", systemImage: "book.closed") {
                JournalView()
            }
            Tab("Insights", systemImage: "sparkles") {
                InsightsView()
            }
        }
        // One tap, always reachable: floats above the tab bar. I'm okay moments are added automatically.
        .tabViewBottomAccessory {
            Button {
                isLogging = true
                Task {
                    await services.log(.attack, in: context, writeToHealth: writeToHealth)
                    isLogging = false
                    logCount += 1
                }
            } label: {
                Label(isLogging ? "Logging…" : "Used inhaler", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
            }
            .disabled(isLogging)
            .sensoryFeedback(.success, trigger: logCount)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, autoBaseline else { return }
            Task { await services.sampleUsualDayIfDue(in: context) }
        }
    }
}
