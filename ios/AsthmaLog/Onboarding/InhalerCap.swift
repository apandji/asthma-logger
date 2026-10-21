import AsthmaCore
import SwiftUI

/// Onboarding's pair screen: the inhaler seen from above, the felt button on its cap.
/// Waiting for a felt button, the cap is an empty ring that listens. Without one, it's a **software cap**
/// in the cap's colour that you press. It counts the way the felt button does (`hardware/felt-button/felt-button.ino`):
/// the moment it goes down, after the firmware's 30 ms debounce, with no hold. The cap sinks for the firmware's
/// 150 ms press flash, a ring fills with it, one firm thud, and it springs back.
/// Chrome (the boot) has no colour; the cap's colour is the only ink, the same as the felt button's own cap.
struct InhalerCap: View {
    enum Mode: Equatable {
        /// A felt button is being paired: the cap is an empty ring, listening.
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
        .modifier(Press(enabled: mode == .soft, onChange: pressing))
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

    private func pressing(_ isDown: Bool) {
        guard isDown != down else { return }
        down = isDown
        if isDown {
            guard !fired else { return }
            withAnimation(.easeIn(duration: Self.pressFlash)) { travel = 1 }
            // Counts after the firmware's debounce: a touch that lifts before then is a glitch, not a press.
            pending = Task {
                try? await Task.sleep(for: .seconds(Self.debounce))
                guard !Task.isCancelled else { return }
                actuate()
            }
        } else {
            pending?.cancel()
            if !fired { withAnimation(Theme.snap) { travel = 0 } }
        }
    }

    private func actuate() {
        guard !fired else { return }
        fired = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        onActuate()
        // Stay at the bottom for the press flash, then spring back.
        Task {
            try? await Task.sleep(for: .seconds(Self.pressFlash))
            withAnimation(Theme.lift) { travel = 0 }
        }
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
