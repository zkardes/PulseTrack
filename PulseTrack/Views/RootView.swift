import SwiftUI

struct RootView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        Group {
            if health.isAuthorized {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.Colors.recovery)
    }
}

struct MainTabView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "bolt.heart.fill") }
            StrainView()
                .tabItem { Label("Strain", systemImage: "flame.fill") }
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon.stars.fill") }
            HeartView()
                .tabItem { Label("Heart", systemImage: "waveform.path.ecg") }
        }
        .overlay {
            if health.isLoading && health.days.isEmpty {
                ZStack {
                    Theme.Colors.background.opacity(0.8).ignoresSafeArea()
                    ProgressView("Syncing Health data…")
                        .tint(Theme.Colors.recovery)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        ZStack {
            RadialGradient(colors: [Theme.Colors.recovery.opacity(0.25), Theme.Colors.background],
                           center: .top, startRadius: 20, endRadius: 500)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Colors.recovery)
                    .shadow(color: Theme.Colors.recovery.opacity(0.6), radius: 20)
                Text("PulseTrack")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Recovery, strain, sleep and heart insights — powered entirely by Apple Health and your paired sensors.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 14) {
                    feature("bolt.heart.fill", "Daily recovery score from HRV & RHR")
                    feature("flame.fill", "Cardiovascular strain & workout tracking")
                    feature("moon.stars.fill", "Sleep stages & performance analysis")
                    feature("waveform.path.ecg", "Heart rate zones all day")
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                Spacer()
                Button {
                    Task { await health.requestAuthorization() }
                } label: {
                    Text("Connect Apple Health")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Colors.recovery)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)

                if let err = health.errorMessage {
                    Text(err).font(Theme.Typography.caption).foregroundStyle(Theme.Colors.heart)
                }
                Spacer().frame(height: 20)
            }
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.Colors.recovery).frame(width: 24)
            Text(text).font(Theme.Typography.body).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
    }
}
