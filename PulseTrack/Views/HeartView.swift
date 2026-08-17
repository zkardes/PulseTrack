import SwiftUI

struct HeartView: View {
    @EnvironmentObject var store: DataStore

    private var today: DayMetrics? { store.today }
    private var zones: [HeartRateZone: TimeInterval] {
        guard let today else { return [:] }
        return HealthAnalytics.zoneDurations(samples: today.heartRateSamples, maxHR: store.maxHR)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.spacing) {
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Heart Rate Today")
                        HStack(spacing: 20) {
                            hrStat("Min", today?.minHeartRate, Theme.Colors.recovery)
                            hrStat("Avg", today?.avgHeartRate, Theme.Colors.strain)
                            hrStat("Max", today?.maxHeartRate, Theme.Colors.heart)
                        }
                        if let samples = today?.heartRateSamples, !samples.isEmpty {
                            HeartRateGraph(samples: samples)
                                .frame(height: 130)
                        } else {
                            Text("No heart rate samples yet today.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                }

                Card {
                    HStack {
                        Text("Est. Max HR").font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(store.maxHR)) bpm").font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.heart)
                    }
                }

                SectionHeader(title: "Heart Rate Zones").frame(maxWidth: .infinity, alignment: .leading)
                Card {
                    VStack(spacing: 14) {
                        ForEach(HeartRateZone.allCases.reversed()) { zone in
                            let dur = zones[zone] ?? 0
                            let total = max(zones.values.reduce(0, +), 1)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Circle().fill(Color(hex: zone.colorHex)).frame(width: 10, height: 10)
                                    Text("Z\(zone.rawValue) · \(zone.name)")
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Text(Fmt.duration(dur)).font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                MiniBar(fraction: dur / total, color: Color(hex: zone.colorHex))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .refreshable { await store.syncWithings() }
    }

    private func hrStat(_ label: String, _ value: Double?, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(Fmt.int(value)).font(Theme.Typography.metric(30)).foregroundStyle(color)
            Text(label.uppercased()).font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textTertiary).tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// Line graph of heart-rate samples.
struct HeartRateGraph: View {
    var samples: [HeartRateSample]

    var body: some View {
        GeometryReader { geo in
            let bpms = samples.map(\.bpm)
            let minV = (bpms.min() ?? 40) - 5
            let maxV = (bpms.max() ?? 180) + 5
            let range = max(maxV - minV, 1)
            Path { p in
                for (i, s) in samples.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(samples.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((s.bpm - minV) / range))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(
                LinearGradient(colors: [Theme.Colors.strain, Theme.Colors.heart],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
