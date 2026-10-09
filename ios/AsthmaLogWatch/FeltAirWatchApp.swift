import SwiftUI
import WatchKit

/// felt air on Apple Watch: one press logs a moment. Orange = rescue inhaler, blue = standard inhaler.
/// The phone notes where you were and the outdoor air when it receives the moment.
@main
struct FeltAirWatchApp: App {
    @State private var logger = WatchLogger()

    var body: some Scene {
        WindowGroup {
            LogButtonsView()
                .environment(logger)
        }
    }
}

struct LogButtonsView: View {
    @Environment(WatchLogger.self) private var logger

    var body: some View {
        VStack(spacing: 8) {
            LogButton(title: "Rescue", color: WatchColors.rescue) { logger.log(.rescue) }
            LogButton(title: "Standard", color: WatchColors.standard) { logger.log(.standard) }
            Text(logger.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.opacity)
                .animation(.default, value: logger.status)
        }
        .padding(.horizontal, 4)
        .containerBackground(.black.gradient, for: .navigation)
    }
}

struct LogButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .buttonBorderShape(.roundedRectangle(radius: 22))
        .accessibilityHint("Logs a \(title.lowercased()) inhaler moment now")
    }
}

enum WatchColors {
    // Same as Theme.rescue / Theme.standard (dark values) on the phone.
    static let rescue = Color(red: 1.0, green: 0x8A / 255, blue: 0x3D / 255)
    static let standard = Color(red: 0x4F / 255, green: 0xB0 / 255, blue: 0xF5 / 255)
}
