import Foundation

// MARK: - Generische Token-Antwort

struct WithingsTokenResponse: Decodable {
    let status: Int
    let body: Body?
    struct Body: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        let userid: String?
    }
}

// MARK: - /measure (Herz, Gewicht, SpO2 etc.)

struct WithingsMeasureResponse: Decodable {
    let status: Int
    let body: Body?
    struct Body: Decodable {
        let measuregrps: [Group]
    }
    struct Group: Decodable {
        let date: Int          // unix timestamp
        let measures: [Measure]
    }
    struct Measure: Decodable {
        let value: Int
        let type: Int          // Withings-Messtyp
        let unit: Int          // Zehnerpotenz
        var real: Double { Double(value) * pow(10, Double(unit)) }
    }
}

/// Withings Messtypen (Auszug).
enum WithingsMeasureType: Int {
    case weight = 1
    case heartRate = 11
    case spo2 = 54
    case diastolic = 9
    case systolic = 10
    case temperature = 71
    case hrv = 135          // (falls verfügbar)
}

// MARK: - /v2/measure getactivity (Aktivität pro Tag)

struct WithingsActivityResponse: Decodable {
    let status: Int
    let body: Body?
    struct Body: Decodable {
        let activities: [Activity]
    }
    struct Activity: Decodable {
        let date: String            // "yyyy-MM-dd"
        let steps: Int?
        let distance: Double?       // Meter
        let calories: Double?       // aktive kcal
        let totalcalories: Double?
        let hr_average: Int?
        let hr_min: Int?
        let hr_max: Int?
        let active: Int?            // aktive Sekunden
    }
}

// MARK: - /v2/sleep getsummary

struct WithingsSleepResponse: Decodable {
    let status: Int
    let body: Body?
    struct Body: Decodable { let series: [Series] }
    struct Series: Decodable {
        let startdate: Int
        let enddate: Int
        let data: SleepData
    }
    struct SleepData: Decodable {
        let deepsleepduration: Int?
        let lightsleepduration: Int?
        let remsleepduration: Int?
        let wakeupduration: Int?
        let durationtosleep: Int?
        let hr_average: Int?
        let rr_average: Int?          // Atemfrequenz
        let sleep_efficiency: Double?
    }
}

// MARK: - /v2/measure getworkouts (Trainingseinheiten)

struct WithingsWorkoutResponse: Decodable {
    let status: Int
    let body: Body?
    struct Body: Decodable { let series: [Series] }
    struct Series: Decodable {
        let category: Int          // Workout-Typ
        let startdate: Int
        let enddate: Int
        let data: WorkoutData?
    }
    struct WorkoutData: Decodable {
        let calories: Double?
        let distance: Double?       // Meter
        let hr_average: Double?
        let steps: Int?
    }
}

/// Withings Workout-Kategorien -> Name + SF Symbol.
enum WithingsWorkoutType {
    static func name(_ category: Int) -> String {
        switch category {
        case 1: return "Gehen"
        case 2: return "Laufen"
        case 3: return "Wandern"
        case 4: return "Skaten"
        case 5: return "BMX"
        case 6: return "Radfahren"
        case 7: return "Schwimmen"
        case 8: return "Surfen"
        case 9: return "Kitesurfen"
        case 10: return "Windsurfen"
        case 11: return "Bodyboard"
        case 12: return "Tennis"
        case 13: return "Tischtennis"
        case 14: return "Squash"
        case 15: return "Badminton"
        case 16: return "Krafttraining"
        case 17: return "Rudern"
        case 18: return "Crossfit"
        case 19: return "Elliptisch"
        case 20: return "Pilates"
        case 21: return "Basketball"
        case 22: return "Fußball"
        case 23: return "Football"
        case 24: return "Rugby"
        case 25: return "Volleyball"
        case 27: return "Yoga"
        case 28: return "Tanzen"
        case 29: return "Boxen"
        case 32: return "Ski"
        case 33: return "Snowboard"
        case 187: return "HIIT"
        case 188: return "Golf"
        default: return "Training"
        }
    }

    static func symbol(_ category: Int) -> String {
        switch category {
        case 1: return "figure.walk"
        case 2: return "figure.run"
        case 3: return "figure.hiking"
        case 6: return "figure.outdoor.cycle"
        case 7: return "figure.pool.swim"
        case 12: return "figure.tennis"
        case 16: return "dumbbell.fill"
        case 17: return "figure.rower"
        case 18, 187: return "flame.fill"
        case 19: return "figure.elliptical"
        case 20: return "figure.pilates"
        case 21: return "figure.basketball"
        case 22: return "figure.soccer"
        case 27: return "figure.yoga"
        case 28: return "figure.dance"
        case 29: return "figure.boxing"
        case 32, 33: return "figure.skiing.downhill"
        default: return "figure.mixed.cardio"
        }
    }
}

// MARK: - /v2/heart list (HRV / EKG Ereignisse)

struct WithingsHeartResponse: Decodable {
    let status: Int
    let body: Body?
    struct Body: Decodable { let series: [Series] }
    struct Series: Decodable {
        let timestamp: Int
        let heart_rate: Int?
    }
}
