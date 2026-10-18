import AsthmaCore
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
    /// Not yet: the forecast's sentence is set slanted (Recursive's slant axis).
    var italic = false
    @ViewBuilder let kicker: Kicker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Read so the sentence redraws when voice or Settings › Type changes.
    @AppStorage(Prefs.statementTypeface) private var statementTypeface = Theme.Typeface.recursive.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) { kicker }
                .font(Theme.kicker).tracking(Theme.kickerTracking).textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1).truncationMode(.middle)  // fixed size: a long place name clips, the type never shrinks
                .contentTransition(.opacity)
            let hasByline = byline != nil || reserveByline
            // The sentence: Settings › Type face, a touch tight; blurs between readings instead of cutting.
            ZStack(alignment: .topLeading) {
                Text(title)
                    .font(Theme.Typeface.sentence(size: compact ? 26 : 30, slanted: italic, voice: .current))
                    .kerning(Theme.serifKerning)
                    .animation(nil, value: statementTypeface)
                    // Two lines, always: the byline sits in the same place whatever the title says.
                    .lineLimit(reserveTwoLines ? 2 : 1, reservesSpace: reserveTwoLines)
                    .lineSpacing(-1)
                    .id(title)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
            .animation(Theme.smooth, value: title)
            if hasByline {
                // felt air's own voice, marked with the sparkle so it reads as the app thinking, not data.
                let tint = bylineTint ?? Theme.secondaryText
                Button { onByline?() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.caption)
                            .symbolEffect(.bounce, value: byline)
                        Text(byline ?? " ").lineLimit(2).multilineTextAlignment(.leading)
                        if onByline != nil { Image(systemName: "chevron.right").font(.caption2.weight(.bold)).opacity(0.7) }
                    }
                    .font(bylineTint == nil ? .subheadline : Theme.bylineSerif)
                    .foregroundStyle(tint)
                    .padding(.horizontal, onByline == nil ? 0 : 13).padding(.vertical, onByline == nil ? 0 : 8)
                    .background { if onByline != nil { Capsule().fill(tint.opacity(bylineTint == nil ? 0.1 : 0.16)) } }
                }
                .buttonStyle(PressStyle())
                .disabled(onByline == nil)
                .contentTransition(.opacity)
                .animation(Theme.smooth, value: bylineTint)
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
        let kind = moment.title
        return ["\(kind) · \(day), \(time)", placeName].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Mon, 8:15 AM · Tower Grove South": the details line when the kind is shown as a tag.
    var whenAndWhere: String {
        let cal = Calendar.current
        let time = loggedAt.formatted(date: .omitted, time: .shortened)
        let day = cal.isDateInToday(loggedAt) ? "Today" : cal.isDateInYesterday(loggedAt) ? "Yesterday"
            : loggedAt.formatted(.dateTime.weekday(.abbreviated))
        return ["\(day), \(time)", placeName].compactMap { $0 }.joined(separator: " · ")
    }

    /// The moment's one-line statement, or why there isn't one.
    var statement: String { weave.isEmpty ? "No air reading." : headline }
}

/// Which inhaler, as a small tag in the kicker: the word in a rounded rectangle, in the moment's ink.
/// Replaces the orange / blue dot, which said less and shouted more.
struct MomentTag: View {
    let moment: MomentKind
    var text: String? = nil

    var body: some View {
        // The word carries the kind; colour is kept for the air.
        let ink = moment == .rescue ? Color.primary : Theme.secondaryText
        Text(text ?? moment.title)
            // The same size as the place beside it, so the top line reads as one line.
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ink)
            .lineLimit(1).fixedSize()
            // One width for every kind, so the tag doesn't resize as you scrub between moments; a custom
            // word ("Forecast", "First capture") gets only what it needs.
            .frame(minWidth: text == nil ? 84 : 0)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(ink.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(ink.opacity(0.35), lineWidth: 0.8))
    }
}
