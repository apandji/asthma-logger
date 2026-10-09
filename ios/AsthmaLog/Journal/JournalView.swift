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
                VStack(alignment: .leading, spacing: 22) {
                    header
                    MomentStrip(days: week, selectedID: selectedID) { selectedID = $0 }
                    WeaveLegend().padding(.horizontal, 20)
                    if let event = selected {
                        MomentCard(event: event).padding(.horizontal, 16)
                    } else if events.isEmpty {
                        emptyState.padding(.horizontal, 20)
                    }
                    if let error = services.lastError {
                        Text(error).font(Theme.caption).foregroundStyle(.orange).padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.stage.ignoresSafeArea())
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

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Text(headline)
                .font(Theme.headlineSerif)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    /// Plain counts for the week; never a judgement.
    private var headline: String {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: .now))!
        let recent = events.filter { $0.loggedAt >= start }
        let rescue = recent.filter { $0.moment == .rescue }.count
        let standard = recent.filter { $0.moment == .maintenance }.count
        if recent.isEmpty { return "Your week of moments will gather here." }
        let r = rescue == 1 ? "1 rescue moment" : "\(rescue) rescue moments"
        let s = standard == 1 ? "1 standard dose" : "\(standard) standard doses"
        return "This week: \(r) and \(s)."
    }

    private var emptyState: some View {
        Text("Tap Rescue or Standard below, or press a button on Apple Watch. Each moment is woven from the outdoor air at that time.")
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

/// This week's moments as rounded woven cards, grouped by day, starting scrolled to now.
struct MomentStrip: View {
    let days: [MomentDay]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void

    private let card: CGFloat = 104

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 28) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label(day.day))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Calendar.current.isDateInToday(day.day) ? Theme.accent : Theme.secondaryText)
                        if day.events.isEmpty {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Theme.secondaryText.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .frame(width: 44, height: card)
                                .accessibilityLabel("No moments")
                        } else {
                            HStack(spacing: 10) {
                                ForEach(day.events) { event in
                                    Button { onSelect(event.id) } label: {
                                        MomentTile(event: event, size: card, isSelected: event.id == (selectedID ?? days.last { !$0.events.isEmpty }?.events.last?.id))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .id(day.day)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .defaultScrollAnchor(.trailing)
        .scrollTargetBehavior(.viewAligned)
        .frame(height: card + 30)
    }

    private func label(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day())
    }
}

/// One moment: its weave, a kind dot, and the time.
struct MomentTile: View {
    let event: LogEvent
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch event.envStatus {
            case .pending:
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card)
                    .overlay { ProgressView() }
            case .ready, .partial, .failed:
                if event.weave.isEmpty {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card)
                        .overlay {
                            Text("No air\nreading").font(.caption2).multilineTextAlignment(.center)
                                .foregroundStyle(Theme.secondaryText)
                        }
                } else {
                    WeaveSwatch(weave: event.weave)
                }
            }
            MomentDot(moment: event.moment)
                .padding(10)
            Text(event.loggedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.thinMaterial, in: .capsule)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.moment.title), \(event.loggedAt.formatted(date: .omitted, time: .shortened)), \(event.weave.isEmpty ? "no outdoor readings" : event.weave.summary)")
    }
}

/// Orange dot = rescue, blue dot = standard, open ring = I'm okay. Same colours as the watch.
struct MomentDot: View {
    let moment: MomentKind

    var body: some View {
        switch moment {
        case .rescue: Circle().fill(Theme.rescue).frame(width: 12, height: 12).overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
        case .maintenance: Circle().fill(Theme.standard).frame(width: 12, height: 12).overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
        case .okay: Circle().strokeBorder(Theme.secondaryText, lineWidth: 2).frame(width: 12, height: 12)
        }
    }
}

/// The key for weave inks and density.
struct WeaveLegend: View {
    var body: some View {
        ViewThatFits {
            HStack(spacing: 14) { items }
            VStack(alignment: .leading, spacing: 6) { items }
        }
        .font(.caption)
        .foregroundStyle(Theme.secondaryText)
    }

    @ViewBuilder private var items: some View {
        key(.air, "Air")
        key(.humidity, "Humidity")
        key(.temperature, "Temperature")
        key(.pollen, "Pollen (not yet)")
        Text("denser = higher")
    }

    private func key(_ f: WeaveSpec.Factor, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(WeaveSwatch.ink(f)).frame(width: 10, height: 10)
            Text(label)
        }
    }
}

// MARK: - Selected moment

/// The selected moment in plain iOS: kind, time, the weave in words, and every outdoor value with its source.
struct MomentCard: View {
    let event: LogEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MomentDot(moment: event.moment)
                Text(event.moment.title).font(.headline)
                Spacer()
                Text(event.loggedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            if !event.weave.isEmpty {
                Text(event.weave.summary.prefix(1).uppercased() + event.weave.summary.dropFirst())
                    .font(.title3.weight(.semibold))
            }
            if let c = event.conditions, !c.observations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(c.observations.prefix(5).enumerated()), id: \.offset) { _, o in
                        Text(ObservationCopy.line(o)).font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                }
            } else if let err = event.envError {
                Text(err).font(.footnote).foregroundStyle(Theme.secondaryText)
            } else if event.envStatus == .pending {
                Text("Noting the outdoor air…").font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            NavigationLink(value: event) {
                Text("Details and sources").font(.subheadline.weight(.semibold))
            }
            Text("Outdoor air near you, not indoor air, not a diagnosis.")
                .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 20, style: .continuous))
    }
}
