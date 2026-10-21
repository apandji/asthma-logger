import AsthmaCore
import SwiftUI

/// Onboarding's pair screen: the inhaler seen from above, the felt button on its cap.
/// Waiting for a felt button, the cap is an empty ring that listens. Without one, it's a **software cap**
/// in the cap's colour that you press and hold, like actuating an inhaler: the cap travels down, a ring fills,
/// a light tick as it travels and one firm thud at the bottom. Let go early and nothing happens.
/// Chrome (the boot) has no colour; the cap's colour is the only ink, the same as the felt button's own cap.
struct InhalerCap: View {
    enum Mode: Equatable {
        /// A felt button is being paired: the cap is an empty ring, listening.
        case waiting
        /// No felt button: press and hold the cap on screen.
        case soft
        /// Pressed (by either): filled in the cap's colour, no longer pressable.
        case pressed
    }

    let mode: Mode
    var cap: ButtonPacket.Cap = .rescue
    /// Recordings in the simulator (Debug, `-demoPress`): holds the cap by itself a few seconds in.
    var autoPress = false
    /// The hold reached the bottom of its travel.
    var onActuate: () -> Void = {}

    /// How long a press takes to reach the bottom, like a canister's travel.
    static let travelTime: Double = 0.6

    @State private var travel: CGFloat = 0
    @State private var holding = false
    @State private var fired = false
    @State private var ticks: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let capSize: CGFloat = 112

    private var ink: Color { cap == .standard ? Theme.standard : Theme.rescue }

    var body: some View {
        ZStack {
            if mode == .waiting { Listening().transition(.opacity) }
            boot
            ring
            capFace
        }
        .frame(width: 260, height: 300)
        .contentShape(.rect)
        .animation(Theme.snap, value: mode)
        .modifier(Hold(enabled: mode == .soft, minimum: Self.travelTime, onPressing: pressing, onDone: actuate))
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
            try? await Task.sleep(for: .seconds(Self.travelTime))
            actuate()
        }
        #endif
    }

    /// The inhaler's plastic holder from above: the body the canister sits in, and the mouthpiece below it.
    private var boot: some View {
        VStack(spacing: -10) {
            RoundedRectangle(cornerRadius: 58, style: .continuous).frame(width: 156, height: 176)
            RoundedRectangle(cornerRadius: 16, style: .continuous).frame(width: 104, height: 52)
        }
        .foregroundStyle(.white.opacity(0.07))
        .overlay {
            VStack(spacing: -10) {
                RoundedRectangle(cornerRadius: 58, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1).frame(width: 156, height: 176)
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1).frame(width: 104, height: 52)
            }
        }
        .offset(y: 26)
    }

    /// The travel: a ring that fills as the cap goes down.
    private var ring: some View {
        Circle()
            .trim(from: 0, to: travel)
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: capSize + 22, height: capSize + 22)
            .opacity(mode == .soft ? 1 : 0)
    }

    @ViewBuilder private var capFace: some View {
        let pressedIn = reduceMotion ? 0 : travel
        ZStack {
            if mode == .waiting {
                Circle().strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
            } else {
                Circle().fill(ink)
                // The felt top: a softer disc inset in the cap.
                Circle().fill(ink.mix(with: .white, by: 0.14)).padding(capSize * 0.13)
                Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1).padding(capSize * 0.13)
            }
        }
        .frame(width: capSize, height: capSize)
        .shadow(color: .black.opacity(mode == .waiting ? 0 : 0.45 * (1 - pressedIn)), radius: 10 * (1 - pressedIn), y: 6 * (1 - pressedIn))
        .scaleEffect(1 - 0.08 * pressedIn)
        .brightness(-0.12 * Double(pressedIn))
    }

    // MARK: The press

    private func pressing(_ down: Bool) {
        if down {
            guard !fired else { return }
            holding = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
            withAnimation(.linear(duration: Self.travelTime)) { travel = 1 }
            // A light tick as the canister travels.
            ticks = Task {
                let tick = UIImpactFeedbackGenerator(style: .light)
                for k in 1...2 {
                    try? await Task.sleep(for: .seconds(Self.travelTime / 3))
                    guard !Task.isCancelled else { return }
                    tick.impactOccurred(intensity: 0.4 + 0.2 * Double(k))
                }
            }
        } else {
            holding = false
            ticks?.cancel()
            // Let go early: it springs back, nothing logged.
            if !fired { withAnimation(Theme.snap) { travel = 0 } }
        }
    }

    private func actuate() {
        guard !fired else { return }
        fired = true
        ticks?.cancel()
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        withAnimation(Theme.lift) { travel = 0 }
        onActuate()
    }
}

/// A press and hold that reports going down and reaching the end, and does nothing when disabled.
private struct Hold: ViewModifier {
    let enabled: Bool
    let minimum: Double
    let onPressing: (Bool) -> Void
    let onDone: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onLongPressGesture(minimumDuration: minimum, maximumDistance: 40, perform: onDone, onPressingChanged: onPressing)
        } else {
            content
        }
    }
}
