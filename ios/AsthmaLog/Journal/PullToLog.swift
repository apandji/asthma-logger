import AsthmaCore
import SwiftUI

/// The +, pulled. Press, and the glass circle grows up into a well with two zones (Rescue nearest the
/// finger, Standard above); a glass lens follows the thumb; lift in a zone to log, lift low to cancel. A tap
/// opens the well and keeps it open for a second tap. It's the same Liquid Glass morph iOS uses for its own
/// menus (`GlassEffectContainer` + `glassEffectID`), so it moves like part of the system, not a widget on top.
/// Haptics: a soft tick entering Rescue, a rigid one entering Standard, success on the log.
/// VoiceOver gets the plain menu (`CaptureMenu`): no gesture to learn.
struct PullToLog: View {
    let onLog: (MomentKind) -> Void
    @AppStorage(Crit.CaptureOrder.key) private var order = Crit.CaptureOrder.rescueFirst
    /// The well grows inward from the +'s outer edge, so it never runs off the screen.
    @AppStorage(Prefs.railLeft) private var railLeft = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    @State private var open = false
    /// Opened by a tap: stays open until a zone is tapped or the finger lands outside.
    @State private var latched = false
    /// Finger height above the +, in points (positive = up).
    @State private var pull: CGFloat = 0
    @State private var zone: MomentKind?
    @State private var logged = 0
    @State private var pressedAt: Date?

    private let button: CGFloat = 56
    private let zoneHeight: CGFloat = 60
    /// The well: the + plus two zones.
    private var wellHeight: CGFloat { button + 2 * zoneHeight }
    private var first: MomentKind { order == .rescueFirst ? .rescue : .maintenance }
    private var second: MomentKind { order == .rescueFirst ? .maintenance : .rescue }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            ZStack(alignment: railLeft ? .bottomLeading : .bottomTrailing) {
                if open {
                    well
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("log", in: glass)
                        .transition(.identity)
                } else {
                    plus
                        .glassEffect(.regular.interactive(), in: .circle)
                        .glassEffectID("log", in: glass)
                        .transition(.identity)
                }
            }
            .frame(width: 88, height: wellHeight, alignment: railLeft ? .bottomLeading : .bottomTrailing)
        }
        .frame(width: button, height: button, alignment: railLeft ? .bottomLeading : .bottomTrailing)   // lays out as the + only; the well overflows upward
        .contentShape(Rectangle())
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

    private var plus: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: button, height: button)
    }

    /// Two zones over the +'s spot, and a lens where the thumb is.
    private var well: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                zoneLabel(second)
                zoneLabel(first)
                Color.clear.frame(height: button)
            }
            // The lens: a glass disc that rides with the finger and takes the zone's ink.
            Circle()
                .fill(zoneInk.opacity(zone == nil ? 0.08 : 0.28))
                .padding(.horizontal, 4)
                .overlay(Circle().strokeBorder(zoneInk.opacity(zone == nil ? 0.2 : 0.55), lineWidth: 1))
                .frame(width: 48, height: 48)
                .offset(y: -lensRise)
                .animation(reduceMotion ? nil : .interactiveSpring(response: 0.18, dampingFraction: 0.86), value: lensRise)
                .allowsHitTesting(false)
        }
        .frame(width: 88, height: wellHeight)
    }

    private func zoneLabel(_ kind: MomentKind) -> some View {
        let on = zone == kind
        return Text(kind == .rescue ? "Rescue" : "Standard")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(on ? Color.primary : Theme.secondaryText)
            .scaleEffect(on ? 1.06 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: zoneHeight)
            .contentShape(Rectangle())
            .onTapGesture { if latched { commit(kind) } }
    }

    private var zoneInk: Color {
        switch zone {
        case .rescue: Theme.rescue
        case .maintenance: Theme.standard
        default: Color.primary
        }
    }

    /// How far the lens sits above the +'s centre: clamped to the well.
    private var lensRise: CGFloat {
        guard open else { return 0 }
        if latched, let zone { return zone == first ? zoneHeight : 2 * zoneHeight }
        return min(max(0, pull), 2 * zoneHeight) + 4
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if pressedAt == nil { pressedAt = .now }
                if !open { open = true }
                if latched { return }
                pull = -v.translation.height
                // Zones by height above the +: below the first line is nothing (lift to cancel).
                let next: MomentKind? = pull < 28 ? nil : pull < zoneHeight + 28 ? first : second
                if next != zone { zone = next }
            }
            .onEnded { v in
                defer { pressedAt = nil }
                if latched { return }
                let quick = pressedAt.map { Date().timeIntervalSince($0) < 0.3 } ?? false
                let still = abs(v.translation.height) < 8 && abs(v.translation.width) < 8
                if quick && still {
                    // A tap: keep the well open and point the lens at the first zone.
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
