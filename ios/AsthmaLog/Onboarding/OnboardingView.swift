import AsthmaCore
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

/// First run: welcome → press your felt button to sync → your location and the air there, on a map
/// (the location prompt appears right after the press, no extra screen) → motion and Apple Health →
/// "felt air learns over time". No account. Each permission is asked when it's about to be used.
/// Photos come from the owner's Figma (local only; woven fallback without).
struct OnboardingView: View {
    @Environment(LogService.self) private var services
    @Environment(ButtonLink.self) private var button
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.didOnboard) private var didOnboard = false
    @AppStorage(Prefs.logMethod) private var logMethod = "app"
    @AppStorage(LevelStyle.key) private var style = LevelStyle.signal
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]

    @State private var step = Step.welcome
    @State private var working = false
    @State private var firstMoment: LogEvent?
    @State private var fix: CLLocationCoordinate2D?
    @State private var locating = false
    @State private var camera: MapCameraPosition = .automatic
    @State private var askedMotion = false
    @State private var askedHealth = false

    enum Step: Int, CaseIterable { case welcome, sync, here, health, learn }

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()
                .transition(.opacity)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 32, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .environment(\.colorScheme, .dark)
                pageDots.padding(.vertical, 12)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .onChange(of: button.syncPresses) { _, n in
            guard n > 0, step == .sync else { return }
            logMethod = "button"
            // A beat to see "Synced", then straight on to location: the press is the go-ahead.
            Task { try? await Task.sleep(for: .seconds(1.2)); goToHere() }
        }
    }

    @ViewBuilder private var backdrop: some View {
        if step == .here, let fix {
            Map(position: $camera, interactionModes: []) {
                Marker("", systemImage: "wind", coordinate: fix).tint(Theme.accent)
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .environment(\.colorScheme, .dark)
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom))
        } else {
            OnboardingBackdrop(photo: photo, seed: step.rawValue).id(step)
        }
    }

    private var photo: String {
        switch step {
        case .welcome: "onboardingTree"
        case .sync: "onboardingHand"
        case .here: "onboardingPark"
        case .health: "onboardingGrass"
        case .learn: "onboardingTree"
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .sync: sync
        case .here: here
        case .health: health
        case .learn: learn
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("felt air").font(.system(size: 30, weight: .light)).tracking(1)
            Text("Breathe. We'll keep an eye on the air.")
                .font(.system(.title2, design: .serif, weight: .medium))
            Text("Every time you use your inhaler, felt air saves the weather and air quality outside. Over time, you'll see what your hard days have in common.")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Outdoor air only. Not medical advice.").font(.footnote).foregroundStyle(.secondary)
            primary("Get started") {
                step = .sync
                button.beginSync()
            }
        }
    }

    private var sync: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                SyncPulse(synced: button.syncPresses > 0, cap: button.lastSyncCap)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(button.syncPresses > 0 ? "Synced" : "Press your felt button")
                        .font(.system(.title2, design: .serif, weight: .medium))
                        .contentTransition(.opacity)
                    Text(syncStatus).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("Orange is for your rescue inhaler, teal for your daily one. This first press only connects it; it isn't saved as inhaler use.")
                .font(.footnote).foregroundStyle(.secondary)
            secondary("I don't have a button") {
                button.endSync()
                logMethod = "app"
                goToHere()
            }
        }
    }

    private var syncStatus: String {
        if button.syncPresses > 0 { return "Next, the air where you are." }
        switch button.status {
        case .notAllowed: return "Bluetooth is off for felt air. Turn it on in Settings › felt air."
        case .bluetoothOff: return "Turn on Bluetooth to connect."
        case .connected: return "Connected. Press either cap."
        case .connecting: return "Connecting…"
        default: return "Keep it close to your iPhone."
        }
    }

    private var here: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let m = firstMoment, !m.weave.isEmpty {
                Text("The air where you are").font(.system(.title2, design: .serif, weight: .medium))
                VStack(spacing: 0) {
                    tierRow(m, .air, "Air quality", m.conditions?.best(.pm25).map { "PM2.5 \(Int($0.value.rounded()))" })
                    tierRow(m, .temperature, "Temperature", m.conditions?.best(.temperature).map { "\(Int($0.value.rounded()))°F" })
                    tierRow(m, .humidity, "Humidity", m.conditions?.best(.humidity).map { "\(Int($0.value.rounded()))%" })
                }
                Text("Outdoors, from \(sources(m)). Saved as your first \"I'm okay\" moment, a calm baseline to compare against.")
                    .font(.footnote).foregroundStyle(.secondary)
                WeatherAttributionView()
                primary("Continue") { step = .health }
            } else if fix == nil && !locating {
                Text("No location, no problem").font(.system(.title2, design: .serif, weight: .medium))
                Text("felt air can still save your moments. Turn on location later in Settings to see the air.")
                    .font(.subheadline).foregroundStyle(.secondary)
                primary("Continue") { step = .health }
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(fix == nil ? "Finding you…" : "Checking the air…")
                        .font(.system(.title2, design: .serif, weight: .medium))
                }
                Text("We check the air where you are each time you log. Your location stays on this phone.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Two more, both optional").font(.system(.title2, design: .serif, weight: .medium))
            permission("figure.walk", "Motion & Fitness",
                       "Walking, driving or still helps guess if you were indoors or out.", done: askedMotion) {
                Task { _ = await services.motion.recent(); askedMotion = true }
            }
            permission("heart.text.square", "Apple Health",
                       "Saves each rescue puff as Inhaler Usage, next to the rest of your health.", done: askedHealth) {
                Task { await services.health.requestAccess(); askedHealth = true }
            }
            primary("Continue") { step = .learn }
        }
    }

    private var learn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("felt air learns over time").font(.system(.title2, design: .serif, weight: .medium))
            Text("Each press saves the air around it. felt air also notes calm moments on its own. Once there are enough of both, it shows which conditions turn up more on your inhaler days, and flags days ahead that look like them.")
                .font(.subheadline).foregroundStyle(.secondary)
            learning
            primary("Start") {
                button.endSync()
                didOnboard = true
            }
        }
    }

    /// Honest progress toward the first pattern (the default sample gate).
    private var learning: some View {
        let real = events.filter { !$0.isDemo }
        let rescue = real.filter { $0.moment == .rescue }.count
        let okay = real.filter { $0.moment == .okay }.count
        let gate = LiftGate.default
        return VStack(alignment: .leading, spacing: 8) {
            progress("Inhaler uses", rescue, gate.minAttacks, Theme.rescue)
            progress("Calm moments", okay, gate.minBaselines, .white)
        }
    }

    // MARK: Actions

    private func goToHere() {
        guard step != .here else { return }
        step = .here
        locating = true
        Task {
            // The system prompt appears here, right after the press.
            if let loc = try? await services.location.currentLocation(timeout: .seconds(10)) {
                let c = loc.coordinate
                camera = .camera(MapCamera(centerCoordinate: c, distance: 400_000, pitch: 0))
                fix = c
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeInOut(duration: 2.4)) {
                    camera = .camera(MapCamera(centerCoordinate: c, distance: 1_600, heading: 20, pitch: 55))
                }
                let moment = LogEvent(moment: .okay)
                context.insert(moment)
                try? context.save()
                firstMoment = moment
                await services.enrich(moment)
                try? context.save()
            }
            locating = false
        }
    }

    // MARK: Pieces

    private func tierRow(_ m: LogEvent, _ f: WeaveSpec.Factor, _ name: String, _ value: String?) -> some View {
        let level = m.weave.levels[f]
        return HStack(spacing: 12) {
            LevelIndicator(level: level, ink: WeaveSwatch.ink(f), style: style).frame(minWidth: 30)
            Text(name)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(level.map { Tier($0).word } ?? "No reading")
                if let value { Text(value).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 7)
    }

    private func permission(_ symbol: String, _ title: String, _ detail: String, done: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button(done ? "Done" : "Allow", action: action)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(done)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func progress(_ label: String, _ n: Int, _ goal: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(min(n, goal)) of \(goal)").monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.footnote)
            ProgressView(value: Double(min(n, goal)), total: Double(goal)).tint(tint)
        }
    }

    private func sources(_ m: LogEvent) -> String {
        let names = Array(Set((m.conditions?.observations ?? []).map(\.source))).sorted()
        return names.isEmpty ? "your air services" : names.joined(separator: ", ")
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .buttonBorderShape(.capsule)
        .disabled(working)
        .padding(.top, 6)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .foregroundStyle(.secondary)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(Step.allCases, id: \.self) { s in
                Circle().fill(.white.opacity(s == step ? 0.95 : 0.35)).frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Waiting for the first press: soft rings pulse outward. On sync, a solid disc in the pressed cap's colour.
struct SyncPulse: View {
    let synced: Bool
    let cap: ButtonPacket.Cap?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: synced || reduceMotion)) { tl in
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2
                if synced {
                    let color = cap == .standard ? Theme.standard : Theme.rescue
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.7, y: c.y - r * 0.7, width: r * 1.4, height: r * 1.4)), with: .color(color))
                    var check = Path()
                    check.move(to: CGPoint(x: c.x - r * 0.28, y: c.y))
                    check.addLine(to: CGPoint(x: c.x - r * 0.06, y: c.y + r * 0.22))
                    check.addLine(to: CGPoint(x: c.x + r * 0.32, y: c.y - r * 0.2))
                    ctx.stroke(check, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                } else {
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for k in 0..<3 {
                        let phase = (t / 2.2 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                        let rr = r * (0.35 + 0.65 * phase)
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                                   with: .color(.white.opacity(0.6 * (1 - phase))), lineWidth: 1.5)
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.3, y: c.y - r * 0.3, width: r * 0.6, height: r * 0.6)),
                             with: .color(.white.opacity(0.9)))
                }
            }
        }
        .animation(.spring(duration: 0.4), value: synced)
        .accessibilityLabel(synced ? "Synced" : "Waiting for a press")
    }
}

/// Full-bleed photo, darkened at the bottom for the text. Without the photo (fresh clone), a woven field.
struct OnboardingBackdrop: View {
    let photo: String
    let seed: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = UIImage(named: photo), image.size.height < 1000 {
                    // Small photo (the hand): blurred to fill, sharp copy in the top half so the subject isn't under the card.
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped().blur(radius: 24)
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.55).clipped()
                        .frame(maxHeight: .infinity, alignment: .top)
                } else if let image = UIImage(named: photo) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                } else {
                    Color(white: 0.08)
                    WeaveSwatch(weave: fallback, cornerRadius: 0).opacity(0.55)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            }
        }
    }

    private var fallback: WeaveSpec {
        let levels: [WeaveSpec.Level] = [.low, .medium, .high]
        return WeaveSpec(levels: [.air: levels[seed % 3], .humidity: levels[(seed + 1) % 3], .temperature: levels[(seed + 2) % 3]])
    }
}
