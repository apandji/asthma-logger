import AsthmaCore
import SwiftData
import SwiftUI

@main
struct AsthmaLogApp: App {
    @State private var services: LogService
    private let container: ModelContainer
    private let watch = WatchBridge()
    @State private var button = ButtonLink()

    init() {
        AppTips.configure()
        ABTest.applyLaunchArguments()
        do { container = try ModelContainer(for: LogEvent.self, InhalerUse.self, VoiceNote.self) }
        catch { fatalError("Couldn't open the journal store: \(error)") }
        let services = LogService()
        _services = State(initialValue: services)
        // Here, not in .task: a Lock Screen button can wake the app in the background with no scene.
        let container = container
        // Moments gain inhaler uses and voice notes (docs/data-model.md): a one-time, additive upgrade.
        ModelUpgrade.run(container.mainContext)
        AmbeeSampleFill.run(container.mainContext)
        QuickRecordCenter.shared.container = container
        // iOS relaunches the app in the background to deliver a visit: the log has to be listening from launch.
        VisitLog.shared.start()
        QuickRecordLive.shared.install(container: container) { id in
            let health = UserDefaults.standard.object(forKey: Prefs.writeToHealth) as? Bool ?? true
            Task { _ = await services.log(.rescue, id: id, in: container.mainContext, writeToHealth: health) }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(button)
                .tint(Theme.tint)
                .task {
                    // The speech model for voice notes, fetched ahead so the first note is transcribed well.
                    Task.detached(priority: .utility) { await LiveTranscriber.prepare() }
                    let context = container.mainContext
                    #if DEBUG
                    // For demos and recordings: `-demoWeek` loads the labelled demo week, `-skipOnboarding` skips first run.
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("-demoWeek") { DemoSeeder.add(in: context) }
                    if args.contains("-skipOnboarding") { UserDefaults.standard.set(true, forKey: Prefs.didOnboard) }
                    if args.contains("-showOnboarding") { UserDefaults.standard.set(false, forKey: Prefs.didOnboard) }
                    // `-dataSet hotHazy` (any DataSetPreset) loads a made-up person; `-freshStart` erases everything.
                    if let i = args.firstIndex(of: "-dataSet"), i + 1 < args.count {
                        if let p = DataSetPreset(rawValue: args[i + 1]) { DataSets.load(p, context: context) }
                        // `-dataSet mine`: your own data back ("My data").
                        else if args[i + 1] == "mine", let mine = DataSets.saved().first(where: { $0.name == DataSets.ownData }) {
                            DataSets.load(mine, context: context)
                        }
                    }
                    if args.contains("-backfillNow") { await BaselineFiller.shared.runIfDue(in: context, force: true) }
                    if args.contains("-exportNow") {
                        // Copies both export files to Documents/Exports, to read off the simulator.
                        let events = (try? context.fetch(FetchDescriptor<LogEvent>())) ?? []
                        let dir = URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory)
                        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                        for f in EngineExport.files(events: events) {
                            let to = dir.appending(path: f.lastPathComponent)
                            try? FileManager.default.removeItem(at: to)
                            try? FileManager.default.copyItem(at: f, to: to)
                        }
                    }
                    if args.contains("-freshStart") { DataSets.freshStart(context: context, button: button) }
                    #endif
                    QuickRecordCenter.shared.start(container: container)
                    watch.start { log in
                        Task { await services.logFromWatch(log, in: context) }
                    }
                    button.start { packet, received, deviceID in
                        Task { await services.logFromButton(packet, receivedAt: received, deviceID: deviceID, in: context) }
                    }
                    #if DEBUG
                    // `-pressTwice`: two orange-cap presses 5 s apart (one use, two puffs).
                    if ProcessInfo.processInfo.arguments.contains("-pressTwice") {
                        Task {
                            try? await Task.sleep(for: .seconds(3)); button.simulatePress(.rescue)
                            try? await Task.sleep(for: .seconds(5)); button.simulatePress(.rescue)
                        }
                    }
                    #endif
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
            // The only time iOS lets felt air start its Lock Screen card.
            if phase == .active, didOnboard { QuickRecordLive.shared.standby() }
            guard phase == .active, autoBaseline, didOnboard else { return }
            // Baseline moments are filled in across past days (not sampled at app open, which leaned toward
            // home and toward when the phone was in hand).
            Task { await BaselineFiller.shared.runIfDue(in: context) }
        }
    }
}
