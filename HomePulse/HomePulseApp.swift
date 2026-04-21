import SwiftUI

@main
struct HomePulseApp: App {
    @StateObject private var homeKitManager = HomeKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(homeKitManager)
                .preferredColorScheme(.dark)
        }
    }
}
