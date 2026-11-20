import CoreLocation
import MapKit
import SwiftUI

/// "Somewhere else" (owner, Nov 19): where you were, picked on a map. It opens on the moment's own spot (or
/// near you); tap to drop the pin, then "Use this spot". Only the pin goes to Apple's geocoder, for its name.
struct MomentPlacePicker: View {
    let event: LogEvent
    let picked: (_ latitude: Double, _ longitude: Double, _ name: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pin: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var saving = false

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let pin { Marker("", coordinate: pin).tint(.black) }
                }
                .onTapGesture { p in
                    if let c = proxy.convert(p, from: .local) { withAnimation(Theme.smooth) { pin = c } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard let pin else { return }
                    saving = true
                    Task {
                        let name = await Self.name(pin)
                        picked(pin.latitude, pin.longitude, name)
                        dismiss()
                    }
                } label: {
                    Text(pin == nil ? "Tap the map where you were" : "Use this spot")
                        .font(Theme.ui(.body, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .foregroundStyle(pin == nil ? Color.secondary : .white)
                        .background(Capsule().fill(pin == nil ? Color.primary.opacity(0.06) : .black))
                }
                .disabled(pin == nil || saving)
                .padding(.horizontal, 20).padding(.bottom, 8)
            }
            .navigationTitle("Where were you?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(role: .close) { dismiss() } } }
            .onAppear {
                if let lat = event.latitude, let lon = event.longitude {
                    let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    pin = c
                    position = .region(MKCoordinateRegion(center: c, latitudinalMeters: 1500, longitudinalMeters: 1500))
                }
            }
        }
        .presentationDetents([.large])
        .environment(\.colorScheme, .light)
    }

    /// "Tower Grove South", or the city, for the pin.
    private static func name(_ c: CLLocationCoordinate2D) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude))
        guard let m = marks?.first else { return nil }
        return m.subLocality ?? m.name ?? m.locality
    }
}
