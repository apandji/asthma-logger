import Foundation
import HealthKit

/// Reads a little from Apple Health for Self, and says it in words, never numbers (owner, Oct 17): last
/// night's sleep, and heart and breathing rate in the two hours before a moment compared with your own
/// usual (the 30 days before). Asked only from Self's "Connect Apple Health". Nothing leaves the phone,
/// and none of it feeds the patterns (yet).
@MainActor
final class HealthReader {
    static let shared = HealthReader()
    private let store = HKHealthStore()

    static let reads: Set<HKObjectType> = [
        HKQuantityType(.heartRate), HKQuantityType(.respiratoryRate), HKCategoryType(.sleepAnalysis),
    ]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether iOS would still show the prompt (it never says what was granted, only whether it asked).
    func shouldAsk() async -> Bool {
        guard isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.reads)
        return status == .shouldRequest
    }

    func ask() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: Self.reads)
    }

    struct Words: Equatable {
        var sleep: String?
        var heart: String?
        var breathing: String?
        var isEmpty: Bool { sleep == nil && heart == nil && breathing == nil }
    }

    func words(before date: Date) async -> Words {
        async let s = sleep(before: date)
        async let h = compared(.heartRate, unit: .count().unitDivided(by: .minute()), before: date)
        async let b = compared(.respiratoryRate, unit: .count().unitDivided(by: .minute()), before: date)
        return Words(sleep: await s, heart: await h, breathing: await b)
    }

    /// The night before `date` (6 pm to noon), asleep time only.
    private func sleep(before date: Date) async -> String? {
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let end = date < noon ? noon : cal.date(byAdding: .day, value: 1, to: noon)!.addingTimeInterval(-86_400)
        let start = end.addingTimeInterval(-18 * 3600)
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let query = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis),
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [])
        guard let samples = try? await query.result(for: store) else { return nil }
        let hours = samples.filter { asleep.contains($0.value) }.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600
        guard hours > 0.5 else { return nil }
        switch hours {
        case ..<6: return "A short night."
        case ..<8.5: return "A usual night."
        default: return "A long night."
        }
    }

    /// The two hours before, compared with the 30 days before that.
    private func compared(_ id: HKQuantityTypeIdentifier, unit: HKUnit, before date: Date) async -> String? {
        let type = HKQuantityType(id)
        func average(_ from: Date, _ to: Date) async -> Double? {
            let q = HKStatisticsQueryDescriptor(
                predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: from, end: to)),
                options: .discreteAverage)
            return (try? await q.result(for: store))??.averageQuantity()?.doubleValue(for: unit)
        }
        guard let now = await average(date.addingTimeInterval(-2 * 3600), date),
              let usual = await average(date.addingTimeInterval(-32 * 86_400), date.addingTimeInterval(-2 * 86_400)),
              usual > 0 else { return nil }
        let change = now / usual - 1
        switch change {
        case ..<(-0.06): return "Lower than usual."
        case ..<0.06: return "About your usual."
        case ..<0.2: return "A bit higher than usual."
        default: return "Higher than usual."
        }
    }
}
