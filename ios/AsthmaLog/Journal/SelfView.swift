import AsthmaCore
import CoreMotion
import SwiftUI

/// Self is a group on the rail like the others: the header lists what it tracks (your voice, your body), and
/// each item reads beside the thumb. Let go on any of them and it stays open. In words, never numbers.

/// The shared panel look: the same glass label as a reading on the rail.
private struct RailPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// A grey label and its value on one line, one size throughout.
private struct BodyLine: View {
    let name: String
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name).font(.caption.weight(.medium)).foregroundStyle(Theme.secondaryText).frame(width: 64, alignment: .leading)
            Text(text).font(.subheadline)
        }
    }
}

/// Self's header: what it tracks, like Particles & gases lists its items.
struct SelfSummary: View {
    let event: LogEvent?
    let date: Date
    @State private var activity: String?

    var body: some View {
        RailPanel(title: "Self", icon: Icons.me) {
            let words = (event?.voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            BodyLine(name: "Voice", text: words.isEmpty ? (event == nil ? "Nothing logged" : "Nothing said yet") : "“\(words.prefix(28))\(words.count > 28 ? "…" : "")”")
            BodyLine(name: "Body", text: activity ?? "…")
        }
        .task(id: date) { activity = await ActivityWords.before(date) }
    }
}

/// Your voice: your words and tags, and a way to add them.
struct VoicePanel: View {
    let event: LogEvent?
    let interactive: Bool
    let record: (LogEvent) -> Void

    var body: some View {
        RailPanel(title: "Your voice", icon: "waveform") {
            let text = (event?.voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                Text(event == nil ? "Nothing logged right now." : "Nothing said yet.").font(.subheadline).foregroundStyle(Theme.secondaryText)
            } else {
                Text("“\(text)”").font(.subheadline).italic().lineLimit(5)
            }
            if let tags = event?.tags, !tags.isEmpty {
                Text(tags.sorted().map(\.label).joined(separator: " · ")).font(.caption.weight(.semibold))
            }
            if let event, event.moment != .okay {
                Button { record(event) } label: {
                    Label(text.isEmpty ? "Say what was going on" : "Add more", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(PressStyle())
                .disabled(!interactive)
                .opacity(interactive ? 1 : 0.5)
            }
        }
    }
}

/// Your body: activity (motion sensor) and Apple Health (sleep, heart, breathing), in words.
struct BodyPanel: View {
    let date: Date
    let interactive: Bool
    @State private var activity: String?
    @State private var health: HealthReader.Words?
    @State private var askHealth = false

    var body: some View {
        RailPanel(title: "Your body", icon: "figure.walk") {
            BodyLine(name: "Activity", text: activity ?? "…")
            if let h = health {
                if let v = h.sleep { BodyLine(name: "Sleep", text: v) }
                if let v = h.heart { BodyLine(name: "Heart", text: v) }
                if let v = h.breathing { BodyLine(name: "Breathing", text: v) }
            }
            if askHealth {
                Button { Task { await HealthReader.shared.ask(); await load() } } label: {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(PressStyle())
                .disabled(!interactive)
                .opacity(interactive ? 1 : 0.5)
                Text("Adds sleep, heart and breathing, in words.").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .task(id: date) { await load() }
    }

    private func load() async {
        askHealth = await HealthReader.shared.shouldAsk()
        activity = await ActivityWords.before(date)
        health = askHealth ? nil : await HealthReader.shared.words(before: date)
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
