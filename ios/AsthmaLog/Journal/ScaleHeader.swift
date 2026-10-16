import SwiftUI

/// The top-left line every scale shares, in the same place and style: a small details line, then one
/// serif title. It stays put while the scale's content scrolls beneath it.
struct ScaleHeader<Kicker: View>: View {
    let title: String
    /// Statements can run to two lines; reserving both keeps the content below from jumping.
    var reserveTwoLines = false
    /// One quiet line under the title, with its space kept so it can come and go without a jump.
    var byline: String? = nil
    var reserveByline = false
    /// A step smaller, for two-sentence titles that have to fit two lines.
    var compact = false
    @ViewBuilder let kicker: Kicker

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) { kicker }
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                .lineLimit(1).truncationMode(.middle)  // fixed size: a long place name clips, the type never shrinks
            let hasByline = byline != nil || reserveByline
            Text(title)
                .font(.system(compact ? .title2 : .title, design: .serif, weight: .medium))
                // With a byline the block keeps a fixed height instead, so the byline hugs the title.
                .lineLimit(reserveTwoLines ? 2 : 1, reservesSpace: reserveTwoLines && !hasByline)
                .contentTransition(.opacity)
            if hasByline {
                // felt air's own voice, marked with the sparkle so it reads as the app thinking, not data.
                Label { Text(byline ?? " ") } icon: { Image(systemName: "sparkles").font(.caption).padding(.top, 2) }
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .opacity(byline == nil ? 0 : 1)
            }
        }
        .frame(minHeight: (byline != nil || reserveByline) ? (compact ? 108 : 118) : 0, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 20)
        .padding(.trailing, JournalView.railAxis + 30)  // clear the glass column
        .padding(.top, 6)
    }
}

extension LogEvent {
    /// "Standard · Yesterday, 7:55 AM · Tower Grove South": the details line on Moment and Details.
    var detailsLine: String {
        let cal = Calendar.current
        let time = loggedAt.formatted(date: .omitted, time: .shortened)
        let day = cal.isDateInToday(loggedAt) ? "Today" : cal.isDateInYesterday(loggedAt) ? "Yesterday"
            : loggedAt.formatted(.dateTime.weekday(.abbreviated))
        let kind = moment == .rescue ? "Rescue" : moment == .maintenance ? "Standard" : "I'm okay"
        return ["\(kind) · \(day), \(time)", placeName].compactMap { $0 }.joined(separator: " · ")
    }

    /// The moment's one-line statement, or why there isn't one.
    var statement: String { weave.isEmpty ? "No air reading." : headline }
}
