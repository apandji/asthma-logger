import AsthmaCore
import SwiftData
import SwiftUI

/// The Journal, in two modes (switch at the top):
/// - Ambient: the day's outdoor conditions as a soft colour field, one sentence, and today's moments.
///   Tap anywhere for the details, each condition as Good / OK / Not good.
/// - Data: temperature, humidity and air as scrollable hourly line charts, with inhaler moments marked.
/// Logging lives in the tab bar accessory, on Apple Watch, and on the felt button.
struct JournalView: View {
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @State private var selectedID: UUID?
    @State private var showDetails = false
    @AppStorage("journalMode") private var mode = Mode.ambient

    enum Mode: String { case ambient, data }

    private let days = 7

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .ambient: ambient
                case .data:
                    ScrollView {
                        AirChartsView()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 110)
                    }
                    .background(Theme.stage.ignoresSafeArea())
                }
            }
            .navigationDestination(for: LogEvent.self) { EventDetailView(event: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { MomentListView() } label: { Image(systemName: "list.bullet") }
                        .accessibilityLabel("All moments")
                }
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $mode.animation(.easeInOut)) {
                        Text("Ambient").tag(Mode.ambient)
                        Text("Data").tag(Mode.data)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
            }
            .settingsToolbar()
            .sheet(isPresented: $showDetails) {
                if let event = selected {
                    DetailsSheet(event: event)
                        .presentationDetents([.medium, .large])
                        .presentationBackground(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: Ambient

    private var ambient: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 24)
            if events.isEmpty {
                emptyState.padding(.horizontal, 20)
            } else {
                todayMoments
            }
            if let error = services.lastError {
                Text(error).font(.footnote).foregroundStyle(.orange).padding(.horizontal, 20).padding(.top, 8)
            }
            Text("Tap anywhere for details")
                .font(.footnote).foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .padding(.bottom, 120)  // clear the floating log bar
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { if selected != nil { showDetails = true } }
        .background {
            // The room takes on the selected moment's air (today's, until you pick one).
            AmbientField(weave: selected.map { $0.weave.isEmpty ? todayWeave : $0.weave } ?? todayWeave)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: selected?.id)
        }
    }

    /// Today's moments as quiet glass chips; tapping one tints the room with its air and opens it.
    private var todayMoments: some View {
        let today = events.filter { Calendar.current.isDateInToday($0.loggedAt) && $0.moment != .okay }
        return VStack(alignment: .leading, spacing: 10) {
            Text(today.isEmpty ? "No inhaler use today" : "Today")
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 20)
            if !today.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(today) { e in
                            Button {
                                withAnimation(.snappy) { selectedID = e.id }
                                showDetails = true
                            } label: {
                                HStack(spacing: 6) {
                                    MomentDot(moment: e.moment, size: 8)
                                    Text(e.loggedAt.formatted(date: .omitted, time: .shortened))
                                        .font(.subheadline.monospacedDigit())
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .glassEffect(.regular, in: .capsule)
                                .overlay(Capsule().strokeBorder(.primary.opacity(e.id == selected?.id ? 0.5 : 0), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(e.moment.title) at \(e.loggedAt.formatted(date: .omitted, time: .shortened))")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .defaultScrollAnchor(.trailing)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            Text(airSentence)
                .font(.system(.title, design: .serif, weight: .medium))
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

/// Opened by tapping the ambient Journal: the moment's conditions as tiers, a switcher for the tier
/// style (for comparing in review), and a link to everything about the moment.
struct DetailsSheet: View {
    let event: LogEvent
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MomentCard(event: event, showsChevron: false)
                    NavigationLink(value: event) {
                        Label("Everything about this moment", systemImage: "chevron.right")
                            .labelStyle(.titleOnly)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .padding(16)
            }
            .navigationDestination(for: LogEvent.self) { EventDetailView(event: $0) }
            .navigationTitle(event.moment == .okay ? "Conditions" : event.moment.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Level style", selection: $style) {
                            ForEach(LevelStyle.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Level style")
                }
            }
        }
    }
}
