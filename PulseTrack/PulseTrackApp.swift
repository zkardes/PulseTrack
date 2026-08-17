import SwiftUI

@main
struct PulseTrackApp: App {
    @StateObject private var health = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .preferredColorScheme(.dark)
        }
    }
}
