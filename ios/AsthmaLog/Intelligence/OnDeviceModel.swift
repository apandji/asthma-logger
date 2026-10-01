import AsthmaCore
import Foundation
import FoundationModels

/// Guided-generation shapes. `nonisolated` because the app target defaults to the main actor.
@Generable
nonisolated struct NarrationDraft {
    @Guide(description: "One honest insight. Must include the exact inhaler-day and usual-day counts for the top driver.")
    var headline: String
    @Guide(description: "One short honest limit, e.g. outdoor air only, not a diagnosis, not a prediction.")
    var caveat: String
    @Guide(description: "Driver ids copied exactly from the table, like ozone:high.")
    var drivers: [String]
}

@Generable
nonisolated struct TagDraft {
    @Guide(description: "Ids from the allowed list that the note clearly mentions. Empty if none.")
    var tags: [String]
}

/// Apple Foundation Models, on device. Two jobs only: say the lift table, and pull tags from a note.
/// It never computes stats; every output passes AsthmaCore's checks or falls back to the template.
enum OnDeviceModel {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var status: String {
        switch SystemLanguageModel.default.availability {
        case .available: "Ready"
        case .unavailable(let reason): "Unavailable (\(String(describing: reason)))"
        @unknown default: "Unknown"
        }
    }

    static func narrate(_ input: NarratorInput) async -> NarratorOutput {
        guard isAvailable else {
            var t = Narrator.template(input)
            t.note = "On-device model \(status.lowercased())"
            return t
        }
        let p = Narrator.prompt(input)
        do {
            let session = LanguageModelSession(instructions: p.instructions)
            let response = try await session.respond(
                to: p.prompt,
                generating: NarrationDraft.self,
                options: GenerationOptions(temperature: NarratorStyle(score: input.styleScore).temperature)
            )
            let d = response.content
            return NarrationGuard.accept(headline: d.headline, caveat: d.caveat, drivers: d.drivers, input: input)
        } catch {
            var t = Narrator.template(input)
            t.note = "On-device model failed: \(error.localizedDescription)"
            return t
        }
    }

    /// Suggested tags for a journal note. The user confirms before they count.
    static func suggestTags(for text: String) async -> [JournalTag] {
        guard isAvailable, !text.isEmpty else { return TagExtraction.keywordGuess(text) }
        let list = JournalTag.allCases.map { "- \($0.rawValue): \($0.hint)" }.joined(separator: "\n")
        do {
            let session = LanguageModelSession(instructions: """
                You tag short asthma diary notes. Pick ids only from this list, only when the note clearly mentions them:
                \(list)
                """)
            let response = try await session.respond(to: text, generating: TagDraft.self)
            return TagExtraction.sanitize(response.content.tags)
        } catch {
            return TagExtraction.keywordGuess(text)
        }
    }
}
