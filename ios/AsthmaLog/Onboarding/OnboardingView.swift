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
            Text("felt air keeps track of the air for you, so you don't have to.")
                .font(.system(.title2, design: .serif, weight: .medium))
            Text("Each time you log a moment, it notes the outdoor air around you. Over time it shows which conditions turn up when breathing is harder for you.")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Outdoor air only. Not medical advice.").font(.footnote).foregroundStyle(.secondary)
            primary("Get started") { step = .logging }
        }
    }

    private var logging: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How will you log?").font(.system(.title2, design: .serif, weight: .medium))
            choice("watch", "applewatch", "Apple Watch", "Two buttons: orange for rescue, blue for standard.")
            choice("app", "iphone", "In the app", "Tap Rescue or Standard at the bottom of the screen.")
            choice("button", "button.programmable", "felt button", "Pair it later, once you have one. The app works without it.")
            primary("Continue") { step = .location }
        }
    }

    private var location: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notice the air where you are.").font(.system(.title2, design: .serif, weight: .medium))
            Text("Your location lets felt air note the outdoor air near each moment. It stays on this iPhone; weather and air services only get the spot when felt air asks them for the air.")
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
                Text(m.envStatus == .pending ? "Noting the air…" : "Here's the air right now.")
                    .font(.system(.title2, design: .serif, weight: .medium))
                if !m.weave.isEmpty {
                    HStack(spacing: 14) {
                        WeaveSwatch(weave: m.weave, cornerRadius: 18).frame(width: 72, height: 72)
                        Text(m.weave.summary.prefix(1).uppercased() + m.weave.summary.dropFirst())
                            .font(.headline)
                    }
                    Text("Outdoor air near you, from \(sources(m)).").font(.footnote).foregroundStyle(.secondary)
                } else if m.envStatus != .pending {
                    Text("felt air couldn't note the air this time. Your moments still save; the air is added when it can be.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
                learning
                primary("Start") { didOnboard = true }
            } else {
                Text("Let's note the air right now.").font(.system(.title2, design: .serif, weight: .medium))
                Text("felt air will save this as an I'm okay moment, the kind it compares your inhaler moments with. From then on it adds these on its own.")
                    .font(.subheadline).foregroundStyle(.secondary)
                primary("Note the air now") {
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
        return Text("felt air is learning: \(min(rescue, gate.minAttacks)) of \(gate.minAttacks) rescue moments, \(min(okay, gate.minBaselines)) of \(gate.minBaselines) I'm okay moments.")
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
                if let image = UIImage(named: photo) {
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
