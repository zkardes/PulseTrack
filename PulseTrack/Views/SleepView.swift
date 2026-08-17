import SwiftUI

struct SleepView: View {
    @EnvironmentObject var health: HealthKitManager

    private var sleep: SleepSummary? { health.today?.sleep }
    private var performance: Int {
        guard let sleep else { return 0 }
        let prior = health.days.count > 1
            ? HealthAnalytics.strainScore(today: health.days[1], maxHR: health.maxHR) : 0
        return HealthAnalytics.sleepPerformance(sleep: sleep, priorStrain: prior)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.spacing) {
                Card {
                    VStack(spacing: 14) {
                        MetricRing(progress: Double(performance) / 100, color: Theme.Colors.sleep,
                                   value: "\(performance)%", label: "Sleep", size: 200)
                        if let sleep {
                            HStack(spacing: 24) {
                                miniStat("Asleep", Fmt.hoursMinutes(sleep.asleep))
                                miniStat("In Bed", Fmt.hoursMinutes(sleep.inBed))
                                miniStat("Efficiency", "\(Int(sleep.efficiency * 100))%")
                            }
                        }
                    }.frame(maxWidth: .infinity)
                }

                if let sleep {
                    SectionHeader(title: "Sleep Stages").frame(maxWidth: .infinity, alignment: .leading)
                    Card {
                        VStack(spacing: 14) {
                            stageBar("Deep", sleep.deep, sleep.inBed, Theme.Colors.sleep)
                            stageBar("REM", sleep.rem, sleep.inBed, Theme.Colors.strain)
                            stageBar("Core", sleep.core, sleep.inBed, Theme.Colors.recovery)
                            stageBar("Awake", sleep.awake, sleep.inBed, Theme.Colors.heart)
                        }
                    }

                    Card {
                        HStack {
                            miniStat("Bedtime", Fmt.time(sleep.start))
                            Spacer()
                            miniStat("Wake", Fmt.time(sleep.end))
                            Spacer()
                            miniStat("Restfulness", "\(Int(sleep.efficiency * 100))%")
                        }
                    }
                } else {
                    Card {
                        Text("No sleep data recorded for last night. Wear your device or paired sensor to bed to track sleep.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                SectionHeader(title: "7-Day Sleep Duration").frame(maxWidth: .infinity, alignment: .leading)
                Card {
                    TrendBars(values: Array(health.days.prefix(7).reversed().map {
                        ($0.sleep?.hoursAsleep ?? 0)
                    }), color: Theme.Colors.sleep)
                }
            }
            .padding(16)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .refreshable { await health.loadAll() }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.Typography.headline).foregroundStyle(Theme.Colors.textPrimary)
            Text(label.uppercased()).font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textTertiary).tracking(1)
        }
    }

    private func stageBar(_ name: String, _ value: TimeInterval, _ total: TimeInterval, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(Theme.Typography.body).foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(Fmt.duration(value)).font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            MiniBar(fraction: total > 0 ? value / total : 0, color: color)
        }
    }
}
