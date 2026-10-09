import AsthmaCore
import SwiftData
import SwiftUI

/// The ambient Journal: a full-bleed stage with this week's moments as a horizontal strip of woven
/// cards (one per moment, grouped by day, scrolled to now), and the selected moment underneath.
/// Logging lives in the tab bar accessory and on Apple Watch. Wireframe: Figma "10.2 Journal View".
struct JournalView: View {
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var selectedID: UUID?

    private let days = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("This week").font(.title3.weight(.semibold))
                            Spacer()
                            Button { showKey = true } label: {
                                Image(systemName: "info.circle").font(.body)
                            }
                            .foregroundStyle(Theme.secondaryText)
                            .accessibilityLabel("How to read the weaves")
                            .popover(isPresented: $showKey) { WeaveKey().presentationCompactAdaptation(.popover) }
                        }
                        .padding(.horizontal, 20)
                        MomentStrip(days: week, selectedID: selected?.id) { id in
                            withAnimation(.snappy) { selectedID = id }
                        }
                    }
                    if let event = selected {
                        NavigationLink(value: event) { MomentCard(event: event) }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                    } else if events.isEmpty {
                        emptyState.padding(.horizontal, 20)
                    }
                    if let error = services.lastError {
                        Text(error).font(.footnote).foregroundStyle(.orange).padding(.horizontal, 20)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background {
                // The room takes on the selected moment's air (today's, until you pick one).
                AmbientField(weave: selected.map { $0.weave.isEmpty ? todayWeave : $0.weave } ?? todayWeave)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.8), value: selected?.id)
            }
            .navigationDestination(for: LogEvent.self) { EventDetailView(event: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { MomentListView() } label: { Image(systemName: "list.bullet") }
                        .accessibilityLabel("All moments")
                }
            }
            .settingsToolbar()
        }
    }

    @State private var showKey = false

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            Text(airSentence)
                .font(Theme.headlineSerif)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                stat(count(.rescue), "Rescue", Theme.rescue)
                stat(count(.maintenance), "Standard", Theme.standard)
            }
        }
        .padding(.horizontal, 20)
    }

    /// One plain sentence about the latest air, e.g. "Good air, 63° and comfortable."
    private var airSentence: String {
        guard let latest = events.last(where: { !$0.weave.isEmpty }) else { return "Nothing logged yet." }
        let line = latest.airLine
        return Calendar.current.isDateInToday(latest.loggedAt) ? line : "Last time: " + line.prefix(1).lowercased() + line.dropFirst()
    }

    /// Today's air for the ambient field: the latest moment today with a reading, else the latest one.
    private var todayWeave: WeaveSpec {
        let today = events.last { Calendar.current.isDateInToday($0.loggedAt) && !$0.weave.isEmpty }
        return (today ?? events.last { !$0.weave.isEmpty })?.weave ?? WeaveSpec()
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
        Text("Tap Rescue or Standard below, or use the buttons on your Apple Watch.")
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryText)
    }

    // MARK: Data

    /// The last `days` days, oldest first, each with its moments in time order (empty days kept).
    private var week: [MomentDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            return MomentDay(day: day, events: events.filter { $0.loggedAt >= day && $0.loggedAt < next })
        }
    }

    private var selected: LogEvent? {
        if let id = selectedID, let e = events.first(where: { $0.id == id }) { return e }
        return events.last
    }
}

struct MomentDay: Identifiable {
    let day: Date
    let events: [LogEvent]
    var id: Date { day }
}

// MARK: - Strip

/// This week's moments as woven tiles, grouped by day, starting scrolled to now.
struct MomentStrip: View {
    let days: [MomentDay]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void

    private let tile: CGFloat = 92

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 20) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(label(day.day))
                            .font(.footnote.weight(Calendar.current.isDateInToday(day.day) ? .semibold : .regular))
                            .foregroundStyle(Calendar.current.isDateInToday(day.day) ? .primary : Theme.secondaryText)
                        if day.events.isEmpty {
                            Capsule().fill(Theme.secondaryText.opacity(0.18))
                                .frame(width: 4, height: tile)
                                .frame(width: 28)
                                .accessibilityLabel("No moments")
                        } else {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(day.events) { event in
                                    Button { onSelect(event.id) } label: {
                                        MomentTile(event: event, size: tile, isSelected: event.id == selectedID)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .defaultScrollAnchor(.trailing)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: tile + 62)
    }

    private func label(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day())
    }
}

/// One moment: its weave, and below it the kind and time. Selection lifts the tile and outlines it.
struct MomentTile: View {
    let event: LogEvent
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                switch event.envStatus {
                case .pending:
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card)
                        .overlay { ProgressView() }
                case .ready, .partial, .failed:
                    if event.weave.isEmpty {
                        RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card)
                            .overlay { Image(systemName: "wind").foregroundStyle(Theme.secondaryText) }
                    } else {
                        WeaveSwatch(weave: event.weave, cornerRadius: 24)
                    }
                }
            }
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 0.5)
            }
            .scaleEffect(isSelected ? 1.0 : 0.94)
            .shadow(color: .black.opacity(isSelected ? 0.18 : 0), radius: 10, y: 4)

            HStack(spacing: 5) {
                MomentDot(moment: event.moment, size: 7)
                Text(event.loggedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? .primary : Theme.secondaryText)
            }
            .padding(.leading, 4)
        }
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.moment.title), \(event.loggedAt.formatted(date: .omitted, time: .shortened)), \(event.weave.isEmpty ? "no outdoor readings" : event.weave.summary)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

/// How to read a weave. Opened from the info button, so the Journal stays quiet.
struct WeaveKey: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Each square is one moment. Its pattern shows the air outside at the time.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                row(.air, "Air quality")
                row(.humidity, "Humidity")
                row(.temperature, "Temperature")
                row(.pollen, "Pollen (not yet)")
            }
            HStack(spacing: 10) {
                ForEach(WeaveSpec.Level.allCases, id: \.self) { l in
                    VStack(spacing: 4) {
                        WeaveSwatch(weave: WeaveSpec(levels: [.air: l]), cornerRadius: 8).frame(width: 36, height: 36)
                        Text(["Low", "Medium", "High"][l.rawValue]).font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            Text("Denser means higher. For temperature and humidity, it means further from comfortable.")
                .font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                HStack(spacing: 5) { MomentDot(moment: .rescue, size: 8); Text("Rescue") }
                HStack(spacing: 5) { MomentDot(moment: .maintenance, size: 8); Text("Standard") }
                HStack(spacing: 5) { MomentDot(moment: .okay, size: 8); Text("I'm okay") }
            }
            .font(.caption)
        }
        .padding(18)
        .frame(width: 300)
    }

    private func row(_ f: WeaveSpec.Factor, _ label: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(WeaveSwatch.ink(f)).frame(width: 12, height: 12)
            Text(label).font(.subheadline)
        }
    }
}

// MARK: - Selected moment

/// The selected moment in plain iOS: kind, time, the weave in words, and every outdoor value with its source.
struct MomentCard: View {
    let event: LogEvent

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
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
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

    /// One condition: a small weave swatch, its name, the plain word, and the reading.
    private func factorRow(_ f: WeaveSpec.Factor, _ name: String, value: String?) -> some View {
        let level = event.weave.levels[f]
        // Air in everyday words (good / moderate / poor), matching the headline.
        let word = f == .air ? level.map { ["good", "moderate", "poor"][$0.rawValue] } : event.weave.words[f]
        return HStack(spacing: 12) {
            LevelMeter(level: level, ink: WeaveSwatch.ink(f))
                .frame(width: 26)
            Text(name)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(word.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? (f == .pollen ? "Not yet" : "No reading"))
                    .foregroundStyle(word == nil ? Theme.secondaryText : .primary)
                if let value { Text(value).font(.caption.monospacedDigit()).foregroundStyle(Theme.secondaryText) }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 9)
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

/// Three short bars: how many are filled is the level (low, medium, high). Dashed when there's no reading.
struct LevelMeter: View {
    let level: WeaveSpec.Level?
    let ink: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(level.map { i <= $0.rawValue } == true ? ink : Theme.secondaryText.opacity(0.22))
                    .frame(width: 5, height: CGFloat(8 + i * 5))
            }
        }
        .frame(height: 20, alignment: .bottom)
        .accessibilityHidden(true)
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
