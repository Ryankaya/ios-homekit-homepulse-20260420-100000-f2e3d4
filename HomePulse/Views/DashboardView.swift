import SwiftUI
import HomeKit

struct DashboardView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var homeKitManager: HomeKitManager
    @State private var selectedAccessory: HMAccessory?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        sceneSection
                        statsSection
                        roomsSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(viewModel.home.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                if homeKitManager.homes.count > 1 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        homePickerMenu
                    }
                }
            }
            .sheet(item: $selectedAccessory) { acc in
                AccessoryDetailSheet(accessory: acc)
            }
            .onAppear { viewModel.readAllCharacteristics() }
            .refreshable { viewModel.refresh() }
        }
    }

    // MARK: - Header (Pulse Ring)

    private var headerSection: some View {
        VStack(spacing: 16) {
            PulseRingView(
                ratio: viewModel.healthRatio,
                reachable: viewModel.reachableCount,
                total: viewModel.totalCount
            )
            Text("Home Health")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .tracking(2)
                .textCase(.uppercase)
        }
        .padding(.top, 8)
    }

    // MARK: - Scenes

    private var sceneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Scenes")
            if viewModel.scenes.isEmpty {
                Text("No scenes configured")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.scenes, id: \.uniqueIdentifier) { scene in
                            SceneButton(scene: scene, isExecuting: viewModel.isExecutingScene) {
                                viewModel.activateScene(scene)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatPillView(icon: "house.fill",         value: "\(viewModel.totalCount)",     label: "Accessories", color: .orange)
            StatPillView(icon: "checkmark.circle.fill",value: "\(viewModel.reachableCount)",label: "Online",      color: .green)
            StatPillView(icon: "theatermask.and.paintbrush.fill", value: "\(viewModel.scenes.count)", label: "Scenes", color: .purple)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Rooms")
            ForEach(viewModel.rooms, id: \.uniqueIdentifier) { room in
                RoomSectionView(
                    room: room,
                    accessories: viewModel.accessories(in: room),
                    onSelectAccessory: { selectedAccessory = $0 }
                )
            }
            if !viewModel.unassignedAccessories.isEmpty {
                UnassignedSectionView(
                    accessories: viewModel.unassignedAccessories,
                    onSelectAccessory: { selectedAccessory = $0 }
                )
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
    }

    private var homePickerMenu: some View {
        Menu {
            ForEach(homeKitManager.homes, id: \.uniqueIdentifier) { home in
                Button(home.name) { homeKitManager.selectHome(home) }
            }
        } label: {
            Image(systemName: "house.and.flag.fill")
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Scene Button

private struct SceneButton: View {
    let scene: HMActionSet
    let isExecuting: Bool
    let action: () -> Void

    private var icon: String {
        switch scene.actionSetType {
        case HMActionSetTypeWakeUp:          return "sunrise.fill"
        case HMActionSetTypeSleep:           return "moon.fill"
        case HMActionSetTypeHomeDeparture:   return "door.right.hand.open"
        case HMActionSetTypeHomeArrival:     return "house.fill"
        default:                             return "theatermask.and.paintbrush.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                Text(scene.name)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 80, height: 72)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
        }
        .disabled(isExecuting)
        .opacity(isExecuting ? 0.5 : 1)
    }
}
