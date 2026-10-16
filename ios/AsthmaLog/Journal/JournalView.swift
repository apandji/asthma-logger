import AsthmaCore
import CoreLocation
import SwiftData
import SwiftUI

/// The Journal: the outdoor conditions as a soft colour field, one live sentence, and this week's
/// moments as cards you swipe through. Pinch a card open for everything about it (weather first);
/// pinch the room closed for the calendar of all moments. Turn the phone sideways for the Data view.
/// Logging is the + at the bottom (RootView), the felt button and Apple Watch.
struct JournalView: View {
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var selectedID: UUID?
    @State private var opened: LogEvent?
    @Namespace private var zoom
    @State private var showOverview = false
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off

    private let days = 7

    var body: some View {
        NavigationStack {
            ambient
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: LogEvent.self) { EventDetailView(event: $0) }
                .navigationDestination(item: $opened) { e in
                    MomentDetailsView(event: e)
                        .navigationTransition(.zoom(sourceID: e.id, in: zoom))
                }
                .navigationDestination(isPresented: $showOverview) { MomentListView() }
        }
    }

    // MARK: Ambient

    private var ambient: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 16)
            if cards.isEmpty {
                emptyState.padding(.horizontal, 20)
            } else {
                MomentCarousel(events: cards, selectedID: $selectedID, namespace: zoom, onOverview: { showOverview = true }) { opened = $0 }
                    .frame(height: 400)
                Text("Pinch a card open for details · pinch in for all moments")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            if let error = services.lastError {
                Text(error).font(.footnote).foregroundStyle(.orange).padding(.horizontal, 20).padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            MagnifyGesture().onEnded { v in if v.magnification < 0.85 { showOverview = true } }
        )
        .background {
            // The room takes on the current card's air (today's, until you swipe).
            AmbientField(weave: selected.map { $0.weave.isEmpty ? todayWeave : $0.weave } ?? todayWeave,
                         temperatureF: selected?.conditions?.best(.temperature)?.value ?? now?.temp,
                         pollen: DemoPollen.sample(at: selected?.loggedAt ?? .now, season: pollenSeason))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: selected?.id)
        }
    }

    /// This week's inhaler moments, oldest first (the newest starts in the middle).
    private var cards: [LogEvent] {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        return events.filter { $0.loggedAt >= start && $0.moment != .okay }
    }

    // MARK: Header

    @AppStorage(Crit.Header.key) private var headerStyle = Crit.Header.now
    @State private var now: (weave: WeaveSpec, temp: Double?, place: String?)?
    @State private var showSettings = false

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                // Settings is tucked away: long-press the date (or open it from the calendar view).
                .onLongPressGesture { showSettings = true }
            switch headerStyle {
            case .now, .nowWithCounts:
                if let now, let sentence = nowSentence(now.weave) {
                    Text(sentence)
                        .font(.system(.title, design: .serif, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = nowDetail(now) {
                        Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                }
                if headerStyle == .nowWithCounts {
                    HStack(spacing: 10) {
                        stat(count(.rescue), "Rescue", Theme.rescue)
                        stat(count(.maintenance), "Standard", Theme.standard)
                    }
                    .padding(.top, 4)
                }
            case .lastMoment:
                Text(lastSentence)
                    .font(.system(.title, design: .serif, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    stat(count(.rescue), "Rescue", Theme.rescue)
                    stat(count(.maintenance), "Standard", Theme.standard)
                }
            case .dateOnly:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut, value: now?.temp)
        .task { await loadNow() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    /// "The air is good right now." Present tense, outdoor, no number.
    private func nowSentence(_ w: WeaveSpec) -> String? {
        guard let air = w.levels[.air] else { return nil }
        return ["The air is good right now.", "The air is OK right now.", "The air isn't great right now."][air.rawValue]
    }

    /// "65° and comfortable · University City, MO"
    private func nowDetail(_ n: (weave: WeaveSpec, temp: Double?, place: String?)) -> String? {
        var parts: [String] = []
        var feel: [String] = []
        if let t = n.temp { feel.append("\(Int(t.rounded()))°") }
        if let h = n.weave.words[.humidity] { feel.append(h) }
        if !feel.isEmpty { parts.append(feel.joined(separator: " and ")) }
        if let p = n.place { parts.append(p) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The air where you are now, for the header only (nothing is saved).
    private func loadNow() async {
        guard now == nil, let fix = try? await services.location.currentLocation(timeout: .seconds(6)) else { return }
        let c = await services.conditions.conditions(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
        let marks = try? await CLGeocoder().reverseGeocodeLocation(fix)
        let place = marks?.first.map { [$0.locality ?? $0.subAdministrativeArea, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ") }
        now = (WeaveSpec(c.input), c.best(.temperature)?.value, place)
    }

    /// The old header: the latest moment's air.
    private var lastSentence: String {
        guard let latest = events.last(where: { !$0.weave.isEmpty }) else { return "Nothing logged yet." }
        let line = latest.airLine
        return Calendar.current.isDateInToday(latest.loggedAt) ? line : "Last time: " + line.prefix(1).lowercased() + line.dropFirst()
    }

    /// Today's air for the ambient field: the latest moment today with a reading, else the latest one.
    private var todayWeave: WeaveSpec {
        let today = events.last { Calendar.current.isDateInToday($0.loggedAt) && !$0.weave.isEmpty }
        return (today ?? events.last { !$0.weave.isEmpty })?.weave ?? now?.weave ?? WeaveSpec()
    }

    private func count(_ kind: MomentKind) -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        return events.filter { $0.loggedAt >= start && $0.moment == kind }.count
    }

    private func stat(_ n: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(n)").font(.headline.monospacedDigit())
            Text(label).font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(n) \(label.lowercased()) this week")
    }

    private var emptyState: some View {
        Text("Press + and pull up to log, or use your felt button or Apple Watch.")
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryText)
    }

    // MARK: Data

    private var selected: LogEvent? {
        if let id = selectedID, let e = events.first(where: { $0.id == id }) { return e }
        return events.last { !$0.weave.isEmpty } ?? events.last
    }
}

/// Orange dot = rescue, blue dot = standard, open ring = I'm okay. Same colours as the watch.
struct MomentDot: View {
    let moment: MomentKind
    var size: CGFloat = 10
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColor

    var body: some View {
        switch moment {
        case .rescue: Circle().fill(Theme.rescue).frame(width: size, height: size)
        case .maintenance:
            // With Differentiate Without Color, standard doses are squares, not just blue.
            RoundedRectangle(cornerRadius: noColor ? size * 0.15 : size / 2).fill(Theme.standard).frame(width: size, height: size)
        case .okay: Circle().strokeBorder(Theme.secondaryText, lineWidth: max(1.5, size / 5)).frame(width: size, height: size)
        }
    }
}

// MARK: - Selected moment

/// The selected moment in plain iOS: kind, time, the weave in words, and every outdoor value with its source.
struct MomentCard: View {
    let event: LogEvent
    var showsChevron = true
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        MomentDot(moment: event.moment, size: 9)
                        Text(event.moment.title).font(.headline)
                    }
                    Text(event.loggedAt.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 12)

            if let c = event.conditions, !c.observations.isEmpty {
                Divider()
                factorRow(.air, "Air quality", value: airValue(c))
                Divider().padding(.leading, 40)
                factorRow(.humidity, "Humidity", value: c.best(.humidity).map { "\(Int($0.value.rounded()))%" })
                Divider().padding(.leading, 40)
                factorRow(.temperature, "Temperature", value: c.best(.temperature).map { "\(Int($0.value.rounded()))°F" })
                Divider().padding(.leading, 40)
                factorRow(.pollen, "Pollen", value: nil)
                Divider()
                Text("Outdoors near you · \(sourceLine(c))")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                    .padding(.top, 12)
            } else if let err = event.envError {
                Divider()
                Text(err).font(.footnote).foregroundStyle(Theme.secondaryText).padding(.top, 12)
            } else if event.envStatus == .pending {
                Divider()
                Text("Checking the air…").font(.footnote).foregroundStyle(Theme.secondaryText).padding(.top, 12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedCard()
        .contentShape(.rect(cornerRadius: 22))
    }

    /// One condition: its tier as a small graphic (style from Settings), the name, Good / OK / Not good,
    /// and the plain word with the reading underneath.
    private func factorRow(_ f: WeaveSpec.Factor, _ name: String, value: String?) -> some View {
        let level = event.weave.levels[f]
        let detail = [event.weave.words[f].map { $0.prefix(1).uppercased() + $0.dropFirst() }, value]
            .compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 12) {
            LevelIndicator(level: level, ink: WeaveSwatch.ink(f), style: style)
                .frame(minWidth: 30)
            Text(name)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if style != .word || level == nil {
                    Text(level.map { Tier($0).word } ?? (f == .pollen ? "Not yet" : "No reading"))
                        .foregroundStyle(level == nil ? Theme.secondaryText : .primary)
                }
                if !detail.isEmpty {
                    Text(detail).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func airValue(_ c: Conditions) -> String? {
        if let pm = c.best(.pm25) { return "PM2.5 \(Int(pm.value.rounded()))" }
        if let aqi = c.best(.aqi) { return "AQI \(Int(aqi.value))" }
        if let o3 = c.best(.ozone) { return "O₃ \(Int(o3.value.rounded()))" }
        return nil
    }

    /// "Apple Weather, OpenAQ (2–6 mi) ·": the full provenance is one tap away (Details).
    private func sourceLine(_ c: Conditions) -> String {
        let names = Array(Set(c.observations.map(\.source))).sorted()
        let miles = c.observations.compactMap(\.distanceKm).map { Int(($0 * 0.621371).rounded()) }
        var line = names.joined(separator: ", ")
        if let lo = miles.min(), let hi = miles.max() { line += lo == hi ? " (\(lo) mi)" : " (\(lo)–\(hi) mi)" }
        return line
    }
}

extension LogEvent {
    /// The air at this moment as a short phrase: "Good air, 63° and comfortable."
    var airLine: String {
        let w = weave
        var parts: [String] = []
        if let air = w.levels[.air] { parts.append(["Good air", "Moderate air", "Poor air"][air.rawValue]) }
        var tail: [String] = []
        if let t = conditions?.best(.temperature) { tail.append("\(Int(t.value.rounded()))°") }
        if let h = w.words[.humidity] { tail.append(h) }
        if !tail.isEmpty { parts.append(tail.joined(separator: " and ")) }
        return parts.isEmpty ? "No air reading." : parts.joined(separator: ", ") + "."
    }
}
