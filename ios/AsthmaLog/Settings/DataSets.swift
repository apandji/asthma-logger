import AsthmaCore
import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// Whole Journals you can swap in, for demos and reviews (Settings › Data sets, Debug builds):
/// - **Saved on this phone:** your real usage (or any state) kept as a file in Documents/DataSets. Never in the
///   repo: it's personal, and the repo is public.
/// - **Made-up people:** `DataSetPreset`, computed through the real pipeline (an archetype is never forced).
/// Loading replaces the Journal; your own data is saved as "My data" first, so it can always come back.
@MainActor
enum DataSets {
    static let activeKey = "activeDataSet"
    static let ownData = "My data"

    static let folder: URL = {
        let url = URL.documentsDirectory.appending(path: "DataSets", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// The Journal now showing: nil is your own data.
    static var active: String? {
        get { UserDefaults.standard.string(forKey: activeKey) }
        set { UserDefaults.standard.set(newValue, forKey: activeKey) }
    }

    struct Saved: Codable {
        var name: String
        var savedAt: Date
        var moments: [Moment]
        var profileHistory: Data?
    }

    /// A moment as stored in a data set file: every field of `LogEvent` that carries meaning.
    struct Moment: Codable {
        var id: UUID
        var kindRaw: String
        var loggedAt: Date
        var latitude: Double?
        var longitude: Double?
        var horizontalAccuracy: Double?
        var envStatusRaw: String
        var envError: String?
        var conditionsData: Data?
        var indoorGuessRaw: String?
        var indoorConfirmedRaw: String?
        var tagsRaw: [String]
        var note: String?
        var isDemoMoment: Bool
        var isFirstCapture: Bool
        var voiceTranscript: String?
        var tagsReviewed: Bool
        var voiceNoteFile: String?
        var placeName: String?
        var isBackfilled: Bool?
        var exerted: Bool?
        var exertedBy: String?
        var uses: [Use]?
        var notes: [Note]?

        struct Use: Codable { var at: Date; var lastPressAt: Date; var puffs: Int; var kind: String; var inhalerName: String?; var device: String; var deviceID: String?; var healthSampleID: UUID? }
        struct Note: Codable { var recordedAt: Date; var audioFile: String?; var transcript: String; var source: String }

        init(_ e: LogEvent) {
            id = e.id; kindRaw = e.kindRaw; loggedAt = e.loggedAt; latitude = e.latitude; longitude = e.longitude
            horizontalAccuracy = e.horizontalAccuracy; envStatusRaw = e.envStatusRaw; envError = e.envError
            conditionsData = e.conditionsData; indoorGuessRaw = e.indoorGuessRaw; indoorConfirmedRaw = e.indoorConfirmedRaw
            tagsRaw = e.tagsRaw; note = e.note; isDemoMoment = e.isDemoMoment; isFirstCapture = e.isFirstCapture
            voiceTranscript = e.voiceTranscript; tagsReviewed = e.tagsReviewed; voiceNoteFile = e.voiceNoteFile; placeName = e.placeName
            isBackfilled = e.isBackfilled; exerted = e.exerted; exertedBy = e.exertedByRaw
            uses = e.uses.map { Use(at: $0.at, lastPressAt: $0.lastPressAt, puffs: $0.puffs, kind: $0.kindRaw, inhalerName: $0.inhalerName,
                                    device: $0.deviceRaw, deviceID: $0.deviceID, healthSampleID: $0.healthSampleID) }
            notes = e.notes.map { Note(recordedAt: $0.recordedAt, audioFile: $0.audioFile, transcript: $0.transcript, source: $0.sourceRaw) }
        }

        var event: LogEvent {
            let e = LogEvent(moment: MomentKind(rawValue: kindRaw) ?? .rescue, loggedAt: loggedAt, id: id)
            e.latitude = latitude; e.longitude = longitude; e.horizontalAccuracy = horizontalAccuracy
            e.envStatusRaw = envStatusRaw; e.envError = envError; e.conditionsData = conditionsData
            e.indoorGuessRaw = indoorGuessRaw; e.indoorConfirmedRaw = indoorConfirmedRaw; e.tagsRaw = tagsRaw
            e.note = note; e.isDemoMoment = isDemoMoment; e.isFirstCapture = isFirstCapture
            e.voiceTranscript = voiceTranscript; e.tagsReviewed = tagsReviewed; e.voiceNoteFile = voiceNoteFile; e.placeName = placeName
            e.isBackfilled = isBackfilled ?? false; e.exerted = exerted; e.exertedByRaw = exertedBy
            for u in uses ?? [] {
                let kind = Inhaler.Kind(rawValue: u.kind) ?? .rescue
                let use = InhalerUse(at: u.at, kind: kind, inhaler: Inhaler.current(kind), device: InhalerUse.Device(rawValue: u.device) ?? .unknown,
                                     deviceID: u.deviceID, puffs: u.puffs)
                use.lastPressAt = u.lastPressAt
                use.healthSampleID = u.healthSampleID
                e.uses.append(use)
            }
            for n in notes ?? [] {
                e.notes.append(VoiceNote(recordedAt: n.recordedAt, audioFile: n.audioFile, transcript: n.transcript, source: n.source))
            }
            return e
        }
    }

    // MARK: Saved sets

    static func url(_ name: String) -> URL { folder.appending(path: "\(name).json") }

    static func saved() -> [Saved] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Saved.self, from: Data(contentsOf: $0)) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// Saves the Journal as it is now under `name` (replacing a set with that name).
    static func save(as name: String, context: ModelContext) {
        let events = (try? context.fetch(FetchDescriptor<LogEvent>(sortBy: [SortDescriptor(\.loggedAt)]))) ?? []
        let set = Saved(name: name, savedAt: .now, moments: events.map(Moment.init),
                        profileHistory: UserDefaults.standard.data(forKey: "profileHistory"))
        if let data = try? JSONEncoder().encode(set) { try? data.write(to: url(name), options: .atomic) }
    }

    static func delete(_ name: String) { try? FileManager.default.removeItem(at: url(name)) }

    // MARK: Loading

    /// Before anything replaces your own data, it's kept as "My data".
    private static func keepOwnData(_ context: ModelContext) {
        guard active == nil, ((try? context.fetchCount(FetchDescriptor<LogEvent>())) ?? 0) > 0 else { return }
        save(as: ownData, context: context)
    }

    static func load(_ set: Saved, context: ModelContext) {
        keepOwnData(context)
        wipeMoments(context)
        set.moments.forEach { context.insert($0.event) }
        try? context.save()
        // Older saved sets have no uses or notes: give them theirs.
        ModelUpgrade.run(context, force: true)
        UserDefaults.standard.set(set.profileHistory, forKey: "profileHistory")
        active = set.name == ownData ? nil : set.name
        BaselineFiller.reset()
    }

    static func load(_ preset: DataSetPreset, context: ModelContext) {
        keepOwnData(context)
        wipeMoments(context)
        for m in preset.moments(endingAt: .now) {
            let e = LogEvent(moment: m.kind, loggedAt: m.at)
            e.conditions = m.conditions
            e.envStatus = .ready
            e.tags = m.tags
            e.tagsReviewed = m.tagsReviewed
            e.infection = m.infection
            let place = DemoRoute.place(at: m.at)
            (e.latitude, e.longitude) = DemoRoute.coordinate(for: place, at: m.at)
            e.horizontalAccuracy = 15
            e.placeName = place.name
            e.indoorGuessRaw = (place.outdoor ? IndoorOutdoor.outdoor : .indoor).rawValue
            context.insert(e)
        }
        try? context.save()
        ModelUpgrade.run(context, force: true)
        UserDefaults.standard.removeObject(forKey: "profileHistory")
        active = preset.title
    }

    private static func wipeMoments(_ context: ModelContext) {
        try? context.delete(model: LogEvent.self)
        try? context.save()
    }

    // MARK: Fresh start

    /// Erases the Journal, voice notes, settings, pairing, tips and profile history, and starts onboarding.
    /// Saved data sets stay (they're files). iOS keeps granted permissions until the app is deleted: for those,
    /// ios/scripts/fresh-install.sh.
    static func freshStart(context: ModelContext, button: ButtonLink) {
        keepOwnData(context)
        wipeMoments(context)
        if let files = try? FileManager.default.contentsOfDirectory(at: VoiceNotes.folder, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        button.resetForOnboarding()
        QuickRecordLive.shared.endAll()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        if let bundle = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundle) }
        UserDefaults.standard.set(true, forKey: AppTips.resetKey)
        // Last: flipping this shows onboarding.
        UserDefaults.standard.set(false, forKey: Prefs.didOnboard)
    }
}

/// Settings › Data sets › Load a data set.
struct DataSetsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var saved = DataSets.saved()
    @State private var confirmSaved: DataSets.Saved?
    @State private var confirmPreset: DataSetPreset?

    var body: some View {
        List {
            Section {
                if saved.isEmpty {
                    Text("Nothing saved yet. Use “Save current as…” to keep your own usage.").foregroundStyle(Theme.secondaryText)
                }
                ForEach(saved, id: \.name) { s in
                    Button { confirmSaved = s } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.body.weight(.medium))
                            Text("\(s.moments.count) moments · saved \(s.savedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions { Button("Delete", role: .destructive) { DataSets.delete(s.name); saved = DataSets.saved() } }
                }
            } header: {
                Text("Saved on this phone")
            }
            Section {
                ForEach(DataSetPreset.allCases) { p in
                    Button { confirmPreset = p } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title).font(.body.weight(.medium))
                            Text(p == .stillLearning ? "4 rescue, 9 baseline moments" : "14 rescue, 40 baseline moments over six weeks")
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Made-up people")
            } footer: {
                Text("Each one goes through the same pattern maths as real data. Loading replaces the Journal; your own data is saved as “My data” first.")
            }
        }
        .navigationTitle("Load a data set")
        .confirmationDialog("Replace the Journal with “\(confirmSaved?.name ?? "")”?", isPresented: Binding(get: { confirmSaved != nil }, set: { if !$0 { confirmSaved = nil } }), titleVisibility: .visible) {
            Button("Load") { if let s = confirmSaved { DataSets.load(s, context: context); dismiss() } }
        }
        .confirmationDialog("Replace the Journal with “\(confirmPreset?.title ?? "")”?", isPresented: Binding(get: { confirmPreset != nil }, set: { if !$0 { confirmPreset = nil } }), titleVisibility: .visible) {
            Button("Load") { if let p = confirmPreset { DataSets.load(p, context: context); dismiss() } }
        }
    }
}
