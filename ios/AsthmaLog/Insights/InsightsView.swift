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
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // The same top-left header as the home: a small line, then one serif title.
                    ScaleHeader(title: learned ? "felt air knows your pattern." : "Still learning your pattern.") {
                        Image(systemName: "sparkles")
                        Text(["Insights", demo ? "Demo data" : nil, demoLearned ? "Demo person" : nil].compactMap { $0 }.joined(separator: " · "))
                    }
                    .padding(.horizontal, -20)
                    LearningRing(progress: model.progress, forcedLearned: forced == .learned)
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
                .padding(.horizontal, 20)
                .padding(.top, 12).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            // The home's paper: black or linen, with the same still riso grain.
            .background { ZStack { Theme.paper(paper); SkyGrain(responds: false).opacity(0.5) }.ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.colorScheme, paper == .linen ? .light : .dark)
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
        InsightSection(title: "Your pattern", systemImage: "sparkles") {
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
        InsightSection(title: "Looking ahead", systemImage: "calendar") {
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
        InsightSection(title: "Your profile", systemImage: "person.crop.circle") {
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
        InsightSection(title: "Your moments", systemImage: "calendar") {
            MonthCalendar(month: $month, events: Array(events), selected: $day)
            Button { showDoctor = true } label: {
                Label("Table for your doctor", systemImage: "tablecells")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDoctor) { DoctorSheet(events: Array(events)) }
        }
    }

    /// Design crit › Insights state › learned, while the real gate isn't met: a labelled demo person.
    private var demoLearned: Bool { forced == .learned && !(model.progress?.isMet ?? false) }

    private var evidenceCard: some View {
        InsightSection(title: "Evidence", systemImage: "tablecells") {
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

    /// Before the sample gate: no sentence to read yet. The ring above already shows the counts.
    @ViewBuilder private func learning(_ p: GateProgress) -> some View {
        Text("Your pattern appears here once there are \(p.minAttacks) rescue and \(p.minBaselines) baseline moments to compare.")
            .font(Theme.headlineSerif)
        Text("Baseline moments are added on their own when you open the app. Outdoor air only, not a diagnosis.")
            .font(Theme.caption).foregroundStyle(Theme.secondaryText)
    }

    private var learned: Bool { forced == .learned || (model.progress?.isMet ?? false) }

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

/// A section in the home's language: a small line with its symbol, the content, a hairline under it.
/// No boxes: Insights is printed on the same paper as the home.
struct InsightSection<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
            content
            Rectangle().fill(Theme.secondaryText.opacity(0.2)).frame(height: 0.5).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Learning, as a ring of riso dots with the sparkle in the middle, like the home's particles. Dots
/// fill around the ring in the inhaler inks by the smaller of the two counts it's waiting for, and the
/// two counts sit under it, so you know exactly what it needs.
struct LearningRing: View {
    let progress: GateProgress?
    var forcedLearned = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let a = progress.map { min(1, Double($0.attacks) / Double(max(1, $0.minAttacks))) } ?? 0
        let b = progress.map { min(1, Double($0.baselines) / Double(max(1, $0.minBaselines))) } ?? 0
        let fill = forcedLearned ? 1 : min(a, b)
        let done = fill >= 1
        VStack(spacing: 16) {
            ZStack {
                Canvas { ctx, size in
                    let n = 72
                    let c = CGPoint(x: size.width / 2, y: size.height / 2), radius = size.width / 2 - 6
                    for i in 0..<n {
                        let t = Double(i) / Double(n)
                        let ang = t * 2 * .pi - .pi / 2
                        let p = CGPoint(x: c.x + radius * cos(ang), y: c.y + radius * sin(ang))
                        let on = t < fill
                        let r: CGFloat = on ? 3.4 : 1.6
                        // Rescue orange into standard blue as it fills; the rest is faint grain.
                        let ink = on ? Theme.rescue.mix(with: Theme.standard, by: t) : Theme.secondaryText.opacity(0.35)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(ink))
                    }
                }
                Image(systemName: done ? "sparkles" : "sparkle").font(.system(size: 30, weight: .semibold))
                    .symbolEffect(.pulse, isActive: done && !reduceMotion)
            }
            .frame(width: 140, height: 140)
            if let p = progress, !done {
                HStack(spacing: 32) {
                    count("Rescue moments", p.attacks, p.minAttacks, Theme.rescue)
                    count("Baseline moments", p.baselines, p.minBaselines, Theme.standard)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(done ? "Learned" : "Learning, \(Int(fill * 100)) percent")
    }

    private func count(_ label: String, _ n: Int, _ goal: Int, _ ink: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(min(n, goal)) of \(goal)").font(.system(.title3, design: .serif, weight: .medium)).monospacedDigit()
            HStack(spacing: 5) {
                Circle().fill(ink).frame(width: 6, height: 6)
                Text(label)
            }
            .font(Theme.caption).foregroundStyle(Theme.secondaryText)
        }
    }
}
