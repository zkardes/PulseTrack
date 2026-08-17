import Foundation
import Combine

/// Zentraler Datenspeicher: kombiniert Withings-Cloud-Daten und BLE-Live-Daten
/// zu `DayMetrics`. Ersetzt den früheren HealthKitManager.
@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()

    let withings = WithingsClient()
    let ble = BLEManager()

    @Published var days: [DayMetrics] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var age: Int = 30

    private var cancellables = Set<AnyCancellable>()

    var today: DayMetrics? { days.first }
    var baseline: Baseline { Baseline.from(days: Array(days.dropFirst())) }
    var maxHR: Double { HealthAnalytics.estimatedMaxHR(age: age) }

    var isWithingsConnected: Bool { withings.isConnected }

    private init() {
        loadCache()
        // BLE Live-Herzfrequenz in den heutigen Tag einspeisen.
        ble.$liveSamples
            .receive(on: RunLoop.main)
            .sink { [weak self] samples in
                self?.mergeLiveSamples(samples)
            }
            .store(in: &cancellables)
    }

    // MARK: - Withings Sync

    func syncWithings(daysBack: Int = 30) async {
        guard withings.isConnected else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let cal = Calendar.current
            let now = Date()
            let start = cal.date(byAdding: .day, value: -daysBack, to: now)!

            async let activity = fetchActivity(from: start, to: now)
            async let sleep    = fetchSleep(from: start, to: now)
            async let heart    = fetchHeartMeasures(from: start, to: now)
            async let workouts = fetchWorkouts(from: start, to: now)

            var byDay: [Date: DayMetrics] = [:]
            func day(_ d: Date) -> Date { cal.startOfDay(for: d) }

            // Aktivität
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            for a in try await activity {
                guard let date = df.date(from: a.date) else { continue }
                let key = day(date)
                var m = byDay[key] ?? DayMetrics(date: key)
                m.steps = a.steps.map(Double.init)
                m.distanceWalkingRunning = a.distance
                m.activeEnergy = a.calories
                m.basalEnergy = (a.totalcalories ?? 0) - (a.calories ?? 0)
                m.exerciseMinutes = a.active.map { Double($0) / 60 }
                m.avgHeartRate = a.hr_average.map(Double.init)
                m.maxHeartRate = a.hr_max.map(Double.init)
                m.minHeartRate = a.hr_min.map(Double.init)
                byDay[key] = m
            }

            // Schlaf
            for s in try await sleep {
                let key = day(Date(timeIntervalSince1970: TimeInterval(s.startdate)))
                var m = byDay[key] ?? DayMetrics(date: key)
                var summary = SleepSummary()
                summary.deep = TimeInterval(s.data.deepsleepduration ?? 0)
                summary.rem  = TimeInterval(s.data.remsleepduration ?? 0)
                summary.core = TimeInterval(s.data.lightsleepduration ?? 0)
                summary.awake = TimeInterval(s.data.wakeupduration ?? 0)
                summary.asleep = summary.deep + summary.rem + summary.core
                summary.inBed = summary.asleep + summary.awake
                summary.start = Date(timeIntervalSince1970: TimeInterval(s.startdate))
                summary.end = Date(timeIntervalSince1970: TimeInterval(s.enddate))
                m.sleep = summary
                m.respiratoryRate = s.data.rr_average.map(Double.init)
                byDay[key] = m
            }

            // Herz / SpO2 Einzelmessungen
            for (date, values) in try await heart {
                let key = day(date)
                var m = byDay[key] ?? DayMetrics(date: key)
                if let rhr = values[.heartRate] { m.restingHeartRate = rhr }
                if let spo2 = values[.spo2] { m.bloodOxygen = spo2 }
                if let hrv = values[.hrv] { m.hrv = hrv }
                byDay[key] = m
            }

            // Workouts
            for w in try await workouts {
                let startDate = Date(timeIntervalSince1970: TimeInterval(w.startdate))
                let key = day(startDate)
                var m = byDay[key] ?? DayMetrics(date: key)
                let summary = WorkoutSummary(
                    typeName: WithingsWorkoutType.name(w.category),
                    symbol: WithingsWorkoutType.symbol(w.category),
                    start: startDate,
                    duration: TimeInterval(w.enddate - w.startdate),
                    energyBurned: w.data?.calories,
                    distance: w.data?.distance,
                    avgHeartRate: w.data?.hr_average
                )
                m.workouts.append(summary)
                byDay[key] = m
            }

            // Sortiert, neuester Tag zuerst.
            var assembled = byDay.values.sorted { $0.date > $1.date }
            // Sicherstellen, dass heute existiert (für BLE-Live).
            let todayKey = day(now)
            if !assembled.contains(where: { $0.date == todayKey }) {
                assembled.insert(DayMetrics(date: todayKey), at: 0)
            }
            self.days = assembled
            saveCache()
        } catch {
            errorMessage = "Withings-Sync fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Einzelne Withings-Abfragen

    private func fetchActivity(from: Date, to: Date) async throws -> [WithingsActivityResponse.Activity] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let resp = try await withings.request(path: "/v2/measure", params: [
            "action": "getactivity",
            "startdateymd": df.string(from: from),
            "enddateymd": df.string(from: to),
            "data_fields": "steps,distance,calories,totalcalories,hr_average,hr_min,hr_max,active"
        ], as: WithingsActivityResponse.self)
        return resp.body?.activities ?? []
    }

    private func fetchSleep(from: Date, to: Date) async throws -> [WithingsSleepResponse.Series] {
        let resp = try await withings.request(path: "/v2/sleep", params: [
            "action": "getsummary",
            "startdateymd": iso(from),
            "enddateymd": iso(to),
            "data_fields": "deepsleepduration,lightsleepduration,remsleepduration,wakeupduration,durationtosleep,hr_average,rr_average,sleep_efficiency"
        ], as: WithingsSleepResponse.self)
        return resp.body?.series ?? []
    }

    private func fetchWorkouts(from: Date, to: Date) async throws -> [WithingsWorkoutResponse.Series] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let resp = try await withings.request(path: "/v2/measure", params: [
            "action": "getworkouts",
            "startdateymd": df.string(from: from),
            "enddateymd": df.string(from: to),
            "data_fields": "calories,distance,hr_average,steps"
        ], as: WithingsWorkoutResponse.self)
        return resp.body?.series ?? []
    }

    private func fetchHeartMeasures(from: Date, to: Date) async throws -> [Date: [WithingsMeasureType: Double]] {
        let resp = try await withings.request(path: "/measure", params: [
            "action": "getmeas",
            "meastypes": "11,54,135",   // heart rate, spo2, hrv
            "category": "1",
            "startdate": String(Int(from.timeIntervalSince1970)),
            "enddate": String(Int(to.timeIntervalSince1970))
        ], as: WithingsMeasureResponse.self)

        var result: [Date: [WithingsMeasureType: Double]] = [:]
        for grp in resp.body?.measuregrps ?? [] {
            let date = Date(timeIntervalSince1970: TimeInterval(grp.date))
            for meas in grp.measures {
                if let type = WithingsMeasureType(rawValue: meas.type) {
                    result[date, default: [:]][type] = meas.real
                }
            }
        }
        return result
    }

    private func iso(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    // MARK: - BLE Live-Merge

    private func mergeLiveSamples(_ samples: [HeartRateSample]) {
        guard !samples.isEmpty else { return }
        let cal = Calendar.current
        let todayKey = cal.startOfDay(for: Date())
        if let idx = days.firstIndex(where: { $0.date == todayKey }) {
            days[idx].heartRateSamples = samples
            if let bpms = samples.map(\.bpm).max() { days[idx].maxHeartRate = bpms }
            if let mn = samples.map(\.bpm).min() { days[idx].minHeartRate = mn }
            days[idx].avgHeartRate = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
        } else {
            var m = DayMetrics(date: todayKey)
            m.heartRateSamples = samples
            days.insert(m, at: 0)
        }
    }

    // MARK: - Lokaler Cache (leichtgewichtig via UserDefaults JSON)

    private let cacheKey = "pulsetrack.cache.v1"

    private func saveCache() {
        // Minimaler Cache: nur die wichtigsten Skalare pro Tag.
        let dtos = days.map { DayCacheDTO(from: $0) }
        if let data = try? JSONEncoder().encode(dtos) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dtos = try? JSONDecoder().decode([DayCacheDTO].self, from: data) else { return }
        self.days = dtos.map { $0.toDayMetrics() }
    }
}

// MARK: - Cache DTO

private struct DayCacheDTO: Codable {
    var date: Date
    var restingHeartRate: Double?
    var hrv: Double?
    var respiratoryRate: Double?
    var bloodOxygen: Double?
    var activeEnergy: Double?
    var basalEnergy: Double?
    var steps: Double?
    var exerciseMinutes: Double?
    var distance: Double?
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var minHeartRate: Double?
    var sleepDeep: Double?
    var sleepRem: Double?
    var sleepCore: Double?
    var sleepAwake: Double?
    var sleepStart: Date?
    var sleepEnd: Date?

    init(from m: DayMetrics) {
        date = m.date
        restingHeartRate = m.restingHeartRate
        hrv = m.hrv
        respiratoryRate = m.respiratoryRate
        bloodOxygen = m.bloodOxygen
        activeEnergy = m.activeEnergy
        basalEnergy = m.basalEnergy
        steps = m.steps
        exerciseMinutes = m.exerciseMinutes
        distance = m.distanceWalkingRunning
        avgHeartRate = m.avgHeartRate
        maxHeartRate = m.maxHeartRate
        minHeartRate = m.minHeartRate
        sleepDeep = m.sleep?.deep
        sleepRem = m.sleep?.rem
        sleepCore = m.sleep?.core
        sleepAwake = m.sleep?.awake
        sleepStart = m.sleep?.start
        sleepEnd = m.sleep?.end
    }

    func toDayMetrics() -> DayMetrics {
        var m = DayMetrics(date: date)
        m.restingHeartRate = restingHeartRate
        m.hrv = hrv
        m.respiratoryRate = respiratoryRate
        m.bloodOxygen = bloodOxygen
        m.activeEnergy = activeEnergy
        m.basalEnergy = basalEnergy
        m.steps = steps
        m.exerciseMinutes = exerciseMinutes
        m.distanceWalkingRunning = distance
        m.avgHeartRate = avgHeartRate
        m.maxHeartRate = maxHeartRate
        m.minHeartRate = minHeartRate
        if sleepDeep != nil || sleepCore != nil {
            var s = SleepSummary()
            s.deep = sleepDeep ?? 0
            s.rem = sleepRem ?? 0
            s.core = sleepCore ?? 0
            s.awake = sleepAwake ?? 0
            s.asleep = s.deep + s.rem + s.core
            s.inBed = s.asleep + s.awake
            s.start = sleepStart
            s.end = sleepEnd
            m.sleep = s
        }
        return m
    }
}
