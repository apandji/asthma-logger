import AsthmaCore
import CoreLocation
import SwiftData
import SwiftUI

/// First run, in the home's own language (docs/design/design-system.md, docs/design/onboarding-pair.md):
/// welcome · where you are (the location prompt, the map draws with no air on it yet) · **pair your inhaler**
/// (press the felt button, or press the cap on screen without one: that press fetches the air, and the scan
/// draws your **first moment**, a test press saved as a baseline) · name your inhalers · what felt air uses ·
/// what happens next.
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
        case welcome, here, pair, inhalers, permissions, learn
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }
    @State private var step = Step.welcome
    /// Where you are, found on the "here" step. The air isn't read until the first press.
    @State private var here: (lat: Double, lon: Double, place: String?)?
    @State private var locating = false
    @State private var noLocation = false
    @State private var first: LogEvent?
    /// Between the press and the first moment's air arriving: the readings shimmer.
    @State private var fetching = false
    /// No felt button: the cap on screen takes the press.
    @State private var softButton = false
    /// Which cap was pressed (the felt button says; the cap on screen is Rescue's).
    @State private var pressedCap: ButtonPacket.Cap = .rescue
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
            guard n > 0, step == .pair, first == nil, !fetching, !softButton else { return }
            pressedCap = button.lastSyncCap ?? .rescue
            logMethod = "button"
            capture()
        }
        #if DEBUG
        // Recordings in the simulator: `-demoPress` presses the felt button for you a few seconds into that step,
        // `-demoNoButton` opens it on the cap on screen (and `-demoPress` then presses the cap for you).
        // `-onboardingAt pair` starts there (it finds you first).
        .task(id: step) {
            let args = ProcessInfo.processInfo.arguments
            if step == .welcome, let i = args.firstIndex(of: "-onboardingAt"), i + 1 < args.count, args[i + 1] == "pair" {
                goHere()
                while locating { try? await Task.sleep(for: .milliseconds(200)) }
                step = .pair
                button.beginSync()
                return
            }
            guard step == .pair else { return }
            if args.contains("-demoNoButton") { button.endSync(); softButton = true }
            guard args.contains("-demoPress"), !softButton else { return }
            try? await Task.sleep(for: .seconds(3))
            button.simulatePress(.rescue)
        }
        #endif
    }

    // MARK: Header (the home's)

    /// The top is the air: where you are and what's in the air there, the same on every step once it's read
    /// (and the first moment's once it's saved). Before there's a place, felt air's line.
    @ViewBuilder private var header: some View {
        if let f = first {
            VerdictHeader(place: AnyView(HStack(spacing: 8) { MomentTag(moment: .okay, text: OnboardingCopy.firstTag); placeLine }),
                          title: AirWords.sentence(tense: .present, weave: f.weave, conditions: f.conditions),
                          verdict: nil, tint: nil, around: CalendarReader.shared.around(f.loggedAt)?.line)
            // The magic moment: the readings land one by one, with a tick.
            AirReadings(conditions: f.conditions, weave: f.weave,
                        pollen: DemoPollen.sample(at: f.loggedAt, season: pollenSeason))
        } else if fetching {
            VerdictHeader(place: AnyView(placeLine), title: OnboardingCopy.fetchingTop, verdict: nil, tint: nil)
            AirReadings(conditions: nil, weave: WeaveSpec(), pollen: nil, pending: true)
        } else if step >= .here, here != nil || locating || noLocation {
            VerdictHeader(place: AnyView(placeLine), title: hereTitle, verdict: nil, tint: nil)
        } else {
            VerdictHeader(place: AnyView(Label("felt air", systemImage: "sparkles").font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)),
                          title: OnboardingCopy.welcomeTop, verdict: nil, tint: nil)
        }
    }

    private var placeLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill").font(.caption)
            Text(here?.place ?? (noLocation ? OnboardingCopy.noLocation : OnboardingCopy.hereLocatingTop)).lineLimit(1)
        }
        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
    }

    private var hereTitle: String {
        if here != nil { return OnboardingCopy.hereFoundTop }
        return noLocation ? OnboardingCopy.hereNoLocationTop : OnboardingCopy.hereLocatingTop
    }

    // MARK: Sky

    @ViewBuilder private var sky: some View {
        if let f = first, step >= .pair {
            // The first moment: the map alone, then the scan in the cap's colour, then the air.
            NowSky(conditions: f.conditions, weave: f.weave,
                   date: f.loggedAt, pollen: DemoPollen.sample(at: f.loggedAt, season: pollenSeason), probing: $probing,
                   mapID: f.id.uuidString, coordinate: f.latitude.flatMap { lat in f.longitude.map { (lat, $0) } } ?? here.map { ($0.lat, $0.lon) },
                   captureInk: pressedCap == .standard ? Theme.standardSoft : Theme.rescueSoft)
                .id(f.id)
        } else if let here, step >= .here {
            // Where you are: the map, with no air on it yet. On the pair step it dims behind the cap.
            NowSky(conditions: nil, weave: WeaveSpec(), date: .now, pollen: nil, probing: $probing,
                   mapID: "here", coordinate: (here.lat, here.lon))
                .opacity(step == .pair ? 0.4 : 1)
                .overlay { if step == .pair { cap.transition(.opacity) } }
        } else {
            // Before there's a place (or without one): the grain alone, breathing.
            ParticleField(particles: [], animated: !reduceMotion, inviting: false)
                .padding(.horizontal, 8)
                .mask(EllipticalGradient(colors: [.black, .clear], center: .center, startRadiusFraction: 0.2, endRadiusFraction: 0.7))
                .overlay {
                    if step == .welcome { Listening(quiet: true) }
                    if step == .pair { cap.transition(.opacity) }
                }
        }
    }

    /// The inhaler's cap, waiting for the felt button, or on screen to press.
    private var cap: some View {
        InhalerCap(mode: fetching ? .pressed : (softButton ? .soft : .waiting), cap: pressedCap,
                   autoPress: softButton && ProcessInfo.processInfo.arguments.contains("-demoPress")) {
            logMethod = "app"
            capture()
        }
        .id(softButton)
    }

    private var pageTop: Color {
        let t = first?.conditions?.best(.temperature)?.value ?? 62
        return WeatherColor.light(WeatherColor.temperature(t), at: .now).mix(with: .black, by: 0.22)
    }

    // MARK: The card: one short paragraph and the actions

    @ViewBuilder private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The step's name, inside the panel, in the sentence face.
            Text(cardTitle)
                .font(Theme.Typeface.sentence(size: 24)).kerning(Theme.serifKerning)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            switch step {
            case .welcome:
                body(OnboardingCopy.welcomeBody)
                fine(OnboardingCopy.welcomeFine)
                primary(OnboardingCopy.welcomeAction) { goHere() }
            case .here:
                if here != nil {
                    body(OnboardingCopy.hereBody)
                    WeatherAttributionView()
                    primary(OnboardingCopy.next) { step = .pair; button.beginSync() }
                } else if noLocation {
                    body(OnboardingCopy.hereNoLocation)
                    primary(OnboardingCopy.next) { step = .pair; button.beginSync() }
                } else {
                    HStack(spacing: 10) { ProgressView(); body(OnboardingCopy.hereWaiting) }
                }
            case .pair:
                if first != nil {
                    body(logMethod == "app" ? OnboardingCopy.firstBodyApp : OnboardingCopy.firstBodyButton)
                    primary(OnboardingCopy.next) { button.endSync(); step = .inhalers }
                } else if fetching {
                    HStack(spacing: 10) { ProgressView(); body(OnboardingCopy.fetchingBody) }
                } else if softButton {
                    pressRow(OnboardingCopy.softBody)
                    fine(OnboardingCopy.softFine)
                    secondary(OnboardingCopy.softHaveButton) {
                        softButton = false
                        button.beginSync()
                    }
                } else {
                    pressRow(buttonStatus)
                    fine(OnboardingCopy.buttonHint)
                    secondary(OnboardingCopy.buttonSkip) {
                        button.endSync()
                        softButton = true
                    }
                }
            case .inhalers:
                body(OnboardingCopy.inhalersBody)
                inhalerField(OnboardingCopy.inhalerRescueLabel, placeholder: OnboardingCopy.inhalerRescuePlaceholder, text: $rescueName)
                inhalerField(OnboardingCopy.inhalerDailyLabel, placeholder: OnboardingCopy.inhalerDailyPlaceholder, text: $dailyName)
                primary(OnboardingCopy.next) { saveInhalers(); step = .permissions }
            case .permissions:
                body(OnboardingCopy.dataBody)
                // One card per source: what it uses, what it's for, and where it goes.
                DataCards()
                primary(OnboardingCopy.next) { step = .learn }
            case .learn:
                body(OnboardingCopy.learnBody)
                LearningRing(progress: GateProgress(nAttacks: events.filter { !$0.isDemo && $0.moment == .rescue }.count,
                                                    nBaselines: events.filter { !$0.isDemo && $0.moment == .okay }.count, gate: .default), size: 96)
                primary(OnboardingCopy.learnAction) { button.endSync(); didOnboard = true }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .animation(Theme.smooth, value: cardTitle)
    }

    private var cardTitle: String {
        switch step {
        case .welcome: OnboardingCopy.welcomeTitle
        case .here: OnboardingCopy.hereTitle
        case .pair: first == nil ? OnboardingCopy.pairTitle : OnboardingCopy.firstTitle
        case .inhalers: OnboardingCopy.inhalersTitle
        case .permissions: OnboardingCopy.dataTitle
        case .learn: OnboardingCopy.learnTitle
        }
    }

    /// One text size for the panel's words (body, primary), and one for the fine print.
    private func body(_ s: String) -> some View {
        Text(s).font(.body).foregroundStyle(.primary.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
    }

    /// The press hint: the press icon beside the line that asks for a press.
    private func pressRow(_ s: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PressIcon(size: 26)
            body(s)
        }
    }

    private func fine(_ s: String) -> some View {
        Text(s).font(.footnote).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
    }

    private var buttonStatus: String {
        switch button.status {
        case .notAllowed: OnboardingCopy.buttonNotAllowed
        case .bluetoothOff: OnboardingCopy.buttonBluetoothOff
        case .connected: OnboardingCopy.buttonConnected
        case .connecting: OnboardingCopy.buttonConnecting
        default: OnboardingCopy.buttonListening
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
                let marks = try? await CLGeocoder().reverseGeocodeLocation(fix)
                let place = marks?.first.map { [$0.locality ?? $0.subAdministrativeArea, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ") }
                here = (lat, lon, place)
            } else {
                noLocation = true
            }
            locating = false
        }
    }

    /// The first moment: a test press, saved as a baseline (never a rescue, never in Health), stamped with
    /// the air fetched now. The readings shimmer while it's fetched, then land.
    private func capture() {
        guard first == nil, !fetching else { return }
        withAnimation(Theme.smooth) { fetching = true }
        Task {
            let e = await services.logFirstCapture(in: context)
            if let here, e.placeName == nil { e.placeName = here.place }
            withAnimation(Theme.smooth) { first = e; fetching = false }
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
