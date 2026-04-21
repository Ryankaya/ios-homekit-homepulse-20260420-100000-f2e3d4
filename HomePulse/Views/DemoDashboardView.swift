import SwiftUI

// Shown when no HomeKit homes are configured — gives a full interactive demo.
struct DemoDashboardView: View {
    @StateObject private var vm = DemoHomeViewModel()
    @State private var selectedAccessory: DemoAccessory?

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        demoBanner
                        headerSection
                        sceneSection
                        statsSection
                        roomsSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(vm.home.name)
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedAccessory) { acc in
                DemoAccessoryDetailSheet(vm: DemoAccessoryViewModel(accessory: acc, parentVM: vm))
            }
        }
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text("Demo Mode — No HomeKit homes found. Add homes via the Home app.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 16) {
            PulseRingView(
                ratio: vm.healthRatio,
                reachable: vm.reachableCount,
                total: vm.totalCount
            )
            Text("Home Health")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .tracking(2)
                .textCase(.uppercase)
        }
    }

    private var sceneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Scenes")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.home.scenes) { scene in
                        DemoSceneButton(scene: scene, isActive: vm.activeScene == scene.id) {
                            vm.activateScene(scene)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatPillView(icon: "house.fill",            value: "\(vm.totalCount)",     label: "Accessories", color: .orange)
            StatPillView(icon: "checkmark.circle.fill",  value: "\(vm.reachableCount)", label: "Online",      color: .green)
            StatPillView(icon: "theatermask.and.paintbrush.fill", value: "\(vm.home.scenes.count)", label: "Scenes", color: .purple)
        }
        .padding(.horizontal, 16)
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Rooms")
            ForEach(vm.rooms) { room in
                DemoRoomSectionView(
                    room: room,
                    accessories: vm.accessories(in: room),
                    onSelect: { selectedAccessory = $0 }
                )
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
    }
}

// MARK: - Demo ViewModel

final class DemoHomeViewModel: ObservableObject {
    @Published var home: DemoHome = DemoHome.sample

    var rooms: [DemoRoom] { home.rooms }
    var totalCount: Int { home.rooms.flatMap(\.accessories).count }
    var reachableCount: Int { home.rooms.flatMap(\.accessories).filter(\.isReachable).count }
    var healthRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(reachableCount) / Double(totalCount)
    }
    @Published var activeScene: UUID?

    func accessories(in room: DemoRoom) -> [DemoAccessory] {
        home.rooms.first { $0.id == room.id }?.accessories ?? []
    }

    func activateScene(_ scene: DemoScene) {
        activeScene = scene.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.activeScene = nil
        }
    }

    func toggle(accessory: DemoAccessory) {
        for ri in home.rooms.indices {
            for ai in home.rooms[ri].accessories.indices {
                if home.rooms[ri].accessories[ai].id == accessory.id {
                    home.rooms[ri].accessories[ai].isPowered.toggle()
                    return
                }
            }
        }
    }

    func setBrightness(_ value: Float, for accessory: DemoAccessory) {
        for ri in home.rooms.indices {
            for ai in home.rooms[ri].accessories.indices {
                if home.rooms[ri].accessories[ai].id == accessory.id {
                    home.rooms[ri].accessories[ai].brightness = value
                    return
                }
            }
        }
    }

    func setTemperature(_ value: Float, for accessory: DemoAccessory) {
        for ri in home.rooms.indices {
            for ai in home.rooms[ri].accessories.indices {
                if home.rooms[ri].accessories[ai].id == accessory.id {
                    home.rooms[ri].accessories[ai].temperature = value
                    return
                }
            }
        }
    }
}

// MARK: - Demo Room Section

struct DemoRoomSectionView: View {
    let room: DemoRoom
    let accessories: [DemoAccessory]
    let onSelect: (DemoAccessory) -> Void
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { isExpanded.toggle() } label: {
                HStack {
                    Text(room.name).font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text("\(accessories.count)").font(.caption).foregroundStyle(.white.opacity(0.5))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 14)
            }
            if isExpanded {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(accessories) { accessory in
                        DemoAccessoryCard(accessory: accessory, onTap: { onSelect(accessory) })
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isExpanded)
    }
}

// MARK: - Demo Accessory Card

struct DemoAccessoryCard: View {
    let accessory: DemoAccessory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: accessory.category.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accessory.isPowered ? accessory.category.color : .gray)
                    Spacer()
                }
                Text(accessory.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let brightness = accessory.brightness, accessory.isPowered {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                            Capsule()
                                .fill(accessory.category.color.opacity(0.8))
                                .frame(width: geo.size.width * CGFloat(brightness / 100), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accessory.isPowered ? accessory.category.color.opacity(0.13) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(accessory.isPowered ? accessory.category.color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Demo Scene Button

struct DemoSceneButton: View {
    let scene: DemoScene
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scene.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? .black : .orange)
                Text(scene.name)
                    .font(.caption2)
                    .foregroundStyle(isActive ? .black.opacity(0.8) : .white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 80, height: 72)
            .background(isActive ? Color.orange : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
        }
        .animation(.spring(response: 0.3), value: isActive)
    }
}

// MARK: - Demo Accessory Detail

final class DemoAccessoryViewModel: ObservableObject {
    @Published var accessory: DemoAccessory
    let parentVM: DemoHomeViewModel

    init(accessory: DemoAccessory, parentVM: DemoHomeViewModel) {
        self.accessory = accessory
        self.parentVM = parentVM
    }

    func togglePower() {
        accessory.isPowered.toggle()
        parentVM.toggle(accessory: accessory)
    }

    func setBrightness(_ v: Float) {
        accessory.brightness = v
        parentVM.setBrightness(v, for: accessory)
    }

    func setTemperature(_ v: Float) {
        accessory.temperature = v
        parentVM.setTemperature(v, for: accessory)
    }
}

struct DemoAccessoryDetailSheet: View {
    @ObservedObject var vm: DemoAccessoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        iconHeader
                        controlsSection
                        infoSection
                    }
                    .padding()
                }
            }
            .navigationTitle(vm.accessory.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.orange)
                }
            }
        }
    }

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(vm.accessory.category.color.opacity(vm.accessory.isPowered ? 0.2 : 0.06))
                .frame(width: 110, height: 110)
            Image(systemName: vm.accessory.category.systemImage)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(vm.accessory.isPowered ? vm.accessory.category.color : .gray)
        }
        .padding(.top, 8)
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            controlRow {
                Toggle(isOn: Binding(get: { vm.accessory.isPowered }, set: { _ in vm.togglePower() })) {
                    Label("Power", systemImage: "power").foregroundStyle(.white)
                }
                .tint(vm.accessory.category.color)
            }

            if vm.accessory.brightness != nil {
                controlRow {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Brightness  \(Int(vm.accessory.brightness ?? 0))%", systemImage: "sun.max.fill")
                            .foregroundStyle(.white).font(.subheadline)
                        Slider(
                            value: Binding(get: { Double(vm.accessory.brightness ?? 0) }, set: { vm.setBrightness(Float($0)) }),
                            in: 0...100, step: 5
                        )
                        .tint(vm.accessory.category.color)
                        .disabled(!vm.accessory.isPowered)
                    }
                }
            }

            if vm.accessory.temperature != nil {
                controlRow {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Temperature  \(Int(vm.accessory.temperature ?? 0))°C", systemImage: "thermometer")
                            .foregroundStyle(.white).font(.subheadline)
                        Slider(
                            value: Binding(get: { Double(vm.accessory.temperature ?? 20) }, set: { vm.setTemperature(Float($0)) }),
                            in: 16...30, step: 0.5
                        )
                        .tint(.orange)
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").font(.headline).foregroundStyle(.white.opacity(0.7))
            infoRow(label: "Category", value: vm.accessory.category.rawValue.capitalized)
            infoRow(label: "Status", value: vm.accessory.isPowered ? "On" : "Off")
            infoRow(label: "Reachable", value: vm.accessory.isReachable ? "Yes" : "No")
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
    }

    private func controlRow<C: View>(@ViewBuilder content: () -> C) -> some View {
        content().padding(16).background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
