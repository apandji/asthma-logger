import SwiftUI

/// Menus look (owner, Nov 13): Voice memo and Log symptoms open as a sheet that grows out of the + (the zoom
/// transition, like Messages' New Message). A title, a close button, and the same chat or journal capture as
/// before underneath; closing keeps what you said or wrote, or drops an empty one.
struct CaptureSheet: View {
    @Bindable var session: CaptureSession
    let chat: Bool
    /// Opened from Voice memo (the mic is listening) rather than Log symptoms.
    let voice: Bool
    let close: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if chat { ChatCapture(session: session, finish: finish) } else { JournalCapture(session: session) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(voice ? "Voice memo" : "Felt something?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close, action: finish)
                }
            }
        }
        // About half height (owner, Nov 13): the choices and the mic stay in thumb reach; drag up for more room.
        .presentationDetents([.fraction(0.55), .large])
        .presentationDragIndicator(.visible)
        // Light, on the app's paper, like every other screen on this look (owner, Nov 13).
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .onChange(of: session.live) { _, words in if session.listening { session.hear(words) } }
        // Swiping it down keeps what's there, the same as the close button.
        .interactiveDismissDisabled(session.listening)
    }

    private func finish() {
        if session.listening { Task { await session.stopListening(); keepOrDrop() } } else { keepOrDrop() }
    }

    private func keepOrDrop() {
        if session.hasAnything { session.save(context: context) } else { session.discard() }
        close()
    }
}
