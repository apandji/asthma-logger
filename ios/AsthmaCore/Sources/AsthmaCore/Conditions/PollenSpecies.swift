import Foundation

/// The pollen count broken down by species, as the provider sent it (Ambee `Species`, North America, Europe
/// and ANZ). The total per group is what the sky and the patterns use; this is the layer underneath, kept so
/// a person can open it. Zeros are kept: "measured, none" is different from "not measured".
public struct PollenSpecies: Codable, Sendable, Equatable {
    public enum Group: String, Codable, Sendable, CaseIterable {
        case tree, grass, weed
    }

    public struct Count: Sendable, Equatable, Identifiable {
        public let name: String
        public let count: Double
        public var id: String { name }
    }

    /// Species name → particles/m³, per group.
    public var tree: [String: Double]
    public var grass: [String: Double]
    public var weed: [String: Double]
    /// Pollen the provider counted but didn't name.
    public var others: Double?
    public var source: String
    public var asOf: Date

    public init(tree: [String: Double] = [:], grass: [String: Double] = [:], weed: [String: Double] = [:],
                others: Double? = nil, source: String, asOf: Date) {
        self.tree = tree; self.grass = grass; self.weed = weed
        self.others = others; self.source = source; self.asOf = asOf
    }

    public var isEmpty: Bool { tree.isEmpty && grass.isEmpty && weed.isEmpty }

    /// A group's species, most first, then by name. Zeros included.
    public func counts(_ group: Group) -> [Count] {
        let d: [String: Double] = switch group {
        case .tree: tree
        case .grass: grass
        case .weed: weed
        }
        return d.map { Count(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    /// "12 particles/m³", whole numbers unless the count is under 10 and fractional.
    public static func text(_ count: Double) -> String {
        let n = count.rounded() == count || count >= 10 ? String(Int(count.rounded())) : String(format: "%.1f", count)
        return "\(n) particles/m³"
    }
}
