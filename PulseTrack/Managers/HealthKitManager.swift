import Foundation
import HealthKit
import Combine

/// Central manager that requests HealthKit permission and reads all the
/// health data the app needs. Works with any sensor paired through Apple
/// Health (Apple Watch, chest straps, rings, etc.) because it reads the
/// aggregated HealthKit store.
@MainActor
final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Last ~30 days of assembled metrics (index 0 = today).
    @Published var days: [DayMetrics] = []

    var today: DayMetrics? { days.first }
    var baseline: Baseline { Baseline.from(days: Array(days.dropFirst())) }

    // User profile (age drives max-HR estimate).
    @Published var age: Int = 30
    var maxHR: Double { HealthAnalytics.estimatedMaxHR(age: age) }

    private init() {}

    // MARK: - Types we want to read

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        func q(_ id: HKQuantityTypeIdentifier) { if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) } }
        func c(_ id: HKCategoryTypeIdentifier)  { if let t = HKCategoryType.categoryType(forIdentifier: id) { types.insert(t) } }

        q(.heartRate); q(.restingHeartRate); q(.heartRateVariabilitySDNN)
        q(.respiratoryRate); q(.oxygenSaturation)
        q(.activeEnergyBurned); q(.basalEnergyBurned)
        q(.stepCount); q(.appleExerciseTime); q(.appleStandTime)
        q(.distanceWalkingRunning); q(.vo2Max)
        if #available(iOS 16.0, *) { q(.appleSleepingWristTemperature) }
        c(.sleepAnalysis)
        types.insert(HKObjectType.workoutType())
        if let dob = try? store.dateOfBirthComponents() { _ = dob }
        types.insert(HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!)
        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is not available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await loadAll()
        } catch {
            errorMessage = "Authorization failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Load everything

    func loadAll(daysBack: Int = 30) async {
        isLoading = true
        defer { isLoading = false }

        readAge()

        let cal = Calendar.current
        var assembled: [DayMetrics] = []

        for offset in 0..<daysBack {
            guard let dayStart = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            var m = DayMetrics(date: dayStart)

            async let rhr    = avgQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: dayStart, end: dayEnd)
            async let hrv    = avgQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: dayStart, end: dayEnd)
            async let rr     = avgQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), start: dayStart, end: dayEnd)
            async let spo2   = avgQuantity(.oxygenSaturation, unit: .percent(), start: dayStart, end: dayEnd)
            async let active = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: dayStart, end: dayEnd)
            async let basal  = sumQuantity(.basalEnergyBurned, unit: .kilocalorie(), start: dayStart, end: dayEnd)
            async let steps  = sumQuantity(.stepCount, unit: .count(), start: dayStart, end: dayEnd)
            async let exer   = sumQuantity(.appleExerciseTime, unit: .minute(), start: dayStart, end: dayEnd)
            async let dist   = sumQuantity(.distanceWalkingRunning, unit: .meter(), start: dayStart, end: dayEnd)
            async let hr     = heartRateSamples(start: dayStart, end: dayEnd)
            async let sleep  = sleepSummary(for: dayStart)
            async let wkts   = workouts(start: dayStart, end: dayEnd)

            m.restingHeartRate = await rhr
            m.hrv = await hrv
            m.respiratoryRate = await rr
            if let s = await spo2 { m.bloodOxygen = s * 100 }
            m.activeEnergy = await active
            m.basalEnergy = await basal
            m.steps = await steps
            m.exerciseMinutes = await exer
            m.distanceWalkingRunning = await dist
            m.sleep = await sleep
            m.workouts = await wkts

            let samples = await hr
            m.heartRateSamples = samples
            if !samples.isEmpty {
                m.maxHeartRate = samples.map(\.bpm).max()
                m.minHeartRate = samples.map(\.bpm).min()
                m.avgHeartRate = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
            }

            assembled.append(m)
        }

        self.days = assembled
    }

    // MARK: - Profile

    private func readAge() {
        if let comps = try? store.dateOfBirthComponents(),
           let birth = Calendar.current.date(from: comps),
           let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year {
            self.age = years
        }
    }

    // MARK: - Quantity helpers

    private func avgQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        await statistic(id, unit: unit, start: start, end: end, options: .discreteAverage) { $0.averageQuantity() }
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        await statistic(id, unit: unit, start: start, end: end, options: .cumulativeSum) { $0.sumQuantity() }
    }

    private func statistic(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date,
                           options: HKStatisticsOptions,
                           extract: @escaping (HKStatistics) -> HKQuantity?) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, stats, _ in
                cont.resume(returning: stats.flatMap(extract)?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Heart rate samples

    private func heartRateSamples(start: Date, end: Date) async -> [HeartRateSample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                let result = (samples as? [HKQuantitySample])?.map {
                    HeartRateSample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
                } ?? []
                cont.resume(returning: result)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    private func sleepSummary(for night: Date) async -> SleepSummary? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let cal = Calendar.current
        // Window: 6pm previous evening -> 11am on `night` day.
        let start = cal.date(byAdding: .hour, value: -6, to: night)!
        let end   = cal.date(byAdding: .hour, value: 11, to: night)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                guard let cats = samples as? [HKCategorySample], !cats.isEmpty else {
                    cont.resume(returning: nil); return
                }
                var s = SleepSummary()
                for c in cats {
                    let dur = c.endDate.timeIntervalSince(c.startDate)
                    if s.start == nil { s.start = c.startDate }
                    s.end = c.endDate
                    switch c.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        s.inBed += dur
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        s.deep += dur; s.asleep += dur
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        s.rem += dur; s.asleep += dur
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        s.core += dur; s.asleep += dur
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        s.awake += dur
                    default: break
                    }
                }
                if s.inBed == 0 { s.inBed = s.asleep + s.awake }
                cont.resume(returning: s)
            }
            store.execute(query)
        }
    }

    // MARK: - Workouts

    private func workouts(start: Date, end: Date) async -> [WorkoutSummary] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                let result = (samples as? [HKWorkout])?.map { w -> WorkoutSummary in
                    let energy = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                        .sumQuantity()?.doubleValue(for: .kilocalorie())
                    let distance = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                        .sumQuantity()?.doubleValue(for: .meter())
                    return WorkoutSummary(
                        typeName: w.workoutActivityType.displayName,
                        symbol: w.workoutActivityType.symbolName,
                        start: w.startDate,
                        duration: w.duration,
                        energyBurned: energy,
                        distance: distance,
                        avgHeartRate: nil
                    )
                } ?? []
                cont.resume(returning: result)
            }
            store.execute(query)
        }
    }
}
