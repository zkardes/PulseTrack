import Foundation

/// Computes Whoop-style scores from raw HealthKit data using deterministic
/// formulas (rolling baselines + weighted models). No AI / ML involved.
enum HealthAnalytics {

    // MARK: - Recovery Score (0-100)

    /// Recovery blends HRV (primary), resting HR, sleep quality, respiratory
    /// rate and SpO2 against the user's personal rolling baseline.
    static func recoveryScore(today: DayMetrics, baseline: Baseline) -> Int {
        var weightSum = 0.0
        var score = 0.0

        // HRV — higher than baseline is good. 50% weight.
        if let hrv = today.hrv, let base = baseline.hrv, base > 0 {
            let ratio = hrv / base
            let sub = clamp(remap(ratio, 0.6, 1.3, 0, 100), 0, 100)
            score += sub * 0.50; weightSum += 0.50
        }

        // Resting HR — lower than baseline is good. 20% weight.
        if let rhr = today.restingHeartRate, let base = baseline.restingHeartRate, base > 0 {
            let ratio = base / rhr
            let sub = clamp(remap(ratio, 0.85, 1.15, 0, 100), 0, 100)
            score += sub * 0.20; weightSum += 0.20
        }

        // Sleep — efficiency + duration vs 8h. 20% weight.
        if let sleep = today.sleep {
            let durScore = clamp(sleep.hoursAsleep / 8.0 * 100, 0, 100)
            let effScore = sleep.efficiency * 100
            let sub = durScore * 0.6 + effScore * 0.4
            score += sub * 0.20; weightSum += 0.20
        }

        // Respiratory rate — closer to baseline is good. 5% weight.
        if let rr = today.respiratoryRate, let base = baseline.respiratoryRate, base > 0 {
            let dev = abs(rr - base) / base
            let sub = clamp(100 - dev * 400, 0, 100)
            score += sub * 0.05; weightSum += 0.05
        }

        // SpO2 — 95%+ ideal. 5% weight.
        if let spo2 = today.bloodOxygen {
            let pct = spo2 <= 1 ? spo2 * 100 : spo2
            let sub = clamp(remap(pct, 90, 98, 0, 100), 0, 100)
            score += sub * 0.05; weightSum += 0.05
        }

        guard weightSum > 0 else { return 0 }
        return Int(round(score / weightSum))
    }

    // MARK: - Strain Score (0-21, Whoop scale)

    /// Strain is a logarithmic function of cardiovascular load, derived from
    /// time spent in heart-rate zones plus active energy.
    static func strainScore(today: DayMetrics, maxHR: Double) -> Double {
        // Weighted "load" points: higher zones count more.
        var load = 0.0
        for s in today.heartRateSamples {
            let frac = s.bpm / maxHR
            switch frac {
            case 0.5..<0.6:  load += 1
            case 0.6..<0.7:  load += 2
            case 0.7..<0.8:  load += 3
            case 0.8..<0.9:  load += 5
            case 0.9...:     load += 8
            default: break
            }
        }
        // Add contribution from active energy.
        load += (today.activeEnergy ?? 0) * 0.15

        // Map onto a 0-21 logarithmic scale.
        let strain = 6.0 * log(1 + load / 60.0)
        return clamp(strain, 0, 21)
    }

    // MARK: - Sleep Performance (0-100)

    /// Sleep need scales with the prior day's strain (harder days need more).
    static func sleepPerformance(sleep: SleepSummary, priorStrain: Double) -> Int {
        let baseNeedHours = 7.5
        let strainBonus = priorStrain / 21.0 * 1.5      // up to +1.5h
        let need = baseNeedHours + strainBonus
        let perf = sleep.hoursAsleep / need * 100
        // Blend with efficiency.
        let combined = perf * 0.8 + sleep.efficiency * 100 * 0.2
        return Int(clamp(combined, 0, 100).rounded())
    }

    // MARK: - Heart rate zone breakdown

    static func zoneDurations(samples: [HeartRateSample], maxHR: Double) -> [HeartRateZone: TimeInterval] {
        var result: [HeartRateZone: TimeInterval] = [:]
        let sorted = samples.sorted { $0.date < $1.date }
        for i in 0..<sorted.count {
            let s = sorted[i]
            // Estimate duration until next sample (cap at 60s).
            let dt: TimeInterval = i + 1 < sorted.count
                ? min(sorted[i + 1].date.timeIntervalSince(s.date), 60)
                : 30
            let frac = s.bpm / maxHR
            for zone in HeartRateZone.allCases where zone.range.contains(frac) {
                result[zone, default: 0] += dt
            }
        }
        return result
    }

    // MARK: - Estimated max HR (Tanaka formula)

    static func estimatedMaxHR(age: Int) -> Double {
        208 - 0.7 * Double(age)
    }

    // MARK: - Helpers

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    /// Linear remap of x from [inLo,inHi] to [outLo,outHi].
    static func remap(_ x: Double, _ inLo: Double, _ inHi: Double, _ outLo: Double, _ outHi: Double) -> Double {
        guard inHi != inLo else { return outLo }
        return outLo + (x - inLo) / (inHi - inLo) * (outHi - outLo)
    }
}

/// Rolling personal baseline (e.g. 30-day averages).
struct Baseline {
    var hrv: Double?
    var restingHeartRate: Double?
    var respiratoryRate: Double?

    static func from(days: [DayMetrics]) -> Baseline {
        func avg(_ vals: [Double]) -> Double? {
            vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
        }
        return Baseline(
            hrv: avg(days.compactMap { $0.hrv }),
            restingHeartRate: avg(days.compactMap { $0.restingHeartRate }),
            respiratoryRate: avg(days.compactMap { $0.respiratoryRate })
        )
    }
}
