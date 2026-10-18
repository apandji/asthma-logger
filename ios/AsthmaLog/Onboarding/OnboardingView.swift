import AsthmaCore
import CoreLocation
import SwiftData
import SwiftUI

/// First run, in the home's own language (docs/design/design-system.md). Four screens and one moment:
/// welcome · where you are (the location prompt, then the sky draws for the first time) · your felt
/// button (press it: the phone answers, and the scan draws your **first capture**) · two optional
/// permissions · what happens next. Skippable at the button: a tap on the + does the first capture.
struct OnboardingView: View {
    @Environment(LogService.self) private var services
    @Environment(ButtonLink.self) private var button
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Prefs.didOnboard) private var didOnboard = false
    @AppStorage(Prefs.logMethod) private var logMethod = "app"
    @AppStorage(DemoPollen.Season.key) private var pollenSeason = DemoPollen.Season.off
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]

    enum Step: Int, CaseIterable, Comparable {
        case welcome, here, button, inhalers, permissions, learn
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }
    @State private var step = Step.welcome
    /// The air where you are, read on the "here" step; the first capture is stamped from it.
    @State private var here: (lat: Double, lon: Double, place: String?, conditions: Conditions)?
    @State private var locating = false
    @State private var noLocation = false
    @State private var first: LogEvent?
    @State private var probing = false
    /// The inhalers' names (renamed later in Settings › Devices).
    @State private var rescueName = ""
    @State private var dailyName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            sky
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
            card
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            pageDots.padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                LinearGradient(colors: [pageTop, pageTop.mix(with: .black, by: 0.6), .black], startPoint: .top, endPoint: .bottom)
                SkyGrain(responds: false).opacity(0.5)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: step)
        }
        .environment(\.colorScheme, .dark)
        .animation(Theme.smooth, value: step)
        .onChange(of: button.syncPresses) { _, n in
            guard n > 0, step == .button, first == nil else { return }
            logMethod = "button"
            capture()
        }
        #if DEBUG
        // Recordings in the simulator: `-demoPress` presses the button for you a few seconds into that step.
        .task(id: step) {
            guard step == .button, ProcessInfo.processInfo.arguments.contains("-demoPress") else { return }
            try? await Task.sleep(for: .seconds(3))
            button.simulatePress(.rescue)
        }
        #endif
    }

    // MARK: Header (the home's)

    @ViewBuilder private var header: some View {
        switch step {
        case .welcome:
            VerdictHeader(place: AnyView(Label("felt air", systemImage: "sparkles").font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)),
                          title: "Your inhaler, and the air around it.", verdict: nil, tint: nil)
        case .here:
            VerdictHeader(place: AnyView(placeLine), title: hereTitle, verdict: nil, tint: nil)
        case .button:
            if let f = first {
                VerdictHeader(tag: nil, place: AnyView(HStack(spacing: 8) { MomentTag(moment: .okay, text: "First capture"); placeLine }),
                              title: AirWords.sentence(tense: .present, weave: f.weave, conditions: f.conditions),
                              verdict: nil, tint: nil)
            } else {
                VerdictHeader(place: AnyView(placeLine), title: "Press your felt button.", verdict: nil, tint: nil)
            }
        case .inhalers:
            VerdictHeader(place: AnyView(placeLine), title: "Name your inhalers.", verdict: nil, tint: nil)
        case .permissions:
            VerdictHeader(place: AnyView(placeLine), title: "What felt air uses, and where it goes.", verdict: nil, tint: nil)
        case .learn:
            VerdictHeader(place: AnyView(placeLine), title: "It gets better with time.", verdict: nil, tint: nil,
                          when: nil)
        }
    }

    private var placeLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill").font(.caption)
            Text(here?.place ?? (noLocation ? "No location" : "Finding you…")).lineLimit(1)
        }
        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
    }

    private var hereTitle: String {
        if let here { return AirWords.sentence(tense: .present, weave: WeaveSpec(here.conditions.input), conditions: here.conditions) }
        return noLocation ? "You can still log without it." : (locating ? "Checking the air near you…" : "The air where you are.")
    }

    // MARK: Sky

    @ViewBuilder private var sky: some View {
        let listening = step == .button && first == nil
        if let f = first, step >= .button {
            // The first capture: the map alone, then the scan, then the air. Logged by the button or the +.
            NowSky(conditions: f.conditions ?? here?.conditions, weave: f.weave.isEmpty ? (here.map { WeaveSpec($0.conditions.input) } ?? WeaveSpec()) : f.weave,
                   date: f.loggedAt, pollen: DemoPollen.sample(at: f.loggedAt, season: pollenSeason), probing: $probing,
                   mapID: f.id.uuidString, coordinate: f.latitude.flatMap { lat in f.longitude.map { (lat, $0) } } ?? here.map { ($0.lat, $0.lon) },
                   captureInk: logMethod == "button" ? Theme.rescueSoft : Theme.standardSoft)
                .id(f.id)
        } else if let here, step >= .here {
            // Where you are: the map draws in with the air's ripple, then the particles.
            NowSky(conditions: here.conditions, weave: WeaveSpec(here.conditions.input), date: .now,
                   pollen: DemoPollen.sample(at: .now, season: pollenSeason), probing: $probing,
                   mapID: "here", coordinate: (here.lat, here.lon))
                .opacity(listening ? 0.45 : 1)
                .overlay { if listening { Listening().transition(.opacity) } }
        } else {
            // Before there's a place: the grain alone, breathing.
            ParticleField(particles: [], animated: !reduceMotion, inviting: false)
                .padding(.horizontal, 8)
                .mask(EllipticalGradient(colors: [.black, .clear], center: .center, startRadiusFraction: 0.2, endRadiusFraction: 0.7))
                .overlay { if step == .welcome { Listening(quiet: true) } }
        }
    }

    private var pageTop: Color {
        let t = here?.conditions.best(.temperature)?.value ?? 62
        return WeatherColor.light(WeatherColor.temperature(t), at: .now).mix(with: .black, by: 0.22)
    }

    // MARK: The card: one short paragraph and the actions

    @ViewBuilder private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case .welcome:
                Text("Each time you use your inhaler, felt air saves the outdoor air and weather. After a few weeks you can see what your flare days have in common.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                Text("Outdoor air only. Not medical advice.").font(.footnote).foregroundStyle(Theme.secondaryText)
                primary("Get started") { goHere() }
            case .here:
                if here != nil {
                    Text("felt air reads the air near you each time you log. The weather and air services get your area, never who you are. Your exact location stays on this iPhone.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    WeatherAttributionView()
                    primary("Next") { step = .button; button.beginSync() }
                } else if noLocation {
                    Text("Turn on location in Settings to add the air to each moment.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    primary("Next") { step = .button; button.beginSync() }
                } else {
                    HStack(spacing: 10) { ProgressView(); Text("The location prompt appears now.").font(.subheadline).foregroundStyle(Theme.secondaryText) }
                }
            case .button:
                if first != nil {
                    // Without a button there was no press: the + will be the way to log.
                    Text(logMethod == "app"
                         ? "This is your first capture: the air, here, right now. From now on each press of the + saves a moment like it."
                         : "That press is your first capture: the air, here, right now. From now on each press saves a moment like it.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    primary("Next") { step = .inhalers }
                } else {
                    Text(buttonStatus).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    Text("Orange cap is Rescue, teal is Standard. This first press pairs the button, it isn't counted as inhaler use.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                    HStack(spacing: 10) {
                        secondary("I don't have a button") {
                            button.endSync()
                            logMethod = "app"
                            capture()
                        }
                    }
                }
            case .inhalers:
                Text("So each moment says which one you used. You can rename them in Settings › Devices.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)   // the keyboard squeezes the sky, not the words
                inhalerField("Rescue · orange cap", placeholder: "e.g. Ventolin", text: $rescueName)
                inhalerField("Daily · teal cap", placeholder: "e.g. Flovent", text: $dailyName)
                primary("Next") { saveInhalers(); step = .permissions }
            case .permissions:
                // One card per source: what it uses, what it's for, and where it goes.
                DataCards()
                primary("Next") { step = .learn }
            case .learn:
                Text("Each press saves a moment. felt air adds baseline moments on its own. With enough of both, Insights shows what your flare days have in common.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                LearningRing(progress: GateProgress(nAttacks: events.filter { !$0.isDemo && $0.moment == .rescue }.count,
                                                    nBaselines: events.filter { !$0.isDemo && $0.moment == .okay }.count, gate: .default), size: 96)
                primary("Start") { button.endSync(); didOnboard = true }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private var buttonStatus: String {
        switch button.status {
        case .notAllowed: "Bluetooth is off for felt air. Turn it on in Settings › felt air."
        case .bluetoothOff: "Turn on Bluetooth to connect."
        case .connected: "Connected. Press either cap."
        case .connecting: "Connecting…"
        default: "Listening. Keep the button close to your iPhone."
        }
    }

    // MARK: Actions

    private func goHere() {
        step = .here
        locating = true
        Task {
            // The system prompt appears here.
            if let fix = try? await services.location.currentLocation(timeout: .seconds(10)) {
                let lat = fix.coordinate.latitude, lon = fix.coordinate.longitude
                async let c = services.conditions.conditions(latitude: lat, longitude: lon)
                async let marks = try? CLGeocoder().reverseGeocodeLocation(fix)
                let place = await marks?.first.map { [$0.locality ?? $0.subAdministrativeArea, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ") }
                here = (lat, lon, place, await c)
            } else {
                noLocation = true
            }
            locating = false
        }
    }

    /// The first capture: a baseline moment stamped with the air here, drawn by the scan.
    private func capture() {
        guard first == nil else { return }
        Task {
            let e = await services.logFirstCapture(in: context)
            if let here, e.placeName == nil { e.placeName = here.place }
            withAnimation(Theme.smooth) { first = e }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: Pieces

    private func inhalerField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(Theme.secondaryText)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .padding(.horizontal, 14).padding(.vertical, 11)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }

    /// Keeps the names (blank keeps "Rescue inhaler" / "Daily inhaler").
    private func saveInhalers() {
        var list = Inhaler.load()
        for i in list.indices {
            let name = (list[i].kind == .rescue ? rescueName : dailyName).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { list[i].name = name }
        }
        Inhaler.save(list)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .foregroundStyle(.black)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(PressStyle())
        .padding(.top, 4)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(PressStyle())
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(Step.allCases, id: \.self) { s in
                Circle().fill(.white.opacity(s == step ? 0.95 : 0.3)).frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Waiting for the first press: the pin breathes out slow rings over the map, the way Now's pin does,
/// but larger, so the phone visibly listens.
struct Listening: View {
    var quiet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let t = tl.date.timeIntervalSinceReferenceDate
                for k in 0..<3 {
                    let phase = (t / 2.6 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                    let rr = 14 + 150 * phase
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                               with: .color(.white.opacity((quiet ? 0.3 : 0.6) * (1 - phase))), lineWidth: 1.5)
                }
                if !quiet {
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Waiting for a press")
    }
}
