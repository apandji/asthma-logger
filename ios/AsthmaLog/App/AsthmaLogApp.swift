import AsthmaCore
import SwiftData
import SwiftUI

@main
struct AsthmaLogApp: App {
    @State private var services = LogService()
    private let container: ModelContainer
    private let watch = WatchBridge()

    init() {
        do { container = try ModelContainer(for: LogEvent.self) }
        catch { fatalError("Couldn't open the journal store: \(error)") }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .tint(Theme.tint)
                .task {
                    let context = container.mainContext
                    #if DEBUG
                    // For demos and recordings: `-demoWeek` loads the labelled demo week, `-skipOnboarding` skips first run.
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("-demoWeek") { DemoSeeder.add(in: context) }
                    if args.contains("-skipOnboarding") { UserDefaults.standard.set(true, forKey: Prefs.didOnboard) }
                    if args.contains("-showOnboarding") { UserDefaults.standard.set(false, forKey: Prefs.didOnboard) }
                    #endif
                    await services.resumePending(in: context)
                    watch.start { log in
                        Task { await services.logFromWatch(log, in: context) }
                    }
                }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(LogService.self) private var services
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.writeToHealth) private var writeToHealth = true
    @AppStorage(Prefs.didOnboard) private var didOnboard = false
    @State private var logging: MomentKind?
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
        // One tap, always reachable: floats above the tab bar. Same two actions as the watch.
        // I'm okay moments are added automatically.
        .tabViewBottomAccessory {
            HStack(spacing: 0) {
                logButton(.rescue, "Rescue", Theme.rescue)
                Divider().frame(height: 22)
                logButton(.maintenance, "Standard", Theme.standard)
            }
            .disabled(logging != nil)
            .sensoryFeedback(.success, trigger: logCount)
        }
        .fullScreenCover(isPresented: Binding(get: { !didOnboard }, set: { _ in })) {
            OnboardingView()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, autoBaseline, didOnboard else { return }
            Task { await services.sampleUsualDayIfDue(in: context) }
        }
    }

    private func logButton(_ moment: MomentKind, _ title: String, _ color: Color) -> some View {
        Button {
            logging = moment
            Task {
                await services.log(moment, in: context, writeToHealth: writeToHealth)
                logging = nil
                logCount += 1
            }
        } label: {
            Label(logging == moment ? "Logging…" : title, systemImage: "plus")
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
        }
    }
}
