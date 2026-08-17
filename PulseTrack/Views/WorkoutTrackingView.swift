import SwiftUI

struct WorkoutTrackingView: View {
    @EnvironmentObject var store: DataStore
    @State private var titleInput = ""
    @State private var showHistory = false

    private var session: WorkoutSessionManager { store.workout }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.spacing) {
                    if session.state == .idle {
                        idleView
                        if !session.history.isEmpty { historySection }
                    } else {
                        liveView
                    }
                }
                .padding(16)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Workout")
        }
    }

    // MARK: - Idle (Startbildschirm)

    private var idleView: some View {
        VStack(spacing: Theme.Layout.spacing) {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Neues Training")
                    TextField("Bezeichnung (z.B. Laufen, Gym)", text: $titleInput)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.Colors.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    // Sensor-Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(store.ble.connectedDevice != nil ? Theme.Colors.recovery : Theme.Colors.heart)
                            .frame(width: 8, height: 8)
                        Text(store.ble.connectedDevice != nil
                             ? "Sensor verbunden: \(store.ble.connectedDevice!.name)"
                             : "Kein Bluetooth-Sensor verbunden (unter Geraete koppeln)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Button {
                        session.start(title: titleInput)
                    } label: {
                        Text("Training starten")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.Colors.recovery)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    // MARK: - Live (laufendes Training)

    private var liveView: some View {
        VStack(spacing: Theme.Layout.spacing) {
            Card {
                VStack(spacing: 10) {
                    Text(session.title.uppercased())
                        .font(Theme.Typography.label).tracking(2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(Fmt.hoursMinutes(session.elapsed) + timeSeconds)
                        .font(Theme.Typography.metric(44))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()

                    // Live BPM
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Theme.Colors.heart)
                            .symbolEffect(.pulse, options: .repeating, isActive: session.state == .running)
                        Text(session.currentBPM.map { "\($0)" } ?? "--")
                            .font(Theme.Typography.metric(40))
                            .foregroundStyle(Theme.Colors.heart)
                        Text("bpm").font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    if let bpm = session.currentBPM {
                        let zone = currentZone(bpm: Double(bpm))
                        Text("Zone \(zone.rawValue) · \(zone.name)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color(hex: zone.colorHex))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Live-Graph
            if session.samples.count > 1 {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Herzfrequenz-Verlauf")
                        HeartRateGraph(samples: session.samples.map {
                            HeartRateSample(date: Date().addingTimeInterval($0.t), bpm: $0.bpm)
                        })
                        .frame(height: 120)
                    }
                }
            }

            // Live Stats
            HStack(spacing: Theme.Layout.spacing) {
                statCard("Ø", avgOf(session.samples), Theme.Colors.strain)
                statCard("Max", session.samples.map(\.bpm).max(), Theme.Colors.heart)
                statCard("Kcal", liveCalories, Theme.Colors.recovery)
            }

            // Steuerung
            HStack(spacing: 12) {
                if session.state == .running {
                    controlButton("Pause", "pause.fill", Theme.Colors.strain) { session.pause() }
                } else {
                    controlButton("Weiter", "play.fill", Theme.Colors.recovery) { session.resume() }
                }
                controlButton("Beenden", "stop.fill", Theme.Colors.heart) {
                    _ = session.stop(age: store.age)
                    titleInput = ""
                }
            }
        }
    }

    // MARK: - Verlauf

    private var historySection: some View {
        VStack(spacing: Theme.Layout.spacing) {
            SectionHeader(title: "Verlauf").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(session.history) { rec in
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(rec.title).font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(rec.start.formatted(.dateTime.day().month().hour().minute()))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        HStack(spacing: 20) {
                            histStat("Dauer", Fmt.duration(rec.duration))
                            histStat("Ø HR", "\(Int(rec.avgBPM))")
                            histStat("Max", "\(Int(rec.maxBPM))")
                            histStat("Kcal", "\(Int(rec.estimatedCalories(age: store.age)))")
                        }
                        if rec.samples.count > 1 {
                            HeartRateGraph(samples: rec.samples.map {
                                HeartRateSample(date: Date().addingTimeInterval($0.t), bpm: $0.bpm)
                            })
                            .frame(height: 70)
                        }
                    }
                }
                .contextMenu {
                    Button(role: .destructive) { session.deleteRecord(rec) } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var timeSeconds: String {
        let s = Int(session.elapsed) % 60
        return String(format: ":%02d", s)
    }

    private func currentZone(bpm: Double) -> HeartRateZone {
        let frac = bpm / store.maxHR
        return HeartRateZone.allCases.first { $0.range.contains(frac) } ?? .zone1
    }

    private func avgOf(_ pts: [WorkoutRecord.HRPoint]) -> Double? {
        guard !pts.isEmpty else { return nil }
        return pts.map(\.bpm).reduce(0, +) / Double(pts.count)
    }

    private var liveCalories: Double? {
        guard let avg = avgOf(session.samples), avg > 0 else { return nil }
        let minutes = session.elapsed / 60
        let kcalPerMin = (-55.0969 + 0.6309 * avg + 0.1988 * 75 + 0.2017 * Double(store.age)) / 4.184
        return max(0, kcalPerMin) * minutes
    }

    private func statCard(_ label: String, _ value: Double?, _ color: Color) -> some View {
        Card {
            VStack(spacing: 4) {
                Text(value.map { "\(Int($0))" } ?? "--")
                    .font(Theme.Typography.metric(26)).foregroundStyle(color)
                Text(label.uppercased()).font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textTertiary).tracking(1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func controlButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.Typography.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func histStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Theme.Typography.headline).foregroundStyle(Theme.Colors.textPrimary)
            Text(label.uppercased()).font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textTertiary).tracking(1)
        }
    }
}
