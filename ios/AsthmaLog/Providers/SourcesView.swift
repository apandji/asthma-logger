import SwiftUI
import WeatherKit

/// Where everything felt air shows comes from, in one place: each source, what it gives, whether it's on, and
/// a link to it. Outside sources first (the air and weather), then what comes from you and this iPhone.
/// Reached from Settings, from a moment's Sources card, and from onboarding. Apple Weather's mark and legal
/// link are shown as Apple requires.
struct SourcesView: View {
    @State private var attribution: WeatherAttribution?

    struct Source: Identifiable {
        let name: String
        let gives: String
        let status: String
        let link: URL?
        var id: String { name }
    }

    /// The air and weather by how local they are (owner, Oct 19): modeled for everywhere, then monitors for
    /// the region, then the nearest monitor, then (later) sensors on the street. The more local, the better, when
    /// it's there.
    private var tiers: [(title: String, note: String, sources: [Source])] {
        [
            ("Modeled", "Estimated for every place from weather and satellite models. Always there, smoothed over an area.", [
                Source(name: "Apple Weather", gives: "Temperature, humidity, wind, rain and storms, now, in the past hours and 10 days ahead.",
                       status: "On", link: attribution?.legalPageURL),
                Source(name: "Ambee", gives: "Pollen (tree, grass, weed), and active wildfires nearby when the air looks smoky.",
                       status: Secrets.ambee == nil ? "Sample" : "On", link: URL(string: "https://www.getambee.com")),
            ]),
            ("Regional monitors", "Government monitors, read for the area around you. Reliable, but often miles away.", [
                Source(name: "AirNow (US EPA)", gives: "The air quality index and its forecast.",
                       status: Secrets.airNow == nil ? "Off" : "On", link: URL(string: "https://www.airnow.gov")),
            ]),
            ("The nearest monitor", "One named station, with its distance, so you can see how close it is.", [
                Source(name: "OpenAQ", gives: "Fine particles (PM2.5) and ozone from the nearest public monitor.",
                       status: Secrets.openAQ == nil ? "Off" : "On", link: URL(string: "https://openaq.org")),
            ]),
            ("Sensors on your street", "Low-cost sensors on homes and schools, often a block away. Not connected yet.", [
                Source(name: "PurpleAir", gives: "Fine particles from community sensors, corrected the way the EPA does.",
                       status: "Later", link: URL(string: "https://www.purpleair.com")),
            ]),
        ]
    }

    private let yours: [Source] = [
        Source(name: "Your inhaler presses", gives: "The felt button, Apple Watch or the +: when, which inhaler, how many puffs.", status: "", link: nil),
        Source(name: "Your location", gives: "Where each moment was, and the places you spend time (with Always location).", status: "", link: nil),
        Source(name: "Your voice notes", gives: "What you said, written down on this iPhone, and the tags you confirmed.", status: "", link: nil),
        Source(name: "Apple Health", gives: "Sleep, heart and breathing rate, steps, workouts and State of Mind, if you allowed it.", status: "", link: nil),
        Source(name: "Motion", gives: "Walking, running, driving or still.", status: "", link: nil),
        Source(name: "Calendar", gives: "What was on around a moment, if you allowed it.", status: "", link: nil),
    ]

    var body: some View {
        List {
            ForEach(tiers, id: \.title) { tier in
                Section {
                    ForEach(tier.sources) { row($0) }
                } header: {
                    Text(tier.title)
                } footer: {
                    Text(tier.note)
                }
            }
            if let a = attribution {
                Section {
                    HStack(spacing: 8) {
                        AsyncImage(url: a.combinedMarkDarkURL) { $0.resizable().scaledToFit() } placeholder: { Text(a.serviceName) }
                            .frame(height: 14)
                        Spacer()
                        Link("Legal", destination: a.legalPageURL).font(.footnote)
                    }
                } footer: {
                    Text("Outdoor readings only. Each reading in a moment's details says which source it came from and how far away.")
                }
            }
            Section {
                ForEach(yours) { row($0) }
            } header: {
                Text("From you and this iPhone")
            } footer: {
                Text("These stay on this iPhone. Only your location goes out, to the services above, with each request.")
            }
        }
        .navigationTitle("Where your data comes from")
        .navigationBarTitleDisplayMode(.inline)
        .task { attribution = try? await WeatherService.shared.attribution }
    }

    private func row(_ s: Source) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let link = s.link {
                    Link(destination: link) {
                        HStack(spacing: 4) { Text(s.name).font(.headline); Image(systemName: "arrow.up.right").font(.caption) }
                    }
                    .foregroundStyle(.primary)
                } else {
                    Text(s.name).font(.headline)
                }
                Spacer()
                if !s.status.isEmpty {
                    Text(s.status).font(.subheadline).foregroundStyle(s.status == "On" ? Color.primary : Theme.secondaryText)
                }
            }
            Text(s.gives).font(.subheadline).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
