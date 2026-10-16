#if DEBUG
import AsthmaCore
import SwiftUI

/// Debug-only prototype of the voice note effect (docs/design/voice-exploration.md).
/// Settings → Prototypes → "Voice effect (prototype)". No microphone, no Speech, no new permissions: the level is
/// simulated, the transcript is canned, and tags come from `VoiceNoteTagger` with keyword rules only.
struct VoiceOrbPrototype: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var level = SimulatedVoiceLevel()
    @State private var isHolding = false
    @State private var transcript: String?
    @State private var suggestions: [TagSuggestion] = []
    @State private var confirmed: Set<JournalTag> = []
    @State private var sample = 0

    var body: some View {
        VStack(spacing: Theme.spacing * 2) {
            Text(isHolding ? "Listening…" : "Hold to tell felt air what's going on")
                .font(Theme.headlineSerif)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            orb
                .frame(maxWidth: .infinity)
                .frame(height: 300)

            holdButton

            if let transcript {
                review(transcript)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.stage.ignoresSafeArea())
        .navigationTitle("Voice effect")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: isHolding)
        .animation(.easeInOut(duration: 0.25), value: transcript)
    }

    // MARK: Orb

    @ViewBuilder private var orb: some View {
        if reduceMotion {
            // No drift or wobble: one still frame, a touch larger while listening.
            orbFrame(time: 0, level: isHolding ? 0.35 : 0)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                orbFrame(time: t, level: level.value(at: t, speaking: isHolding))
            }
        }
    }

    /// Plain SwiftUI, no Metal: a wobbling blob shape masks a drifting mesh of three weave inks,
    /// with a blurred copy behind it as the glow. (A shader version: docs/design/voice-exploration/VoiceOrb.metal.)
    private func orbFrame(time: Double, level: Double) -> some View {
        let t = time.truncatingRemainder(dividingBy: 3600)
        let blob = VoiceBlob(time: t, level: level)
        return ZStack {
            // Glow: wider and brighter as the level rises.
            inks(t, level)
                .mask(blob)
                .blur(radius: 18 + 26 * level)
                .opacity(0.35 + 0.5 * level)
                .scaleEffect(1.05 + 0.1 * level)
            inks(t, level)
                .mask(blob)
                .overlay(blob.stroke(.white.opacity(0.25), lineWidth: 0.75))
        }
        .accessibilityHidden(true)
    }

    /// Today's conditions would pick these inks (the AmbientField's weave); fixed here.
    private func inks(_ t: Double, _ level: Double) -> some View {
        let speed = 0.4 + 1.2 * level
        func d(_ phase: Double, _ amp: Double = 0.18) -> Float { Float(sin(t * speed + phase) * amp) }
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5 + d(0.3, 0.1), 0], [1, 0],
                [0, 0.5 + d(1)], [0.5 + d(2), 0.5 + d(3)], [1, 0.5 + d(4)],
                [0, 1], [0.5 + d(5, 0.1), 1], [1, 1],
            ],
            colors: [
                Theme.weaveAir, Theme.weaveHumidity, Theme.weaveAir,
                Theme.weaveHumidity, Theme.weaveTemperature, Theme.weaveHumidity,
                Theme.weaveTemperature, Theme.weaveAir, Theme.weaveHumidity,
            ]
        )
    }

    // MARK: Hold to talk

    private var holdButton: some View {
        Label(isHolding ? "Release to finish" : "Hold to talk", systemImage: "mic.fill")
            .font(Theme.body.weight(.semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
            .frostedCard(cornerRadius: 28)
            .scaleEffect(isHolding && !reduceMotion ? 0.96 : 1)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 60) {
            } onPressingChanged: { pressing in
                if pressing { start() } else { finish() }
            }
            // VoiceOver can't hold; a double tap records one sample.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Simulated. Records a sample note and suggests tags.")
            .accessibilityAction { start(); finish() }
    }

    private func start() {
        isHolding = true
        transcript = nil
        suggestions = []
        confirmed = []
    }

    private func finish() {
        guard isHolding else { return }
        isHolding = false
        let text = Self.samples[sample % Self.samples.count]
        sample += 1
        transcript = text
        Task {
            // No model here: keyword rules + negation only. The real feature passes a Foundation Models TagProposer.
            let result = await VoiceNoteTagger.suggest(transcript: text, using: nil)
            suggestions = result.suggestions
        }
    }

    // MARK: Review

    private func review(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("\u{201C}\(text)\u{201D}")
                .font(Theme.body)
            if suggestions.isEmpty {
                Text("No tags suggested.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("Tap to confirm")
                    .font(Theme.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryText)
                HStack {
                    ForEach(suggestions) { s in
                        TagChoice(label: s.tag.label, isOn: confirmed.contains(s.tag)) {
                            if confirmed.contains(s.tag) { confirmed.remove(s.tag) } else { confirmed.insert(s.tag) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.padding)
        .frostedCard()
    }

    private static let samples = [
        "Went for a run in the cold this morning, chest got tight on the way back.",
        "Neighbours had a fire going and the cat was on my bed all night.",
        "Cleaning the bathroom with bleach, no exercise today.",
    ]
}

/// A suggested tag: dashed outline until confirmed, then filled. Tags are never inked (visual-style.md).
private struct TagChoice: View {
    let label: String
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Label(label, systemImage: isOn ? "checkmark" : "plus")
                .font(Theme.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? Theme.card : Color.primary)
                .background(isOn ? Color.primary : Color.clear, in: .capsule)
                .overlay {
                    if !isOn {
                        Capsule().strokeBorder(Theme.secondaryText, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "Confirmed" : "Suggested")
    }
}

/// A circle whose edge wobbles: a few sine waves around the rim (whole-number frequencies, so the
/// outline always closes). Quiet = nearly round and small; louder = bigger and wobblier.
nonisolated private struct VoiceBlob: Shape {
    var time: Double
    var level: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) * (0.3 + 0.07 * level)
        let amp = 0.025 + 0.11 * level
        let steps = 120
        var path = Path()
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let wobble = sin(3 * a + time * 1.3) * 0.5
                + sin(5 * a - time * 1.9 + 1) * 0.3
                + sin(7 * a + time * 2.7 + 2) * 0.2
            let r = base * (1 + amp * wobble)
            let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

/// A fake microphone level: syllable-like pulses while "speaking", a faint breath otherwise,
/// eased so it rises fast and falls slowly like a real level meter.
/// Plain class (not observed) so updating it while drawing doesn't re-trigger the view.
private final class SimulatedVoiceLevel {
    private var envelope = 0.0
    private var smoothed = 0.0
    private var last: Double?

    func value(at t: Double, speaking: Bool) -> Double {
        let dt = min(max(t - (last ?? t), 0), 0.1)
        last = t
        envelope += ((speaking ? 1 : 0) - envelope) * min(dt * 6, 1)

        // Two beating sines for syllables, plus a little jitter.
        let syllables = max(0, sin(t * 9.1) * 0.6 + sin(t * 3.7 + 1) * 0.4)
        let jitter = Double.random(in: 0...0.15)
        let raw = 0.04 + envelope * (0.25 + 0.6 * syllables + jitter)

        let rate = raw > smoothed ? 18.0 : 5.0   // fast attack, slow release
        smoothed += (raw - smoothed) * min(dt * rate, 1)
        return min(max(smoothed, 0), 1)
    }
}

#Preview {
    NavigationStack { VoiceOrbPrototype() }
}
#endif
