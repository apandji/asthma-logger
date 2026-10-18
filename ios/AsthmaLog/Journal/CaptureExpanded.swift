import AsthmaCore
import SwiftUI

/// The capture card, grown: it rises from where the card sat and stops short, so the moment's line and a
/// band of its sky stay in view above it. Two styles to compare with people (Crit.CaptureStyle, test A1):
/// a chat that asks one question at a time, and a classic journal with sections. Same session underneath.
/// Swipe down or tap the sky above to close; anything said is kept.
struct CaptureExpanded: View {
    @Bindable var session: CaptureSession
    let chat: Bool
    let close: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    @State private var map: UIImage?
    /// What was on your calendar then (EventKit, on this iPhone; the title never leaves it).
    @State private var around: CalendarReader.Event?

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                // The sky above stays visible, dimmed; a tap there closes.
                Color.black.opacity(0.35).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: finish)
                VStack(spacing: 0) {
                    handle
                    if chat { ChatCapture(session: session, finish: finish) } else { JournalCapture(session: session) }
                }
                .frame(height: g.size.height * 0.8)
                .frame(maxWidth: .infinity)
                .background(Theme.stage.opacity(0.55))
                .glassEffect(.regular, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .offset(y: max(0, drag))
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { drag = $0.translation.height }
                        .onEnded { v in
                            if v.translation.height > 120 || v.predictedEndTranslation.height > 260 { finish() }
                            withAnimation(Theme.snap) { drag = 0 }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: session.live) { _, words in if session.listening { session.hear(words) } }
        .task {
            let t = session.event.loggedAt
            around = CalendarReader.shared.events(from: t.addingTimeInterval(-3600), to: t.addingTimeInterval(900))
                .first { !$0.isAllDay }
        }
        .task {
            // The same snapshot the sky drew (cached), so it's there at once.
            guard let lat = session.event.latitude, let lon = session.event.longitude else { return }
            let img = await MapSnapshots.image(id: session.event.id.uuidString, latitude: lat, longitude: lon,
                                               size: SkyPanel.mapSize, dark: true, scale: SkyPanel.mapScale)
            withAnimation(Theme.smooth) { map = img }
        }
    }

    /// The grabber, the moment, and Done.
    private var handle: some View {
        VStack(spacing: 10) {
            Capsule().fill(Color.primary.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)
            HStack(spacing: 8) {
                // The sheet covers the map: a small one comes along, with where and when.
                if let map {
                    // The middle of the snapshot (the pin and its streets), not the whole wide view.
                    Image(uiImage: map).resizable().scaledToFill()
                        .frame(width: 40, height: 40).scaleEffect(3).frame(width: 40, height: 40).clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                        .overlay(Circle().fill(Color.white).frame(width: 6, height: 6))
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 1) {
                    MomentTag(moment: session.event.moment)
                    Text([session.event.placeName, NowTimeline.when(session.event.loggedAt, now: .now)]
                            .compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote.weight(.medium)).foregroundStyle(Theme.secondaryText).lineLimit(1)
                    if let around { aroundLine(around) }
                }
                Spacer()
                // The chat finishes at the thumb (its bottom-right button); the journal keeps Done up here.
                if !chat {
                    Button("Done", action: finish)
                        .font(.headline)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .buttonStyle(PressStyle())
                }
            }
            .frame(minHeight: 40)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 6)
    }

    /// "Team sync, 4–5 PM" from the calendar. While the question is what you were doing or where, a tap
    /// answers it with the event; otherwise it's just there to jog the memory.
    private func aroundLine(_ e: CalendarReader.Event) -> some View {
        let answers = chat && (session.question == .doing || session.question == .place) && !session.listening
        return Button {
            session.answer("At \(e.title)")
        } label: {
            Label(e.line, systemImage: "calendar")
                .font(.footnote.weight(.medium)).lineLimit(1)
                .foregroundStyle(answers ? Color.primary : Theme.secondaryText)
        }
        .buttonStyle(PressStyle())
        .disabled(!answers)
        .accessibilityHint(answers ? "Answers with this event" : "")
    }

    private func finish() {
        if session.listening { Task { await session.stopListening(); keepOrDrop() } } else { keepOrDrop() }
    }

    private func keepOrDrop() {
        if session.hasAnything { session.save(context: context) } else { session.discard() }
        close()
    }
}

// MARK: - Chat

/// One question at a time, like an assistant's thread: felt air's question in the serif on the left, your
/// answer in a bubble on the right (streaming as you speak, the words it's picking up lit), then what it
/// heard as chips you can untick, then the next question. The questions are a fixed set (`Interview`), never
/// generated, and it ends after a few. Quick replies sit above the composer for when you can't talk.
private struct ChatCapture: View {
    @Bindable var session: CaptureSession
    let finish: () -> Void
    @State private var typing = false
    @State private var typed = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(session.turns) { turn in row(turn, current: turn == currentQuestion).id(turn.id) }
                        // The answers sit under their question, in the thread, not parked above the composer.
                        replies.id("replies")
                        if session.listening || session.writing {
                            bubble(Text(session.live.isEmpty ? "Listening…" : "").foregroundStyle(Theme.secondaryText), live: true)
                                .id("live")
                        }
                        if session.done {
                            Text("That's everything. Done keeps it with this moment.")
                                .font(.subheadline).foregroundStyle(Theme.secondaryText).id("done")
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                // Earlier turns fade under the header rather than being cut by it.
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                                             .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
                .onChange(of: session.turns.count) { _, _ in withAnimation(Theme.smooth) { proxy.scrollTo("replies", anchor: .bottom) } }
                .onChange(of: session.live) { _, _ in proxy.scrollTo("live", anchor: .bottom) }
            }
            composer
        }
    }

    /// The question waiting for an answer: the last turn, while the interview is still going.
    private var currentQuestion: CaptureSession.Turn? {
        guard !session.done, let last = session.turns.last, case .question = last else { return nil }
        return last
    }

    /// The question being asked is the sentence; answered ones step back to a quiet line above their answer,
    /// so the thread reads as pairs and only one thing is large at a time.
    @ViewBuilder private func row(_ turn: CaptureSession.Turn, current: Bool) -> some View {
        switch turn {
        case .question(let q):
            Group {
                if current {
                    Text(session.text(q)).font(Theme.Typeface.sentence(size: 22)).kerning(Theme.serifKerning)
                } else {
                    Text(session.text(q)).font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, turn == session.turns.first ? 0 : 14)
            .animation(Theme.smooth, value: current)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .answer(_, let text):
            if text == "…" {
                // A voice answer with no words written down: say so, rather than an empty bubble.
                bubble(Label("Voice note", systemImage: "waveform").font(.subheadline).foregroundStyle(Theme.secondaryText))
            } else {
                bubble(LiveWords(text: text, ink: Theme.rescueSoft, font: .body, lineLimit: nil, hugs: true))
            }
        case .heard(_, let tags):
            // What felt air picked up, like an assistant's tool result: tap one to untick it.
            VStack(alignment: .leading, spacing: 6) {
                Label("Heard", systemImage: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                FlowLayout(spacing: 6) {
                    ForEach(tags) { t in
                        CaptureChip(tag: t, on: session.chosen.contains(t), suggested: session.suggested.contains(t), small: true) { session.toggle(t) }
                    }
                }
            }
        }
    }

    private func bubble(_ content: some View, live: Bool = false) -> some View {
        HStack {
            Spacer(minLength: 48)
            Group {
                if live, !session.live.isEmpty {
                    LiveWords(text: session.live, ink: Theme.rescueSoft, font: .body, lineLimit: nil, hugs: true)
                } else {
                    content
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(live ? 0.14 : 0.1)))
            .overlay {
                if live { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.rescueSoft.opacity(0.6), lineWidth: 1.2) }
            }
        }
    }

    /// The current question's replies, big enough to hit mid-flare.
    @ViewBuilder private var replies: some View {
        if let q = session.question, !session.listening {
            let rs = Interview.replies(q)
            if !rs.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(rs, id: \.self) { r in
                        switch r {
                        case .tag(let t):
                            CaptureChip(tag: t, on: session.chosen.contains(t), suggested: session.suggested.contains(t)) { session.reply(r) }
                        default:
                            CaptureChip(label: r.label, on: false) { session.reply(r) }
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
    }

    private var canSendTyped: Bool { typing && !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canSend: Bool { canSendTyped || session.pickedForQuestion }

    private func sendTyped() {
        guard canSendTyped else { return }
        session.answer(typed)
        typed = ""
    }

    private func switchMode() {
        if typing {
            focused = false
            withAnimation(Theme.smooth) { typing = false }
            Task { await session.startListening() }
        } else if session.listening {
            Task {
                await session.stopListening(toType: true)
                typed = [typed, session.draft ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
                session.draft = nil
                withAnimation(Theme.smooth) { typing = true }
                focused = true
            }
        } else {
            withAnimation(Theme.smooth) { typing = true }
            focused = true
        }
    }

    /// The last question (or all asked): the arrow becomes a checkmark that finishes.
    private var isLast: Bool { session.done || session.question == .anythingElse }

    /// The one action at the thumb: an arrow that sends what you typed or the chips you picked (quiet, it
    /// skips the question), and on the last question a checkmark that sends them and finishes. Swiping down also keeps it, at any point.
    private var primary: some View {
        let on = canSend || isLast
        return Button {
            if canSendTyped { sendTyped() } else if session.pickedForQuestion { session.sendPicked() }
            else if !isLast { session.skip() }
            if isLast { finish() }
        } label: {
            Image(systemName: isLast ? "checkmark" : "arrow.up").font(.title3.weight(.semibold))
                .frame(width: 48, height: 48)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(on ? Color.black : Theme.secondaryText)
                .background(Circle().fill(on ? Color.white : Color.clear))
                .glassEffect(.regular.interactive(), in: .circle)
                .animation(Theme.smooth, value: isLast)
        }
        .buttonStyle(PressStyle())
        .disabled(session.listening)
        .accessibilityLabel(isLast ? "Done" : canSend ? "Send" : "Skip this question")
    }

    /// Mic in the middle; type on the left; the one action on the right.
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Speaking ⇄ typing in one tap: mid-sentence, what you said so far becomes the text to edit; while
            // typing, the same button is the mic again.
            Button { switchMode() } label: {
                Image(systemName: typing ? "mic" : "keyboard").font(.title3).frame(width: 48, height: 48)
                    .contentTransition(.symbolEffect(.replace))
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(typing ? "Speak instead" : "Type instead")

            if typing {
                // Grows to a few lines: an answer switched over from speaking is often a sentence or two.
                TextField("Type an answer", text: $typed, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(sendTyped)
                    .padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 48)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            } else {
                Spacer()
                MicButton(session: session)
                Spacer()
            }
            primary

        }
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 34)
        // The thread above gives way, so the field can grow to its lines.
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Journal

/// The classic journal entry: your words at the top (spoken or typed, the words it's picking up lit), then
/// the same questions as sections of chips, in the providers' order. Everything visible at once, nothing
/// asked; you fill what applies.
private struct JournalCapture: View {
    @Bindable var session: CaptureSession

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    words
                    section(Interview.Question.symptoms.text, JournalTag.symptoms.filter { $0 != .wokeAtNight && $0 != .activityLimited })
                    // Puffs are counted where they were logged (LoggedPanel), so no "second puff" chip here.
                    section("Did it…", [.wokeAtNight, .activityLimited, .betterAfter])
                    section("What were you doing?", [.exercise, .cooking, .cleaningProducts, .stress, .laughingOrCrying])
                    section("What was around you?", [.pets, .smoke, .dust, .mold, .coldAir, .strongScents, .coldOrFlu])
                    section("Anything else?", [.urgentVisit, .oralSteroids])
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            HStack { Spacer(); MicButton(session: session); Spacer() }
                .padding(.top, 6).padding(.bottom, 34)
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What happened?").font(Theme.Typeface.sentence(size: 22)).kerning(Theme.serifKerning)
            ZStack(alignment: .topLeading) {
                if session.listening {
                    LiveWords(text: session.journalWords.isEmpty ? session.live : session.journalWords + " " + session.live,
                              ink: Theme.rescueSoft, font: .body, lineLimit: nil)
                } else {
                    TextField("Say it or type it. Where you were, what you were doing, how it felt.",
                              text: $session.journalWords, axis: .vertical)
                        .font(.body).lineLimit(3...8)
                        .onChange(of: session.journalWords) { _, w in session.hear(w) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.08)))
            .overlay {
                if session.listening { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.rescueSoft.opacity(0.6), lineWidth: 1.2) }
            }
        }
    }

    private func section(_ title: String, _ tags: [JournalTag]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(tags) { t in
                    CaptureChip(tag: t, on: session.chosen.contains(t), suggested: session.suggested.contains(t)) { session.toggle(t) }
                }
            }
        }
    }
}

// MARK: - Parts

/// Tap to talk, tap to stop. While listening it takes the inhaler's ink and the grain breathes with you.
private struct MicButton: View {
    let session: CaptureSession

    var body: some View {
        Button {
            Task { if session.listening { await session.stopListening() } else { await session.startListening() } }
        } label: {
            ZStack {
                if session.listening {
                    VoiceGrain(level: Double(VoiceNotes.shared.level), listening: true, ink: Theme.rescueSoft)
                        .frame(width: 96, height: 96).allowsHitTesting(false)
                }
                Image(systemName: session.writing ? "ellipsis" : session.listening ? "stop.fill" : "mic.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(session.listening ? Color.black : .primary)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(session.listening ? AnyShapeStyle(Theme.rescueSoft) : AnyShapeStyle(Color.clear)))
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(PressStyle())
        .disabled(session.writing)
        .accessibilityLabel(session.listening ? "Stop" : "Talk")
    }
}

/// A big tappable chip: 44 pt tall, body text. Symptoms and outcomes in their own ink, triggers plain. A
/// suggestion (heard, not ticked) has a dashed edge; one that was just heard pops in.
struct CaptureChip: View {
    var label: String
    var kind: JournalTag.Kind?
    let on: Bool
    var suggested = false
    var small = false
    let action: () -> Void

    init(tag: JournalTag, on: Bool, suggested: Bool = false, small: Bool = false, action: @escaping () -> Void) {
        label = tag.label; kind = tag.kind; self.on = on; self.suggested = suggested; self.small = small; self.action = action
    }

    init(label: String, on: Bool, action: @escaping () -> Void) {
        self.label = label; kind = nil; self.on = on; self.action = action
    }

    private var ink: Color { kind == .trigger || kind == nil ? .white : Theme.symptom }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(small ? .subheadline.weight(.medium) : .body.weight(.medium))
                .foregroundStyle(on ? Color.black : .primary)
                .padding(.horizontal, small ? 12 : 16)
                .frame(minHeight: small ? 32 : 44)
                .background(Capsule().fill(on ? AnyShapeStyle(ink) : AnyShapeStyle(Color.primary.opacity(0.1))))
                .overlay {
                    if suggested && !on {
                        Capsule().strokeBorder(ink.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    } else if kind == .symptom || kind == .outcome, !on {
                        Capsule().strokeBorder(Theme.symptom.opacity(0.45), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(PressStyle())
        .animation(Theme.snap, value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
