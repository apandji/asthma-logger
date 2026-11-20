import AsthmaCore
import SwiftUI

/// Under the fold on Home (owner, Nov 19): above it the garden says what matters, below it is everything felt
/// air holds about the moment on the playhead. The journal with the words that became tags marked, every
/// reading with where it came from (pollen opens to its species), the kind of day, and what the body was doing.
/// Words first; the detail is there for whoever scrolls or taps.
struct MomentFold: View {
    /// The moment on the playhead, when there is one (Now and forecast hours have only air).
    let event: LogEvent?
    let conditions: Conditions?
    let date: Date
    /// Combinations that passed the gate for this person, to say "one of yours".
    let yours: Set<Combination>
    /// Start a voice note: for this moment, or (nil) for a new manual moment when the playhead is on Now.
    var record: ((LogEvent?) -> Void)? = nil
    /// The playhead is on Now with no moment there: the journal card offers to start one.
    var canStartNew = false
    /// The pollen rows opened to their species.
    @State private var open: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let event { journal(event) } else if canStartNew, record != nil { card("Journal") { recordRow(nil) } }
            readings
            before
            kinds
            if let event { bodyCard(event) }
            card("What felt air can't see") {
                Text("Indoor air, and anything in the room with you. Every reading here is outdoors.")
                    .font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            Text("Outdoor air only. Not medical advice.")
                .font(Theme.ui(.footnote)).foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 4).padding(.top, 4)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Pieces

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.ui(.footnote, weight: .medium)).foregroundStyle(Theme.secondaryText)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    private func line(_ name: String, _ value: String, note: String? = nil, dim: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(Theme.ui(.subheadline, weight: .medium)).foregroundStyle(dim ? Theme.secondaryText : Color.primary)
                if let note { Text(note).font(Theme.ui(.caption)).foregroundStyle(Theme.secondaryText) }
            }
            Spacer(minLength: 8)
            Text(value).font(Theme.ui(.subheadline).monospacedDigit()).foregroundStyle(dim ? Theme.secondaryText : Color.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: Journal

    /// What was said, with the words that became confirmed tags marked, then the tags.
    private func journal(_ e: LogEvent) -> some View {
        let said = Self.transcript(e)
        return card("Journal") {
            if said.isEmpty && e.tags.isEmpty {
                if record != nil { recordRow(e) }
                else { Text("No note on this moment.").font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText) }
            } else {
                if !said.isEmpty {
                    Text(Self.marked(said, tags: e.tags)).font(Theme.ui(.body)).fixedSize(horizontal: false, vertical: true)
                }
                if !e.tags.isEmpty {
                    Text(e.tags.sorted().map(\.label).joined(separator: " · "))
                        .font(Theme.ui(.footnote, weight: .medium)).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private func recordRow(_ e: LogEvent?) -> some View {
        Button { record?(e) } label: {
            // The same row as a moment's page (April, Nov 20): "Add to journal" with the write icon, and the
            // same flow as the +, where you type, tap or speak.
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil").font(.title3).foregroundStyle(Color.primary).frame(width: 28)
                Text("Add to journal").font(Theme.ui(.body)).foregroundStyle(Color.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Add to journal")
        .accessibilityHint(e == nil ? "Starts a moment now and opens the journal" : "Opens the journal for this moment")
    }

    static func transcript(_ e: LogEvent) -> String {
        let notes = e.notes.sorted { $0.recordedAt < $1.recordedAt }.map(\.transcript).filter { !$0.isEmpty }
        return notes.isEmpty ? (e.voiceTranscript ?? "") : notes.joined(separator: " ")
    }

    /// The transcript with each phrase behind a confirmed tag marked (the keyword rules' own evidence).
    static func marked(_ text: String, tags: Set<JournalTag>) -> AttributedString {
        var out = AttributedString(text)
        for m in KeywordTagger.scan(text).mentions where !m.negated && tags.contains(m.tag) {
            var from = out.startIndex
            while let r = out[from...].range(of: m.phrase, options: .caseInsensitive) {
                out[r].backgroundColor = Theme.rescueSoft.opacity(0.45)
                from = r.upperBound
            }
        }
        return out
    }

    // MARK: Readings

    /// The readings that lead each family; the rest sit behind "More".
    static let leading: Set<Signal> = [.temperature, .humidity, .windSpeed, .pm25, .ozone, .pollenTree, .pollenGrass, .pollenWeed]

    /// One card per family (owner, Nov 19: chunked so it reads), the main readings first and the rest one tap down.
    @ViewBuilder private var readings: some View {
        if let c = conditions, !c.observations.isEmpty {
            ForEach(ReadingFamily.allCases, id: \.self) { family in
                let all = family.signals.compactMap { s in c.best(s) }
                let main = all.filter { Self.leading.contains($0.signal) }
                let rest = all.filter { !Self.leading.contains($0.signal) }
                if !all.isEmpty {
                    card(family == .pollutants ? "Irritants and pollution" : family.title) {
                        ForEach(main, id: \.signal) { o in reading(o, in: c) }
                        if family == .weather, let swing = c.pressureChangeHpa {
                            line("Pressure", MenusEnvironment.pressureText(swing), note: "Apple Weather · over 3 hours")
                        }
                        if !rest.isEmpty {
                            let key = "more-" + family.rawValue
                            let isOpen = open.contains(key)
                            if isOpen { ForEach(rest, id: \.signal) { o in reading(o, in: c) } }
                            Button { withAnimation(Theme.smooth) { if isOpen { open.remove(key) } else { open.insert(key) } } } label: {
                                Text(isOpen ? "Fewer readings" : "More readings")
                                    .font(Theme.ui(.footnote, weight: .medium)).foregroundStyle(Theme.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else {
            card("Readings") {
                Text("No reading for this hour.").font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// A plain word for a reading where the app has one (the same bands the patterns use), before its number.
    static func word(_ o: EnvObservation) -> String? {
        func level(_ b: PollutantBand) -> String? { b == .low ? "Low" : b == .moderate ? "Raised" : b == .high ? "High" : nil }
        switch o.signal {
        case .pm25: return level(Banding.pm25(o.value))
        case .pm10: return level(Banding.pm10(o.value))
        case .ozone: return level(Banding.ozone(ppb: o.value))
        case .no2: return level(Banding.no2(ppb: o.value))
        case .humidity: return Banding.humidity(o.value) == .dry ? "Dry" : Banding.humidity(o.value) == .humid ? "Humid" : nil
        case .windSpeed: return Banding.wind(mph: o.value) == .calm ? "Calm" : Banding.wind(mph: o.value) == .windy ? "Windy" : "Breezy"
        default: return nil
        }
    }

    /// Where a reading came from: its source, and how far away when it's a station.
    static func source(_ o: EnvObservation) -> String {
        var parts = [o.source]
        if let km = o.distanceKm { let mi = km * 0.621371; parts.append(mi < 1 ? "under a mile away" : "\(Int(mi.rounded())) mi away") }
        if o.isForecast { parts.append("forecast") }
        return parts.joined(separator: " · ")
    }

    // MARK: The two days before

    /// What the air had been doing before the moment (`LookBack`): the highest in the six hours up to it and in
    /// the day and a half before that. A flare often trails the air, so this is kept on every moment.
    @ViewBuilder private var before: some View {
        if let b = conditions?.lookBack {
            card("The two days before") {
                Text("The highest reading in each stretch.").font(Theme.ui(.caption)).foregroundStyle(Theme.secondaryText)
                peaks("Fine particles", now: b.pm25Now, earlier: b.pm25Earlier, unit: "µg/m³") { Self.word(EnvObservation(signal: .pm25, value: $0, unit: "", asOf: .now, source: "", spatialScale: .modelGrid)) }
                peaks("Ozone", now: b.ozoneNow, earlier: b.ozoneEarlier, unit: "ppb") { Self.word(EnvObservation(signal: .ozone, value: $0, unit: "", asOf: .now, source: "", spatialScale: .modelGrid)) }
                peaks("Biggest temperature fall", now: b.tempFallNow, earlier: b.tempFallEarlier, unit: "°F in 3 hours") { TempDrop.band($0) == .sharp ? "Sharp" : nil }
                if let station = b.pm25Station ?? b.ozoneStation {
                    Text("From \(station).").font(Theme.ui(.caption)).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private func peaks(_ name: String, now: WindowPeak, earlier: WindowPeak, unit: String, word: (Double) -> String?) -> some View {
        func text(_ p: WindowPeak, hours: Double) -> String {
            guard LookBack.isCovered(p, windowHours: hours), let v = p.worst else { return "Not enough readings" }
            let n = v.rounded() == v || v >= 10 ? String(Int(v.rounded())) : String(format: "%.1f", v)
            return [word(v), "\(n) \(unit)"].compactMap { $0 }.joined(separator: " · ")
        }
        let hasNow = LookBack.isCovered(now, windowHours: LookBack.nowHours)
        let hasEarlier = LookBack.isCovered(earlier, windowHours: LookBack.spanHours - LookBack.nowHours)
        return VStack(alignment: .leading, spacing: 3) {
            if !hasNow && !hasEarlier {
                // Nothing to show for either window: one quiet line, not two.
                line(name, "Not enough readings", dim: true)
            } else {
                Text(name).font(Theme.ui(.subheadline, weight: .medium))
                line("Last 6 hours", text(now, hours: LookBack.nowHours), dim: !hasNow)
                line("Before that", text(earlier, hours: LookBack.spanHours - LookBack.nowHours), dim: !hasEarlier)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder private func reading(_ o: EnvObservation, in c: Conditions) -> some View {
        let name = Self.name(o.signal)
        let group: PollenSpecies.Group? = o.signal == .pollenTree ? .tree : o.signal == .pollenGrass ? .grass : o.signal == .pollenWeed ? .weed : nil
        let species = group.flatMap { g in c.pollenSpecies?.counts(g) }.flatMap { $0.isEmpty ? nil : $0 }
        let value = group == nil ? [Self.word(o), ObservationCopy.value(o)].compactMap { $0 }.joined(separator: " · ")
            : [o.category, PollenSpecies.text(o.value)].compactMap { $0 }.joined(separator: " · ")
        let note = Self.source(o)
        if let species {
            let isOpen = open.contains(name)
            Button { withAnimation(Theme.smooth) { if isOpen { open.remove(name) } else { open.insert(name) } } } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    line(name, value, note: note)
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryText)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isOpen ? "Hides the species" : "Shows the count for each species")
            if isOpen {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(species) { s in
                        HStack {
                            Text(s.name)
                            Spacer(minLength: 8)
                            Text(PollenSpecies.text(s.count)).monospacedDigit()
                        }
                        .foregroundStyle(s.count > 0 ? Color.primary : Theme.secondaryText)
                    }
                    Text("A zero was looked for and not found.").foregroundStyle(Theme.secondaryText)
                }
                .font(Theme.ui(.caption))
                .padding(.leading, 12)
                .transition(.opacity)
            }
        } else {
            line(name, value, note: note)
        }
    }

    static func name(_ s: Signal) -> String {
        switch s {
        case .temperature: "Temperature"
        case .pm25: "Fine particles (PM2.5)"
        case .pm10: "Coarse dust (PM10)"
        case .no2: "Traffic fumes (NO₂)"
        default: ObservationCopy.label(s)
        }
    }

    // MARK: Kind of day

    /// Combinations present in this hour's air. One that passed the gate for you says so.
    private var kinds: some View {
        let present: [Combination] = conditions.map { c in
            let f = FrameBuilder.frame(id: "fold", kind: .baseline, date: date, conditions: c.input)
            return Combination.allCases.filter { $0.present(in: f) == true }
        } ?? []
        return card("Kind of day") {
            if present.isEmpty {
                Text("Nothing in combination.").font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(present) { k in
                    line(k.title, yours.contains(k) ? "Often on your inhaler days" : "Not one of yours", note: k.parts, dim: false)
                }
            }
        }
    }

    // MARK: Body

    private func bodyCard(_ e: LogEvent) -> some View {
        card("Body") {
            if e.moment == .rescue || e.moment == .maintenance {
                let puffs = e.uses.reduce(0) { $0 + $1.puffs }
                if puffs > 0 { line(e.moment == .rescue ? "Inhaler" : "Standard inhaler", puffs == 1 ? "1 puff" : "\(puffs) puffs") }
            }
            switch e.exerted {
            case true?: line("The hour before", "Active", note: "Apple Health and Motion")
            case false?: line("The hour before", "Still", note: "Apple Health and Motion")
            case nil: line("The hour before", "Not known", dim: true)
            }
            if let flu = e.infection, flu != .unknown {
                line("Flu going around", flu.rawValue.capitalized, note: "Ambee · metro area, weekly")
            }
        }
    }
}
