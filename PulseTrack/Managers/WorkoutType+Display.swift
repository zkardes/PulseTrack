import HealthKit

/// Friendly names + SF Symbols for workout types.
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .coreTraining: return "Core"
        case .pilates: return "Pilates"
        case .dance, .cardioDance: return "Dance"
        case .boxing, .kickboxing: return "Boxing"
        case .stairClimbing, .stairs: return "Stairs"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        default: return "Workout"
        }
    }

    var symbolName: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "flame.fill"
        case .yoga: return "figure.yoga"
        case .hiking: return "figure.hiking"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .coreTraining: return "figure.core.training"
        case .pilates: return "figure.pilates"
        case .dance, .cardioDance: return "figure.dance"
        case .boxing, .kickboxing: return "figure.boxing"
        case .stairClimbing, .stairs: return "figure.stairs"
        case .soccer: return "figure.soccer"
        case .basketball: return "figure.basketball"
        case .tennis: return "figure.tennis"
        default: return "figure.mixed.cardio"
        }
    }
}
