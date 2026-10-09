import AsthmaCore
import SwiftData
import SwiftUI

/// First run, per the refined journey (docs/design/felt-air-context.md): welcome → how you'll log →
/// location → a first moment that shows the air right away → done. No account, and each permission is
/// asked only when it's needed. Photos come from the owner's Figma (local only; woven fallback without).
struct OnboardingView: View {
    @Environment(LogService.self) private var services
    @Environment(\.modelContext) private var context
    @AppStorage(Prefs.didOnboard) private var didOnboard = false
    @AppStorage(Prefs.logMethod) private var logMethod = "app"
    @Query(sort: \LogEvent.loggedAt) private var events: [LogEvent]

    @State private var step = Step.welcome
    @State private var working = false
    @State private var firstMoment: LogEvent?

    enum Step: Int, CaseIterable { case welcome, logging, location, first }

    var body: some View {
        ZStack {
            OnboardingBackdrop(photo: photo, seed: step.rawValue)
                .ignoresSafeArea()
                .id(step)
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
    }

    private var photo: String {
        switch step {
        case .welcome: "onboardingTree"
        case .logging: "onboardingHand"
        case .location: "onboardingPark"
        case .first: "onboardingGrass"
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .logging: logging
        case .location: location
        case .first: first
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
            primary("Get started") { step = .logging }
        }
    }

    private var logging: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How will you log?").font(.system(.title2, design: .serif, weight: .medium))
            choice("watch", "applewatch", "Apple Watch", "Orange for rescue, blue for your daily inhaler.")
            choice("app", "iphone", "In the app", "Two buttons at the bottom of the screen.")
            choice("button", "dot.radiowaves.left.and.right", "felt button", "Set it up when you have one.")
            primary("Continue") { step = .location }
        }
    }

    private var location: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use your location?").font(.system(.title2, design: .serif, weight: .medium))
            Text("So we can check the air where you are. Your location stays on this phone.")
                .font(.subheadline).foregroundStyle(.secondary)
            primary(working ? "Asking…" : "Allow location") {
                working = true
                Task {
                    _ = try? await services.location.currentLocation(timeout: .seconds(8))
                    working = false
                    step = .first
                }
            }
            secondary("Not now") { step = .first }
        }
    }

    private var first: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let m = firstMoment {
                Text(m.envStatus == .pending ? "Checking the air…" : "Right now")
                    .font(.system(.title2, design: .serif, weight: .medium))
                if !m.weave.isEmpty {
                    HStack(spacing: 14) {
                        WeaveSwatch(weave: m.weave, cornerRadius: 18).frame(width: 72, height: 72)
                        Text(m.airLine)
                            .font(.headline)
                    }
                    Text("From \(sources(m)).").font(.footnote).foregroundStyle(.secondary)
                } else if m.envStatus != .pending {
                    Text("Couldn't get the air just now. You can still log.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
                learning
                primary("Start") { didOnboard = true }
            } else {
                Text("Check the air now").font(.system(.title2, design: .serif, weight: .medium))
                Text("This is saved as an \"I'm okay\" moment, a day without your inhaler to compare against. After this, felt air adds them on its own.")
                    .font(.subheadline).foregroundStyle(.secondary)
                primary("Check the air") {
                    let moment = LogEvent(moment: .okay)
                    context.insert(moment)
                    try? context.save()
                    firstMoment = moment
                    Task {
                        await services.enrich(moment)
                        try? context.save()
                    }
                }
                secondary("Skip for now") { didOnboard = true }
            }
        }
    }

    /// Honest progress toward the first pattern (the default sample gate).
    private var learning: some View {
        let real = events.filter { !$0.isDemo }
        let rescue = real.filter { $0.moment == .rescue }.count
        let okay = real.filter { $0.moment == .okay }.count
        let gate = LiftGate.default
        return Text("Patterns appear after \(gate.minAttacks) inhaler uses and \(gate.minBaselines) \"I'm okay\" moments. You're at \(rescue) and \(okay).")
            .font(.footnote).foregroundStyle(.secondary)
    }

    private func sources(_ m: LogEvent) -> String {
        let names = Array(Set((m.conditions?.observations ?? []).map(\.source))).sorted()
        return names.isEmpty ? "your air services" : names.joined(separator: ", ")
    }

    // MARK: Pieces

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

    private func choice(_ value: String, _ symbol: String, _ title: String, _ detail: String) -> some View {
        Button { logMethod = value } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).font(.title3).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: logMethod == value ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(logMethod == value ? .primary : .tertiary)
            }
            .padding(12)
            .background(.white.opacity(logMethod == value ? 0.14 : 0.06), in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
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
