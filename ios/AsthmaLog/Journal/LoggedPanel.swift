import AsthmaCore
import SwiftData
import SwiftUI

/// Just logged: a panel rises over the bottom of Now (the timeline and the +) like a toast. It says what was
/// logged, keeps the puffs (− takes one off, and the last one takes the moment with it; + adds one, as another
/// press would), and offers the mic, which opens the journal capture. Swipe it down, or it goes on its own
/// after a while untouched. The felt button and the watch add puffs to the same moment, and the count follows.
struct LoggedPanel: View {
    let event: LogEvent
    let record: () -> Void
    let close: () -> Void
    @Environment(LogService.self) private var services
    @Environment(\.modelContext) private var context
    @State private var drag: CGFloat = 0
    /// Bumped on every touch, so the panel only leaves after a quiet spell.
    @State private var touched = 0

    private var puffs: Int { event.uses.reduce(0) { $0 + $1.puffs } }
    private var ink: Color { event.moment == .rescue ? Theme.rescue : Theme.standard }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Circle().fill(ink).frame(width: 10, height: 10)
                Text("\(event.moment.title) logged").font(.headline)
                Spacer()
                Text(event.loggedAt, style: .time).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            HStack(alignment: .center, spacing: 12) {
                stepper
                Spacer(minLength: 0)
                Button {
                    record()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.body.weight(.bold))
                        Text("Quick journal").font(.subheadline.weight(.semibold)).lineLimit(1)
                    }
                    .padding(.horizontal, 20).frame(height: 56)
                    .foregroundStyle(.black)
                    .background(Capsule().fill(.white))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Quick journal")
                .accessibilityHint("Opens the journal, listening")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .offset(y: max(0, drag))
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { drag = $0.translation.height; touched += 1 }
                .onEnded { v in
                    if v.translation.height > 60 || v.predictedEndTranslation.height > 140 { close() }
                    else { withAnimation(Theme.lift) { drag = 0 } }
                }
        )
        // Leaves after 15 s untouched; a new puff (from any device) counts as a touch.
        .task(id: "\(touched)-\(puffs)") {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            close()
        }
    }

    /// − puffs +, the count rolling as it changes. A dose, so the number stays (it's what the inhaler says).
    private var stepper: some View {
        HStack(spacing: 4) {
            stepButton("minus", label: puffs <= 1 ? "Undo" : "One puff fewer") {
                touched += 1
                // The last puff takes the moment with it: close first, so nothing reads a deleted moment.
                if puffs <= 1 { close() }
                Task { await services.undoPress(event, in: context) }
            }
            VStack(spacing: 0) {
                Text("\(puffs)").font(.title2.weight(.semibold)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(puffs)))
                Text(puffs == 1 ? "puff" : "puffs").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .frame(minWidth: 44)
            .animation(Theme.lift, value: puffs)
            .accessibilityElement(children: .combine)
            stepButton("plus", label: "One more puff") {
                touched += 1
                Task { _ = await services.press(event.moment, device: .phone, in: context) }
            }
        }
    }

    private func stepButton(_ symbol: String, label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}
