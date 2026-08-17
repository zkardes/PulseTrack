import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager

    private var today: DayMetrics? { health.today }

    private var recovery: Int {
        guard let today else { return 0 }
        return HealthAnalytics.recoveryScore(today: today, baseline: health.baseline)
    }
    private var strain: Double {
        guard let today else { return 0 }
        return HealthAnalytics.strainScore(today: today, maxHR: health.maxHR)
    }
    private var sleepPerf: Int {
        guard let sleep = today?.sleep else { return 0 }
        let prior = health.days.count > 1
            ? HealthAnalytics.strainScore(today: health.days[1], maxHR: health.maxHR) : 0
        return HealthAnalytics.sleepPerformance(sleep: sleep, priorStrain: prior)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.spacing) {
                header

                // Recovery hero ring
                Card {
                    VStack(spacing: 16) {
                        MetricRing(
                            progress: Double(recovery) / 100,
                            color: Theme.Colors.recoveryZone(Double(recovery)),
                            value: "\(recovery)%",
                            label: "Recovery"
                        )
                        Text(recoveryMessage)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Strain + Sleep summary row
                HStack(spacing: Theme.Layout.spacing) {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Day Strain")
                            Text(String(format: "%.1f", strain))
                                .font(Theme.Typography.metric(40))
                                .foregroundStyle(Theme.Colors.strain)
                            MiniBar(fraction: strain / 21, color: Theme.Colors.strain)
                            Text("of 21").font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Sleep")
                            Text("\(sleepPerf)%")
                                .font(Theme.Typography.metric(40))
                                .foregroundStyle(Theme.Colors.sleep)
                            MiniBar(fraction: Double(sleepPerf) / 100, color: Theme.Colors.sleep)
                            Text(Fmt.duration(today?.sleep?.asleep ?? 0))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                }

                // Vitals grid
                SectionHeader(title: "Today's Vitals")
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: Theme.Layout.spacing) {
                    StatPill(icon: "heart.fill", value: Fmt.int(today?.restingHeartRate), label: "Rest HR", color: Theme.Colors.heart)
                    StatPill(icon: "waveform.path.ecg", value: Fmt.int(today?.hrv), label: "HRV ms", color: Theme.Colors.recovery)
                    StatPill(icon: "lungs.fill", value: Fmt.int(today?.respiratoryRate), label: "Resp", color: Theme.Colors.strain)
                    StatPill(icon: "drop.fill", value: today?.bloodOxygen.map { "\(Int($0))%" } ?? "--", label: "SpO2", color: Theme.Colors.sleep)
                    StatPill(icon: "flame.fill", value: Fmt.int(today?.activeEnergy), label: "Active kcal", color: Theme.Colors.heart)
                    StatPill(icon: "figure.walk", value: Fmt.int(today?.steps), label: "Steps", color: Theme.Colors.recovery)
                }
            }
            .padding(16)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .refreshable { await health.loadAll() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Circle().fill(Theme.Colors.surfaceHigh)
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "bolt.heart.fill").foregroundStyle(Theme.Colors.recovery))
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var recoveryMessage: String {
        switch recovery {
        case ..<34: return "Your body needs rest. Keep strain low today and prioritize recovery."
        case ..<67: return "You're moderately recovered. Train, but listen to your body."
        default:    return "You're primed. Your body is ready to take on strain today."
        }
    }
}
