import SwiftUI

struct FloorPlanView: View {
    @StateObject private var vm = FloorPlanViewModel()
    @State private var showAddRoom = false
    @State private var roomToDelete: FloorRoom?

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchFactor: CGFloat = 1.0

    private var effectiveScale: CGFloat {
        (vm.scale * pinchFactor).clamped(0.30...4.5)
    }
    private var effectiveOffset: CGSize {
        CGSize(
            width:  vm.panOffset.width  + dragDelta.width,
            height: vm.panOffset.height + dragDelta.height
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.09, green: 0.09, blue: 0.13).ignoresSafeArea()
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
            .toolbarBackground(Color(red: 0.09, green: 0.09, blue: 0.13), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddRoom = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Double-tap to reset")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .sheet(isPresented: $showAddRoom) {
            AddRoomSheet(vm: vm) { room in vm.addRoom(room) }
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

    // MARK: - Canvas

    private func floorCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            // Build transform: scale about origin, then translate (pan)
            var t = CGAffineTransform(scaleX: effectiveScale, y: effectiveScale)
            t.tx = effectiveOffset.width
            t.ty = effectiveOffset.height
            context.concatenate(t)

            drawGrid(&context, size: size)

            // Painter's order: back rooms first (smallest gx+gy)
            for room in vm.rooms.sorted(by: { $0.gridX + $0.gridY < $1.gridX + $1.gridY }) {
                drawRoom(&context, room: room, size: size)
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
                AccessoryMarker(accessory: acc) {
                    withAnimation(.spring(response: 0.25)) { vm.toggleAccessory(id: acc.id) }
                }
                .position(screen)
            }
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
            .onEnded { v in
                vm.scale = (vm.scale * v).clamped(0.30...4.5)
            }
    }

    // MARK: - Controls

    private var cameraControls: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    camButton("plus.magnifyingglass")   { vm.scale = min(4.5, vm.scale * 1.30) }
                    camButton("minus.magnifyingglass")  { vm.scale = max(0.30, vm.scale / 1.30) }
                    Divider().frame(width: 32).overlay(Color.white.opacity(0.2))
                    camButton("scope")                  { vm.resetCamera() }
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

    private func camButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                // Room legend with long-press delete
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(vm.rooms) { room in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(room.floorColor)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                )
                            Text(room.name)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .onLongPressGesture { roomToDelete = room }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                // Online count badge
                VStack(spacing: 2) {
                    let onCount = vm.rooms.flatMap(\.accessories).filter(\.isPowered).count
                    let allCount = vm.rooms.flatMap(\.accessories).count
                    Text("\(onCount)/\(allCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("devices on")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Canvas Drawing

    private func drawGrid(_ ctx: inout GraphicsContext, size: CGSize) {
        let color = Color.white.opacity(0.04)
        for i in stride(from: 0, through: 18, by: 1) {
            let f = CGFloat(i)
            var h = Path()
            h.move(to: vm.iso(f, 0, in: size))
            h.addLine(to: vm.iso(f, 14, in: size))
            ctx.stroke(h, with: .color(color), lineWidth: 0.5)

            var v = Path()
            v.move(to: vm.iso(0, f, in: size))
            v.addLine(to: vm.iso(14, f, in: size))
            ctx.stroke(v, with: .color(color), lineWidth: 0.5)
        }
    }

    private func drawRoom(_ ctx: inout GraphicsContext, room: FloorRoom, size: CGSize) {
        let tl = vm.iso(room.gridX,              room.gridY,              in: size)
        let tr = vm.iso(room.gridX + room.gridW, room.gridY,              in: size)
        let br = vm.iso(room.gridX + room.gridW, room.gridY + room.gridH, in: size)
        let bl = vm.iso(room.gridX,              room.gridY + room.gridH, in: size)
        let wh = vm.wallH

        // Right wall (east face — darker)
        var rw = Path()
        rw.move(to: tr)
        rw.addLine(to: br)
        rw.addLine(to: CGPoint(x: br.x, y: br.y + wh))
        rw.addLine(to: CGPoint(x: tr.x, y: tr.y + wh))
        rw.closeSubpath()
        ctx.fill(rw, with: .color(room.floorColor.opacity(0.50)))
        ctx.stroke(rw, with: .color(.black.opacity(0.14)), lineWidth: 1)

        // Front wall (south face — darkest)
        var fw = Path()
        fw.move(to: bl)
        fw.addLine(to: br)
        fw.addLine(to: CGPoint(x: br.x, y: br.y + wh))
        fw.addLine(to: CGPoint(x: bl.x, y: bl.y + wh))
        fw.closeSubpath()
        ctx.fill(fw, with: .color(room.floorColor.opacity(0.35)))
        ctx.stroke(fw, with: .color(.black.opacity(0.14)), lineWidth: 1)

        // Floor (top face — brightest)
        var floor = Path()
        floor.move(to: tl)
        floor.addLine(to: tr)
        floor.addLine(to: br)
        floor.addLine(to: bl)
        floor.closeSubpath()
        ctx.fill(floor, with: .color(room.floorColor))
        ctx.stroke(floor, with: .color(.black.opacity(0.18)), lineWidth: 1.5)

        // Floor texture: subtle diagonal lines
        let stripeColor = Color.black.opacity(0.04)
        for s in stride(from: 0.0, through: room.gridW + room.gridH, by: 1.0) {
            let s0x = min(s, room.gridW)
            let s0y = max(0, s - room.gridW)
            let s1x = max(0, s - room.gridH)
            let s1y = min(s, room.gridH)
            let p0 = vm.iso(room.gridX + s0x, room.gridY + s0y, in: size)
            let p1 = vm.iso(room.gridX + s1x, room.gridY + s1y, in: size)
            var stripe = Path()
            stripe.move(to: p0)
            stripe.addLine(to: p1)
            ctx.stroke(stripe, with: .color(stripeColor), lineWidth: 0.5)
        }

        // Room name
        let cx = vm.iso(room.gridX + room.gridW * 0.5, room.gridY + room.gridH * 0.5, in: size)
        ctx.draw(
            Text(room.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.black.opacity(0.55)),
            at: cx
        )

        // Active count badge
        let on = room.accessories.filter(\.isPowered).count
        if on > 0 {
            ctx.draw(
                Text("\(on) on")
                    .font(.system(size: 9))
                    .foregroundColor(.black.opacity(0.38)),
                at: CGPoint(x: cx.x, y: cx.y + 13)
            )
        }
    }
}

// MARK: - Accessory Marker

private struct AccessoryMarker: View {
    let accessory: FloorAccessory
    let onTap: () -> Void

    @State private var showLabel = false

    var body: some View {
        ZStack(alignment: .top) {
            if showLabel {
                Text(accessory.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .offset(y: -28)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            Button {
                onTap()
                showLabel = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut(duration: 0.2)) { showLabel = false }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(accessory.isPowered
                              ? accessory.category.color
                              : Color(white: 0.35))
                        .frame(width: 30, height: 30)
                        .shadow(
                            color: accessory.isPowered ? accessory.category.color.opacity(0.7) : .clear,
                            radius: 7
                        )
                    Image(systemName: accessory.category.systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
