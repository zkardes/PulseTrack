import SwiftUI

@main
struct PulseTrackApp: App {
    @StateObject private var store = DataStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
