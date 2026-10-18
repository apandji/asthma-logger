import AsthmaCore
import SwiftData
import SwiftUI

/// Personal Insights: who you are with the air (an archetype, provisional), the radar, what shows up on your
/// flare days by category, when and where, then Profile History and every moment. Code finds every number
/// (AsthmaCore: AirProfile, Archetype, Rhythm); this only lays them out.
struct InsightsView: View {
    /// The home sky's colour at the moment the page opened: the bloom starts from it.
    var skyColor: Color? = nil
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @AppStorage(Prefs.useDemoData) private var demo = false
    @State private var model = InsightsModel()
    @AppStorage(Crit.InsightsState.key) private var forced = Crit.InsightsState.auto
    @AppStorage(Crit.Paper.key) private var paper = Crit.Paper.black
    @State private var path: [Page] = []
    @State private var picked: AirProfile.Category?
    /// Open category cards. The leading one starts open.
    @State private var open: Set<AirProfile.Category>?
    @State private var shown = false
    /// The bloom's start: it blends from the sky's colour into your factors over the first second.
    @State private var openedAt: Date?
    @State private var shownName = false

    enum Page: Hashable { case history, moments }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    // SF for the page's name; the one Recursive line on the page is your archetype.
                    Text("Personal Insights")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    if learned, let p = profile {
                        archetypeBlock(Archetype(profile: p, learned: true))
                            // The name is the last thing to arrive, so the eye lands on it after the page.
                            .opacity(shownName ? 1 : 0).offset(y: shownName ? 0 : 6)
                        AirRadar(profile: p, selected: $picked, size: 216).frame(maxWidth: .infinity)
                        categories(p)
                    } else {
                        LearningRing(progress: model.progress, forcedLearned: forced == .learned, size: 184)
                            .frame(maxWidth: .infinity)
                        Text("Still learning…").font(Theme.serifTitleLarge).kerning(Theme.serifKerning)
                        Text("Keep logging when you use your inhaler. felt air fills in your ordinary moments on its own, and your profile appears here once it has learned.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                    }
                    whenAndWhere
                    tiles
                    Text("Outdoor air only. Not medical advice, and not a prediction.")
                        .font(Theme.caption).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12).padding(.bottom, 40)
                .opacity(shown ? 1 : 0)
            }
            .scrollIndicators(.hidden)
            .background(paperBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .history: ProfileHistoryView(current: currentSnapshot, history: history, demo: demoLearned)
                    .background(paperBackground)
                case .moments: MomentsLogView(events: Array(events)).background(paperBackground)
                }
            }
            .environment(\.colorScheme, paper == .linen ? .light : .dark)
            .task(id: dataKey) {
                model.rebuild(events: events, demo: demo)
                recordSnapshot()
            }
            .onAppear {
                openedAt = .now
                withAnimation(.easeOut(duration: 0.3)) { shown = true }
                Task { try? await Task.sleep(for: .milliseconds(220)); withAnimation(.smooth(duration: 0.5)) { shownName = true } }
            }
        }
    }

    private var paperBackground: some View {
        ZStack {
            Theme.paper(paper)
            FactorBloom(colors: factorColors, from: skyColor, since: openedAt).opacity(0.85)
            // A dark wash keeps the text readable over the colour.
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            SkyGrain(responds: false).opacity(0.5)
        }
        .ignoresSafeArea()
    }

    /// The inks of what shows up most on your flare days, strongest first: the page is drawn from you.
    /// Before felt air has learned, a quiet blend of the weather's blues.
    private var factorColors: [Color] {
        if demoLearned { return [WeatherColor.pollen[2], WeatherColor.pollen[1], WeatherColor.ozone] }
        let rows = (model.report?.gatedRows ?? []).sorted { $0.lift > $1.lift }
        let inks = rows.compactMap { r -> Color? in
            switch r.bin {
            case "pm25": WeatherColor.pm25
            case "ozone": WeatherColor.ozone
            case "pollen_weed": WeatherColor.pollen[2]
            case "temp": WeatherColor.temperature(r.level == "hot" ? 88 : r.level == "cold" ? 30 : 62)
            case "humidity": Color(red: 0.45, green: 0.6, blue: 0.95)
            case "smoke_at_point": Color(red: 0.6, green: 0.42, blue: 0.25)
            default: nil
            }
        }
        var unique: [Color] = []
        for c in inks where !unique.contains(c) { unique.append(c) }
        return unique.isEmpty ? [Color(red: 0.25, green: 0.35, blue: 0.6), Color(red: 0.2, green: 0.45, blue: 0.55), Color(red: 0.35, green: 0.3, blue: 0.55)]
                              : Array(unique.prefix(3))
    }

    // MARK: Who you are

    /// The archetype, big and centred: its name, one plain line, the evidence, and how much it rests on.
    private func archetypeBlock(_ a: Archetype) -> some View {
        // Three steps only: the name (Recursive), what it means (body), the evidence (one grey line).
        VStack(spacing: 10) {
            Text(a.name).font(Theme.serifTitleLarge).kerning(Theme.serifKerning).multilineTextAlignment(.center)
            Text(a.line).font(.body).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            // Learned, not a score. It can move: felt air keeps learning, and seasons change what's in the air.
            Button { path.append(Page.history) } label: {
                HStack(spacing: 6) {
                    Circle().fill(Verdict.green).frame(width: 7, height: 7)
                    Text("Learned · may shift with the seasons").lineLimit(1)
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold)).opacity(0.6)
                }
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    /// The four categories from the lift table (or the demo person's).
    private var profile: AirProfile? {
        demoLearned ? .demoPerson : model.report.map(AirProfile.init(report:))
    }

    private var report: LiftReport? {
        if demoLearned {
            let rows = AirProfile.demoPerson.axes.compactMap(\.lead)
            return LiftReport(nAttacks: 14, nBaselines: 40, seasonHint: nil, rows: rows, gatedRows: rows.filter(\.gated))
        }
        return model.report
    }

    // MARK: What shows up

    /// Each category with the things inside it and how strongly each shows up on flare days. Not called
    /// "triggers" on screen: we compare what was in the air, we don't claim a cause.
    private func categories(_ p: AirProfile) -> some View {
        let rank: [AirProfile.Status: Int] = [.pattern: 0, .early: 1, .nothing: 2, .notTracked: 3]
        let axes = p.axes.sorted { (rank[$0.status]!, -$0.strength) < (rank[$1.status]!, -$1.strength) }
        return VStack(alignment: .leading, spacing: 10) {
            Text("What shows up on your flare days").font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
            let arch = Archetype(profile: p, learned: true)
            let lead = arch.categories.first ?? axes.first?.category
            let opened = open ?? Set([lead].compactMap { $0 })
            ForEach(axes) { a in
                CategoryCard(axis: a, triggers: report.map { AirProfile.triggers(a.category, report: $0) } ?? [],
                             starred: Set(arch.leads.map(\.id)), selected: picked == a.category,
                             expanded: opened.contains(a.category)) {
                    withAnimation(Theme.snap) {
                        var next = opened
                        if next.contains(a.category) { next.remove(a.category) } else { next.insert(a.category) }
                        open = next
                        picked = next.contains(a.category) ? a.category : nil
                    }
                }
            }
        }
    }

    // MARK: When and where

    private var rescues: [LogEvent] { events.filter { $0.moment == .rescue && !$0.isDemo } }

    /// Two boxes on one line. Plain counts of your rescue moments, not a comparison (baseline moments aren't
    /// spread across the day yet).
    @ViewBuilder private var whenAndWhere: some View {
        let when = demoLearned ? "Mostly in the afternoon." : Rhythm(dates: rescues.map(\.loggedAt)).map { "Mostly in the \($0.part)." }
        let place = demoLearned ? "Mostly at home." : wherePlace
        if when != nil || place != nil {
            HStack(alignment: .top, spacing: 10) {
                SmallBox(title: "When", icon: "clock", text: when ?? "No one time of day.")
                SmallBox(title: "Where", icon: "mappin", text: place ?? "No one place.", pins: rescues.compactMap { e in
                    e.latitude.flatMap { lat in e.longitude.map { (lat, $0) } } })
            }
        }
    }

    /// "At home: 6 of your 10 rescue moments." The most common place once it holds at least 40%.
    private var wherePlace: String? {
        let names = rescues.map { NowHomeView.knownPlace($0.latitude, $0.longitude)?.name ?? $0.placeName ?? "Somewhere else" }
        guard names.count >= 3 else { return nil }
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        guard let top = counts.max(by: { $0.value < $1.value }), Double(top.value) / Double(names.count) >= 0.4 else { return nil }
        return top.key == "Home" ? "Mostly at home." : top.key == "Work" ? "Mostly at work." : "Mostly around \(top.key)."
    }

    // MARK: Tiles

    private var tiles: some View {
        VStack(spacing: 10) {
            NavigationLink(value: Page.history) {
                // Words, not counts (no numbers on screen, Oct 17).
                row("clock.arrow.circlepath", "Your profile history",
                    demoLearned || history.count > 1 ? "Has shifted" : history.isEmpty ? "Starts once it's learned" : "Learned")
            }
            NavigationLink(value: Page.moments) {
                row("list.bullet", "Your moments", events.contains { $0.moment != .okay } ? "" : "None yet")
            }
        }
        .buttonStyle(PressStyle())
    }

    /// One row, on the same glass as the home's buttons: icon, name, value, chevron.
    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).frame(width: 24)
            Text(title).font(.body.weight(.medium))
            Spacer(minLength: 8)
            Text(value).font(.subheadline).foregroundStyle(Theme.secondaryText).lineLimit(1)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16).padding(.vertical, 15)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Profile history

    @AppStorage("profileHistory") private var historyData = Data()

    private var history: [ProfileSnapshot] {
        (try? JSONDecoder().decode([ProfileSnapshot].self, from: historyData)) ?? []
    }

    private var currentSnapshot: ProfileSnapshot? {
        guard learned, let p = profile else { return nil }
        return ProfileSnapshot(date: .now, profile: p, archetype: Archetype(profile: p, learned: true))
    }

    /// Keeps a snapshot when your profile changes (or monthly). Never for the demo person.
    private func recordSnapshot() {
        guard !demoLearned, let s = currentSnapshot else { return }
        let next = ProfileSnapshot.record(s, into: history)
        if next.count != history.count, let data = try? JSONEncoder().encode(next) { historyData = data }
    }

    // MARK: Helpers

    /// Design crit › Insights state › learned, while the real gate isn't met: the demo person.
    private var demoLearned: Bool { forced == .learned && !(model.progress?.isMet ?? false) }

    private var learned: Bool { forced == .learned || (model.progress?.isMet ?? false) }

    private var dataKey: String {
        let ready = events.filter { $0.conditionsData != nil }.count
        return "\(events.count)-\(ready)-\(demo)-\(forced.rawValue)"
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
    var size: CGFloat = 140
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownAt: Date?

    var body: some View {
        let a = progress.map { min(1, Double($0.attacks) / Double(max(1, $0.minAttacks))) } ?? 0
        let b = progress.map { min(1, Double($0.baselines) / Double(max(1, $0.minBaselines))) } ?? 0
        let fill = forcedLearned ? 1 : min(a, b)
        let done = fill >= 1
        VStack(spacing: 16) {
            ZStack {
                // The ring draws itself in over 1.4 s when the page opens (at once with Reduce Motion).
                TimelineView(.animation(minimumInterval: 1 / 60, paused: shownAt.map { Date().timeIntervalSince($0) > 1.6 } ?? true)) { frame in
                Canvas { ctx, size in
                    let n = 72
                    let elapsed = shownAt.map { frame.date.timeIntervalSince($0) } ?? 0
                    let eased = reduceMotion ? 1 : 1 - pow(1 - min(1, elapsed / 1.4), 3)
                    let drawn = fill * eased
                    let c = CGPoint(x: size.width / 2, y: size.height / 2), radius = size.width / 2 - 6
                    for i in 0..<n {
                        let t = Double(i) / Double(n)
                        let ang = t * 2 * .pi - .pi / 2
                        let p = CGPoint(x: c.x + radius * cos(ang), y: c.y + radius * sin(ang))
                        let on = t < drawn
                        let r: CGFloat = on ? 3.4 : 1.6
                        // Rescue orange into standard blue as it fills; the rest is faint grain.
                        let ink = on ? Color.primary.opacity(0.55 + 0.45 * t) : Theme.secondaryText.opacity(0.35)
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(ink))
                    }
                }
                }
                Image(systemName: done ? "sparkles" : "sparkle").font(.system(size: size * 0.2, weight: .semibold))
                    .symbolEffect(.pulse, isActive: done && !reduceMotion)
                    .symbolEffect(.bounce, value: done)
            }
            .frame(width: size, height: size)
            .onAppear { shownAt = .now }
            // No counts: you're not a number (owner, Oct 17). The ring filling is enough.
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(done ? "Learned" : "Still learning")
    }

}

/// Soft blobs of colour that drift slowly, like Apple Card's: a 3×3 mesh whose inner points wander. The
/// first colour gets the most room.
struct FactorBloom: View {
    let colors: [Color]
    /// A colour to start from (the sky the page opened over), blended into `colors` over 1.2 s from `since`.
    var from: Color? = nil
    var since: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion && since == nil)) { frame in
            let t = reduceMotion ? 0 : frame.date.timeIntervalSinceReferenceDate
            // 0 at open, 1 after 1.2 s, eased: how far from the sky's colour to your own.
            let raw = since.map { min(1, frame.date.timeIntervalSince($0) / 1.2) } ?? 1
            let blend = reduceMotion ? 1 : 1 - pow(1 - raw, 3)
            let mixed: (Color) -> Color = { c in from.map { $0.mix(with: c, by: blend) } ?? c }
            let a = mixed(colors.first ?? .blue), b = mixed(colors.count > 1 ? colors[1] : colors.first ?? .blue), c = mixed(colors.count > 2 ? colors[2] : colors.count > 1 ? colors[1] : colors.first ?? .blue)
            let w = { (p: Double, s: Double) in Float(0.5 + 0.18 * sin(t * s + p)) }
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, w(0, 0.21)], [w(1, 0.17), w(2, 0.13)], [1, w(3, 0.19)],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                a, a, b,
                b, a, c,
                c, b, a,
            ])
            .blur(radius: 30)
        }
        .accessibilityHidden(true)
    }
}
