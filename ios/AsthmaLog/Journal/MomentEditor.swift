import AsthmaCore
import SwiftData
import SwiftUI

/// Moments tab › a moment (owner, Nov 20): fix and fill in one moment. Puffs (the button can miss or double a
/// press), the time, where it was and inside or outside, what was going on, a note, or delete it. Grouped like
/// Apple's Settings, on the app's paper. Changes save as you make them; Apple Health follows when you leave.
struct MomentEditor: View {
    @Bindable var event: LogEvent
    @Environment(\.modelContext) private var context
    @Environment(LogService.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var pickingPlace = false
    @State private var confirmDelete = false
    @State private var confirmClear = false

    private var hasJournal: Bool {
        !event.notes.isEmpty || !(event.voiceTranscript ?? "").isEmpty || !event.tags.isEmpty || event.voiceNoteFile != nil
    }

    /// The words, the recordings and the picked tags go; the moment, its air and its inhaler use stay.
    private func clearJournal() {
        for n in event.notes {
            if let f = n.audioFile { try? FileManager.default.removeItem(at: VoiceNotes.shared.url(f)) }
            context.delete(n)
        }
        if let f = event.voiceNoteFile { try? FileManager.default.removeItem(at: VoiceNotes.shared.url(f)) }
        event.notes = []
        event.voiceTranscript = nil
        event.voiceNoteFile = nil
        event.tags = []
        event.tagsReviewed = false
        try? context.save()
    }
    @State private var journal: CaptureSession?
    @AppStorage(Crit.CaptureStyle.key) private var captureStyle = Crit.CaptureStyle.chat
    @AppStorage(Crit.AutoSelect.key) private var autoSelect = Crit.AutoSelect.ticked
    /// What Health last heard, so leaving only rewrites the sample when puffs or time changed.
    @State private var healthPuffs = 0
    @State private var healthTime = Date.distantPast

    private var isInhaler: Bool { event.moment == .rescue || event.moment == .maintenance }

    var body: some View {
        List {
            Section {
                LabeledContent("Kind", value: event.moment.title)
                DatePicker("Time", selection: time, in: ...Date.now)
                if isInhaler {
                    Stepper(value: puffs, in: 1...20) {
                        LabeledContent("Puffs", value: "\(event.puffs)")
                    }
                }
            } footer: {
                if isInhaler { Text("If the button missed a press or counted one twice, set it right here.") }
            }

            Section("Where") {
                Button { pickingPlace = true } label: {
                    HStack {
                        Text("Place").foregroundStyle(.primary)
                        Spacer()
                        Text(event.placeName ?? (event.latitude == nil ? "Not set" : "On the map"))
                            .foregroundStyle(.secondary).lineLimit(1)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                Picker("Inside or outside", selection: inside) {
                    Text("Not sure").tag(IndoorOutdoor?.none)
                    Text("Inside").tag(IndoorOutdoor?.some(.indoor))
                    Text("Outside").tag(IndoorOutdoor?.some(.outdoor))
                }
                if let air = EveningLookBack.air(event.conditions) {
                    LabeledContent("Air", value: air.replacingOccurrences(of: "Outside: ", with: "").capitalizedFirst)
                }
            }

            // The journal (owner, Nov 20): what's been said and picked, in a line or two, and the same
            // "Add to journal" flow as the +, rather than every question's chips laid out here.
            Section("Journal") {
                if !event.tags.isEmpty {
                    Text(event.tags.sorted().map(\.label).joined(separator: ", "))
                        .font(.subheadline)
                }
                if let words = event.voiceTranscript?.trimmingCharacters(in: .whitespacesAndNewlines), !words.isEmpty {
                    Text(words).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
                Button { openJournal() } label: {
                    HStack {
                        Label("Add to journal", systemImage: "square.and.pencil").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
            }

            Section {
                // Takes the journal off the moment and keeps the moment (April, Nov 20).
                if hasJournal {
                    Button("Remove journal", role: .destructive) { confirmClear = true }
                        .frame(maxWidth: .infinity)
                }
                Button("Delete moment", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        // Room under the last row for the bar and the + floating over the page.
        .contentMargins(.bottom, 110, for: .scrollContent)
        .navigationTitle(event.loggedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $pickingPlace) {
            MomentPlacePicker(event: event) { lat, lon, name in
                event.latitude = lat; event.longitude = lon; event.placeName = name
                save()
            }
        }
        .sheet(isPresented: Binding(get: { journal != nil }, set: { if !$0 { closeJournal() } })) {
            if let s = journal {
                CaptureSheet(session: s, chat: captureStyle == .chat, voice: false) { journal = nil }
            }
        }
        .confirmationDialog("Remove this moment's journal?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Remove journal", role: .destructive) { clearJournal() }
        } message: {
            Text("The words, the recording and the tags are deleted from this iPhone. The moment and its air stay. This can't be undone.")
        }
        .confirmationDialog("Delete this moment?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await services.delete(event, in: context) }
                dismiss()
            }
        } message: {
            Text("It's removed from your journal and from Apple Health. This can't be undone.")
        }
        .onAppear { healthPuffs = event.puffs; healthTime = event.loggedAt }
        .onDisappear {
            guard !event.isDeleted, event.puffs != healthPuffs || event.loggedAt != healthTime else { return }
            Task { await services.rewriteHealth(event, in: context) }
        }
    }

    // MARK: Bindings

    private var time: Binding<Date> {
        Binding(get: { event.loggedAt }, set: { t in
            // The uses move with the moment, so their presses stay inside it.
            let shift = t.timeIntervalSince(event.loggedAt)
            event.loggedAt = t
            for u in event.uses { u.at = u.at.addingTimeInterval(shift); u.lastPressAt = u.lastPressAt.addingTimeInterval(shift) }
            save()
        })
    }

    /// The total across uses. The change lands on the latest use, which is where a missed or doubled press was.
    private var puffs: Binding<Int> {
        Binding(get: { max(1, event.puffs) }, set: { n in
            if event.uses.isEmpty {
                let kind: Inhaler.Kind = event.moment == .rescue ? .rescue : .controller
                event.uses.append(InhalerUse(at: event.loggedAt, kind: kind, inhaler: Inhaler.current(kind), device: .unknown, puffs: n))
            } else if let last = event.uses.max(by: { $0.at < $1.at }) {
                let others = event.puffs - last.puffs
                last.puffs = max(1, n - others)
            }
            UISelectionFeedbackGenerator().selectionChanged()
            save()
        })
    }

    private var inside: Binding<IndoorOutdoor?> {
        Binding(get: { event.indoorConfirmedRaw.flatMap(IndoorOutdoor.init(rawValue:)) },
                set: { event.indoorConfirmedRaw = $0?.rawValue; save() })
    }

    // MARK: Pieces

    /// The +'s capture, on this moment: the same questions, chips, mic and keyboard.
    private func openJournal() {
        journal = CaptureSession(event: event, chat: captureStyle == .chat, autoSelect: autoSelect == .ticked)
    }

    /// Closing it any way keeps what was said or picked, or drops an empty one (as from the +).
    private func closeJournal() {
        guard let s = journal else { return }
        if s.listening { Task { await s.stopListening(); if s.hasAnything { s.save(context: context) } else { s.discard() } } }
        else if s.hasAnything { s.save(context: context) } else { s.discard() }
        journal = nil
    }

    private func save() { try? context.save() }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
