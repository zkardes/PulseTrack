import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        Group {
            if store.isWithingsConnected || !store.days.isEmpty {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.Colors.recovery)
        .task {
            if store.isWithingsConnected { await store.syncWithings() }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2.fill") }
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "bolt.heart.fill") }
            StrainView()
                .tabItem { Label("Belastung", systemImage: "flame.fill") }
            WorkoutTrackingView()
                .tabItem { Label("Workout", systemImage: "stopwatch.fill") }
            SleepView()
                .tabItem { Label("Schlaf", systemImage: "moon.stars.fill") }
            HeartView()
                .tabItem { Label("Herz", systemImage: "waveform.path.ecg") }
            SettingsView()
                .tabItem { Label("Geräte", systemImage: "gearshape.fill") }
        }
        .overlay {
            if store.isLoading && store.days.isEmpty {
                ZStack {
                    Theme.Colors.background.opacity(0.8).ignoresSafeArea()
                    ProgressView("Synchronisiere Daten…")
                        .tint(Theme.Colors.recovery)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        ZStack {
            RadialGradient(colors: [Theme.Colors.recovery.opacity(0.25), Theme.Colors.background],
                           center: .top, startRadius: 20, endRadius: 500)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 40)
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.Colors.recovery)
                        .shadow(color: Theme.Colors.recovery.opacity(0.6), radius: 20)
                    Text("PulseTrack")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Recovery, Belastung, Schlaf und Herzfrequenz — direkt aus Withings und deinen Bluetooth-Sensoren. Ganz ohne Apple Health.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 14) {
                        feature("cloud.fill", "Withings Scanwatch 2 über die Cloud API")
                        feature("dot.radiowaves.left.and.right", "Bluetooth-Herzfrequenzsensoren live")
                        feature("bolt.heart.fill", "Recovery-Score aus HRV & Ruhepuls")
                        feature("moon.stars.fill", "Schlafphasen & Belastungsanalyse")
                    }
                    .padding(.horizontal, 40)

                    VStack(spacing: 12) {
                        Button {
                            Task { await store.withings.connect(); await store.syncWithings() }
                        } label: {
                            primaryLabel("Mit Withings verbinden", filled: true)
                        }
                        Button {
                            store.days = [DayMetrics(date: Calendar.current.startOfDay(for: Date()))]
                        } label: {
                            primaryLabel("Nur Bluetooth-Sensor nutzen", filled: false)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    if let err = store.withings.lastError {
                        Text(err).font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.heart)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    Spacer().frame(height: 30)
                }
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

    private func primaryLabel(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(Theme.Typography.headline)
            .foregroundStyle(filled ? Color.black : Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(filled ? Theme.Colors.recovery : Theme.Colors.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
