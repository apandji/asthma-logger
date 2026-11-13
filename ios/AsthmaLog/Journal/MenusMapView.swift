import MapKit
import SwiftData
import SwiftUI

/// Menus look, Map tab (owner, Nov 13): where your moments were, on a quiet map. Each moment is a pill in one
/// ink, as on the timeline: rescue filled, standard an outline. Tap one for when and where. Coordinates stay on
/// the phone; the map tiles are Apple's.
struct MenusMapView: View {
    let events: [LogEvent]
    @State private var selected: PersistentIdentifierBox?

    /// Inhaler moments that have a place.
    private var placed: [LogEvent] {
        events.filter { ($0.moment == .rescue || $0.moment == .maintenance) && $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        Map(initialPosition: .automatic) {
            ForEach(placed, id: \.persistentModelID) { e in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: e.latitude!, longitude: e.longitude!), anchor: .bottom) {
                    pin(e)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass() }
        .overlay(alignment: .top) {
            if placed.isEmpty {
                Text("Moments you log show up here, where they happened.")
                    .font(Theme.Figtree.font(.subheadline))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
    }

    private func pin(_ e: LogEvent) -> some View {
        let on = selected?.id == e.persistentModelID
        return VStack(spacing: 6) {
            if on {
                VStack(spacing: 1) {
                    Text(e.loggedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                        .font(Theme.Figtree.font(size: 13, weight: .medium))
                    if let place = e.placeName {
                        Text(place).font(Theme.Figtree.font(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .fixedSize()
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
            // The timeline's pill: rescue filled, standard an outline, on a white disc so it reads on the map.
            ZStack {
                Circle().fill(.white).frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                if e.moment == .rescue {
                    Capsule().fill(Color.black).frame(width: 7, height: 15)
                } else {
                    Capsule().strokeBorder(Color.black, lineWidth: 1.4).frame(width: 7, height: 15)
                }
            }
        }
        .onTapGesture {
            withAnimation(Theme.snap) { selected = on ? nil : PersistentIdentifierBox(id: e.persistentModelID) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(e.moment == .rescue ? "Rescue" : "Standard"), \(e.loggedAt.formatted(date: .abbreviated, time: .shortened))\(e.placeName.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(.isButton)
    }
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
