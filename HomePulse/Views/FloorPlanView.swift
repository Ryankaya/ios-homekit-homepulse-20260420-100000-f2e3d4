import SwiftUI

struct FloorPlanView: View {
    @EnvironmentObject private var vm: FloorPlanViewModel
    @State private var showAddRoom = false
    @State private var roomToDelete: FloorRoom?
    @State private var activeDevice: ActiveDevice?

    @GestureState private var dragDelta: CGSize  = .zero
    @GestureState private var pinchFactor: CGFloat = 1.0

    private var effectiveScale: CGFloat  { (vm.scale * pinchFactor).clamped(0.28...5.0) }
    private var effectiveOffset: CGSize  {
        CGSize(width:  vm.panOffset.width  + dragDelta.width,
               height: vm.panOffset.height + dragDelta.height)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
                GeometryReader { geo in
                    ZStack {
                        floorCanvas(size: geo.size)
                        accessoryLayer(size: geo.size)
                    }
                    .gesture(panGesture)
                    .simultaneousGesture(zoomGesture)
                    .onTapGesture(count: 2) { vm.resetCamera() }
                }
                cameraControls
                legend
            }
            .navigationTitle("Floor Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.08, green: 0.08, blue: 0.12), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        if vm.isRealHome {
                            Button { vm.refreshFromHomeKit() } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        Button { showAddRoom = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Double-tap to reset")
                        .font(.caption2).foregroundStyle(.white.opacity(0.30))
                }
            }
        }
        .sheet(isPresented: $showAddRoom) {
            AddRoomSheet(vm: vm) { vm.addRoom($0) }
        }
        .sheet(item: $activeDevice) { device in
            deviceSheet(for: device)
        }
        .confirmationDialog(
            "Delete \"\(roomToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Room", role: .destructive) {
                if let r = roomToDelete { vm.deleteRoom(id: r.id) }
                roomToDelete = nil
            }
            Button("Cancel", role: .cancel) { roomToDelete = nil }
        }
    }

    // MARK: - Device Sheet Routing

    @ViewBuilder
    private func deviceSheet(for device: ActiveDevice) -> some View {
        let room = vm.rooms.first { $0.id == device.roomID }
        if let idx = vm.rooms.firstIndex(where: { $0.id == device.roomID }),
           let accIdx = vm.rooms[idx].accessories.firstIndex(where: { $0.id == device.accID }) {

            let acc = vm.rooms[idx].accessories[accIdx]
            let roomName = room?.name ?? ""

            let onUpdate: (FloorAccessory) -> Void = { updated in
                vm.rooms[idx].accessories[accIdx] = updated
                vm.bridgeToHomeKit(vm.rooms[idx], updated)
            }
            switch acc.category {
            case .lightbulb:
                LightSheet(
                    accessory: bindingFor(roomIdx: idx, accIdx: accIdx),
                    roomName: roomName,
                    onUpdate: onUpdate
                )
            case .thermostat:
                ThermostatSheet(
                    accessory: bindingFor(roomIdx: idx, accIdx: accIdx),
                    roomName: roomName,
                    onUpdate: onUpdate
                )
            case .camera, .doorbell:
                CameraSheet(
                    accessory: bindingFor(roomIdx: idx, accIdx: accIdx),
                    roomName: roomName,
                    onUpdate: onUpdate
                )
            default:
                GenericDeviceSheet(
                    accessory: bindingFor(roomIdx: idx, accIdx: accIdx),
                    roomName: roomName,
                    onUpdate: onUpdate
                )
            }
        }
    }

    private func bindingFor(roomIdx: Int, accIdx: Int) -> Binding<FloorAccessory> {
        Binding(
            get: { vm.rooms[roomIdx].accessories[accIdx] },
            set: { vm.rooms[roomIdx].accessories[accIdx] = $0 }
        )
    }

    // MARK: - Canvas

    private func floorCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            var t = CGAffineTransform(scaleX: effectiveScale, y: effectiveScale)
            t.tx = effectiveOffset.width
            t.ty = effectiveOffset.height
            context.concatenate(t)

            drawGrid(&context, size: size)

            let sorted = vm.rooms.sorted { $0.gridX + $0.gridY < $1.gridX + $1.gridY }
            for room in sorted {
                // Light glows (behind floor so they bleed up through floor edge)
                drawLightGlows(&context, room: room, size: size)
                drawRoom(&context, room: room, size: size)
                drawFurniture(&context, room: room, size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Accessory Overlay

    private func accessoryLayer(size: CGSize) -> some View {
        ForEach(vm.rooms) { room in
            ForEach(room.accessories) { acc in
                let base   = vm.accessoryScreenPos(room: room, acc: acc, in: size)
                let screen = CGPoint(
                    x: base.x * effectiveScale + effectiveOffset.width,
                    y: base.y * effectiveScale + effectiveOffset.height
                )
                FloorAccessoryMarker(accessory: acc) {
                    handleTap(acc: acc, room: room)
                }
                .position(screen)
            }
        }
    }

    private func handleTap(acc: FloorAccessory, room: FloorRoom) {
        // Lights: toggle immediately AND open sheet on longer interaction
        // Camera/Thermostat: always open sheet
        switch acc.category {
        case .lightbulb:
            withAnimation(.spring(response: 0.25)) {
                vm.toggleAccessory(id: acc.id)
            }
        default:
            activeDevice = ActiveDevice(roomID: room.id, accID: acc.id)
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragDelta) { v, state, _ in state = v.translation }
            .onEnded { v in
                vm.panOffset.width  += v.translation.width
                vm.panOffset.height += v.translation.height
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchFactor) { v, state, _ in state = v }
            .onEnded { v in vm.scale = (vm.scale * v).clamped(0.28...5.0) }
    }

    // MARK: - Controls

    private var cameraControls: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    camBtn("plus.magnifyingglass")  { vm.scale = min(5.0, vm.scale * 1.30) }
                    camBtn("minus.magnifyingglass") { vm.scale = max(0.28, vm.scale / 1.30) }
                    Divider().frame(width: 32).overlay(Color.white.opacity(0.2))
                    camBtn("scope") { vm.resetCamera() }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.trailing, 16)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private func camBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(vm.rooms) { room in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(room.floorColor)
                                .frame(width: 12, height: 12)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                            Text(room.name)
                                .font(.caption2).foregroundStyle(.white.opacity(0.75))
                        }
                        .onLongPressGesture { roomToDelete = room }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                VStack(spacing: 2) {
                    let on  = vm.rooms.flatMap(\.accessories).filter(\.isPowered).count
                    let all = vm.rooms.flatMap(\.accessories).count
                    Text("\(on)/\(all)")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("devices on").font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    // MARK: - Canvas: Grid

    private func drawGrid(_ ctx: inout GraphicsContext, size: CGSize) {
        let c = Color.white.opacity(0.035)
        for i in stride(from: 0, through: 22, by: 1) {
            let f = CGFloat(i)
            var h = Path(); h.move(to: vm.iso(f, 0, in: size)); h.addLine(to: vm.iso(f, 18, in: size))
            var v = Path(); v.move(to: vm.iso(0, f, in: size)); v.addLine(to: vm.iso(18, f, in: size))
            ctx.stroke(h, with: .color(c), lineWidth: 0.5)
            ctx.stroke(v, with: .color(c), lineWidth: 0.5)
        }
    }

    // MARK: - Canvas: Light Glows

    private func drawLightGlows(_ ctx: inout GraphicsContext, room: FloorRoom, size: CGSize) {
        for acc in room.accessories where acc.category == .lightbulb && acc.isPowered {
            let center = vm.accessoryScreenPos(room: room, acc: acc, in: size)
            let radius = vm.tileW * 2.2 * CGFloat(acc.brightness / 100)
            let color  = colorForKelvin(acc.colorTemperature)
            let grad = Gradient(colors: [color.opacity(0.38 * Double(acc.brightness / 100)), .clear])
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.55,
                                       width: radius * 2, height: radius * 1.1)),
                with: .radialGradient(grad, center: center,
                                      startRadius: 0, endRadius: radius)
            )
        }
    }

    // MARK: - Canvas: Room

    private func drawRoom(_ ctx: inout GraphicsContext, room: FloorRoom, size: CGSize) {
        let tl = vm.iso(room.gridX,              room.gridY,              in: size)
        let tr = vm.iso(room.gridX + room.gridW, room.gridY,              in: size)
        let br = vm.iso(room.gridX + room.gridW, room.gridY + room.gridH, in: size)
        let bl = vm.iso(room.gridX,              room.gridY + room.gridH, in: size)
        let wh = vm.wallH

        // Right (east) wall
        drawQuad(&ctx,
                 [tr, br, CGPoint(x: br.x, y: br.y + wh), CGPoint(x: tr.x, y: tr.y + wh)],
                 fill: room.floorColor.opacity(0.48), stroke: .black.opacity(0.13))

        // Front (south) wall
        drawQuad(&ctx,
                 [bl, br, CGPoint(x: br.x, y: br.y + wh), CGPoint(x: bl.x, y: bl.y + wh)],
                 fill: room.floorColor.opacity(0.33), stroke: .black.opacity(0.13))

        // Floor
        drawQuad(&ctx, [tl, tr, br, bl], fill: room.floorColor, stroke: .black.opacity(0.20))

        // Subtle diagonal floor texture
        let stripe = Color.black.opacity(0.035)
        for s in stride(from: 0.0, through: room.gridW + room.gridH, by: 1.0) {
            let x0 = min(s, room.gridW);  let y0 = max(0, s - room.gridW)
            let x1 = max(0, s - room.gridH); let y1 = min(s, room.gridH)
            var p = Path()
            p.move(to: vm.iso(room.gridX + x0, room.gridY + y0, in: size))
            p.addLine(to: vm.iso(room.gridX + x1, room.gridY + y1, in: size))
            ctx.stroke(p, with: .color(stripe), lineWidth: 0.5)
        }

        // Room label + on-count
        let cx = vm.iso(room.gridX + room.gridW * 0.5, room.gridY + room.gridH * 0.48, in: size)
        ctx.draw(Text(room.name).font(.system(size: 11, weight: .semibold)).foregroundColor(.black.opacity(0.50)), at: cx)
        let on = room.accessories.filter(\.isPowered).count
        if on > 0 {
            ctx.draw(Text("\(on) on").font(.system(size: 9)).foregroundColor(.black.opacity(0.35)),
                     at: CGPoint(x: cx.x, y: cx.y + 13))
        }

        // Wall highlight line (top edge)
        var topLine = Path()
        topLine.move(to: tl); topLine.addLine(to: tr)
        ctx.stroke(topLine, with: .color(.white.opacity(0.20)), lineWidth: 1)
    }

    // MARK: - Canvas: Furniture

    private func drawFurniture(_ ctx: inout GraphicsContext, room: FloorRoom, size: CGSize) {
        for piece in room.furniture {
            let ftl = vm.iso(piece.gx,            piece.gy,            in: size)
            let ftr = vm.iso(piece.gx + piece.gw, piece.gy,            in: size)
            let fbr = vm.iso(piece.gx + piece.gw, piece.gy + piece.gh, in: size)
            let fbl = vm.iso(piece.gx,            piece.gy + piece.gh, in: size)
            drawQuad(&ctx, [ftl, ftr, fbr, fbl], fill: piece.color, stroke: .black.opacity(0.18))
        }
    }

    // MARK: - Canvas Helpers

    private func drawQuad(_ ctx: inout GraphicsContext, _ pts: [CGPoint], fill: Color, stroke: Color) {
        var p = Path()
        p.move(to: pts[0])
        pts.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath()
        ctx.fill(p, with: .color(fill))
        ctx.stroke(p, with: .color(stroke), lineWidth: 1)
    }

    private func colorForKelvin(_ k: Float) -> Color {
        if k < 3000 { return Color(red: 1.0, green: 0.75, blue: 0.40) }
        if k < 4500 { return Color(red: 1.0, green: 0.92, blue: 0.70) }
        return Color(red: 0.88, green: 0.94, blue: 1.00)
    }
}

// MARK: - Active Device

private struct ActiveDevice: Identifiable {
    let id = UUID()
    let roomID: UUID
    let accID: UUID
}

// MARK: - Accessory Marker

private struct FloorAccessoryMarker: View {
    let accessory: FloorAccessory
    let onTap: () -> Void

    @State private var showLabel = false
    @State private var pressed = false

    var markerColor: Color {
        accessory.isPowered ? accessory.category.color : Color(white: 0.30)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Label popup
            if showLabel {
                VStack(spacing: 2) {
                    Text(accessory.name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                    if accessory.category == .lightbulb && accessory.isPowered {
                        Text("\(Int(accessory.brightness))%")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.7))
                    } else if accessory.category == .thermostat {
                        Text(String(format: "%.0f°F", Double(accessory.targetTemp) * 9.0 / 5.0 + 32.0))
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color.black.opacity(0.80))
                .clipShape(Capsule())
                .offset(y: -36)
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
            }

            // Marker button
            Button {
                onTap()
                withAnimation(.spring(response: 0.2)) { showLabel = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.25)) { showLabel = false }
                }
            } label: {
                ZStack {
                    // Glow
                    if accessory.isPowered {
                        Circle()
                            .fill(markerColor.opacity(0.30))
                            .frame(width: 44, height: 44)
                            .blur(radius: 6)
                    }
                    // Badge dot for motion
                    if accessory.hasMotionAlert && accessory.isPowered {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
                            .offset(x: 11, y: -11)
                    }
                    // Body
                    Circle()
                        .fill(markerColor)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white.opacity(accessory.isPowered ? 0.35 : 0.15), lineWidth: 1.5))
                        .shadow(color: accessory.isPowered ? markerColor.opacity(0.70) : .clear, radius: 7)
                    // Icon
                    Image(systemName: accessory.category.systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(pressed ? 0.88 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.easeIn(duration: 0.1))  { pressed = true  } }
                    .onEnded   { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
            )
            .contextMenu {
                Button(accessory.isPowered ? "Turn Off" : "Turn On") { onTap() }
                Button("Details") {
                    withAnimation { showLabel = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showLabel = false }
                    }
                }
            }
        }
    }
}

// MARK: - Generic Device Sheet

struct GenericDeviceSheet: View {
    @Binding var accessory: FloorAccessory
    let roomName: String
    let onUpdate: (FloorAccessory) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(accessory.category.color.opacity(accessory.isPowered ? 0.20 : 0.06))
                            .frame(width: 110, height: 110)
                        Image(systemName: accessory.category.systemImage)
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(accessory.isPowered ? accessory.category.color : .gray)
                    }
                    .padding(.top, 24)

                    Toggle(isOn: Binding(
                        get: { accessory.isPowered },
                        set: { v in accessory.isPowered = v; onUpdate(accessory) }
                    )) {
                        Label(accessory.isPowered ? "On" : "Off", systemImage: "power")
                            .foregroundStyle(.white)
                    }
                    .tint(accessory.category.color)
                    .padding(18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle(accessory.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(roomName).font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }
}
