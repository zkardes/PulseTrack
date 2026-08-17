import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject var health: HealthKitManager

    private var recovery: Int {
        guard let t = health.today else { return 0 }
        return HealthAnalytics.recoveryScore(today: t, baseline: health.baseline)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.spacing) {
                Card {
                    VStack(spacing: 14) {
                        MetricRing(progress: Double(recovery) / 100,
                                   color: Theme.Colors.recoveryZone(Double(recovery)),
                                   value: "\(recovery)%", label: "Recovery", size: 200)
                        HStack(spacing: 24) {
                            baselineStat("HRV", health.today?.hrv, health.baseline.hrv, "ms")
                            baselineStat("RHR", health.today?.restingHeartRate, health.baseline.restingHeartRate, "bpm")
                        }
                    }.frame(maxWidth: .infinity)
                }

                SectionHeader(title: "30-Day Recovery Trend")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Card { TrendBars(values: recoveryTrend, color: Theme.Colors.recovery) }

                SectionHeader(title: "Contributing Factors")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Card {
                    VStack(spacing: 14) {
                        factor("Heart Rate Variability", health.today?.hrv, health.baseline.hrv, "ms", higherBetter: true)
                        Divider().overlay(Theme.Colors.stroke)
                        factor("Resting Heart Rate", health.today?.restingHeartRate, health.baseline.restingHeartRate, "bpm", higherBetter: false)
                        Divider().overlay(Theme.Colors.stroke)
                        factor("Respiratory Rate", health.today?.respiratoryRate, health.baseline.respiratoryRate, "br/min", higherBetter: false)
                        Divider().overlay(Theme.Colors.stroke)
                        factor("Blood Oxygen", health.today?.bloodOxygen, 97, "%", higherBetter: true)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .refreshable { await health.loadAll() }
    }

    private var recoveryTrend: [Double] {
        health.days.reversed().map {
            Double(HealthAnalytics.recoveryScore(today: $0, baseline: health.baseline))
        }
    }

    private func baselineStat(_ name: String, _ value: Double?, _ base: Double?, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(Fmt.int(value)).font(Theme.Typography.metric(28))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("\(name) · base \(Fmt.int(base)) \(unit)")
                .font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func factor(_ name: String, _ value: Double?, _ base: Double?, _ unit: String, higherBetter: Bool) -> some View {
        let ok: Bool = {
            guard let value, let base else { return true }
            return higherBetter ? value >= base : value <= base
        }()
        return HStack {
            Circle().fill(ok ? Theme.Colors.recovery : Theme.Colors.heart).frame(width: 8, height: 8)
            Text(name).font(Theme.Typography.body).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text("\(Fmt.int(value)) \(unit)").font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

// Simple bar chart used across trend views.
struct TrendBars: View {
    var values: [Double]
    var color: Color

    var body: some View {
        let maxV = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(values.indices, id: \.self) { i in
                Capsule().fill(color.opacity(0.85))
                    .frame(height: max(3, CGFloat(values[i] / maxV) * 120))
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}
