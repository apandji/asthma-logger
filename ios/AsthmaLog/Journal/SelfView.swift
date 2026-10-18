import AsthmaCore
import CoreMotion
import SwiftUI

/// Self, the last stop on the rail: the sky dims and this sits on top, with the rail still there, so reading
/// the air and reading yourself are one slide up and down. What the sky can't show: your words and tags,
/// how active you'd been, and Apple Health (sleep, heart, breathing), all in words, never numbers.
/// Drawn without glass or a scroll view: it lives inside the sky's shader layer.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Self", systemImage: Icons.me).font(.headline)
            words
            card("Activity", "figure.walk") {
                Text(activity ?? "Reading your activity…")
                Text("In the two hours before, from your iPhone's motion sensor.").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            card("Sleep, heart and breathing", "heart.text.square") {
                if askHealth {
                    Text("Apple Health can add how you slept, and your heart and breathing around this moment, in words.")
                    Button {
                        Task { await HealthReader.shared.ask(); await load() }
                    } label: {
                        Label("Connect Apple Health", systemImage: "heart.fill").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!interactive)
                } else if let h = health, !h.isEmpty {
                    if let s = h.sleep { line("Sleep", s) }
                    if let s = h.heart { line("Heart", s) }
                    if let s = h.breathing { line("Breathing", s) }
                } else {
                    Text(health == nil ? "Reading Apple Health…" : "Nothing from Apple Health around this time.")
                }
            }
            Text(interactive ? "Hold the rail and slide up to read the air again." : "Let go to stay here.")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(.leading, 18).padding(.trailing, 64).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: date) { await load() }
    }

    private func load() async {
        askHealth = await HealthReader.shared.shouldAsk()
        async let a = ActivityWords.before(date)
        activity = await a
        health = askHealth ? nil : await HealthReader.shared.words(before: date)
    }

    @ViewBuilder private var words: some View {
        card("Your words", "waveform") {
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
    }

    private func line(_ name: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(Theme.secondaryText).frame(width: 80, alignment: .leading)
            Text(text)
        }
    }

    private func card<Content: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            content().font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}

/// Steps in the two hours before a time, as words. iOS keeps a week of pedometer data; older than that, or
/// without Motion & Fitness, there's nothing to say.
enum ActivityWords {
    nonisolated static func before(_ date: Date) async -> String {
        guard CMPedometer.isStepCountingAvailable() else { return "Not available on this iPhone." }
        guard date > Date().addingTimeInterval(-7 * 86_400) else { return "Too long ago: iOS keeps a week of activity." }
        let from = date.addingTimeInterval(-2 * 3600)
        let steps: Int? = await withCheckedContinuation { c in
            CMPedometer().queryPedometerData(from: from, to: min(date, .now)) { @Sendable data, _ in
                c.resume(returning: data?.numberOfSteps.intValue)
            }
        }
        guard let steps else { return "No activity recorded." }
        switch steps {
        case ..<300: return "Mostly still."
        case ..<1500: return "Some walking."
        case ..<4000: return "A fair bit of walking."
        default: return "A lot of walking."
        }
    }
}
