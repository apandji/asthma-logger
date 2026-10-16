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
    /// Color for a byline that carries a verdict (baseline / a bit like / matches your flare days).
    var bylineTint: Color? = nil
    /// The byline is a way in (to Insights): drawn as a pill you can tap.
    var onByline: (() -> Void)? = nil
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
                // Two lines, always: the byline sits in the same place whatever the title says.
                .lineLimit(reserveTwoLines ? 2 : 1, reservesSpace: reserveTwoLines)
                .contentTransition(.opacity)
            if hasByline {
                // felt air's own voice, marked with the sparkle so it reads as the app thinking, not data.
                let tint = bylineTint ?? Theme.secondaryText
                Button { onByline?() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.caption)
                        Text(byline ?? " ").lineLimit(2).multilineTextAlignment(.leading)
                        if onByline != nil { Image(systemName: "chevron.right").font(.caption2.weight(.bold)).opacity(0.7) }
                    }
                    .font(.subheadline.weight(bylineTint == nil ? .regular : .medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, onByline == nil ? 0 : 12).padding(.vertical, onByline == nil ? 0 : 7)
                    .background { if onByline != nil { Capsule().fill(tint.opacity(0.14)).overlay(Capsule().strokeBorder(tint.opacity(0.35))) } }
                }
                .buttonStyle(.plain)
                .disabled(onByline == nil)
                .contentTransition(.opacity)
                .opacity(byline == nil ? 0 : 1)
                .accessibilityHint(onByline == nil ? "" : "Opens Insights")
            }
        }

        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
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
