import AsthmaCore
import SwiftData
import SwiftUI

/// Patterns (what showed up more on inhaler days) and the look-ahead (days that resemble them).
struct InsightsView: View {
    @Environment(LogService.self) private var services
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]
    @AppStorage(Prefs.narratorStyle) private var styleScore = NarratorStyle.defaultScore
    @AppStorage(Prefs.useOnDeviceModel) private var useModel = true
    @AppStorage(Prefs.useDemoData) private var demo = false
    @State private var model = InsightsModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    if demo {
                        Chip(text: "Demo data — turn off in Settings", color: Theme.ink2)
                    }
                    patternCard
                    lookAheadCard
                    evidenceCard
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compares the times you used your inhaler with your I'm okay moments. Outdoor air only. Not medical advice, and not a prediction of an attack.")
                        WeatherAttributionView()
                    }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.padding)
            }
            .background(Theme.background)
            .navigationTitle("Insights")
            .settingsToolbar()
            .task(id: dataKey) {
                model.rebuild(events: events, demo: demo)
                await model.narrate(styleScore: styleScore, useModel: useModel)
            }
            .task(id: forecastKey) {
                await loadForecast()
            }
            .refreshable {
                model.rebuild(events: events, demo: demo)
                await model.narrate(styleScore: styleScore, useModel: useModel)
                await loadForecast()
            }
        }
    }

    // MARK: Cards

    private var patternCard: some View {
        Card(title: "Your pattern", systemImage: "sparkles") {
            if let p = model.progress, !p.isMet {
                learning(p)
            } else if let n = model.narration {
                Text(n.headline).font(Theme.headlineSerif)
                Text(n.caveat).font(Theme.caption).foregroundStyle(Theme.secondaryText)
                HStack {
                    Chip(text: n.source == .onDevice ? "Apple Intelligence · \(NarratorStyle(score: styleScore).label)" : "Template",
                         color: n.source == .onDevice ? Theme.accent : Theme.secondaryText)
                    Spacer()
                }
                if let note = n.note {
                    Text(note).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
            } else {
                ProgressView()
            }
        }
    }

    private var lookAheadCard: some View {
        Card(title: "Looking ahead", systemImage: "calendar") {
            if let p = model.progress, !p.isMet {
                Text("Until felt air knows your pattern, this only shows general outdoor alerts.")
                    .font(Theme.caption).foregroundStyle(Theme.secondaryText)
            }
            if model.isLoadingForecast && model.days.isEmpty {
                ProgressView()
            }
            ForEach(model.days) { day in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(day.day.formatted(.dateTime.weekday(.abbreviated).month().day()))
                            .font(Theme.body.weight(.semibold))
                        Spacer()
                        if day.isPersonal {
                            Chip(text: day.band.rawValue.capitalized, color: color(day.band))
                        } else if !day.genericHazards.isEmpty {
                            Chip(text: "Heads-up", color: Theme.accent)
                        }
                    }
                    ForEach(day.windows) { w in
                        Text(OutlookCopy.headline(w, timeRange: timeRange(w))).font(Theme.caption)
                        ForEach(OutlookCopy.evidence(w), id: \.self) {
                            Text($0).font(.caption2).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    if let line = OutlookCopy.coldStart(day.genericHazards) {
                        Text(line).font(Theme.caption)
                    }
                    if day.leadHours > 30 {
                        Text("Further out — less certain.").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.vertical, 4)
            }
            if let note = model.forecastNote {
                Text(note).font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var evidenceCard: some View {
        Card(title: "Evidence", systemImage: "tablecells") {
            let c = model.frameCount
            Text("\(c.attacks) inhaler logs · \(c.baselines) I'm okay moments" + (c.skipped > 0 ? " · \(c.skipped) without conditions" : ""))
                .font(Theme.caption).foregroundStyle(Theme.secondaryText)
            if let rows = model.report?.rows.prefix(8), !rows.isEmpty {
                ForEach(Array(rows)) { r in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading) {
                            Text("\(Bins.label(r.bin)) · \(r.level)")
                            Text("\(r.attacksWith) of \(r.nAttacks) inhaler · \(r.baselinesWith) of \(r.nBaselines) usual")
                                .font(Theme.caption).foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Lift.format(r.lift))×").font(Theme.number)
                            Text(r.gated ? "Pattern" : "Not enough yet")
                                .font(.caption2)
                                .foregroundStyle(r.gated ? Theme.accent : Theme.secondaryText)
                        }
                    }
                }
            } else {
                Text("Log each time you use your inhaler. felt air adds I'm okay moments on its own.").font(Theme.caption)
            }
        }
    }

    /// Before the sample gate: no sentence to read yet, just honest progress.
    @ViewBuilder private func learning(_ p: GateProgress) -> some View {
        Text("Still learning your pattern").font(Theme.headline)
        progressRow("Times you used your inhaler", p.attacks, p.minAttacks)
        progressRow("I'm okay moments", p.baselines, p.minBaselines)
        Text("I'm okay moments are added automatically when you open the app. Outdoor air only, not a diagnosis.")
            .font(Theme.caption).foregroundStyle(Theme.secondaryText)
    }

    private func progressRow(_ label: String, _ n: Int, _ goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(min(n, goal)) of \(goal)").font(Theme.number).foregroundStyle(Theme.secondaryText)
            }
            .font(Theme.caption)
            ProgressView(value: Double(min(n, goal)), total: Double(goal)).tint(Theme.accent)
        }
    }

    // MARK: Helpers

    private var dataKey: String {
        let ready = events.filter { $0.conditionsData != nil }.count
        return "\(events.count)-\(ready)-\(demo)-\(styleScore)-\(useModel)"
    }

    private var forecastKey: String { "\(demo)-\(events.last?.id.uuidString ?? "none")" }

    /// Home place isn't learned yet, so the look-ahead uses the most recent logged spot.
    private func loadForecast() async {
        if let e = events.last(where: { $0.latitude != nil }), let lat = e.latitude, let lon = e.longitude {
            await model.loadForecast(latitude: lat, longitude: lon, placeLabel: "your last logged spot")
        } else if let fix = try? await services.location.currentLocation() {
            await model.loadForecast(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                     placeLabel: "where you are now")
        }
    }

    private func timeRange(_ w: RiskWindow) -> String {
        "\(w.start.formatted(date: .omitted, time: .shortened))–\(w.end.formatted(date: .omitted, time: .shortened))"
    }

    private func color(_ band: RiskBand) -> Color {
        switch band {
        case .elevated: Theme.elevated
        case .usual: Theme.usual
        case .quiet: Theme.quiet
        }
    }
}
