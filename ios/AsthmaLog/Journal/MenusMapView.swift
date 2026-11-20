import MapKit
import SwiftData
import SwiftUI

/// Menus look, Map tab (owner, Nov 13): where your moments were, on a quiet map. Each moment is a pill in one
/// ink, as on the timeline: rescue filled, standard an outline. Tap one for when and where. Coordinates stay on
/// the phone; the map tiles are Apple's.
struct MenusMapView: View {
    let events: [LogEvent]
    /// Off on home's soil map (owner, Nov 19): inside the page's scroll a pannable map would fight it.
    var interactive = true
    @State private var selected: String?
    /// One trigger picked in the key: the others fade.
    @State private var only: String?

    /// A spot on the map: one of your moments, or a sample one.
    struct Spot: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let lead: String
        let strength: Double
        let when: Date
        let place: String?
        let rescue: Bool
        /// Moments gathered into this spot when they sit close at this zoom.
        var count = 1
        /// Inside (true), outside (false), or not known.
        var inside: Bool? = nil
    }

    enum Setting: String, CaseIterable { case all = "All", outside = "Outside", inside = "Inside" }
    @State private var setting: Setting = .all

    /// How much map is on screen (latitude degrees), for gathering close moments into one flower.
    @State private var span: Double = 0.1

    /// Moments within about a tenth of the screen of each other become one flower with a count (April, Nov 20):
    /// the trigger they share most, at their middle.
    private func gathered(_ all: [Spot]) -> [Spot] {
        let cell = max(span / 9, 0.0004)
        let groups = Dictionary(grouping: all) { "\(Int(floor($0.coordinate.latitude / cell))),\(Int(floor($0.coordinate.longitude / cell)))" }
        return groups.values.map { g in
            guard g.count > 1 else { return g[0] }
            let lead = Dictionary(grouping: g, by: \.lead).max { $0.value.count < $1.value.count }!.key
            let lat = g.map(\.coordinate.latitude).reduce(0, +) / Double(g.count)
            let lon = g.map(\.coordinate.longitude).reduce(0, +) / Double(g.count)
            let place = Dictionary(grouping: g.compactMap(\.place), by: { $0 }).max { $0.value.count < $1.value.count }?.key
            var c = Spot(id: g.map(\.id).sorted().joined(separator: "+"), coordinate: .init(latitude: lat, longitude: lon),
                         lead: lead, strength: g.map(\.strength).max() ?? 0.5, when: g.map(\.when).max() ?? .now,
                         place: place, rescue: g.contains(where: \.rescue))
            c.count = g.count
            return c
        }
        .sorted { $0.coordinate.latitude > $1.coordinate.latitude }   // nearer the bottom draws on top
    }

    /// Inhaler moments that have a place, coloured by what led the air then (the air blanket's watercolour inks,
    /// April, Nov 20). Inside or exercise moments take those instead of an outdoor trigger.
    private var mine: [Spot] {
        events.compactMap { e in
            guard e.moment == .rescue || e.moment == .maintenance, let lat = e.latitude, let lon = e.longitude else { return nil }
            var lead = "", strength = 0.4
            switch e.cause {
            case .exercise?: lead = "Exercise"; strength = 0.8
            case .inside?: lead = "Inside"; strength = 0.6
            case nil:
                if let c = e.conditions, let top = AirBlanket.scores(c.input, flu: e.infection).max(by: { $0.value < $1.value }) {
                    lead = top.key; strength = top.value
                }
            }
            var spot = Spot(id: e.id.uuidString, coordinate: .init(latitude: lat, longitude: lon), lead: lead, strength: strength,
                            when: e.loggedAt, place: e.placeName, rescue: e.moment == .rescue)
            spot.inside = e.indoorOutdoor.map { $0 == .indoor }
            return spot
        }
    }

    /// Too few of your own to see places: a sample St. Louis, labelled as such.
    private var usesSample: Bool { mine.filter { !$0.lead.isEmpty }.count < 25 }
    private var spots: [Spot] {
        let all = usesSample ? Self.sample : mine
        switch setting {
        case .all: return all
        case .outside: return all.filter { $0.inside == false }
        case .inside: return all.filter { $0.inside == true }
        }
    }

    var body: some View {
        let all = spots
        Map(initialPosition: usesSample ? .region(Self.sampleRegion) : .automatic, interactionModes: interactive ? .all : []) {
            ForEach(gathered(all)) { s in
                Annotation("", coordinate: s.coordinate, anchor: .center) { pin(s, dim: only != nil && only != s.lead) }
                    .annotationTitles(.hidden)
            }
        }
        .onMapCameraChange(frequency: .onEnd) { ctx in span = ctx.region.span.latitudeDelta }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls { if interactive { MapCompass() } }
        .allowsHitTesting(interactive)
        .overlay(alignment: .top) {
            if interactive {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.headline(all)).font(Theme.Figtree.font(size: 17, weight: .medium))
                    Text(usesSample ? "Sample map · yours fills in as you log" : "Where you used your inhaler, coloured by what led the air")
                        .font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                .padding(.horizontal, 16).padding(.top, 8)
                .overlay(alignment: .bottom) {
                    // Inside or outside (April, Nov 20).
                    Picker("Where", selection: $setting) {
                        ForEach(Setting.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .padding(4)
                    .background(Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .offset(y: 52)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if interactive { key(all).padding(.bottom, 108) }
        }
    }

    /// A soft wash of ink round the spot, deeper the more there was. Overlapping washes mix like paint.
    private func bloom(_ s: Spot, dim: Bool) -> some View {
        let ink = Self.ink(s.lead)
        return Circle()
            .fill(RadialGradient(colors: [ink.opacity(0.4 * (0.55 + 0.45 * s.strength)), ink.opacity(0.14), ink.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: 62))
            .frame(width: 124, height: 124)
            .opacity(dim ? 0.15 : 1)
            .allowsHitTesting(false)
    }

    private func pin(_ s: Spot, dim: Bool) -> some View {
        let on = selected == s.id
        let ink = Self.ink(s.lead)
        return ZStack {
            if on {
                VStack(alignment: .leading, spacing: 1) {
                    Text((s.lead.isEmpty ? "No reading" : s.lead) + (s.count > 1 ? " · \(s.count) moments" : "")).font(Theme.Figtree.font(size: 13, weight: .medium))
                        .foregroundStyle(ink.mix(with: .black, by: 0.35))
                    Text([s.when.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), s.place].compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.Figtree.font(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .fixedSize()
                .offset(y: -40 - 2.5 * CGFloat(min(s.count, 5)))
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
            // A single stem from the garden (April, Nov 20): the leading trigger's flower, standing on the spot.
            // Plain dots (April, Nov 20): a solid circle in the trigger's ink, the count inside, sized by count,
            // like Apple Maps' clusters. The garden lives on home; the map stays a map.
            let d = min(44, 22 + 5 * CGFloat(s.count - 1))
            ZStack {
                Circle().fill(ink)
                Circle().strokeBorder(.white, lineWidth: 2)
                if s.count > 1 {
                    Text("\(s.count)").font(Theme.Figtree.font(size: d * 0.42, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .frame(width: d, height: d)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        }
        .opacity(dim ? 0.25 : 1)
        .onTapGesture { withAnimation(Theme.snap) { selected = on ? nil : s.id } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.lead.isEmpty ? "No reading" : s.lead), \(s.when.formatted(date: .abbreviated, time: .omitted))\(s.place.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(.isButton)
    }

    /// The triggers on the map, most moments first; tap one to see only its places.
    private func key(_ all: [Spot]) -> some View {
        let counts = Dictionary(grouping: all.filter { !$0.lead.isEmpty }, by: \.lead).mapValues(\.count)
        let order = counts.sorted { $0.value > $1.value }.map(\.key)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(order, id: \.self) { k in
                    let on = only == k
                    Button { withAnimation(Theme.snap) { only = on ? nil : k } } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Self.ink(k)).frame(width: 10, height: 10)
                            Text(k).font(Theme.Figtree.font(size: 14, weight: .medium))
                        }
                        .foregroundStyle(on ? Color.white : .primary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(on ? Color.black : Color(uiColor: .secondarySystemGroupedBackground)))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    static func ink(_ lead: String) -> Color {
        switch lead {
        case "Exercise": Color(red: 0.93, green: 0.56, blue: 0.36)
        case "Inside": Color(red: 0.62, green: 0.58, blue: 0.54)
        case "": Color(white: 0.7)
        default: AirBlanket.ink(lead)
        }
    }

    /// "Mostly pollen, around Forest Park."
    static func headline(_ all: [Spot]) -> String {
        let counts = Dictionary(grouping: all.filter { !$0.lead.isEmpty }, by: \.lead).mapValues(\.count)
        guard let top = counts.max(by: { $0.value < $1.value }) else { return "Your places" }
        let near = Dictionary(grouping: all.filter { $0.lead == top.key }.compactMap(\.place), by: { $0 }).mapValues(\.count)
            .max { $0.value < $1.value }?.key
        let what = top.key == "PM2.5" ? "fine particles" : top.key == "Inside" ? "inside" : top.key.lowercased()
        return "Mostly \(what)" + (near.map { ", around \($0)" } ?? "") + "."
    }

    // MARK: Sample

    static let sampleRegion = MKCoordinateRegion(center: .init(latitude: 38.622, longitude: -90.238),
                                                 latitudinalMeters: 11000, longitudinalMeters: 11000)

    /// A made-up St. Louis (April, Nov 20): pollen in the parks and the garden, fine particles by the highways
    /// and downtown, ozone on summer afternoons in the open, humidity by the river, cold at the bus stop,
    /// a run in Forest Park, a dusty office. Never stored, never in patterns.
    static let sample: [Spot] = {
        let places: [(String, Double, Double, String, Double)] = [
            ("Forest Park", 38.6365, -90.2850, "Pollen", 0.95), ("Forest Park", 38.6400, -90.2930, "Pollen", 0.8),
            ("Forest Park", 38.6330, -90.2790, "Exercise", 0.8), ("Forest Park", 38.6420, -90.2820, "Pollen", 0.7),
            ("Missouri Botanical Garden", 38.6128, -90.2594, "Pollen", 0.9), ("Missouri Botanical Garden", 38.6150, -90.2620, "Pollen", 0.75),
            ("Tower Grove Park", 38.6070, -90.2560, "Ozone", 0.8), ("Tower Grove Park", 38.6090, -90.2500, "Pollen", 0.7),
            ("Tower Grove Park", 38.6050, -90.2610, "Ozone", 0.65),
            ("Downtown", 38.6270, -90.1940, "PM2.5", 0.9), ("Downtown", 38.6300, -90.1990, "PM2.5", 0.75),
            ("I-64 at Kingshighway", 38.6290, -90.2640, "PM2.5", 0.85), ("I-64 at Kingshighway", 38.6305, -90.2600, "PM2.5", 0.7),
            ("Riverfront", 38.6240, -90.1840, "Humidity", 0.85), ("Riverfront", 38.6210, -90.1870, "Humidity", 0.7),
            ("Cortex, Midtown", 38.6400, -90.2510, "Inside", 0.6), ("Cortex, Midtown", 38.6380, -90.2480, "Cold air", 0.75),
            ("Central West End", 38.6450, -90.2620, "Temperature", 0.8), ("Central West End", 38.6470, -90.2570, "Cold air", 0.7),
            ("The Hill", 38.6150, -90.2770, "Pressure", 0.75), ("Soulard", 38.6040, -90.2110, "Ozone", 0.7),
            ("Tower Grove South", 38.5980, -90.2560, "Wind", 0.7), ("Tower Grove South", 38.5960, -90.2490, "Pollen", 0.6),
        ]
        let now = Date()
        return places.enumerated().map { i, p in
            var spot = Spot(id: "sample-\(i)", coordinate: .init(latitude: p.1, longitude: p.2), lead: p.3, strength: p.4,
                            when: now.addingTimeInterval(-Double(i) * 86_400 * 9), place: p.0, rescue: i % 5 != 4)
            spot.inside = p.3 == "Inside" || p.0 == "Cortex, Midtown" || (p.0 == "Downtown" && i % 2 == 0)
            return spot
        }
    }()
}

/// Wraps a model id so it can sit in @State.
struct PersistentIdentifierBox: Equatable {
    let id: PersistentIdentifier
}

/// The Moments tab's mark (owner, Nov 13): nine small rings in a square, a grid of moments.
struct MomentsGridIcon: View {
    var size: CGFloat = 22
    var body: some View {
        let cell = size / 3
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().strokeBorder(lineWidth: cell * 0.2)
                            .frame(width: cell * 0.78, height: cell * 0.78)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The Home tab's mark (owner, Nov 13): one of Home's fans, open on its stem, in outline like the other tab icons.
struct FanIcon: View {
    var size: CGFloat = 24
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, lw = w * 0.075
            let pivot = CGPoint(x: w / 2, y: w * 0.56)
            let r = w * 0.44
            let spread = 150.0 * .pi / 180
            // The fan: a wedge with a cloud rim of three soft bumps.
            var fan = Path()
            fan.move(to: pivot)
            let steps = 60, bumps = 3.0
            for j in 0...steps {
                let t = Double(j) / Double(steps)
                let a = -Double.pi / 2 - spread / 2 + spread * t
                let p = (t * bumps).truncatingRemainder(dividingBy: 1)
                let rr = r * CGFloat(0.86 + 0.14 * (1 - pow(2 * p - 1, 2)).squareRoot())
                fan.addLine(to: CGPoint(x: pivot.x + cos(a) * rr, y: pivot.y + sin(a) * rr))
            }
            fan.closeSubpath()
            ctx.stroke(fan, with: .foreground, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            // The stem.
            var stem = Path()
            stem.move(to: pivot)
            stem.addLine(to: CGPoint(x: pivot.x, y: w * 0.98))
            ctx.stroke(stem, with: .foreground, style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Home's little map (owner, Nov 19): only where one moment was logged, a small circle round it and its pill.
/// It follows the playhead. Still (no pan or zoom), so it sits inside the page's scroll.
struct MomentPlaceMap: View {
    let event: LogEvent?
    @State private var position: MapCameraPosition = .automatic

    private var coordinate: CLLocationCoordinate2D? {
        guard let e = event, let la = e.latitude, let lo = e.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: la, longitude: lo)
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            if let c = coordinate, event != nil {
                MapCircle(center: c, radius: 220)
                    .foregroundStyle(Color.black.opacity(0.06))
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
                // Just the radius (April, Nov 20): no pill in the middle.
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .onAppear { recenter(animated: false) }
        .onChange(of: event?.persistentModelID) { _, _ in recenter(animated: true) }
    }

    private func recenter(animated: Bool) {
        guard let c = coordinate else { return }
        let region = MapCameraPosition.region(MKCoordinateRegion(center: c, latitudinalMeters: 900, longitudinalMeters: 900))
        if animated { withAnimation(Theme.smooth) { position = region } } else { position = region }
    }
}

/// One flower from home's garden, small, for the map (April, Nov 20: the same flower, not a new one). The fan
/// is drawn exactly as home draws it: opens 16°…360° with the reading, five-ish wide soft bumps on the rim
/// (0.93 + 0.07), ink deep at the pivot fading to 8% at the rim, on a thin stem in 70% ink.
struct MapFlower: View {
    let ink: Color
    /// How far the fan opens, 0…1.
    let open: Double
    var rescue = true

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width / 2, size.height * 0.42)
            let foot = CGPoint(x: size.width / 2, y: size.height)
            let o = min(1, max(0, (open - 0.85) / 0.15))
            let pivot = CGPoint(x: foot.x, y: r + 1)
            // As home: a full round's stem stops at its bottom edge.
            let top = CGPoint(x: pivot.x, y: pivot.y + r * 0.93 * o * o * (3 - 2 * o))
            var stem = Path(); stem.move(to: foot); stem.addQuadCurve(to: top, control: CGPoint(x: foot.x + 1, y: (foot.y + top.y) / 2))
            ctx.stroke(stem, with: .color(ink.opacity(0.7)), lineWidth: 0.8)
            let spread = (16 + 344 * open) * .pi / 180
            let bumps = max(2, Int((spread * 180 / .pi / 40).rounded()))
            let full = spread >= 2 * .pi - 0.01
            var w = Path()
            if !full { w.move(to: pivot) }
            for j in 0...120 {
                let t = Double(j) / 120
                let a = -Double.pi / 2 - spread / 2 + spread * t
                let p = (t * Double(bumps)).truncatingRemainder(dividingBy: 1)
                let rr = r * CGFloat(0.93 + 0.07 * (1 - pow(2 * p - 1, 2)).squareRoot())
                let q = CGPoint(x: pivot.x + cos(a) * rr, y: pivot.y + sin(a) * rr)
                if full && j == 0 { w.move(to: q) } else { w.addLine(to: q) }
            }
            w.closeSubpath()
            // On the map the fan sits on a scrap of paper, the same shape, so it reads as it does on home.
            ctx.fill(w, with: .color(Color(red: 0.97, green: 0.97, blue: 0.98).opacity(0.92)))
            ctx.fill(w, with: .radialGradient(Gradient(stops: [.init(color: ink, location: 0), .init(color: ink.opacity(0.55), location: 0.5),
                                                               .init(color: ink.opacity(0.08), location: 1)]),
                                              center: pivot, startRadius: 0, endRadius: r))
        }
    }
}
