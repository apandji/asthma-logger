import MapKit
import SwiftData
import SwiftUI

/// A place to read the air for: here (the phone), or an address you typed, or a saved Home / Work.
/// Stored on the phone only; nothing but the search text goes to Apple's geocoder.
nonisolated struct SavedPlace: Codable, Hashable, Sendable {
    var name: String
    var lat: Double
    var lon: Double

    static func load(_ key: String) -> SavedPlace? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(SavedPlace.self, from: $0) }
    }

    func save(_ key: String) { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: key) }
    static func clear(_ key: String) { UserDefaults.standard.removeObject(forKey: key) }

    static let chosenKey = "place.chosen"
    static let homeKey = "place.home"
    static let workKey = "place.work"

    /// Washington University in St. Louis, Danforth campus: the default Work until one is saved.
    static let washU = SavedPlace(name: "WashU · Danforth Campus", lat: 38.6488, lon: -90.3108)

    /// A guess at Home from your own moments: where you most often were between 9 pm and 8 am.
    /// Computed on the phone from real (not demo) moments with a location; never written anywhere.
    static func inferredHome(from events: [LogEvent]) -> SavedPlace? {
        let cal = Calendar.current
        let night = events.filter { e in
            guard !e.isDemo, e.latitude != nil, e.longitude != nil else { return false }
            let h = cal.component(.hour, from: e.loggedAt)
            return h >= 21 || h < 8
        }
        guard night.count >= 2 else { return nil }
        // Bucket to ~100 m and take the busiest bucket's centre.
        let buckets = Dictionary(grouping: night) { "\(Int($0.latitude! * 1000)),\(Int($0.longitude! * 1000))" }
        guard let best = buckets.values.max(by: { $0.count < $1.count }) else { return nil }
        let lat = best.map { $0.latitude! }.reduce(0, +) / Double(best.count)
        let lon = best.map { $0.longitude! }.reduce(0, +) / Double(best.count)
        return SavedPlace(name: best.first?.placeName ?? "Home", lat: lat, lon: lon)
    }
}

/// "Where?": here, Home, Work, or search an address or city. Picking one reloads the sky and the
/// forecast for that spot, so you can see what tomorrow looks like somewhere else.
struct PlacePicker: View {
    @Binding var chosen: SavedPlace?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SavedPlace] = []
    @State private var searching = false
    @State private var home = SavedPlace.load(SavedPlace.homeKey)
    @State private var work = SavedPlace.load(SavedPlace.workKey) ?? SavedPlace.washU
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Here", icon: "location.fill", place: nil, selected: chosen == nil)
                    if let home { row("Home", icon: "house.fill", place: home, selected: chosen == home) }
                    row("Work", icon: "building.2.fill", place: work, selected: chosen == work)
                } footer: {
                    if home == nil { Text("Home appears once a couple of moments have been logged at night.") }
                }
                Section(results.isEmpty ? "" : "Results") {
                    ForEach(results, id: \.self) { p in
                        row(p.name, icon: "mappin", place: p, selected: chosen == p)
                            .swipeActions(edge: .trailing) { saveActions(p) }
                    }
                    if !results.isEmpty {
                        Text("Swipe a result to save it as Home or Work.").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .searchable(text: $query, prompt: "Address or city")
            .onSubmit(of: .search) { Task { await search() } }
            .overlay { if searching { ProgressView() } }
            .navigationTitle("Where?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { if home == nil { home = SavedPlace.inferredHome(from: events) } }
        }
    }

    private func row(_ title: String, icon: String, place: SavedPlace?, selected: Bool) -> some View {
        Button {
            chosen = place
            place?.save(SavedPlace.chosenKey)
            if place == nil { SavedPlace.clear(SavedPlace.chosenKey) }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 22).foregroundStyle(Theme.secondaryText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let place, title != place.name { Text(place.name).font(.caption).foregroundStyle(Theme.secondaryText) }
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Theme.tint) }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func saveActions(_ p: SavedPlace) -> some View {
        Button("Home", systemImage: "house") { home = p; p.save(SavedPlace.homeKey) }
            .tint(Theme.standard)
        Button("Work", systemImage: "building.2") { work = p; p.save(SavedPlace.workKey) }
            .tint(.indigo)
    }

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searching = true
        defer { searching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        guard let response = try? await MKLocalSearch(request: request).start() else { results = []; return }
        results = response.mapItems.prefix(8).map { item in
            let c = item.location.coordinate
            let city = item.addressRepresentations?.cityWithContext
            // "Boston, MA", not "Boston, Boston, MA".
            let name = switch (item.name, city) {
            case (let n?, let c?) where c.hasPrefix(n): c
            case (let n?, let c?): "\(n), \(c)"
            case (let n?, nil): n
            case (nil, let c?): c
            default: "Place"
            }
            return SavedPlace(name: name, lat: c.latitude, lon: c.longitude)
        }
    }
}
