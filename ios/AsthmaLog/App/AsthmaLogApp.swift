import SwiftData
import SwiftUI

@main
struct AsthmaLogApp: App {
    @State private var services = LogService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .preferredColorScheme(.dark)
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

    var body: some View {
        TabView {
            Tab("Journal", systemImage: "book.closed") {
                JournalView()
            }
            Tab("Insights", systemImage: "sparkles") {
                InsightsView()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, autoBaseline else { return }
            Task { await services.sampleUsualDayIfDue(in: context) }
        }
    }
}
