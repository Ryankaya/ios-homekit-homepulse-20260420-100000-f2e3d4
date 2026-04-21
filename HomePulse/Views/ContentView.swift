import SwiftUI
import HomeKit

struct ContentView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager

    var body: some View {
        if homeKitManager.isLoading {
            LoadingView()
                .transition(.opacity)
        } else if homeKitManager.authorizationStatus == .restricted {
            PermissionDeniedView()
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        TabView {
            dashboardTab
                .tabItem { Label("Home", systemImage: "house.fill") }

            FloorPlanView()
                .tabItem { Label("Floor Plan", systemImage: "square.grid.2x2.fill") }
        }
        .tint(.orange)
    }

    @ViewBuilder
    private var dashboardTab: some View {
        if let home = homeKitManager.selectedHome {
            RealHomeDashboard(home: home)
        } else {
            DemoDashboardView()
        }
    }
}

// MARK: - Loading

private struct LoadingView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                    .scaleEffect(pulse ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                Text("Connecting to HomeKit…")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Permission Denied

private struct PermissionDeniedView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                Text("HomeKit Access Denied")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Enable HomeKit access in Settings to control your home.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 40)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }
}

// MARK: - Real HomeKit Dashboard

private struct RealHomeDashboard: View {
    let home: HMHome
    @StateObject private var viewModel: HomeViewModel

    init(home: HMHome) {
        self.home = home
        _viewModel = StateObject(wrappedValue: HomeViewModel(home: home))
    }

    var body: some View {
        DashboardView(viewModel: viewModel)
    }
}
