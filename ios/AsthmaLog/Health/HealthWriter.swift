import Foundation
import HealthKit

/// Writes each puff to Apple Health as Inhaler Usage. Reads nothing (proof of concept).
final class HealthWriter {
    private let store = HKHealthStore()
    private let type = HKQuantityType(.inhalerUsage)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asked during onboarding, so the permission sheet never interrupts the first log.
    func requestAccess() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [type], read: [])
    }

    /// Returns the HealthKit sample UUID so deletes stay in sync.
    func savePuff(at date: Date, logID: UUID) async throws -> UUID {
        try await store.requestAuthorization(toShare: [type], read: [])
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .count(), doubleValue: 1),
            start: date,
            end: date,
            metadata: [HKMetadataKeyExternalUUID: logID.uuidString]
        )
        try await store.save(sample)
        return sample.uuid
    }

    func deletePuff(sampleID: UUID) async throws {
        _ = try await store.deleteObjects(of: type, predicate: HKQuery.predicateForObject(with: sampleID))
    }
}
