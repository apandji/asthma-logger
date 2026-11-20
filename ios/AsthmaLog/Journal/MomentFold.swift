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
    /// The pollen rows opened to their species.
    @State private var open: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let event { journal(event) }
            readings
            kinds
            if let event { bodyCard(event) }
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
                Text("No note on this moment.").font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText)
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

    private var readings: some View {
        card("Every reading") {
            if let c = conditions, !c.observations.isEmpty {
                ForEach(ReadingFamily.allCases, id: \.self) { family in
                    let rows = family.signals.compactMap { s in c.best(s) }
                    if !rows.isEmpty {
                        Text(family.title).font(Theme.ui(.caption, weight: .medium)).foregroundStyle(Theme.secondaryText).padding(.top, 2)
                        ForEach(rows, id: \.signal) { o in reading(o, in: c) }
                        if family == .weather, let swing = c.pressureChangeHpa {
                            line("Pressure, last 3 hours", MenusEnvironment.pressureText(swing), note: "Apple Weather")
                        }
                    }
                }
            } else {
                Text("No reading for this hour.").font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText)
            }
            line("Indoor air", "Can't be seen", dim: true)
        }
    }

    @ViewBuilder private func reading(_ o: EnvObservation, in c: Conditions) -> some View {
        let name = Self.name(o.signal)
        let group: PollenSpecies.Group? = o.signal == .pollenTree ? .tree : o.signal == .pollenGrass ? .grass : o.signal == .pollenWeed ? .weed : nil
        let species = group.flatMap { g in c.pollenSpecies?.counts(g) }.flatMap { $0.isEmpty ? nil : $0 }
        let value = group == nil ? ObservationCopy.value(o) : [o.category, PollenSpecies.text(o.value)].compactMap { $0 }.joined(separator: " · ")
        let note = o.source + (o.isForecast ? " · forecast" : "")
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
