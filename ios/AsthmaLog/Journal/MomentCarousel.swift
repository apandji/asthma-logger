import AsthmaCore
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

/// The Journal's moments in a row you swipe through, the newest in the middle. Tap or pinch one open
/// for everything about it; pinch in and they shrink into dots on the calendar (shared `morph` ids).
struct MomentCarousel: View {
    let events: [LogEvent]
    @Binding var selectedID: UUID?
    let namespace: Namespace.ID
    let morph: Namespace.ID
    var onOverview: () -> Void = {}
    let onOpen: (LogEvent) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(events) { e in
                    FolderCard(event: e, isCurrent: e.id == selectedID, zoom: namespace, onOpen: { onOpen(e) }, onOverview: onOverview)
                        .matchedGeometryEffect(id: e.id, in: morph)
                        .containerRelativeFrame(.horizontal) { w, _ in w * 0.76 }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                .opacity(phase.isIdentity ? 1 : 0.35)
                        }
                        .id(e.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedID, anchor: .center)
        .contentMargins(.horizontal, 48, for: .scrollContent)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
    }
}

/// One moment. Card style: frosted glass with a quiet tab. Open style: no card, just the map in a
/// feathered circle on the color field with the kind, time and voice note beneath it.
struct FolderCard: View {
    let event: LogEvent
    let isCurrent: Bool
    /// The zoom-transition namespace: the details page grows out of the round map (open style) or the card.
    let zoom: Namespace.ID
    let onOpen: () -> Void
    var onOverview: () -> Void = {}

    @State private var pinch: CGFloat = 1
    @AppStorage(Crit.CardMarker.key) private var marker = Crit.CardMarker.quietTab
    @AppStorage(Crit.CardStyle.key) private var cardStyle = Crit.CardStyle.panel
    @AppStorage(Crit.Header.key) private var headerStyle = Crit.Header.moment

    private var kindWord: String {
        event.moment == .rescue ? "Rescue" : event.moment == .maintenance ? "Standard" : "I'm okay"
    }

    var body: some View {
        Group {
            switch cardStyle {
            case .card: card.matchedTransitionSource(id: event.id, in: zoom)
            case .open, .panel: open
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .scaleEffect(pinch)
        .gesture(
            MagnifyGesture()
                .onChanged { v in pinch = min(1.12, max(0.9, v.magnification)) }
                .onEnded { v in
                    withAnimation(.snappy) { pinch = 1 }
                    if v.magnification > 1.08 { onOpen() } else if v.magnification < 0.85 { onOverview() }
                }
        )
        .task { await PlaceNames.lookUp(event) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open details", onOpen)
    }

    // MARK: Open (no card)

    private var open: some View {
        VStack(spacing: 14) {
            Group {
                if event.latitude != nil {
                    MomentMap(event: event).allowsHitTesting(false)
                } else {
                    Rectangle().fill(.white.opacity(0.08))
                        .overlay { Image(systemName: "location.slash").foregroundStyle(Theme.secondaryText) }
                }
            }
            .frame(width: 240, height: 240)
            // A feathered edge: the place fades into the sky rather than sitting in a frame. The fade is
            // relative to the frame (so it scales with pinches and the calendar morph), and a circular
            // clip underneath guarantees the square map never shows at its corners.
            .clipShape(Circle())
            .mask(EllipticalGradient(colors: [.black, .black, .clear], center: .center,
                                     startRadiusFraction: 0, endRadiusFraction: 0.5))
            .compositingGroup()
            .matchedTransitionSource(id: event.id, in: zoom) { $0.clipShape(RoundedRectangle(cornerRadius: 120)) }
            HStack(spacing: 6) {
                MomentDot(moment: event.moment, size: 8)
                Text("\(kindWord) · \(time)").font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.primary.opacity(0.9))
            VoiceNoteButton(event: event, compact: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if marker == .boldTab || marker == .quietTab { tab }
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    if marker == .dot {
                        HStack(spacing: 6) {
                            MomentDot(moment: event.moment, size: 8)
                            Text(kindWord).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.bottom, 2)
                    }
                    Text(whenWhere).font(.headline).multilineTextAlignment(.leading)
                    if headerStyle != .moment {
                        Text(event.airLine).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if event.latitude != nil {
                    MomentMap(event: event)
                        .frame(height: 150)
                        .clipShape(.rect(cornerRadius: 16, style: .continuous))
                        .allowsHitTesting(false)
                } else {
                    Label("No location for this one", systemImage: "location.slash")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }

                VoiceNoteButton(event: event)
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if marker == .glow {
                    LinearGradient(colors: [tabColor.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                }
            }
            .frostedCard()
            .overlay(alignment: .top) {
                if marker == .boldTab {
                    UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                        .fill(tabColor).frame(height: 3).padding(.horizontal, 1)
                }
            }
        }
    }

    /// The folder tab: bold (solid color) or quiet (the card's own glass, a dot and a grey label).
    private var tab: some View {
        HStack {
            Spacer()
            if marker == .boldTab {
                Text(kindWord.uppercased())
                    .font(.caption.weight(.semibold)).tracking(1)
                    .foregroundStyle(event.moment == .okay ? .primary : Color.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(tabColor, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
            } else {
                HStack(spacing: 6) {
                    MomentDot(moment: event.moment, size: 7)
                    Text(kindWord).font(.caption.weight(.medium)).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
            }
        }
        .padding(.trailing, 18)
    }

    private var tabColor: Color {
        switch event.moment {
        case .rescue: Theme.rescue
        case .maintenance: Theme.standard
        case .okay: Color.secondary.opacity(0.35)
        }
    }

    private var time: String { event.loggedAt.formatted(date: .omitted, time: .shortened) }

    /// "11:48 PM in University City, MO", with the day when it isn't today.
    private var whenWhere: String {
        let cal = Calendar.current
        let day = cal.isDateInToday(event.loggedAt) ? "" : cal.isDateInYesterday(event.loggedAt) ? "Yesterday, "
            : event.loggedAt.formatted(.dateTime.weekday(.wide)) + ", "
        let place = event.placeName.map { " in \($0)" } ?? ""
        return day + time + place
    }
}

/// Where the moment was logged, as a still map image (MKMapSnapshotter): cheap to scale and animate,
/// unlike a live map. Cached per moment and appearance. A quiet placeholder without a location.
struct MomentMap: View {
    let event: LogEvent
    var snapshotSize = CGSize(width: 520, height: 520)
    /// Force dark (the black Journal page) so it matches the prefetched maps whatever the system look.
    var forceDark = false
    /// The faint map under the sky doesn't need full resolution, and draws much faster without it.
    var scale: CGFloat = 3
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?

    private var dark: Bool { forceDark || scheme == .dark }

    var body: some View {
        // A map that's already drawn shows on the first frame, with no fade.
        let shown = image ?? MapSnapshots.cached(for: event, size: snapshotSize, dark: dark, scale: scale)
        GeometryReader { geo in
            ZStack {
                if let shown {
                    Image(uiImage: shown).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .transition(.opacity)
                    Circle()
                        .fill(event.moment == .rescue ? Theme.rescue : event.moment == .maintenance ? Theme.standard : .secondary)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                } else if event.latitude == nil {
                    Rectangle().fill(.quaternary)
                        .overlay { Label("No location", systemImage: "location.slash").font(.footnote).foregroundStyle(Theme.secondaryText) }
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .task(id: "\(event.id)-\(dark)") {
                guard shown == nil else { return }
                // One generous size, cropped to fit: the view can grow and shrink (the zoom) without
                // asking for a new snapshot every frame.
                image = await MapSnapshots.image(for: event, size: snapshotSize, dark: dark, scale: scale)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: image != nil)
    }
}

enum MapSnapshots {
    private static let cache = NSCache<NSString, UIImage>()
    /// Snapshots already on their way, so the view and the prefetch never draw the same map twice.
    private static var inFlight: [NSString: Task<UIImage?, Never>] = [:]
    /// One snapshot at a time: run concurrently, MKMapSnapshotter sometimes ignores the requested
    /// dark appearance and returns a light map.
    private static let queue = SnapshotQueue()

    private static func key(_ id: String, _ size: CGSize, _ dark: Bool, _ scale: CGFloat) -> NSString {
        "\(id)-\(dark ? "dark" : "light")-\(Int(size.width))x\(Int(size.height))@\(scale)" as NSString
    }

    /// A map that's already drawn, without waiting: lets a view show it on its first frame.
    static func cached(for event: LogEvent, size: CGSize, dark: Bool, scale: CGFloat = 3) -> UIImage? {
        cached(id: event.id.uuidString, size: size, dark: dark, scale: scale)
    }

    static func cached(id: String, size: CGSize, dark: Bool, scale: CGFloat = 3) -> UIImage? {
        cache.object(forKey: key(id, size, dark, scale))
    }

    static func image(for event: LogEvent, size: CGSize, dark: Bool, scale: CGFloat = 3) async -> UIImage? {
        guard let lat = event.latitude, let lon = event.longitude else { return nil }
        return await image(id: event.id.uuidString, latitude: lat, longitude: lon, size: size, dark: dark, scale: scale)
    }

    /// Any spot, keyed by `id` (a moment's id, or "here" for the live location).
    static func image(id: String, latitude lat: Double, longitude lon: Double, size: CGSize, dark: Bool, scale: CGFloat = 3) async -> UIImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let key = key(id, size, dark, scale)
        if let hit = cache.object(forKey: key) { return hit }
        if let running = inFlight[key] { return await running.value }
        let options = MKMapSnapshotter.Options()
        options.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                     fromDistance: 1_400, pitch: 40, heading: 0)
        options.size = size
        options.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        options.traitCollection = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: dark ? .dark : .light),
            UITraitCollection(displayScale: scale),
        ])
        let task = Task { await queue.run(options) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}

/// The map under a sky that has no moment behind it (right now, or a forecast hour).
struct PlaceMap: View {
    let id: String
    let latitude: Double
    let longitude: Double
    @State private var image: UIImage?

    var body: some View {
        let shown = image ?? MapSnapshots.cached(id: id, size: SkyPanel.mapSize, dark: true, scale: SkyPanel.mapScale)
        GeometryReader { geo in
            if let shown {
                Image(uiImage: shown).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                    .transition(.opacity)
            }
        }
        .task(id: id) {
            guard shown == nil else { return }
            image = await MapSnapshots.image(id: id, latitude: latitude, longitude: longitude,
                                             size: SkyPanel.mapSize, dark: true, scale: SkyPanel.mapScale)
        }
        .animation(.easeInOut(duration: 0.25), value: image != nil)
    }
}

/// Runs snapshots one after another (on the main actor, where the options are made).
@MainActor final class SnapshotQueue {
    private var tail: Task<UIImage?, Never>?

    func run(_ options: MKMapSnapshotter.Options) async -> UIImage? {
        let previous = tail
        let task = Task<UIImage?, Never> {
            _ = await previous?.value
            return try? await MKMapSnapshotter(options: options).start().image
        }
        tail = task
        return await task.value
    }
}

/// Record, stop, play: one voice note per moment.
struct VoiceNoteButton: View {
    let event: LogEvent
    /// Icon only (for the no-card style).
    var compact = false
    private var notes: VoiceNotes { .shared }
    @Environment(\.modelContext) private var context

    var body: some View {
        let recording = notes.recordingID == event.id
        let playing = notes.playingID == event.id
        Button {
            if recording {
                notes.stopRecording()
                try? context.save()
            } else if playing {
                notes.stopPlaying()
            } else if event.voiceNoteFile != nil {
                notes.play(event)
            } else {
                Task { _ = await notes.startRecording(for: event) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: recording ? "stop.fill" : playing ? "pause.fill" : event.voiceNoteFile != nil ? "play.fill" : "mic.fill")
                if !compact || recording {
                    Text(recording ? "Stop" : playing ? "Playing…" : event.voiceNoteFile != nil ? "Play voice note" : "Record a voice note")
                }
                if recording {
                    Capsule().fill(Theme.rescue).frame(width: 6 + CGFloat(notes.level) * 40, height: 6)
                        .animation(.linear(duration: 0.05), value: notes.level)
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, compact && !recording ? 12 : 16).padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if event.voiceNoteFile != nil {
                Button("Record again", systemImage: "mic") { Task { _ = await notes.startRecording(for: event) } }
            }
        }
    }
}

/// Reverse-geocodes a moment's coordinates once ("University City, MO") and keeps the result on it.
enum PlaceNames {
    static func lookUp(_ event: LogEvent) async {
        guard event.placeName == nil, let lat = event.latitude, let lon = event.longitude else { return }
        let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon))
        guard let m = marks?.first else { return }
        let city = m.locality ?? m.subAdministrativeArea
        event.placeName = [city, m.administrativeArea].compactMap { $0 }.joined(separator: ", ")
    }
}
