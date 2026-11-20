import AsthmaCore
import SwiftUI

/// The evening look-back: open felt air after 6 pm with inhaler moments from today that have no note, and it
/// lays out what it already holds about each one (when, where, what was on your calendar, the outdoor air in
/// words) and asks what was going on. A soft wash over Now, not a sheet (owner, Nov 19): the one thing on
/// screen until it's answered or put off with "Do later". Once an evening.
/// Settings › Demo and development › Evening look-back shows it at any hour.
struct EveningLookBack: View {
    /// Today's inhaler moments, oldest first.
    let moments: [LogEvent]
    /// Add a note to this moment (the wash clears first). `listen`: start with the mic on; otherwise it opens
    /// the journal, where you type, tap what fits, or press the mic yourself.
    let add: (LogEvent, _ listen: Bool) -> Void
    let close: () -> Void

    static let demoKey = "demo.evening"
    static let shownKey = "evening.shownDay"

    /// Today's rescue and standard moments still without a note or reviewed tags. Demo moments never ask.
    static func open(_ events: [LogEvent], now: Date, calendar: Calendar = .current) -> [LogEvent] {
        events.filter {
            ($0.moment == .rescue || $0.moment == .maintenance || $0.moment == .note) && !$0.isDemo && calendar.isDate($0.loggedAt, inSameDayAs: now)
        }.sorted { $0.loggedAt < $1.loggedAt }
    }

    static func needsNote(_ e: LogEvent) -> Bool {
        !e.tagsReviewed && (e.voiceTranscript ?? "").isEmpty && e.notes.allSatisfy { $0.transcript.isEmpty }
    }

    /// Whether to show it on its own: after 6 pm, something to ask about, not already shown this evening.
    static func isDue(_ events: [LogEvent], now: Date, calendar: Calendar = .current) -> Bool {
        if UserDefaults.standard.bool(forKey: demoKey) { return true }
        guard calendar.component(.hour, from: now) >= 18 else { return false }
        let day = calendar.startOfDay(for: now).timeIntervalSince1970
        guard UserDefaults.standard.double(forKey: shownKey) != day else { return false }
        return open(events, now: now, calendar: calendar).contains(where: needsNote)
    }

    static func markShown(now: Date, calendar: Calendar = .current) {
        UserDefaults.standard.set(calendar.startOfDay(for: now).timeIntervalSince1970, forKey: shownKey)
    }

    /// The moments to show: today's, or (for a demo with nothing logged today) the latest few.
    static func shown(_ events: [LogEvent], now: Date) -> [LogEvent] {
        let today = open(events, now: now)
        if !today.isEmpty || !UserDefaults.standard.bool(forKey: demoKey) { return today }
        return Array(events.filter { $0.moment == .rescue && !$0.isDemo && needsNote($0) }.sorted { $0.loggedAt < $1.loggedAt }.suffix(2))
    }

    /// Moments of one kind within 5 minutes of the one before are one card (owner, Nov 19): four taps at 11:22
    /// read as one moment, said as "4 puffs" (or "4 times" for manual ones), not four cards to answer.
    private var groups: [[LogEvent]] {
        var out: [[LogEvent]] = []
        // Only what still needs a note (April, Nov 20): journaled moments drop out, and a card leaves once answered.
        for m in moments where Self.needsNote(m) {
            if let last = out.last?.last, last.moment == m.moment, m.loggedAt.timeIntervalSince(last.loggedAt) <= 5 * 60 {
                out[out.count - 1].append(m)
            } else {
                out.append([m])
            }
        }
        return out
    }

    /// "4 puffs" for an inhaler group (every puff in every use), "4 times" otherwise; nil for one moment of one puff.
    private func countLine(_ g: [LogEvent]) -> String? {
        if g.first?.moment == .rescue || g.first?.moment == .maintenance {
            let puffs = g.reduce(0) { $0 + max(1, $1.uses.reduce(0) { $0 + $1.puffs }) }
            return puffs > 1 ? "\(puffs) puffs" : nil
        }
        return g.count > 1 ? "\(g.count) times" : nil
    }

    private var allToday: Bool { moments.allSatisfy { Calendar.current.isDateInToday($0.loggedAt) } }

    private var headline: String {
        let words = ["No moments", "One moment", "Two moments", "Three moments", "Four moments", "Five moments"]
        let c = groups.count
        let n = c < words.count ? words[c] : "A few moments"
        // Staged with nothing logged today: the latest moments, said as what they are.
        return allToday ? n + " today." : n.replacingOccurrences(of: "moment", with: "recent moment") + "."
    }

    var body: some View {
        ZStack {
            // A soft wash over Now: the page shows through, out of focus. Not a sheet, so it's the one thing
            // on screen until it's answered or put off.
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color(uiColor: .systemGroupedBackground).opacity(0.18).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(headline).font(Theme.ui(size: 34, weight: .medium))
                            Text(groups.count == 1 ? "What was going on?" : "What was going on at each?")
                                .font(Theme.ui(.title3)).foregroundStyle(Theme.secondaryText)
                        }
                        ForEach(groups, id: \.first!.id) { g in card(g) }
                    }
                    .padding(.horizontal, 20).padding(.top, 72).padding(.bottom, 16)
                }
                .scrollBounceBehavior(.basedOnSize)

                Button(action: close) {
                    Text("Do later").font(Theme.ui(.body, weight: .medium)).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(PressStyle())
                .padding(.horizontal, 20).padding(.bottom, 12)
            }
        }
        .environment(\.colorScheme, .light)   // the flowers look is always light
        // Everything answered: the wash goes by itself.
        .onAppear { if groups.isEmpty { close() } }
        .onChange(of: groups.count) { _, n in if n == 0 { close() } }
        .accessibilityAddTraits(.isModal)
    }

    private func card(_ g: [LogEvent]) -> some View {
        // The group answers as one: a note goes on its first moment, "Not sure" covers them all.
        let m = g[0]
        let done = !g.allSatisfy(Self.needsNote)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle().fill(m.moment == .rescue ? Theme.rescue : m.moment == .note ? Color.primary.opacity(0.35) : Theme.standard).frame(width: 10, height: 10)
                Text(m.moment.title).font(Theme.ui(.headline, weight: .medium))
                if let count = countLine(g) {
                    Text(count).font(Theme.ui(.subheadline, weight: .medium)).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Text(Calendar.current.isDateInToday(m.loggedAt) ? m.loggedAt.formatted(date: .omitted, time: .shortened)
                     : m.loggedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(Theme.ui(.subheadline)).foregroundStyle(Theme.secondaryText)
            }
            VStack(alignment: .leading, spacing: 8) {
                if let place = m.placeName, !place.isEmpty { cue("mappin.and.ellipse", place) }
                if let on = CalendarReader.shared.around(m.loggedAt) { cue("calendar", on.line) }
                if let air = Self.air(m.conditions) { cue("wind", air) }
            }
            if done {
                Label("Note added", systemImage: "checkmark").font(Theme.ui(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                // Your choice of how (owner, Nov 19): voice isn't for everyone or every place. "Add a note" opens
                // the journal to type or tap; the mic beside it starts speaking straight away.
                HStack(spacing: 8) {
                    // The note fills the row (owner, Nov 19), so the card's width is used and it reads as the thing to do.
                    Button { add(m, false) } label: {
                        Label("Add a note", systemImage: "square.and.pencil").font(Theme.ui(.subheadline, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(.white).background(Capsule().fill(.black))
                    }
                    Button { add(m, true) } label: {
                        Image(systemName: "mic.fill").font(Theme.ui(.subheadline, weight: .medium))
                            .foregroundStyle(.primary).frame(width: 44, height: 44)
                            .background(Circle().strokeBorder(Color.primary.opacity(0.15)))
                    }
                    .accessibilityLabel("Speak a note")
                    // The way out, quiet: plain text, no outline.
                    Button("Not sure") { for e in g { e.tagsReviewed = true }; try? m.modelContext?.save() }
                        .font(Theme.ui(.subheadline, weight: .medium)).foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 10).frame(height: 44)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    private func cue(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.footnote).foregroundStyle(Theme.secondaryText).frame(width: 18)
            Text(text).font(Theme.ui(.subheadline)).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The outdoor air at a moment in plain words, from the same bands the patterns use. No numbers.
    static func air(_ c: Conditions?) -> String? {
        guard let c else { return nil }
        let i = c.input
        var words: [String] = []
        switch Banding.temp(i.temperatureF, isExtreme: Banding.isExtremeTemp(i.temperatureF)) {
        case .cold: words.append("cold")
        case .hot: words.append("hot")
        case .mild: words.append("mild")
        default: break
        }
        switch Banding.humidity(i.humidityPct) {
        case .dry: words.append("dry")
        case .humid: words.append("humid")
        default: break
        }
        switch Banding.pm25(i.pm25) {
        case .moderate: words.append("fine particles up")
        case .high: words.append("fine particles high")
        default: break
        }
        switch Banding.ozone(ppb: i.ozonePpb) {
        case .moderate: words.append("ozone up")
        case .high: words.append("ozone high")
        default: break
        }
        guard !words.isEmpty else { return nil }
        let line = words.joined(separator: ", ")
        return "Outside: " + line
    }
}
