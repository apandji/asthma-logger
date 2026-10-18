import AsthmaCore
import CoreMotion
import SwiftUI

/// Self, the last stop on the rail: the sky dims and this sits on top, with the rail still there, so reading
/// the air and reading yourself are one slide up and down. What the sky can't show: your words and tags,
/// how active you'd been, and Apple Health (sleep, heart, breathing), all in words, never numbers.
struct SelfPanel: View {
    /// The moment this is about; nil for Now with nothing logged.
    let event: LogEvent?
    let date: Date
    /// Read-only while the finger is still on the rail; buttons work once it's let go.
    let interactive: Bool
    let record: (LogEvent) -> Void
    @State private var activity: String?
    @State private var health: HealthReader.Words?
    @State private var askHealth = false

    /// Two cards, like "Your note" elsewhere: your words, and your body in a few short lines.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            card("Your words", "waveform") { words }
            card("Your body", "figure.walk") { bodyLines }
        }
        .padding(.leading, 20).padding(.trailing, 60).padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: date) { await load() }
    }

    private func load() async {
        askHealth = await HealthReader.shared.shouldAsk()
        activity = await ActivityWords.before(date)
        health = askHealth ? nil : await HealthReader.shared.words(before: date)
    }

    @ViewBuilder private var words: some View {
        let text = (event?.voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            Text(event == nil ? "Nothing logged right now." : "Nothing said yet.").foregroundStyle(Theme.secondaryText)
        } else {
            Text("“\(text)”").italic().lineLimit(4)
        }
        if let tags = event?.tags, !tags.isEmpty {
            Text(tags.sorted().map(\.label).joined(separator: " · ")).font(.subheadline.weight(.semibold))
        }
        if let event, event.moment != .okay {
            Button { record(event) } label: {
                Label(text.isEmpty ? "Say what was going on" : "Add more", systemImage: "mic.fill").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(PressStyle())
            .disabled(!interactive)
        }
    }

    @ViewBuilder private var bodyLines: some View {
        line("Activity", activity ?? "…")
        if let h = health {
            if let v = h.sleep { line("Sleep", v) }
            if let v = h.heart { line("Heart", v) }
            if let v = h.breathing { line("Breathing", v) }
        }
        if askHealth {
            Button { Task { await HealthReader.shared.ask(); await load() } } label: {
                Label("Connect Apple Health for sleep, heart and breathing", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
            }
            .buttonStyle(PressStyle())
            .disabled(!interactive)
        }
    }

    private func line(_ name: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(Theme.secondaryText).frame(width: 84, alignment: .leading)
            Text(text)
        }
    }

    /// The same card as "Your note" (Now's cards): a small titled glass panel.
    private func card<Content: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            content().font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

/// Steps in the two hours before a time, as words. iOS keeps a week of pedometer data; older than that, or
/// without Motion & Fitness, there's nothing to say.
enum ActivityWords {
    nonisolated static func before(_ date: Date) async -> String {
        guard CMPedometer.isStepCountingAvailable() else { return "Not available on this iPhone." }
        guard date > Date().addingTimeInterval(-7 * 86_400) else { return "Too long ago: iOS keeps a week of activity." }
        let from = date.addingTimeInterval(-2 * 3600)
        let pedometer = CMPedometer()   // held until it answers (freed early, it never replies)
        let steps: Int? = await withCheckedContinuation { c in
            pedometer.queryPedometerData(from: from, to: min(date, .now)) { @Sendable data, _ in
                c.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        _ = pedometer
        guard let steps else { return "No activity recorded." }
        switch steps {
        case ..<300: return "Mostly still."
        case ..<1500: return "Some walking."
        case ..<4000: return "A fair bit of walking."
        default: return "A lot of walking."
        }
    }
}
