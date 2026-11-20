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
    /// Exercise: read workouts and steps from Apple Health, then look back over your moments.
    var syncHealth: (() async -> Void)? = nil
    let expanded: Bool
    /// The bin a pattern tip opened Insights on: its row is marked so the eye lands on it.
    var highlight: String? = nil
    let toggle: () -> Void
    /// The starred one first, whatever its strength word says.
    private var ordered: [AirProfile.Trigger] {
        let lead = triggers.filter { t in t.row.map { starred.contains($0.id) } ?? false }
        return lead + triggers.filter { t in !(t.row.map { starred.contains($0.id) } ?? false) }
    }

    var body: some View {
        if menus { menusBody } else { glassBody }
    }

    // MARK: Menus look (April, Nov 20: one name size, one value size, rows under the title, the quiet ones folded)

    /// Name column: where the title's text starts, so every row lines up under it.
    private let indent: CGFloat = 32

    private var menusBody: some View {
        let shown = ordered.filter { [.strong, .some, .leaning].contains($0.strength) }
        let usual = ordered.filter { $0.strength == .none }.map(\.name)
        let untracked = ordered.filter { $0.strength == .notTracked }.map(\.name)
        return VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: Icons.category(axis.category))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(axis.status == .notTracked ? Theme.secondaryText.opacity(0.5) : MenusProfileFlower.ink(axis))
                        .frame(width: 22)
                    Text(axis.category.title).font(Theme.Figtree.font(size: 17, weight: .medium)).foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(axis.status.word).font(Theme.Figtree.font(size: 15))
                        .foregroundStyle(axis.status == .pattern ? Color.primary : Theme.secondaryText)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Collapses" : "Shows what's inside")
            if let syncHealth { healthRow(syncHealth) }
            if expanded {
                ForEach(shown) { t in
                    Divider().padding(.leading, indent)
                    menusRow(t)
                }
                if !usual.isEmpty { folded("No more than usual", usual, dim: false) }
                if !untracked.isEmpty { folded("Not tracked yet", untracked, dim: true) }
                Color.clear.frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .insightCard()
    }

    /// A reading that shows up: its mark in the flower's ink (★ leads your profile), the name, how often.
    private func menusRow(_ t: AirProfile.Trigger) -> some View {
        let lead = t.row.map { starred.contains($0.id) } ?? false
        let strong = t.strength == .strong || t.strength == .some
        return HStack(spacing: 10) {
            Group {
                if let r = t.row, lead { Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(dotInk(r)) }
                else if let r = t.row, strong { Circle().fill(dotInk(r)).frame(width: 7, height: 7) }
                else { Color.clear }
            }
            .frame(width: 22)
            Text(t.name).font(Theme.Figtree.font(size: 16)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(t.strength.word).font(Theme.Figtree.font(size: 15, weight: strong ? .medium : .regular))
                .foregroundStyle(strong ? Color.primary : Theme.secondaryText)
        }
        .padding(.vertical, 12)
        .background {
            if let h = highlight, t.row?.bin == h {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)).padding(.horizontal, -8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(t.name), \(t.strength.word)\(lead ? ", leads your profile" : "")")
    }

    /// The rest, quieter than the rows (April, Nov 20): a small label, then the names under it. "No more than
    /// usual" is something we checked, so it reads a step darker than "Not tracked yet", which we can't say.
    private func folded(_ label: String, _ names: [String], dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(Theme.Figtree.font(size: 12, weight: .semibold))
                    .foregroundStyle(dim ? Color.primary.opacity(0.3) : Theme.secondaryText)
                Text(names.joined(separator: ", ")).font(Theme.Figtree.font(size: 14))
                    .foregroundStyle(dim ? Color.primary.opacity(0.3) : Color.primary.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
        }
        .padding(.leading, indent)
    }

    @State private var syncing = false
    @State private var synced = false

    /// "Sync Apple Health" under Exercise. Health asks once; after that it looks back again over your moments.
    private func healthRow(_ sync: @escaping () async -> Void) -> some View {
        // A button, not a row (April, Nov 20): a soft pill under the title, the heart in Health's pink.
        Button {
            // Ours first (April, Nov 20): Apple's sheet has no close button, so the choice comes before it.
            // Once Health has been asked, it just syncs.
            Task {
                if await HealthReader.shared.shouldAsk() { askingHealth = true }
                else { await runSync(sync) }
            }
        } label: {
            HStack(spacing: 8) {
                if syncing { ProgressView().controlSize(.small) }
                else {
                    Image(systemName: synced ? "checkmark" : "heart.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(synced ? Color.primary : Color.pink)
                }
                Text(synced ? "Synced with Apple Health" : syncing ? "Syncing…" : "Sync Apple Health")
                    .font(Theme.Figtree.font(size: 16, weight: .medium)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .disabled(syncing || synced)
        .padding(.bottom, 14)
        .sheet(isPresented: $askingHealth) {
            HealthSyncPrompt(proceed: {
                askingHealth = false
                Task { try? await Task.sleep(for: .milliseconds(350)); await runSync(sync) }
            }, cancel: { askingHealth = false })
        }
    }

    @State private var askingHealth = false

    private func runSync(_ sync: () async -> Void) async {
        syncing = true
        await sync()
        syncing = false
        withAnimation(Theme.snap) { synced = true }
    }

    // MARK: Other looks

    private var glassBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    // The same symbol as the rail's stop, in the category's ink.
                    Image(systemName: Icons.category(axis.category))
                        .font(Theme.ui(.subheadline, weight: .semibold))
                        .foregroundStyle(axis.status == .notTracked ? Theme.secondaryText.opacity(0.5) : menus ? MenusProfileFlower.ink(axis) : AirRadar.ink(axis))
                        .frame(width: 22)
                    Text(axis.category.title).font(Theme.ui(.body, weight: .medium))
                    Spacer(minLength: 8)
                    Text(axis.status.word).font(Theme.ui(.caption, weight: .semibold))
                        .foregroundStyle(axis.status == .pattern ? Color.primary : Theme.secondaryText)
                    Image(systemName: "chevron.down").font(Theme.ui(.caption, weight: .bold)).foregroundStyle(Theme.secondaryText)
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
        .insightCard(tint: selected ? AirRadar.ink(axis).opacity(0.25) : nil)
    }

    private var menus: Bool { Crit.AppLook.current == .menus }

    /// A reading's mark: on the Menus look, its flower's ink (April, Nov 20), so Insights and Home share colours.
    private func dotInk(_ r: LiftRow) -> Color {
        if menus { return MenusProfileFlower.ink(bin: r.bin) ?? MenusProfileFlower.ink(axis) }
        return Crit.RiskColor.familiesInInk ? Verdict.red : WeatherColor.ink(bin: r.bin, level: r.level) ?? AirRadar.ink(axis)
    }

    /// What's inside, in words. No counts on screen (owner, Oct 17); the numbers you see are readings,
    /// when you hold the sky on Now.
    private func item(_ t: AirProfile.Trigger) -> some View { itemLabel(t) }

    private func itemLabel(_ t: AirProfile.Trigger) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if let r = t.row, starred.contains(r.id) {
                        Image(systemName: "star.fill").font(Theme.ui(.caption2))
                            .foregroundStyle(dotInk(r))
                            .accessibilityLabel("Leads your profile")
                    } else if let r = t.row, t.strength == .strong || t.strength == .some {
                        // Your pattern, in the same ink as the page's wash and the radar.
                        Circle().fill(dotInk(r))
                            .frame(width: 8, height: 8).accessibilityHidden(true)
                    }
                    Text(t.name).font(Theme.ui(.subheadline))
                        .foregroundStyle(t.strength == .notTracked || t.strength == .none ? Theme.secondaryText : .primary)
                }
            }
            Spacer(minLength: 8)
            Text(t.strength.word).font(Theme.ui(.caption, weight: t.strength == .strong ? .bold : .semibold))
                .foregroundStyle(t.strength == .strong || t.strength == .some ? Color.primary : Theme.secondaryText)
        }
        .padding(.leading, 20)
        .padding(.vertical, highlight != nil && t.row?.bin == highlight ? 6 : 0)
        .background {
            if let h = highlight, t.row?.bin == h {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)).padding(.leading, 8)
            }
        }
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
            Label(title, systemImage: icon).font(Theme.ui(.subheadline, weight: .semibold))
            Text(text).font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
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
                .environment(\.colorScheme, Crit.AppLook.current == .menus ? .light : .dark)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .insightCard()
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
        let all = Array((demo ? Self.demoHistory : history).reversed())   // newest first
        // The newest snapshots of the same kind as now are this profile, not a past one: one entry, with
        // when it began.
        let same = current.map { c in all.prefix { $0.kind == c.kind } } ?? []
        let past = all.dropFirst(same.count)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your profile can shift with the seasons. felt air keeps a snapshot each time it changes, and once a month.")
                    .font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText)
                if let current {
                    entry(current, label: same.last.map { "Now, since \($0.date.formatted(.dateTime.month(.abbreviated).day().year()))" } ?? "Now")
                }
                ForEach(Array(past)) { s in
                    entry(s, label: "Since \(s.date.formatted(.dateTime.month(.abbreviated).day().year()))")
                }
                if past.isEmpty && current == nil {
                    Text("Your first profile is kept once felt air has learned your pattern.").font(Theme.ui(.subheadline))
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
                Text(label).font(Theme.ui(.caption)).foregroundStyle(Theme.secondaryText)
                Text(s.title).font(Theme.ui(.body, weight: .medium))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .insightCard()
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
                                    Text("\(m.moment.title) · \(m.loggedAt.formatted(date: .omitted, time: .shortened))").font(Theme.ui(.subheadline, weight: .medium))
                                    Text([m.placeName, (m.voiceTranscript ?? "").isEmpty ? nil : "“\(m.voiceTranscript!)”"].compactMap { $0 }.joined(separator: " · "))
                                        .font(Theme.ui(.caption)).foregroundStyle(Theme.secondaryText).lineLimit(1)
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


/// Before Apple's Health sheet (April, Nov 20): what felt air reads and why, with a clear way out. Apple's sheet
/// itself only offers Allow or Don't Allow at the bottom.
struct HealthSyncPrompt: View {
    let proceed: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "heart.fill").font(.system(size: 34)).foregroundStyle(.pink)
                    .padding(.top, 8)
                Text("Sync Apple Health").font(Theme.Figtree.font(size: 26, weight: .medium))
                Text("felt air reads your workouts and steps to see if you were active before a moment. Apple will also ask about sleep, heart rate, breathing and State of Mind, which describe how you were around each moment. You choose each one, and you can change it later in the Health app.")
                    .font(Theme.Figtree.font(size: 16)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("Stays on this iPhone.", systemImage: "lock.fill")
                    .font(Theme.Figtree.font(size: 14, weight: .medium)).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Button(action: proceed) {
                    Text("Continue").font(Theme.Figtree.font(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .foregroundStyle(.white).background(Capsule().fill(.black))
                }
                Button(action: cancel) {
                    Text("Not now").font(Theme.Figtree.font(size: 17, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 12)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(role: .close, action: cancel) } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .light)
    }
}
