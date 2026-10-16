import AsthmaCore
import SwiftData
import SwiftUI

/// Patterns (what showed up more on inhaler days) and the look-ahead (days that resemble them).
struct InsightsView: View {
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @AppStorage(Prefs.narratorStyle) private var styleScore = NarratorStyle.defaultScore
    @AppStorage(Prefs.useOnDeviceModel) private var useModel = true
    @AppStorage(Prefs.useDemoData) private var demo = false
    @State private var model = InsightsModel()
    @AppStorage(Crit.InsightsState.key) private var forced = Crit.InsightsState.auto
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var day: Date?
    @State private var showDoctor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    if demo {
                        Chip(text: "Demo data — turn off in Settings", color: Theme.ink2)
                    }
                    LearningRing(progress: model.progress, forcedLearned: forced == .learned)
                    if demoLearned { Chip(text: "Demo person: learned", color: Theme.secondaryText) }
                    patternCard
                    profileCard
                    lookAheadCard
                    calendarCard
                    evidenceCard
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compares your flare days (rescue use) with your baseline. Outdoor air only. Not medical advice, and not a prediction.")
                        WeatherAttributionView()
                    }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.padding)
            }
            .background(Theme.background)
            .navigationTitle("Insights")
            .settingsToolbar()
            .task(id: dataKey) {
                model.rebuild(events: events, demo: demo)
                await model.narrate(styleScore: styleScore, useModel: useModel)
            }
            .task(id: forecastKey) {
                await loadForecast()
            }
            .refreshable {
                model.rebuild(events: events, demo: demo)
                await model.narrate(styleScore: styleScore, useModel: useModel)
                await loadForecast()
            }
        }
    }

    // MARK: Cards

    private var patternCard: some View {
        Card(title: "Your pattern", systemImage: "sparkles") {
            if demoLearned {
                Chip(text: "Demo", color: Theme.secondaryText)
                Text("Weed pollen showed up on 9 of 14 flare days vs 6 of 40 baseline days.").font(Theme.headlineSerif)
                Text("A made-up person, for the presentation. Not your data.").font(Theme.caption).foregroundStyle(Theme.secondaryText)
            } else if let p = model.progress, !p.isMet {
                learning(p)
            } else if let n = model.narration {
                Text(n.headline).font(Theme.headlineSerif)
                Text(n.caveat).font(Theme.caption).foregroundStyle(Theme.secondaryText)
                HStack {
                    Chip(text: n.source == .onDevice ? "Apple Intelligence · \(NarratorStyle(score: styleScore).label)" : "Template",
                         color: n.source == .onDevice ? Theme.accent : Theme.secondaryText)
                    Spacer()
                }
                if let note = n.note {
                    Text(note).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
            } else {
                ProgressView()
            }
        }
    }

    private var lookAheadCard: some View {
        Card(title: "Looking ahead", systemImage: "calendar") {
            if let p = model.progress, !p.isMet {
                Text("Until felt air knows your pattern, this only shows general outdoor alerts.")
                    .font(Theme.caption).foregroundStyle(Theme.secondaryText)
            }
            if model.isLoadingForecast && model.days.isEmpty {
                ProgressView()
            }
            ForEach(model.days) { day in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(day.day.formatted(.dateTime.weekday(.abbreviated).month().day()))
                            .font(Theme.body.weight(.semibold))
                        Spacer()
                        if day.isPersonal {
                            Chip(text: day.band.rawValue.capitalized, color: color(day.band))
                        } else if !day.genericHazards.isEmpty {
                            Chip(text: "Heads-up", color: Theme.accent)
                        }
                    }
                    ForEach(day.windows) { w in
                        Text(OutlookCopy.headline(w, timeRange: timeRange(w))).font(Theme.caption)
                        ForEach(OutlookCopy.evidence(w), id: \.self) {
                            Text($0).font(.caption2).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    if let line = OutlookCopy.coldStart(day.genericHazards) {
                        Text(line).font(Theme.caption)
                    }
                    if day.leadHours > 30 {
                        Text("Further out — less certain.").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.vertical, 4)
            }
            if let note = model.forecastNote {
                Text(note).font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// Who you are with the air. Named archetypes wait for the research (docs/mvp-brief-2026-10.md).
    private var profileCard: some View {
        Card(title: "Your profile", systemImage: "person.crop.circle") {
            if demoLearned {
                Chip(text: "Demo", color: Theme.secondaryText)
                Text("Pollen-led").font(Theme.headlineSerif)
                Text("Your flare days line up with pollen more than anything else, weed pollen most of all. A placeholder until the research names the profiles.")
                    .font(Theme.caption).foregroundStyle(Theme.secondaryText)
            } else if let p = model.progress, !p.isMet {
                Text("Once felt air has learned, this says which air your flare days line up with: pollen, particles, ozone, or cold and humid days.")
                    .font(Theme.caption).foregroundStyle(Theme.secondaryText)
            } else if let n = model.narration {
                Text(n.headline).font(Theme.headline)
                Text("Named profiles come next, from the research.").font(Theme.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// The month, moved here from the home: your moments as swatches, and the table for your doctor.
    private var calendarCard: some View {
        Card(title: "Your moments", systemImage: "calendar") {
            MonthCalendar(month: $month, events: Array(events), selected: $day)
            Button { showDoctor = true } label: {
                Label("Table for your doctor", systemImage: "tablecells").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).buttonBorderShape(.capsule)
            .sheet(isPresented: $showDoctor) { DoctorSheet(events: Array(events)) }
        }
    }

    /// Design crit › Insights state › learned, while the real gate isn't met: a labelled demo person.
    private var demoLearned: Bool { forced == .learned && !(model.progress?.isMet ?? false) }

    private var evidenceCard: some View {
        Card(title: "Evidence", systemImage: "tablecells") {
            let c = model.frameCount
            Text("\(c.attacks) rescue moments · \(c.baselines) baseline moments" + (c.skipped > 0 ? " · \(c.skipped) without conditions" : ""))
                .font(Theme.caption).foregroundStyle(Theme.secondaryText)
            if let rows = model.report?.rows.prefix(8), !rows.isEmpty {
                ForEach(Array(rows)) { r in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text("\(Bins.label(r.bin)) · \(r.level)")
                            Text("\(r.attacksWith) of \(r.nAttacks) inhaler · \(r.baselinesWith) of \(r.nBaselines) usual")
                                .font(Theme.caption).foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Lift.format(r.lift))×").font(Theme.number)
                            Text(r.gated ? "Pattern" : "Not enough yet")
                                .font(.caption2)
                                .foregroundStyle(r.gated ? Theme.accent : Theme.secondaryText)
                        }
                    }
                }
            } else {
                Text("Log each time you use your inhaler. felt air adds baseline moments on its own.").font(Theme.caption)
            }
        }
    }

    /// Before the sample gate: no sentence to read yet, just honest progress.
    @ViewBuilder private func learning(_ p: GateProgress) -> some View {
        Text("Still learning your pattern").font(Theme.headline)
        progressRow("Rescue moments", p.attacks, p.minAttacks)
        progressRow("Baseline moments", p.baselines, p.minBaselines)
        Text("Baseline moments are added on their own when you open the app. Outdoor air only, not a diagnosis.")
            .font(Theme.caption).foregroundStyle(Theme.secondaryText)
    }

    private func progressRow(_ label: String, _ n: Int, _ goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(min(n, goal)) of \(goal)").font(Theme.number).foregroundStyle(Theme.secondaryText)
            }
            .font(Theme.caption)
            ProgressView(value: Double(min(n, goal)), total: Double(goal)).tint(Theme.accent)
        }
    }

    // MARK: Helpers

    private var dataKey: String {
        let ready = events.filter { $0.conditionsData != nil }.count
        return "\(events.count)-\(ready)-\(demo)-\(styleScore)-\(useModel)"
    }

    private var forecastKey: String { "\(demo)-\(events.last?.id.uuidString ?? "none")" }

    /// Home place isn't learned yet, so the look-ahead uses the most recent logged spot.
    private func loadForecast() async {
        if let e = events.last(where: { $0.latitude != nil }), let lat = e.latitude, let lon = e.longitude {
            await model.loadForecast(latitude: lat, longitude: lon, placeLabel: "your last logged spot")
        } else if let fix = try? await services.location.currentLocation() {
            await model.loadForecast(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                     placeLabel: "where you are now")
        }
    }

    private func timeRange(_ w: RiskWindow) -> String {
        "\(w.start.formatted(date: .omitted, time: .shortened))–\(w.end.formatted(date: .omitted, time: .shortened))"
    }

    private func color(_ band: RiskBand) -> Color {
        switch band {
        case .elevated: Theme.elevated
        case .usual: Theme.usual
        case .quiet: Theme.quiet
        }
    }
}

/// Learning, as an Apple Watch-style ring with the sparkle in the middle. It fills by the smaller of
/// the two counts it's waiting for, and says both, so you know exactly what it needs.
struct LearningRing: View {
    let progress: GateProgress?
    var forcedLearned = false

    var body: some View {
        let a = progress.map { min(1, Double($0.attacks) / Double(max(1, $0.minAttacks))) } ?? 0
        let b = progress.map { min(1, Double($0.baselines) / Double(max(1, $0.minBaselines))) } ?? 0
        let fill = forcedLearned ? 1 : min(a, b)
        let done = fill >= 1
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.secondaryText.opacity(0.18), lineWidth: 14)
                Circle().trim(from: 0, to: fill)
                    .stroke(AngularGradient(colors: [Theme.standard, Theme.accent, Theme.rescue, Theme.standard], center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 1.2), value: fill)
                Image(systemName: done ? "sparkles" : "sparkle").font(.system(size: 34, weight: .semibold))
                    .symbolEffect(.pulse, isActive: done)
            }
            .frame(width: 132, height: 132)
            Text(done ? "felt air knows your pattern" : "Learning your pattern").font(Theme.headline)
            if let p = progress, !done {
                HStack(spacing: 24) {
                    count("Rescue moments", p.attacks, p.minAttacks)
                    count("Baseline moments", p.baselines, p.minBaselines)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func count(_ label: String, _ n: Int, _ goal: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(min(n, goal)) of \(goal)").font(Theme.number)
            Text(label).font(Theme.caption).foregroundStyle(Theme.secondaryText)
        }
    }
}
