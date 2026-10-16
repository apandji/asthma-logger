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
    @ViewBuilder let kicker: Kicker

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) { kicker }
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(title)
                .font(.system(.title, design: .serif, weight: .medium))
                .lineLimit(reserveTwoLines ? 2 : 1, reservesSpace: reserveTwoLines)
                .minimumScaleFactor(0.85)
                .contentTransition(.opacity)
            if byline != nil || reserveByline {
                Text(byline ?? " ")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .lineLimit(2, reservesSpace: true)
                    .contentTransition(.opacity)
            }
        }
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
