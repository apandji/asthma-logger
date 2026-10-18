import AsthmaCore
import Foundation
import FoundationModels

/// Guided-generation shape. `nonisolated` because the app target defaults to the main actor.
@Generable
nonisolated struct TagDraft {
    @Guide(description: "Ids from the allowed list that the note clearly mentions. Empty if none.")
    var tags: [String]
}

/// Apple Foundation Models, on device. One job: suggest tags from a voice note, which you confirm. Used
/// silently when Apple Intelligence is on; keyword rules otherwise. (It no longer writes the Insights sentence.)
enum OnDeviceModel {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
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
