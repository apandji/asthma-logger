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
/// feathered circle on the colour field with the kind, time and voice note beneath it.
struct FolderCard: View {
    let event: LogEvent
    let isCurrent: Bool
    /// The zoom-transition namespace: the details page grows out of the round map (open style) or the card.
    let zoom: Namespace.ID
    let onOpen: () -> Void
    var onOverview: () -> Void = {}

    @State private var pinch: CGFloat = 1
    @AppStorage(Crit.CardMarker.key) private var marker = Crit.CardMarker.quietTab
    @AppStorage(Crit.CardStyle.key) private var cardStyle = Crit.CardStyle.open
    @AppStorage(Crit.Header.key) private var headerStyle = Crit.Header.moment

    private var kindWord: String {
        event.moment == .rescue ? "Rescue" : event.moment == .maintenance ? "Standard" : "I'm okay"
    }

    var body: some View {
        Group {
            switch cardStyle {
            case .card: card.matchedTransitionSource(id: event.id, in: zoom)
            case .open: open
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

    /// The folder tab: bold (solid colour) or quiet (the card's own glass, a dot and a grey label).
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
    @Environment(\.colorScheme) private var scheme
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
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
            .task(id: "\(event.id)-\(scheme)-\(Int(geo.size.width))") {
                image = await MapSnapshots.image(for: event, size: geo.size, dark: scheme == .dark)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: image != nil)
    }
}

enum MapSnapshots {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for event: LogEvent, size: CGSize, dark: Bool) async -> UIImage? {
        guard let lat = event.latitude, let lon = event.longitude, size.width > 1, size.height > 1 else { return nil }
        let key = "\(event.id)-\(dark)-\(Int(size.width))x\(Int(size.height))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let options = MKMapSnapshotter.Options()
        options.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                     fromDistance: 1_400, pitch: 40, heading: 0)
        options.size = size
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        guard let snap = try? await MKMapSnapshotter(options: options).start() else { return nil }
        cache.setObject(snap.image, forKey: key)
        return snap.image
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
