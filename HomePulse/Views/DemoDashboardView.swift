import SwiftUI

// Dashboard view — uses the shared FloorPlanViewModel so state is
// always identical to what the Floor Plan tab shows (and vice versa).
struct DemoDashboardView: View {
    @EnvironmentObject var floorPlan: FloorPlanViewModel
    @State private var activeDevice: DashActiveDevice?

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
            .navigationTitle(floorPlan.homeName)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.10), for: .navigationBar)
        }
        // Route to the correct sheet based on device category
        .sheet(item: $activeDevice) { device in
            deviceSheet(for: device)
        }
    }

    // MARK: - Device Sheet Routing

    @ViewBuilder
    private func deviceSheet(for device: DashActiveDevice) -> some View {
        if let ri = floorPlan.rooms.firstIndex(where: { $0.id == device.roomID }),
           let ai = floorPlan.rooms[ri].accessories.firstIndex(where: { $0.id == device.accID }) {

            let acc      = floorPlan.rooms[ri].accessories[ai]
            let roomName = floorPlan.rooms[ri].name
            let binding  = Binding(
                get:  { floorPlan.rooms[ri].accessories[ai] },
                set:  { floorPlan.rooms[ri].accessories[ai] = $0 }
            )
            let onUpdate: (FloorAccessory) -> Void = { updated in
                floorPlan.rooms[ri].accessories[ai] = updated
                floorPlan.bridgeToHomeKit(floorPlan.rooms[ri], updated)
            }

            switch acc.category {
            case .lightbulb:
                LightSheet(accessory: binding, roomName: roomName, onUpdate: onUpdate)
            case .thermostat:
                ThermostatSheet(accessory: binding, roomName: roomName, onUpdate: onUpdate)
            case .camera, .doorbell:
                CameraSheet(accessory: binding, roomName: roomName, onUpdate: onUpdate)
            default:
                GenericDeviceSheet(accessory: binding, roomName: roomName, onUpdate: onUpdate)
            }
        }
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            Text("Demo Mode — No HomeKit homes found. Add via the Home app to control real devices.")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
        }
        .padding(12)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    // MARK: - Pulse Ring

    private var headerSection: some View {
        let total     = floorPlan.rooms.flatMap(\.accessories).count
        let reachable = floorPlan.rooms.flatMap(\.accessories).filter(\.isPowered).count
        let ratio     = total > 0 ? Double(reachable) / Double(total) : 0
        return VStack(spacing: 16) {
            PulseRingView(ratio: ratio, reachable: reachable, total: total)
            Text("Home Health")
                .font(.caption).foregroundStyle(.white.opacity(0.45))
                .tracking(2).textCase(.uppercase)
        }
    }

    // MARK: - Scenes

    private var sceneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Scenes")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(floorPlan.scenes) { scene in
                        DashSceneButton(scene: scene) { floorPlan.activateScene(scene) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        let total     = floorPlan.rooms.flatMap(\.accessories).count
        let reachable = floorPlan.rooms.flatMap(\.accessories).filter(\.isPowered).count
        return HStack(spacing: 12) {
            StatPillView(icon: "house.fill",             value: "\(total)",      label: "Accessories", color: .orange)
            StatPillView(icon: "checkmark.circle.fill",  value: "\(reachable)",  label: "On",          color: .green)
            StatPillView(icon: "theatermask.and.paintbrush.fill",
                         value: "\(floorPlan.scenes.count)", label: "Scenes",    color: .purple)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Rooms")
            ForEach(floorPlan.rooms.indices, id: \.self) { ri in
                DashRoomSection(
                    room: floorPlan.rooms[ri],
                    onTap: { acc in handleTap(acc: acc, roomIdx: ri) }
                )
            }
        }
    }

    private func handleTap(acc: FloorAccessory, roomIdx: Int) {
        switch acc.category {
        case .lightbulb:
            withAnimation(.spring(response: 0.25)) { floorPlan.toggleAccessory(id: acc.id) }
        default:
            activeDevice = DashActiveDevice(roomID: floorPlan.rooms[roomIdx].id, accID: acc.id)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 16)
    }
}

// MARK: - Active Device

struct DashActiveDevice: Identifiable {
    let id     = UUID()
    let roomID: UUID
    let accID:  UUID
}

// MARK: - Scene Button

private struct DashSceneButton: View {
    let scene: FloorScene
    let action: () -> Void
    @State private var tapped = false

    var body: some View {
        Button {
            action()
            withAnimation(.spring(response: 0.2)) { tapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.3)) { tapped = false }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: scene.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(tapped ? .black : .orange)
                Text(scene.name)
                    .font(.caption2)
                    .foregroundStyle(tapped ? .black.opacity(0.8) : .white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 84, height: 74)
            .background(tapped ? Color.orange : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: tapped)
    }
}

// MARK: - Room Section

private struct DashRoomSection: View {
    let room: FloorRoom
    let onTap: (FloorAccessory) -> Void
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { expanded.toggle() } } label: {
                HStack {
                    // Room color swatch
                    RoundedRectangle(cornerRadius: 4).fill(room.floorColor)
                        .frame(width: 14, height: 14)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                    Text(room.name).font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    // On-count badge
                    let on = room.accessories.filter(\.isPowered).count
                    if on > 0 {
                        Text("\(on) on")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text("\(room.accessories.count)")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.white.opacity(0.35))
                }
                .padding(.vertical, 14)
            }

            if expanded {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(room.accessories) { acc in
                        DashAccessoryCard(accessory: acc, onTap: { onTap(acc) })
                    }
                }
                .padding(.top, 4).padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Accessory Card

private struct DashAccessoryCard: View {
    let accessory: FloorAccessory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: accessory.category.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accessory.isPowered ? accessory.category.color : .gray)
                    Spacer()
                    // For thermostat show temp; for camera show dot
                    if accessory.category == .thermostat {
                        Text(String(format: "%.0f°", accessory.targetTemp))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(accessory.isPowered ? .orange : .gray)
                    } else if accessory.category == .camera && accessory.isPowered {
                        Circle().fill(.green).frame(width: 7, height: 7)
                    } else if accessory.hasMotionAlert && accessory.isPowered {
                        Circle().fill(.red).frame(width: 7, height: 7)
                    }
                }

                Text(accessory.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2).multilineTextAlignment(.leading)

                // Brightness bar for lights
                if accessory.category == .lightbulb && accessory.isPowered {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.10)).frame(height: 3)
                            Capsule()
                                .fill(accessory.category.color.opacity(0.85))
                                .frame(width: geo.size.width * CGFloat(accessory.brightness / 100), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .animation(.spring(response: 0.4), value: accessory.brightness)
                }

                // Temperature display for thermostat
                if accessory.category == .thermostat {
                    HStack(spacing: 4) {
                        Image(systemName: accessory.thermostatMode.icon)
                            .font(.system(size: 9))
                        Text(accessory.thermostatMode.label)
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(accessory.isPowered ? accessory.thermostatMode.color : .gray)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accessory.isPowered
                          ? accessory.category.color.opacity(0.13)
                          : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(accessory.isPowered
                                    ? accessory.category.color.opacity(0.30)
                                    : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.3), value: accessory.isPowered)
        }
        .buttonStyle(.plain)
    }
}

