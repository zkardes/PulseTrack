import Foundation

// MARK: - Daily aggregate snapshot

/// A full day of health metrics assembled from HealthKit.
struct DayMetrics: Identifiable, Equatable {
    let id = UUID()
    var date: Date

    // Recovery inputs
    var restingHeartRate: Double?      // bpm
    var hrv: Double?                   // SDNN, ms
    var respiratoryRate: Double?       // breaths/min
    var bloodOxygen: Double?           // %  (0-1 from HK, shown as %)
    var wristTemperature: Double?      // °C delta or absolute

    // Sleep
    var sleep: SleepSummary?

    // Strain / activity
    var activeEnergy: Double?          // kcal
    var basalEnergy: Double?           // kcal
    var steps: Double?
    var exerciseMinutes: Double?
    var standHours: Double?
    var distanceWalkingRunning: Double? // meters
    var workouts: [WorkoutSummary]

    // Heart
    var heartRateSamples: [HeartRateSample]
    var maxHeartRate: Double?
    var minHeartRate: Double?
    var avgHeartRate: Double?

    init(date: Date) {
        self.date = date
        self.workouts = []
        self.heartRateSamples = []
    }

    var totalEnergy: Double {
        (activeEnergy ?? 0) + (basalEnergy ?? 0)
    }
}

// MARK: - Sleep

struct SleepSummary: Equatable {
    var inBed: TimeInterval = 0
    var asleep: TimeInterval = 0
    var deep: TimeInterval = 0
    var core: TimeInterval = 0
    var rem: TimeInterval = 0
    var awake: TimeInterval = 0
    var start: Date?
    var end: Date?

    /// Sleep efficiency: time asleep / time in bed.
    var efficiency: Double {
        guard inBed > 0 else { return 0 }
        return min(1, asleep / inBed)
    }

    var hoursAsleep: Double { asleep / 3600 }
}

// MARK: - Workout

struct WorkoutSummary: Identifiable, Equatable {
    let id = UUID()
    var typeName: String
    var symbol: String
    var start: Date
    var duration: TimeInterval
    var energyBurned: Double?    // kcal
    var distance: Double?        // meters
    var avgHeartRate: Double?
}

// MARK: - Heart rate

struct HeartRateSample: Identifiable, Equatable {
    let id = UUID()
    var date: Date
    var bpm: Double
}

// MARK: - Heart rate zones

enum HeartRateZone: Int, CaseIterable, Identifiable {
    case zone1 = 1, zone2, zone3, zone4, zone5
    var id: Int { rawValue }

    var name: String {
        switch self {
        case .zone1: return "Very Light"
        case .zone2: return "Light"
        case .zone3: return "Moderate"
        case .zone4: return "Hard"
        case .zone5: return "Maximum"
        }
    }

    var colorHex: String {
        switch self {
        case .zone1: return "16E7B8"
        case .zone2: return "4AA9FF"
        case .zone3: return "FFD23F"
        case .zone4: return "FF9F45"
        case .zone5: return "FF4D5E"
        }
    }

    /// Lower/upper bound as fraction of max HR.
    var range: ClosedRange<Double> {
        switch self {
        case .zone1: return 0.50...0.60
        case .zone2: return 0.60...0.70
        case .zone3: return 0.70...0.80
        case .zone4: return 0.80...0.90
        case .zone5: return 0.90...1.00
        }
    }
}
