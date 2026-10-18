import AVFoundation
import HealthKit
import SwiftUI

/// Onboarding's data step: every source felt air can use, one card each, saying what it reads, what it's for,
/// and where it goes, plainly: on this iPhone, or sent out (to whom, and why). Each has its own Allow, so
/// people choose source by source; everything is optional and logging works without any of it.
/// Location's When In Use is asked on the "here" step; this card adds the visits (Always).
struct DataCards: View {
    @Environment(LogService.self) private var services
    @State private var done: Set<String> = []

    struct Source: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let uses: String
        let purpose: String
        let goes: String
        /// Sent somewhere outside the phone.
        let leaves: Bool
    }

    static let sources: [Source] = [
        Source(id: "location", symbol: "location.fill", title: "Location",
               uses: "Where you are when you log, and the places you spend time.",
               purpose: "The air and weather at each moment, and ordinary hours where you actually were.",
               goes: "To get the air right where you are, your location goes to Apple Weather, OpenAQ, AirNow and Ambee with each request. No name, account or device ID goes with it, and they never get your history or your places. Those stay on this iPhone.",
               leaves: true),
        Source(id: "voice", symbol: "mic.fill", title: "Microphone and speech",
               uses: "Your voice notes.",
               purpose: "Saying what was going on, and how it felt, instead of typing it.",
               goes: "Recorded and written down on this iPhone. Never uploaded.",
               leaves: false),
        Source(id: "health", symbol: "heart.fill", title: "Apple Health",
               uses: "Saves each inhaler use. Reads sleep, heart and breathing rate, steps, workouts and State of Mind.",
               purpose: "Your inhaler in Health, and your body around each moment, in words (Body).",
               goes: "On this iPhone, in Health. felt air never sends it anywhere.",
               leaves: false),
        Source(id: "motion", symbol: "figure.walk", title: "Motion and fitness",
               uses: "Walking, running, driving or still.",
               purpose: "Whether you were indoors or out, and how active you were before a moment.",
               goes: "On this iPhone.",
               leaves: false),
        Source(id: "calendar", symbol: "calendar", title: "Calendar",
               uses: "Your events: titles, times and places.",
               purpose: "Reminding you what you were doing at a moment, and showing what you'll be doing beside the look-ahead.",
               goes: "On this iPhone. Event titles never leave it and never become patterns.",
               leaves: false),
        Source(id: "notifications", symbol: "bell.badge", title: "Notifications",
               uses: "Reminders felt air schedules.",
               purpose: "After a press, a nudge to add what was going on. The morning look-ahead at 8.",
               goes: "Scheduled on this iPhone.",
               leaves: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Self.sources) { s in card(s) }
                }
            }
            .frame(maxHeight: 420)
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if VisitLog.shared.isAlways { done.insert("location") }
            if CalendarReader.shared.wasAsked { done.insert("calendar") }
        }
    }

    private func card(_ s: Source) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: s.symbol).font(.title3).frame(width: 28)
                Text(s.title).font(.headline)
                Spacer()
                Button(done.contains(s.id) ? "Done" : "Allow") { Task { await allow(s.id) } }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .buttonStyle(PressStyle())
                    .disabled(done.contains(s.id))
            }
            line("Uses", s.uses)
            line("For", s.purpose)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: s.leaves ? "arrow.up.right.circle" : "iphone")
                    .font(.footnote).foregroundStyle(Theme.secondaryText).frame(width: 52, alignment: .leading)
                Text(s.goes).font(.footnote)
                    .foregroundStyle(s.leaves ? Color.primary : Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel((s.leaves ? "Leaves this iPhone: " : "Stays on this iPhone: ") + s.goes)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.07)))
    }

    private func line(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText).frame(width: 52, alignment: .leading)
            Text(text).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func allow(_ id: String) async {
        switch id {
        case "location": VisitLog.shared.requestAlways()
        case "voice":
            _ = await AVAudioApplication.requestRecordPermission()
            _ = await NoteTranscriber.authorize()
        case "health": await HealthReader.shared.askWithWrite()
        case "motion": _ = await services.motion.recent()
        case "calendar": await CalendarReader.shared.requestAccess()
        case "notifications": _ = await QuickRecordCenter.shared.requestPermission()
        default: break
        }
        done.insert(id)
    }
}
