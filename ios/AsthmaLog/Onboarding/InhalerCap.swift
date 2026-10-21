import AsthmaCore
import SwiftUI

/// Onboarding's pair screen: a metered-dose inhaler in side profile, the felt button as the cap on its canister.
/// The plastic boot is line art in the text colour with a faint fill, the mouthpiece pointing left; the metal
/// canister stands in it, its top third above the rim; the felt cap sits on the canister in the cap's colour.
/// Waiting for a felt button, the cap is a dashed outline that breathes. Without one, it's a
/// **software cap** you press. It counts the way the felt button does (`hardware/felt-button/felt-button.ino`):
/// the moment it goes down, after the firmware's 30 ms debounce, with no hold. Canister and cap slide into the
/// boot over the firmware's 150 ms press flash, one firm thud, a small puff from the mouthpiece, and they spring
/// back. Chrome has no colour; the cap's colour is the only ink, the same as the felt button's own cap.
struct InhalerCap: View {
    enum Mode: Equatable {
        /// A felt button is being paired: the cap is a dashed outline, listening.
        case waiting
        /// No felt button: press the cap on screen.
        case soft
        /// Pressed (by either): filled in the cap's colour, no longer pressable.
        case pressed
    }

    let mode: Mode
    var cap: ButtonPacket.Cap = .rescue
    /// Recordings in the simulator (Debug, `-demoPress`): presses the cap by itself a few seconds in.
    var autoPress = false
    /// The press counted.
    var onActuate: () -> Void = {}

    /// The felt button's own timings (`felt-button.ino`): a press counts once the contact has been steady
    /// for `DEBOUNCE_MS`, and the LED flashes for `PRESS_MS`. There's no hold threshold in the firmware.
    static let debounce: Double = 0.030
    static let pressFlash: Double = 0.150

    @State private var travel: CGFloat = 0
    @State private var down = false
    @State private var fired = false
    @State private var pending: Task<Void, Never>?
    /// The puff: shown at the bottom of the travel, then drifting out and fading.
    @State private var puffShown = false
    @State private var puffOut = false
    /// Reduce Motion: no travel, the cap brightens briefly instead.
    @State private var highlight = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ink: Color { cap == .standard ? Theme.standard : Theme.rescue }

    var body: some View {
        ZStack(alignment: .topLeading) {
            boot
            // Canister and cap ride down together; above the rim only, so they slide in behind the boot's wall.
            ZStack(alignment: .topLeading) {
                canister
                capView
            }
            .offset(y: reduceMotion ? 0 : travel * Geo.travel)
            .frame(width: Geo.size.width, height: Geo.size.height, alignment: .topLeading)
            .mask(alignment: .topLeading) { Rectangle().frame(width: Geo.size.width, height: Geo.boot.minY + Geo.line / 2) }
            puffDots
        }
        .frame(width: Geo.size.width, height: Geo.size.height, alignment: .topLeading)
        .contentShape(.rect)
        .animation(Theme.snap, value: mode)
        .modifier(Press(enabled: mode != .waiting, onChange: pressing))
        .accessibilityElement()
        .accessibilityLabel(mode == .waiting ? OnboardingCopy.capWaitingLabel : OnboardingCopy.capLabel)
        .accessibilityHint(mode == .soft ? OnboardingCopy.capHint : "")
        .accessibilityAddTraits(mode == .soft ? .isButton : [])
        .accessibilityAction { if mode == .soft { actuate() } }
        #if DEBUG
        .task {
            guard autoPress, mode == .soft else { return }
            try? await Task.sleep(for: .seconds(3))
            pressing(true)
            try? await Task.sleep(for: .seconds(Self.pressFlash))
            pressing(false)
        }
        #endif
    }

    // MARK: Drawing (side profile, mouthpiece to the left)

    /// The plastic actuator: line art in the text colour over a faint plastic fill, open at the top.
    private var boot: some View {
        ZStack(alignment: .topLeading) {
            BootShape().fill(.primary.opacity(0.06))
            BootShape().stroke(.primary, style: StrokeStyle(lineWidth: Geo.line, lineCap: .round, lineJoin: .round))
            // The mouthpiece's opening: a slightly flared rim, seen edge-on.
            Capsule(style: .continuous)
                .fill(.primary.opacity(0.06))
                .overlay { Capsule(style: .continuous).stroke(.primary, lineWidth: Geo.line) }
                .frame(width: Geo.mouth.width, height: Geo.mouth.height)
                .offset(x: Geo.mouth.minX, y: Geo.mouth.minY)
            // The seat the canister's stem sits in, seen through the boot's wall.
            Capsule().fill(.primary.opacity(0.25))
                .frame(width: Geo.canister.width * 0.5, height: Geo.line)
                .offset(x: Geo.canister.midX - Geo.canister.width * 0.25, y: Geo.boot.maxY - 62)
        }
        .frame(width: Geo.size.width, height: Geo.size.height, alignment: .topLeading)
    }

    /// The metal canister: a neutral grey outline with a faint vertical highlight.
    private var canister: some View {
        let r = Geo.canister
        let body = UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 4,
                                          bottomTrailingRadius: 4, topTrailingRadius: 12, style: .continuous)
        return ZStack(alignment: .topLeading) {
            body.fill(Color(white: 0.55).opacity(0.22))
            body.stroke(Color(white: 0.72), lineWidth: Geo.line)
            Capsule().fill(.white.opacity(0.4))
                .frame(width: 2.5, height: r.height * 0.6)
                .offset(x: r.width * 0.22, y: r.height * 0.24)
        }
        .frame(width: r.width, height: r.height)
        .offset(x: r.minX, y: r.minY)
    }

    /// The felt cap on the canister: the cap's colour with a soft rim, or a dashed outline while waiting.
    @ViewBuilder private var capView: some View {
        let r = Geo.cap
        ZStack(alignment: .top) {
            if mode == .waiting {
                // Listening: the empty cap breathes (the rings that used to listen ran through the line art).
                TimelineView(.animation(paused: reduceMotion)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let breath = reduceMotion ? 1 : 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 2 * .pi / 2.6))
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(.white.opacity(0.75 * breath), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                }
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(ink)
                // The felt top, softer, over a rim line so the cap reads round.
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(ink.mix(with: .white, by: 0.18))
                    .frame(height: r.height * 0.42)
                    .padding(.horizontal, 2).padding(.top, 2)
                Capsule().fill(.black.opacity(0.16))
                    .frame(height: 1.5).padding(.horizontal, 5)
                    .offset(y: r.height * 0.42 + 2.5)
            }
        }
        .frame(width: r.width, height: r.height)
        .brightness(highlight ? 0.2 : 0)
        .offset(x: r.minX, y: r.minY)
    }

    /// A small puff from the mouthpiece at the bottom of the travel: riso dots, fading over 400 ms.
    private var puffDots: some View {
        let o = Geo.mouth
        return ZStack(alignment: .topLeading) {
            ForEach(Self.puff.indices, id: \.self) { i in
                let d = Self.puff[i]
                Circle().fill(.primary.opacity(0.4))
                    .frame(width: d.z, height: d.z)
                    .offset(x: o.minX - 4 - d.x * (puffOut ? 1.5 : 0.5), y: o.midY + d.y * (puffOut ? 1.4 : 0.5))
            }
        }
        .frame(width: Geo.size.width, height: Geo.size.height, alignment: .topLeading)
        .opacity(puffShown && !puffOut ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Fixed dot offsets (x leftward, y about the mouthpiece's centre, z size): the same puff each time.
    private static let puff: [(x: CGFloat, y: CGFloat, z: CGFloat)] = [
        (6, -8, 3), (10, 4, 2.5), (14, -16, 2), (18, 12, 3), (22, -2, 2.5), (26, -20, 2), (30, 18, 2),
        (34, 6, 3), (38, -10, 2.5), (42, 0, 2), (46, 14, 2), (50, -14, 2.5), (56, 6, 2), (60, -4, 2),
    ]

    // MARK: The press

    private func pressing(_ isDown: Bool) {
        guard isDown != down else { return }
        down = isDown
        if isDown {
            guard !fired, mode == .soft else { return }
            withAnimation(.easeIn(duration: Self.pressFlash)) { travel = 1 }
            // Counts after the firmware's debounce: a touch that lifts before then is a glitch, not a press.
            pending = Task {
                try? await Task.sleep(for: .seconds(Self.debounce))
                guard !Task.isCancelled else { return }
                actuate()
            }
        } else {
            pending?.cancel()
            // Let go: the canister springs back (before the press counted, nothing is logged).
            withAnimation(fired ? Theme.lift : Theme.snap) { travel = 0; highlight = false }
        }
    }

    private func actuate() {
        guard !fired else { return }
        fired = true
        onActuate()
        Task {
            // Reach the bottom with the press flash: the thud, the puff, then spring back.
            try? await Task.sleep(for: .seconds(Self.pressFlash - Self.debounce))
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
            if reduceMotion {
                highlight = true
            } else {
                puffShown = true
                withAnimation(.easeOut(duration: 0.4)) { puffOut = true }
            }
            // Held, it stays down like a real canister; it springs back when you let go (or after the
            // flash for VoiceOver's action, which has no release).
            try? await Task.sleep(for: .seconds(Self.pressFlash))
            if !down { withAnimation(Theme.lift) { travel = 0; highlight = false } }
            try? await Task.sleep(for: .seconds(0.3))
            puffShown = false
            puffOut = false
        }
    }
}

/// The inhaler's layout in its 260 × 300 frame. Proportions from a rescue MDI: the boot about 1 : 2.4,
/// the mouthpiece about 60% of the boot's width, a third of the canister above the rim, an 18% travel.
nonisolated private enum Geo {
    static let size = CGSize(width: 260, height: 300)
    static let line: CGFloat = 2.5
    /// The boot's upright body.
    static let boot = CGRect(x: 136, y: 108, width: 76, height: 182)
    /// The mouthpiece's height where it leaves the body.
    static let mouthHeight: CGFloat = 46
    /// The mouthpiece's flared opening at the left.
    static let mouth = CGRect(x: 46, y: boot.maxY - mouthHeight - 6, width: 12, height: mouthHeight + 12)
    static let canister = CGRect(x: boot.midX - 24, y: boot.minY - 44, width: 48, height: 128)
    static let cap = CGRect(x: boot.midX - 30, y: canister.minY - 20, width: 60, height: 28)
    static let travel: CGFloat = canister.height * 0.18
}

/// The boot's outline: open at the top between two short lips, down the back, out along the mouthpiece to its
/// flare, back under the mouthpiece and up the front. Closes across the opening, which the fill needs.
nonisolated private struct BootShape: Shape {
    func path(in _: CGRect) -> Path {
        let b = Geo.boot
        let lip: CGFloat = 12
        let mouthTop = b.maxY - Geo.mouthHeight
        let flareX = Geo.mouth.midX
        var p = Path()
        p.move(to: CGPoint(x: b.minX + lip, y: b.minY))
        p.addLine(to: CGPoint(x: b.minX + 6, y: b.minY))
        p.addQuadCurve(to: CGPoint(x: b.minX, y: b.minY + 6), control: CGPoint(x: b.minX, y: b.minY))
        p.addLine(to: CGPoint(x: b.minX, y: mouthTop - 18))
        // The body angles into the mouthpiece.
        p.addQuadCurve(to: CGPoint(x: b.minX - 22, y: mouthTop), control: CGPoint(x: b.minX, y: mouthTop))
        p.addLine(to: CGPoint(x: flareX + 14, y: mouthTop + 2))
        // The flare out to the opening's rim.
        p.addQuadCurve(to: CGPoint(x: flareX, y: Geo.mouth.minY + 2), control: CGPoint(x: flareX + 4, y: mouthTop + 2))
        p.addLine(to: CGPoint(x: flareX, y: Geo.mouth.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: flareX + 14, y: b.maxY), control: CGPoint(x: flareX + 4, y: b.maxY))
        p.addLine(to: CGPoint(x: b.maxX - 24, y: b.maxY))
        p.addQuadCurve(to: CGPoint(x: b.maxX, y: b.maxY - 24), control: CGPoint(x: b.maxX, y: b.maxY))
        p.addLine(to: CGPoint(x: b.maxX, y: b.minY + 6))
        p.addQuadCurve(to: CGPoint(x: b.maxX - 6, y: b.minY), control: CGPoint(x: b.maxX, y: b.minY))
        p.addLine(to: CGPoint(x: b.maxX - lip, y: b.minY))
        return p
    }
}

/// Touch down and up, reported as they happen (no hold), and nothing when disabled.
private struct Press: ViewModifier {
    let enabled: Bool
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in onChange(true) }
                .onEnded { _ in onChange(false) })
        } else {
            content
        }
    }
}
