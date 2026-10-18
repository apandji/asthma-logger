import AsthmaCore
import CoreMotion
import SwiftUI

/// Self, from the rail: the map slides away and this takes its place. What the sky can't show: your words
/// and tags for the moment, how active you'd been, and (later) vitals from Apple Health. In words, never
/// numbers (owner, Oct 17). Exertion lives here, not on the map.
struct SelfView: View {
    /// The moment this is about; nil for Now with nothing logged.
    let event: LogEvent?
    let date: Date
    let close: () -> Void
    let record: (LogEvent) -> Void
    @State private var activity: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Self", systemImage: Icons.me).font(.headline)
                    Spacer()
                    Button(action: close) {
                        Label("Back to the air", systemImage: "chevron.up").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(PressStyle())
                }
                words
                card(title: "Activity", icon: "figure.walk") {
                    Text(activity ?? "Reading your activity…").font(.body)
                    Text("From your iPhone's motion sensor, in the two hours before.").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                card(title: "Breathing and heart", icon: "heart.text.square") {
                    Text("Not connected yet.").font(.body)
                    Text("Apple Health could add how you slept, your heart and breathing, in words like these.")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .task(id: date) { activity = await ActivityWords.before(date) }
    }

    @ViewBuilder private var words: some View {
        card(title: "Your words", icon: "waveform") {
            let text = (event?.voiceTranscript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                Text(event == nil ? "Nothing logged right now." : "Nothing said yet.").font(.body).foregroundStyle(Theme.secondaryText)
            } else {
                Text("“\(text)”").font(.body).italic()
            }
            if let tags = event?.tags, !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags.sorted()) { t in
                        Text(t.label).font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color.primary.opacity(0.12)))
                    }
                }
            }
            if let event, event.moment != .okay {
                Button { record(event) } label: {
                    Label(text.isEmpty ? "Say what was going on" : "Add more", systemImage: "mic.fill").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private func card<Content: View>(title: String, icon: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            content()
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
