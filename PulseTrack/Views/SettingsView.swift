import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.spacing) {

                    // MARK: Withings
                    SectionHeader(title: "Withings Cloud").frame(maxWidth: .infinity, alignment: .leading)
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "cloud.fill").foregroundStyle(Theme.Colors.strain)
                                Text("Withings Scanwatch 2")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Circle()
                                    .fill(store.isWithingsConnected ? Theme.Colors.recovery : Theme.Colors.textTertiary)
                                    .frame(width: 10, height: 10)
                            }
                            Text(store.isWithingsConnected
                                 ? "Verbunden. Daten werden aus der Health-Mate-Cloud geladen."
                                 : "Verbinde dein Withings-Konto, um Aktivität, Schlaf und Herzdaten zu synchronisieren.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)

                            if store.isWithingsConnected {
                                HStack {
                                    Button {
                                        Task { await store.syncWithings() }
                                    } label: { pill("Jetzt synchronisieren", Theme.Colors.recovery) }
                                    Button {
                                        store.withings.disconnect()
                                    } label: { pill("Trennen", Theme.Colors.heart) }
                                }
                            } else {
                                Button {
                                    Task { await store.withings.connect(); await store.syncWithings() }
                                } label: { pill("Mit Withings verbinden", Theme.Colors.strain) }
                            }

                            if !WithingsConfig.isConfigured {
                                Text("⚠️ Client ID/Secret fehlen in WithingsConfig.swift.")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.heart)
                            }
                        }
                    }

                    // MARK: Bluetooth
                    SectionHeader(title: "Bluetooth-Sensoren").frame(maxWidth: .infinity, alignment: .leading)
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            if let dev = store.ble.connectedDevice {
                                HStack {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .foregroundStyle(Theme.Colors.recovery)
                                    VStack(alignment: .leading) {
                                        Text(dev.name).font(Theme.Typography.headline)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text(store.ble.liveHeartRate.map { "\($0) bpm live" } ?? "verbunden")
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                    Spacer()
                                    if let bat = store.ble.batteryLevel {
                                        Label("\(bat)%", systemImage: "battery.100")
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                }
                                Button { store.ble.disconnect() } label: { pill("Trennen", Theme.Colors.heart) }
                            } else {
                                Text("Suche nach Herzfrequenz-Sensoren (Standard Bluetooth Heart Rate Profil, z.B. GEOID Tracker & Brustgurte).")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)

                                Button {
                                    store.ble.isScanning ? store.ble.stopScan() : store.ble.startScan()
                                } label: {
                                    pill(store.ble.isScanning ? "Suche läuft… (stoppen)" : "Sensoren suchen",
                                         Theme.Colors.recovery)
                                }

                                if store.ble.state == .poweredOff {
                                    Text("Bitte Bluetooth in den Einstellungen aktivieren.")
                                        .font(Theme.Typography.caption).foregroundStyle(Theme.Colors.heart)
                                }

                                ForEach(store.ble.discovered) { dev in
                                    Button {
                                        store.ble.connect(dev)
                                    } label: {
                                        HStack {
                                            Image(systemName: "heart.fill").foregroundStyle(Theme.Colors.heart)
                                            Text(dev.name).font(Theme.Typography.body)
                                                .foregroundStyle(Theme.Colors.textPrimary)
                                            Spacer()
                                            Text("\(dev.rssi) dBm").font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Colors.textTertiary)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Profil
                    SectionHeader(title: "Profil").frame(maxWidth: .infinity, alignment: .leading)
                    Card {
                        Stepper("Alter: \(store.age) Jahre", value: $store.age, in: 10...100)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
                .padding(16)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Geräte")
        }
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
