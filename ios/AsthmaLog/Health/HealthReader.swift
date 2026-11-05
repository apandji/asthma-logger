import AsthmaCore
import Foundation
import HealthKit

/// Reads a little from Apple Health for Body, and says it in words, never numbers (owner, Oct 17): last
/// night's sleep; heart and breathing rate in the two hours before a moment compared with your own usual
/// (the 30 days before); a workout in the two hours before; and a State of Mind you logged that day. Asked in
/// onboarding's data cards (and Body's "Connect Apple Health"). Nothing leaves the phone, and none of it
/// feeds the patterns (yet).
@MainActor
final class HealthReader {
    static let shared = HealthReader()
    private let store = HKHealthStore()

    static let reads: Set<HKObjectType> = [
        HKQuantityType(.heartRate), HKQuantityType(.respiratoryRate), HKCategoryType(.sleepAnalysis),
        HKQuantityType(.stepCount), HKObjectType.workoutType(), HKObjectType.stateOfMindType(),
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

    /// Onboarding: the write (inhaler usage) and the reads in one Health sheet, not two.
    func askWithWrite() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [HKQuantityType(.inhalerUsage)], read: Self.reads)
    }

    struct Words: Equatable {
        var sleep: String?
        var heart: String?
        var breathing: String?
        /// "A run before this." (a workout ending in the two hours before)
        var workout: String?
        /// "You logged feeling stressed." (State of Mind, that day, before the moment)
        var mind: String?
        /// The workout was exertion: the capture can offer Exercise.
        var exerted = false
        /// The logged mood was a stressful one: the capture can offer Stress.
        var stressed = false
        var isEmpty: Bool { sleep == nil && heart == nil && breathing == nil && workout == nil && mind == nil }
    }

    func words(before date: Date) async -> Words {
        async let s = sleep(before: date)
        async let h = compared(.heartRate, unit: .count().unitDivided(by: .minute()), before: date)
        async let b = compared(.respiratoryRate, unit: .count().unitDivided(by: .minute()), before: date)
        async let w = workout(before: date)
        async let m = mind(before: date)
        let (workout, mind) = (await w, await m)
        return Words(sleep: await s, heart: await h, breathing: await b, workout: workout, mind: mind.text,
                     exerted: workout != nil, stressed: mind.stressed)
    }

    /// For the exertion bin (Exertion): a workout overlapping the hour before, and steps in the 30 minutes
    /// before. iOS never says whether reads were allowed, so "no data at all in the six hours before" reads
    /// as unknown (nil), not "not active".
    /// `kind` is the workout's kind, for the moment's line ("a walk"); `note` says what came back, for
    /// Settings › Exertion check.
    func activity(before date: Date) async -> (workout: Bool?, kind: ExertionSource.WorkoutKind?, steps: Int?, note: String) {
        guard isAvailable else { return (nil, nil, nil, "Health isn't available on this device.") }
        guard !(await shouldAsk()) else { return (nil, nil, nil, "Health hasn't been asked yet.") }
        let hour = HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-3600), end: date)
        let w = HKSampleQueryDescriptor(predicates: [.workout(hour)], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        let found = (try? await w.result(for: store))?.first
        let workout = found != nil
        let six = HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-6 * 3600), end: date)
        let any = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(.stepCount), predicate: six)],
                                          sortDescriptors: [], limit: 1)
        let hasSteps = ((try? await any.result(for: store)) ?? []).isEmpty == false
        guard hasSteps || workout else {
            return (nil, nil, nil, "No steps or workouts in the 6 hours before (not shared, or no data), so Health can't say.")
        }
        let half = HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-1800), end: date)
        let sum = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: half),
                                              options: .cumulativeSum)
        let steps = Int((try? await sum.result(for: store))?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        let kind = found.map { Self.kind($0.workoutActivityType) }
        var note = "\(steps) steps in the 30 min before."
        if let found {
            let t = found.startDate.formatted(date: .omitted, time: .shortened) + "–" + found.endDate.formatted(date: .omitted, time: .shortened)
            note += " Workout \(t): \(kind?.words ?? "a workout") (\(Int(found.duration / 60)) min)."
        } else {
            note += " No workout in the hour before."
        }
        return (workout, kind, steps, note)
    }

    static func kind(_ t: HKWorkoutActivityType) -> ExertionSource.WorkoutKind {
        switch t {
        case .running: .run
        case .walking: .walk
        case .hiking: .hike
        case .cycling: .bikeRide
        case .swimming: .swim
        case .soccer, .basketball, .americanFootball, .tennis, .hockey, .rugby: .game
        case .traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining, .crossTraining: .strength
        case .yoga, .pilates: .classSession
        case .stairClimbing, .stairs: .stairs
        default: .other
        }
    }

    /// A workout that ended in the two hours before, by kind and length, in words.
    private func workout(before date: Date) async -> String? {
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-2 * 3600), end: date))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        guard let w = try? await query.result(for: store).first else { return nil }
        let minutes = w.duration / 60
        let length = minutes < 20 ? "A short " : minutes > 60 ? "A long " : "A "
        let kind: String = switch w.workoutActivityType {
        case .running: "run"
        case .walking: "walk"
        case .hiking: "hike"
        case .cycling: "bike ride"
        case .swimming: "swim"
        case .soccer, .basketball, .americanFootball, .tennis, .hockey, .rugby: "game"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .highIntensityIntervalTraining, .crossTraining: "workout"
        case .yoga, .pilates: "class"
        case .stairClimbing, .stairs: "stair climb"
        default: "workout"
        }
        return length + kind + " before this."
    }

    /// The last State of Mind logged that day before the moment, in its own words.
    private func mind(before date: Date) async -> (text: String?, stressed: Bool) {
        let start = Calendar.current.startOfDay(for: date)
        let query = HKSampleQueryDescriptor(
            predicates: [.stateOfMind(HKQuery.predicateForSamples(withStart: start, end: date))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 1)
        guard let s = try? await query.result(for: store).first else { return (nil, false) }
        let stressful: [HKStateOfMind.Label] = [.stressed, .anxious, .worried, .overwhelmed, .scared, .frustrated, .annoyed, .irritated]
        let stressed = s.labels.contains { stressful.contains($0) }
        let feeling: String = s.valence < -0.3 ? "unpleasant" : s.valence > 0.3 ? "pleasant" : "neutral"
        if stressed { return ("You logged feeling stressed that day.", true) }
        return ("You logged feeling \(feeling) that day.", false)
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
