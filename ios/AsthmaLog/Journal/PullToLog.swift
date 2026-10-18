import AsthmaCore
import SwiftUI

/// The +, pulled. Press, and the button's glass stretches up into a well the same width as the +, with two
/// stops in it: Rescue nearest the thumb, Standard above (small dots in the inhaler inks). The + itself rides
/// up with your finger as a lens; when it reaches a stop, the stop's name appears beside it, the way a
/// reading appears beside the rail. Lift on a stop to log, lift low to cancel. A tap opens the well and keeps
/// it open for a second tap. Nothing changes x: the well grows straight up from the button.
/// Haptics: a soft tick entering Rescue, a rigid one entering Standard, success on the log.
/// VoiceOver gets the plain menu (`CaptureMenu`): no gesture to learn.
struct PullToLog: View {
    let onLog: (MomentKind) -> Void
    @AppStorage(Crit.CaptureOrder.key) private var order = Crit.CaptureOrder.rescueFirst
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    @State private var open = false
    /// Opened by a tap: stays open until a stop is tapped, a touch lands outside, or a few seconds pass.
    @State private var latched = false
    /// Finger height above the +, in points (positive = up).
    @State private var pull: CGFloat = 0
    @State private var zone: MomentKind?
    @State private var logged = 0
    @State private var pressedAt: Date?

    private let button: CGFloat = 56
    private let step: CGFloat = 62
    private var wellHeight: CGFloat { button + 2 * step }
    private var first: MomentKind { order == .rescueFirst ? .rescue : .maintenance }
    private var second: MomentKind { order == .rescueFirst ? .maintenance : .rescue }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            ZStack(alignment: .bottom) {
                if open {
                    well
                        // The same kind of glass as the button, or the morph between them draws nothing.
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("log", in: glass)
                        .transition(.identity)
                } else {
                    // At rest the + is the glass circle's own content (a sibling drawn over the glass doesn't
                    // survive the morph back).
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: button, height: button)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("log", in: glass)
                        .transition(.identity)
                }
                // Open, the + is the lens: it rides up the well with the finger and takes the stop's ink.
                if open {
                    lens.offset(y: -lensRise)
                        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.2, dampingFraction: 0.85), value: lensRise)
                        .transition(.identity)
                }
            }
            .frame(width: button, height: wellHeight, alignment: .bottom)
        }
        .frame(width: button, height: button, alignment: .bottom)   // lays out as the + only; the well overflows upward
        // The stop's name, beside the lens, on the sky's side.
        .overlay(alignment: railLeft ? .bottomLeading : .bottomTrailing) {
            if let zone, open {
                Text(zone == .rescue ? "Rescue" : "Standard")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .glassEffect(.regular, in: .capsule)
                    .fixedSize()
                    .offset(x: railLeft ? button + 10 : -(button + 10), y: -lensRise)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }
        }
        // The hit shape is the + at rest and the whole well once open: the stops sit above the +'s frame,
        // and outside the shape a tap would reach the catcher behind and close the well without logging.
        .contentShape(Path(CGRect(x: 0, y: open ? button - wellHeight : 0, width: button, height: open ? wellHeight : button)))
        .gesture(drag)
        // Opened by a tap: a touch anywhere else closes it (the catcher is oversized on purpose; SwiftUI
        // hit-tests it even outside the +'s own frame), and it closes by itself after a few seconds.
        .background {
            if latched {
                Color.clear.frame(width: 3000, height: 4000).contentShape(Rectangle())
                    .onTapGesture { close() }
                    .task { try? await Task.sleep(for: .seconds(4)); if latched { close() } }
            }
        }
        .animation(reduceMotion ? nil : Theme.lift, value: open)
        .animation(reduceMotion ? nil : Theme.snap, value: zone)
        .sensoryFeedback(.success, trigger: logged)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: zone == first)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: zone == second)
        .accessibilityLabel("Log a moment")
        .accessibilityHint("Press and pull up to Rescue or Standard")
    }

    /// The + as a disc: plain glass at rest, the stop's ink when it's on one.
    private var lens: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.semibold))
            .foregroundStyle(zone == nil ? Color.primary : Color.black)
            .frame(width: 48, height: 48)
            .background {
                Circle().fill(zoneInk.opacity(zone == nil ? 0 : 0.95))
                    .animation(reduceMotion ? nil : Theme.snap, value: zone)
            }
            .frame(width: button, height: button)
            .allowsHitTesting(false)
    }

    /// Two stops in the inhaler inks, over the +'s spot.
    private var well: some View {
        VStack(spacing: 0) {
            stop(second)
            stop(first)
            Color.clear.frame(height: button)
        }
        .frame(width: button, height: wellHeight)
    }

    private func stop(_ kind: MomentKind) -> some View {
        let ink = kind == .rescue ? Theme.rescue : Theme.standard
        let on = zone == kind
        return Circle().fill(ink.opacity(on ? 0.2 : 0.9))
            .frame(width: on ? 14 : 9, height: on ? 14 : 9)
            .frame(width: button, height: step)
            .contentShape(Rectangle())
            .onTapGesture { if latched { commit(kind) } }
            .accessibilityLabel(kind == .rescue ? "Rescue" : "Standard")
    }

    private var zoneInk: Color {
        switch zone {
        case .rescue: Theme.rescue
        case .maintenance: Theme.standard
        default: Color.primary
        }
    }

    /// How far the lens sits above the +'s spot: on a stop when latched, else with the finger, clamped to the well.
    private var lensRise: CGFloat {
        guard open else { return 0 }
        if latched { return zone == second ? 2 * step : zone == first ? step : 0 }
        return min(max(0, pull), 2 * step)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if pressedAt == nil { pressedAt = .now }
                if !open { open = true }
                if latched { return }
                pull = -v.translation.height
                // Stops by height above the +: below the first is nothing (lift to cancel).
                let next: MomentKind? = pull < step * 0.5 ? nil : pull < step * 1.5 ? first : second
                if next != zone { zone = next }
            }
            .onEnded { v in
                defer { pressedAt = nil }
                if latched { return }
                let quick = pressedAt.map { Date().timeIntervalSince($0) < 0.3 } ?? false
                let still = abs(v.translation.height) < 8 && abs(v.translation.width) < 8
                if quick && still {
                    // A tap: keep the well open with the lens on the first stop.
                    latched = true
                    zone = first
                    return
                }
                if let zone { commit(zone) } else { close() }
            }
    }

    private func commit(_ kind: MomentKind) {
        logged += 1
        onLog(kind)
        close()
    }

    private func close() {
        zone = nil
        pull = 0
        latched = false
        open = false
    }
}

/// The plain menu: the fallback (Design crit › Log), and what VoiceOver always gets.
struct CaptureMenu: View {
    let onLog: (MomentKind) -> Void
    @State private var logged = 0

    var body: some View {
        Menu {
            Button { logged += 1; onLog(.rescue) } label: { Label("Rescue", systemImage: "circle.fill") }
            Button { logged += 1; onLog(.maintenance) } label: { Label("Standard", systemImage: "circle") }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .menuOrder(.priority)
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: logged)
        .accessibilityLabel("Log a moment")
        .accessibilityHint("Choose Rescue or Standard")
    }
}
