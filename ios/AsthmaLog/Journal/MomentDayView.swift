import AsthmaCore
import SwiftUI

/// Moments › Month › a date (April, Nov 20): the day zoomed in. Its air (the ink that led, in words), then each
/// moment with its journal read back as a diary, one tap from editing it or adding to its journal.
struct MomentDayView: View {
    let day: Date
    /// That day's inhaler, standard, manual and symptom moments.
    let moments: [LogEvent]
    /// Every moment with air that day (baselines too), for the day's lead.
    let air: [LogEvent]

    @Environment(\.modelContext) private var context
    @State private var journal: CaptureSession?
    @AppStorage(Crit.CaptureStyle.key) private var captureStyle = Crit.CaptureStyle.chat
    @AppStorage(Crit.AutoSelect.key) private var autoSelect = Crit.AutoSelect.ticked

    /// The day's lead, the same as Month and Year show (the sample seasons in the demo).
    private var lead: AirBlanket.Day? {
        let d = Calendar.current.startOfDay(for: day)
        return AirBlanket.demoAir ? AirBlanket.sample(year: Calendar.current.component(.year, from: d))[d] : AirBlanket.days(air)[d]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(Theme.Figtree.font(size: 28, weight: .medium))
                    Text(summary).font(Theme.Figtree.font(size: 15)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4).padding(.bottom, 8)

                if let lead, !lead.lead.isEmpty { airCard(lead) }
                ForEach(moments.sorted { $0.loggedAt < $1.loggedAt }) { e in momentCard(e) }
                if moments.isEmpty {
                    Text("No moments this day.").font(Theme.Figtree.font(size: 15)).foregroundStyle(.secondary).padding(.top, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 120)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(day.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { journal != nil }, set: { if !$0 { closeJournal() } })) {
            if let s = journal { CaptureSheet(session: s, chat: captureStyle == .chat, voice: false) { journal = nil } }
        }
    }

    private var summary: String {
        let inhaler = moments.filter { $0.moment == .rescue }.count
        let symptoms = moments.filter(MenusMomentsView.isSymptoms).count
        let parts = [inhaler > 0 ? (inhaler == 1 ? "1 inhaler moment" : "\(inhaler) inhaler moments") : nil,
                     symptoms > 0 ? "symptoms" : nil].compactMap { $0 }
        return parts.isEmpty ? "No inhaler use" : parts.joined(separator: " · ")
    }

    private func airCard(_ lead: AirBlanket.Day) -> some View {
        MenusMomentsView.card {
            HStack(spacing: 10) {
                Image(systemName: "wind").font(.system(size: 17, weight: .medium)).frame(width: 22)
                Text("The air").font(Theme.Figtree.font(size: 17, weight: .medium))
            }
            .padding(.vertical, 15)
            Divider()
            HStack(spacing: 10) {
                MenusMomentsView.airDot(lead, size: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ComingDays.word(lead.lead)) led the air").font(Theme.Figtree.font(size: 16))
                    // Your own readings in words; not under the demo's sample seasons, where they'd disagree.
                    if !AirBlanket.demoAir, let words = air.compactMap({ EveningLookBack.air($0.conditions) }).first {
                        Text(words).font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func momentCard(_ e: LogEvent) -> some View {
        let diary = JournalSummary.read(e)
        let symptoms = MenusMomentsView.isSymptoms(e)
        return MenusMomentsView.card {
            NavigationLink(value: e.id) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        // The time and Home's chip (April, Nov 20), no pill.
                        HStack(spacing: 8) {
                            Text(e.loggedAt.formatted(date: .omitted, time: .shortened))
                                .font(Theme.Figtree.font(size: 17, weight: .medium)).foregroundStyle(.primary)
                            MomentTag(moment: e.moment, symptoms: symptoms)
                            if e.puffs > 1 { Text("\(e.puffs) puffs").font(Theme.Figtree.font(size: 14)).foregroundStyle(.secondary) }
                        }
                        if let place = e.placeName, !place.isEmpty {
                            Text([place, NowHomeView.settingWord(e)].compactMap { $0 }.joined(separator: " · "))
                                .font(Theme.Figtree.font(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            Divider()
            // The journal, read back.
            VStack(alignment: .leading, spacing: 6) {
                if diary.isEmpty {
                    Text("No journal yet.").font(Theme.Figtree.font(size: 15)).foregroundStyle(.secondary)
                } else {
                    if !diary.sentences.isEmpty {
                        Text(diary.sentences.joined(separator: " ")).font(Theme.Figtree.font(size: 16))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(diary.quotes, id: \.self) { q in
                        Text("“\(q)”").font(Theme.Figtree.font(size: 15)).italic().foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 12)
            Divider()
            Button { journal = CaptureSession(event: e, chat: captureStyle == .chat, autoSelect: autoSelect == .ticked) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil").font(.system(size: 17, weight: .medium)).frame(width: 22)
                    Text("Add to journal").font(Theme.Figtree.font(size: 16))
                    Spacer()
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
    }

    private func closeJournal() {
        guard let s = journal else { return }
        if s.listening { Task { await s.stopListening(); if s.hasAnything { s.save(context: context) } else { s.discard() } } }
        else if s.hasAnything { s.save(context: context) } else { s.discard() }
        journal = nil
    }
}
