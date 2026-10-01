import Foundation

/// Loads JSON from the repo's shared `fixtures/` folder.
enum Fixtures {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // AsthmaCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // AsthmaCore
        .deletingLastPathComponent()  // ios
        .deletingLastPathComponent()  // repo root
        .appendingPathComponent("fixtures")

    static func liftFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("lift-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func load<T: Decodable>(_ type: T.Type, _ url: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
