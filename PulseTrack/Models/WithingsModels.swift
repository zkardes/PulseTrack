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
    struct Body: Decodable { let activities: [Activity] }
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
