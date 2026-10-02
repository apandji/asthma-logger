import AsthmaCore
import MapKit
import SwiftData
import SwiftUI

struct EventDetailView: View {
    @Bindable var event: LogEvent
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LogService.self) private var services
    @State private var isRetrying = false

    var body: some View {
        Form {
            Section {
                LabeledContent("What", value: event.kind == .attack ? "Used inhaler" : "I'm okay")
                LabeledContent("When", value: event.loggedAt.formatted(date: .abbreviated, time: .shortened))
                if event.kind == .attack {
                    LabeledContent("Apple Health", value: event.healthSampleID == nil ? "Not saved" : "Saved")
                }
            }

            Section("Where") {
                if let lat = event.latitude, let lon = event.longitude {
                    let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    Map(initialPosition: .region(MKCoordinateRegion(center: center, latitudinalMeters: 800, longitudinalMeters: 800))) {
                        Marker("", systemImage: "lungs.fill", coordinate: center).tint(Theme.accent)
                    }
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    if let acc = event.horizontalAccuracy {
                        LabeledContent("Accuracy", value: "±\(Int(acc)) m")
                    }
                } else {
                    Text("No location").foregroundStyle(Theme.secondaryText)
                }
                Picker("Indoors or outdoors", selection: $event.indoorConfirmedRaw) {
                    Text(guessLabel).tag(String?.none)
                    Text("Indoors").tag(String?.some(IndoorOutdoor.indoor.rawValue))
                    Text("Outdoors").tag(String?.some(IndoorOutdoor.outdoor.rawValue))
                }
                if event.indoorConfirmedRaw == nil, !event.indoorGuessReasons.isEmpty {
                    Text("Guessed from: " + event.indoorGuessReasons.joined(separator: ", "))
                        .font(Theme.caption).foregroundStyle(Theme.secondaryText)
                }
            }

            Section {
                if let c = event.conditions {
                    ForEach(Array(c.observations.enumerated()), id: \.offset) { _, o in
                        Text(ObservationCopy.line(o)).font(Theme.caption)
                    }
                    ForEach(Array(c.alerts.enumerated()), id: \.offset) { _, a in
                        Label("\(a.name) · \(a.source)", systemImage: "exclamationmark.triangle")
                            .font(Theme.caption)
                    }
                    // Source errors are for debugging, not for reading every time: one line, details on tap.
                    if !c.errors.isEmpty {
                        DisclosureGroup {
                            ForEach(c.errors, id: \.self) { Text($0).font(Theme.caption).foregroundStyle(Theme.secondaryText) }
                        } label: {
                            Text(c.observations.isEmpty ? "Couldn't get outdoor conditions" : "Some sources didn't load")
                                .font(Theme.caption)
                                .foregroundStyle(c.observations.isEmpty ? Color.orange : Theme.secondaryText)
                        }
                    }
                } else if let err = event.envError {
                    // No conditions at all (e.g. location off): the message says what to do, so keep it visible.
                    Text(err).font(Theme.caption).foregroundStyle(.orange)
                }
                if event.envStatus != .ready && Date().timeIntervalSince(event.loggedAt) < 3600 {
                    Button(isRetrying ? "Retrying…" : "Retry") {
                        isRetrying = true
                        Task {
                            await services.enrich(event)
                            try? context.save()
                            isRetrying = false
                        }
                    }
                    .disabled(isRetrying)
                }
            } header: {
                Text("Outdoor conditions")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Outdoor air near you — not indoor air, not a diagnosis.")
                    WeatherAttributionView()
                }
            }

            Section {
                Button("Delete log", role: .destructive) {
                    Task {
                        await services.delete(event, in: context)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(event.loggedAt.formatted(date: .omitted, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var guessLabel: String {
        guard let g = event.indoorGuess, g != .unknown else { return "Not sure" }
        let conf = event.indoorGuessConfidenceRaw.map { " (\($0))" } ?? ""
        return "Auto: \(g == .indoor ? "likely indoors" : "likely outdoors")\(conf)"
    }
}
