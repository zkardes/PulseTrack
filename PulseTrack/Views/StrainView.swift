import SwiftUI

struct StrainView: View {
    @EnvironmentObject var health: HealthKitManager

    private var today: DayMetrics? { health.today }
    private var strain: Double {
        guard let today else { return 0 }
        return HealthAnalytics.strainScore(today: today, maxHR: health.maxHR)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.spacing) {
                Card {
                    VStack(spacing: 14) {
                        MetricRing(progress: strain / 21, color: Theme.Colors.strain,
                                   value: String(format: "%.1f", strain), label: "Strain", size: 200)
                        Text(strainMessage).font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity)
                }

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: Theme.Layout.spacing) {
                    StatPill(icon: "flame.fill", value: Fmt.int(today?.activeEnergy), label: "Active kcal", color: Theme.Colors.heart)
                    StatPill(icon: "flame", value: Fmt.int(today?.totalEnergy), label: "Total kcal", color: Theme.Colors.strain)
                    StatPill(icon: "figure.walk", value: Fmt.int(today?.steps), label: "Steps", color: Theme.Colors.recovery)
                    StatPill(icon: "location.fill", value: Fmt.km(today?.distanceWalkingRunning), label: "km", color: Theme.Colors.sleep)
                    StatPill(icon: "timer", value: Fmt.int(today?.exerciseMinutes), label: "Exercise min", color: Theme.Colors.strain)
                    StatPill(icon: "bolt.fill", value: String(format: "%.1f", strain), label: "Strain", color: Theme.Colors.heart)
                }

                if let workouts = today?.workouts, !workouts.isEmpty {
                    SectionHeader(title: "Workouts").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(workouts) { w in
                        Card {
                            HStack(spacing: 14) {
                                Image(systemName: w.symbol)
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.Colors.strain)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.Colors.surfaceHigh)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(w.typeName).font(Theme.Typography.headline)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("\(Fmt.time(w.start)) · \(Fmt.duration(w.duration))")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                Spacer()
                                if let e = w.energyBurned {
                                    Text("\(Int(e)) kcal").font(Theme.Typography.headline)
                                        .foregroundStyle(Theme.Colors.heart)
                                }
                            }
                        }
                    }
                }

                SectionHeader(title: "7-Day Strain").frame(maxWidth: .infinity, alignment: .leading)
                Card {
                    TrendBars(values: Array(health.days.prefix(7).reversed().map {
                        HealthAnalytics.strainScore(today: $0, maxHR: health.maxHR)
                    }), color: Theme.Colors.strain)
                }
            }
            .padding(16)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .refreshable { await health.loadAll() }
    }

    private var strainMessage: String {
        switch strain {
        case ..<8:   return "Light day. Plenty of room for more activity."
        case ..<14:  return "Moderate cardiovascular load built up today."
        case ..<18:  return "Strenuous day — solid training load accumulated."
        default:     return "All-out effort. Make sure to recover well tonight."
        }
    }
}
