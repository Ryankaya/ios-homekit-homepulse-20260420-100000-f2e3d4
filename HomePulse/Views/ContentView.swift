import SwiftUI
import HomeKit

struct ContentView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager

    var body: some View {
        Group {
            if homeKitManager.isLoading {
                LoadingView()
            } else if homeKitManager.authorizationStatus == .restricted {
                PermissionDeniedView()
            } else if let home = homeKitManager.selectedHome {
                RealHomeDashboard(home: home)
            } else {
                DemoDashboardView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: homeKitManager.isLoading)
    }
}

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
