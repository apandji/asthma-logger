import AsthmaCore
import MapKit
import SwiftUI

/// One category on Personal Insights. Collapsed: its ink, name and status. Open: everything in the family,
/// the one that leads your profile first (starred), then by strength, then what isn't tracked yet in grey.
/// This is the detail area, so nothing is hidden behind a "See all".
struct CategoryCard: View {
    let axis: AirProfile.Axis
    let triggers: [AirProfile.Trigger]
    /// LiftRow ids behind your archetype.
    let starred: Set<String>
    let selected: Bool
    let expanded: Bool
    let toggle: () -> Void
    /// The starred one first, whatever its strength word says.
    private var ordered: [AirProfile.Trigger] {
        let lead = triggers.filter { t in t.row.map { starred.contains($0.id) } ?? false }
        return lead + triggers.filter { t in !(t.row.map { starred.contains($0.id) } ?? false) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    // The same symbol as the rail's stop, in the category's ink.
                    Image(systemName: Icons.category(axis.category))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(axis.status == .notTracked ? Theme.secondaryText.opacity(0.5) : AirRadar.ink(axis.category))
                        .frame(width: 22)
                    Text(axis.category.title).font(.body.weight(.medium))
                    Spacer(minLength: 8)
                    Text(axis.status.word).font(.caption.weight(.semibold))
                        .foregroundStyle(axis.status == .pattern ? Color.primary : Theme.secondaryText)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Collapses" : "Shows what's inside")
            if expanded {
                ForEach(ordered) { t in item(t) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(selected ? .regular.tint(AirRadar.ink(axis.category).opacity(0.25)) : .regular, in: .rect(cornerRadius: 22))
    }

    /// What's inside, in words. No counts on screen (owner, Oct 17); the numbers you see are readings,
    /// when you hold the sky on Now.
    private func item(_ t: AirProfile.Trigger) -> some View { itemLabel(t) }

    private func itemLabel(_ t: AirProfile.Trigger) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if let r = t.row, starred.contains(r.id) {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(AirRadar.ink(axis.category))
                            .accessibilityLabel("Leads your profile")
                    }
                    Text(t.name).font(.subheadline)
                        .foregroundStyle(t.strength == .notTracked || t.strength == .none ? Theme.secondaryText : .primary)
                }
            }
            Spacer(minLength: 8)
            Text(t.strength.word).font(.caption.weight(t.strength == .strong ? .bold : .semibold))
                .foregroundStyle(t.strength == .strong || t.strength == .some ? Color.primary : Theme.secondaryText)
        }
        .padding(.leading, 20)
    }
}

/// Half-width box: When or Where. Where shows your rescue moments as dots on a small map.
struct SmallBox: View {
    let title: String
    let icon: String
    let text: String
    var pins: [(Double, Double)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            if !pins.isEmpty {
                Map(initialPosition: .region(Self.region(pins)), interactionModes: []) {
                    ForEach(Array(pins.enumerated()), id: \.offset) { _, p in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: p.0, longitude: p.1)) {
                            Circle().fill(Theme.rescueSoft).frame(width: 8, height: 8)
                                .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1))
                        }
                    }
                }
                .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                .environment(\.colorScheme, .dark)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    /// Around all the pins, never tighter than a neighbourhood (one pin alone would zoom to a street).
    static func region(_ pins: [(Double, Double)]) -> MKCoordinateRegion {
        let lats = pins.map(\.0), lons = pins.map(\.1)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.04, (lats.max()! - lats.min()!) * 1.4),
                                    longitudeDelta: max(0.04, (lons.max()! - lons.min()!) * 1.4))
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// How your profile has moved: now, then each snapshot felt air kept when it changed (or monthly).
/// The hypothesis: it shifts with the seasons.
struct ProfileHistoryView: View {
    let current: ProfileSnapshot?
    let history: [ProfileSnapshot]
    var demo = false

    /// For the presentation: a summer that turned into a pollen autumn.
    private static let demoHistory: [ProfileSnapshot] = {
        let cal = Calendar.current
        func d(_ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: day))! }
        return [ProfileSnapshot(date: d(7, 9), kind: .hotHazy, strengths: [0.42, 0.08, 0.5, 0]),
                ProfileSnapshot(date: d(9, 2), kind: .biologics, strengths: [0.11, 0.49, 0.23, 0.2])]
    }()

    var body: some View {
        let past = (demo ? Self.demoHistory : history).reversed()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your profile can shift with the seasons. felt air keeps a snapshot each time it changes, and once a month.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                if let current { entry(current, label: "Now") }
                ForEach(Array(past)) { s in
                    entry(s, label: "Since \(s.date.formatted(.dateTime.month(.abbreviated).day().year()))")
                }
                if past.isEmpty && current == nil {
                    Text("Your first profile is kept once felt air has learned your pattern.").font(.subheadline)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Your profile history")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entry(_ s: ProfileSnapshot, label: String) -> some View {
        HStack(spacing: 14) {
            AirRadar(profile: s.profile, selected: .constant(nil), size: 56, labels: false)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
                Text(Archetype.name(s.kind)).font(.body.weight(.medium))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

extension ProfileSnapshot {
    /// The snapshot as a radar shape.
    var profile: AirProfile {
        AirProfile(axes: AirProfile.Category.allCases.enumerated().map { i, c in
            let v = i < strengths.count ? strengths[i] : 0
            return AirProfile.Axis(category: c, strength: v, status: v > 0 ? .pattern : .nothing, lead: nil)
        })
    }
}

/// Every moment, newest first, by day. Tap one for its details; Export makes the table to share.
struct MomentsLogView: View {
    let events: [LogEvent]
    @State private var exporting = false

    var body: some View {
        // Your journal: inhaler moments and notes. Baselines are the engine's (they're in the export).
        let shown = events.filter { $0.moment != .okay }.sorted { $0.loggedAt > $1.loggedAt }
        let days = Dictionary(grouping: shown) { Calendar.current.startOfDay(for: $0.loggedAt) }.sorted { $0.key > $1.key }
        List {
            ForEach(days, id: \.key) { day, moments in
                Section(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                    ForEach(moments) { m in
                        NavigationLink { MomentDetailsView(event: m) } label: {
                            HStack(spacing: 12) {
                                MomentSwatch(event: m, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(m.moment.title) · \(m.loggedAt.formatted(date: .omitted, time: .shortened))").font(.subheadline.weight(.medium))
                                    Text([m.placeName, (m.voiceTranscript ?? "").isEmpty ? nil : "“\(m.voiceTranscript!)”"].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Your moments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { exporting = true } label: { Label("Export table", systemImage: "square.and.arrow.up") }
        }
        .sheet(isPresented: $exporting) { DoctorSheet(events: events) }
    }
}
