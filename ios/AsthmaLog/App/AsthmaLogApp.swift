import AsthmaCore
import SwiftData
import SwiftUI

@main
struct AsthmaLogApp: App {
    @State private var services = LogService()
    private let container: ModelContainer
    private let watch = WatchBridge()
    @State private var button = ButtonLink()

    init() {
        AppTips.configure()
        do { container = try ModelContainer(for: LogEvent.self) }
        catch { fatalError("Couldn't open the journal store: \(error)") }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(button)
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
                    QuickRecordCenter.shared.start(container: container)
                    watch.start { log in
                        Task { await services.logFromWatch(log, in: context) }
                    }
                    button.start { packet, received in
                        Task { await services.logFromButton(packet, receivedAt: received, in: context) }
                    }
                    await services.resumePending(in: context)
                    await services.backfillLookBack(in: context)
                }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.verticalSizeClass) private var verticalSize
    @Environment(LogService.self) private var services
    @AppStorage(Prefs.autoBaseline) private var autoBaseline = true
    @AppStorage(Prefs.didOnboard) private var didOnboard = false
    @AppStorage(Prefs.statementTypeface) private var statementTypeface = Theme.Typeface.recursive.rawValue
    @AppStorage(Crit.performanceHUD) private var perfHUD = false

    var body: some View {
        Group {
            if verticalSize == .compact {
                // Sideways: the Data view. Turn back upright for the Journal.
                LandscapeDataView()
            } else {
                NowHomeView()
            }
        }
        #if DEBUG
        .overlay(alignment: .top) {
            // Tap it to reset the dropped-frame count.
            if perfHUD { PerformanceHUD().padding(.top, 2) }
        }
        #endif
        .fullScreenCover(isPresented: Binding(get: { !didOnboard }, set: { _ in })) {
            OnboardingView()
        }
        // Observe Settings › Type so the big statement refreshes without remounting (sheets stay open).
        .animation(nil, value: statementTypeface)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, autoBaseline, didOnboard else { return }
            Task { await services.sampleUsualDayIfDue(in: context) }
        }
    }
}
