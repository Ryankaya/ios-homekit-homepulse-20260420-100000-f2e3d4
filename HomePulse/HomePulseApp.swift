import SwiftUI

@main
struct HomePulseApp: App {
    @StateObject private var homeKitManager = HomeKitManager()
    @StateObject private var floorPlan      = FloorPlanViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(homeKitManager)
                .environmentObject(floorPlan)
                .preferredColorScheme(.dark)
        }
    }
}
