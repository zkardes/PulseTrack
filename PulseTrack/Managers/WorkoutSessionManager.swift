import Foundation
import Combine

/// Eine aufgezeichnete Trainingseinheit (sportartunabhängig).
struct WorkoutRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var samples: [HRPoint]
    var maxHR: Double        // benutzter Max-HR-Wert für Zonen

    struct HRPoint: Codable, Equatable {
        var t: TimeInterval  // Sekunden seit Start
        var bpm: Double
    }

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var avgBPM: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.bpm).reduce(0, +) / Double(samples.count)
    }
    var maxBPM: Double { samples.map(\.bpm).max() ?? 0 }
    var minBPM: Double { samples.map(\.bpm).min() ?? 0 }

    /// Grobe Kalorienschätzung (Keytel-Formel, geschlechtsneutral gemittelt).
    func estimatedCalories(age: Int, weightKg: Double = 75) -> Double {
        guard avgBPM > 0 else { return 0 }
        let minutes = duration / 60
        let hr = avgBPM
        // Gemittelte Keytel-Koeffizienten (m/w).
        let kcalPerMin = (-55.0969 + 0.6309 * hr + 0.1988 * weightKg + 0.2017 * Double(age)) / 4.184
        return max(0, kcalPerMin) * minutes
    }
}

/// Steuert eine laufende Live-Trainingseinheit und zeichnet die
/// Herzfrequenz aus dem BLEManager auf.
@MainActor
final class WorkoutSessionManager: ObservableObject {

    enum State { case idle, running, paused }

    @Published var state: State = .idle
    @Published var title: String = "Training"
    @Published var elapsed: TimeInterval = 0
    @Published var currentBPM: Int?
    @Published var samples: [WorkoutRecord.HRPoint] = []
    @Published var history: [WorkoutRecord] = []

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var timer: AnyCancellable?
    private var hrCancellable: AnyCancellable?

    private unowned let ble: BLEManager
    private let maxHRProvider: () -> Double
    private let historyKey = "pulsetrack.workouts.v1"

    init(ble: BLEManager, maxHR: @escaping () -> Double) {
        self.ble = ble
        self.maxHRProvider = maxHR
        loadHistory()
    }

    // MARK: - Steuerung

    func start(title: String) {
        self.title = title.isEmpty ? "Training" : title
        state = .running
        startDate = Date()
        accumulated = 0
        elapsed = 0
        samples.removeAll()
        subscribeHR()
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        accumulated = elapsed
        state = .paused
        timer?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        startDate = Date()
        state = .running
        startTimer()
    }

    func stop(age: Int) -> WorkoutRecord? {
        guard state != .idle else { return nil }
        timer?.cancel()
        hrCancellable?.cancel()
        let end = Date()
        let start = end.addingTimeInterval(-elapsed)
        let record = WorkoutRecord(
            title: title,
            start: start,
            end: end,
            samples: samples,
            maxHR: maxHRProvider()
        )
        history.insert(record, at: 0)
        saveHistory()
        state = .idle
        currentBPM = nil
        return record
    }

    func discard() {
        timer?.cancel()
        hrCancellable?.cancel()
        state = .idle
        currentBPM = nil
        samples.removeAll()
        elapsed = 0
    }

    // MARK: - Intern

    private func startTimer() {
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let s = self.startDate else { return }
                self.elapsed = self.accumulated + Date().timeIntervalSince(s)
            }
    }

    private func subscribeHR() {
        hrCancellable = ble.$liveHeartRate
            .compactMap { $0 }
            .sink { [weak self] bpm in
                guard let self, self.state == .running else { return }
                self.currentBPM = bpm
                self.samples.append(.init(t: self.elapsed, bpm: Double(bpm)))
            }
    }

    // MARK: - Persistenz

    func deleteRecord(_ record: WorkoutRecord) {
        history.removeAll { $0.id == record.id }
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let list = try? JSONDecoder().decode([WorkoutRecord].self, from: data) else { return }
        history = list
    }
}
