import CoreLocation
import MapKit
import SwiftUI

/// Where a moment was (owner, Nov 20: no pin dropping, "are we playing geo guesser"). It opens on what we
/// already know: where the moment was logged, or where the phone is now, shown on a small map. To change it,
/// search like Apple Maps: a place, a business or an address, with suggestions as you type. Only the search
/// text (and the area it's near) goes to Apple, as in Maps.
struct MomentPlacePicker: View {
    let event: LogEvent
    let picked: (_ latitude: Double, _ longitude: Double, _ name: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = Completer()
    @State private var query = ""
    /// What's shown and kept by Done: the moment's place, else the phone's.
    @State private var spot: Spot?
    /// The phone's location now, offered as "Current location" when it differs from the moment's.
    @State private var here: Spot?
    @State private var resolving = false

    struct Spot: Equatable {
        var coordinate: CLLocationCoordinate2D
        var name: String?
        var detail: String
        static func == (a: Spot, b: Spot) -> Bool {
            a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    if let spot {
                        Section {
                            Map(position: .constant(.region(MKCoordinateRegion(center: spot.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))),
                                interactionModes: []) {
                                Marker(spot.name ?? "", coordinate: spot.coordinate).tint(.black)
                            }
                            .frame(height: 170)
                            .listRowInsets(EdgeInsets())
                            row(spot, icon: "mappin.circle.fill", checked: true) { use(spot) }
                        }
                    } else {
                        Section { Label("Finding where you are…", systemImage: "location").foregroundStyle(.secondary) }
                    }
                    if let here, here != spot {
                        Section { row(here, icon: "location.circle.fill", checked: false) { use(here) } }
                    }
                } else {
                    Section {
                        ForEach(search.results, id: \.self) { r in
                            Button { choose(r) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title).foregroundStyle(.primary)
                                    if !r.subtitle.isEmpty { Text(r.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                                }
                            }
                        }
                        if search.results.isEmpty { Text("No places found yet").foregroundStyle(.secondary) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a place or address")
            .onChange(of: query) { _, q in search.query(q, near: spot?.coordinate ?? here?.coordinate) }
            .overlay { if resolving { ProgressView() } }
            .navigationTitle("Where were you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(role: .close) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { if let spot { use(spot) } else { dismiss() } }.disabled(spot == nil)
                }
            }
            .task { await prefill() }
        }
        .presentationDetents([.large])
        .environment(\.colorScheme, .light)
    }

    private func row(_ s: Spot, icon: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(checked ? Color.primary : Color.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name ?? "Unnamed place").foregroundStyle(.primary)
                    Text(s.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if checked { Image(systemName: "checkmark").foregroundStyle(.primary) }
            }
        }
    }

    /// The moment's own place first; the phone's location now, for "Current location" (and as the place when
    /// the moment has none).
    private func prefill() async {
        if let lat = event.latitude, let lon = event.longitude {
            let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            var name = event.placeName
            if name == nil { name = await Self.name(c) }
            spot = Spot(coordinate: c, name: name, detail: "Where it was logged")
        }
        if let loc = try? await LocationService().currentLocation(timeout: .seconds(4)) {
            let h = Spot(coordinate: loc.coordinate, name: await Self.name(loc.coordinate), detail: "Current location")
            here = h
            if spot == nil { spot = h }
        }
    }

    private func use(_ s: Spot) {
        picked(s.coordinate.latitude, s.coordinate.longitude, s.name)
        dismiss()
    }

    /// A suggestion becomes a place: Apple's search gives its coordinates and name.
    private func choose(_ r: MKLocalSearchCompletion) {
        resolving = true
        Task {
            defer { resolving = false }
            guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: r)).start().mapItems.first else { return }
            use(Spot(coordinate: item.location.coordinate, name: item.name ?? r.title, detail: r.subtitle))
        }
    }

    /// "Tower Grove South", or the street, or the city.
    private static func name(_ c: CLLocationCoordinate2D) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude))
        guard let m = marks?.first else { return nil }
        return m.name ?? m.subLocality ?? m.locality
    }
}

/// Apple Maps' suggestions as you type, near the moment.
@Observable
private final class Completer: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func query(_ q: String, near c: CLLocationCoordinate2D?) {
        if let c { completer.region = MKCoordinateRegion(center: c, latitudinalMeters: 50_000, longitudinalMeters: 50_000) }
        if q.trimmingCharacters(in: .whitespaces).isEmpty { results = []; completer.cancel() } else { completer.queryFragment = q }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}
