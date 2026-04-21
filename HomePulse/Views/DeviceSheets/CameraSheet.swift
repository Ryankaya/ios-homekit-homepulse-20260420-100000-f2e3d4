import SwiftUI

struct CameraSheet: View {
    @Binding var accessory: FloorAccessory
    let roomName: String
    let onUpdate: (FloorAccessory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isNightVision = true
    @State private var scanLine: CGFloat = 0
    @State private var motionBoxOpacity: Double = 0
    @State private var showSnapshotFlash = false
    @State private var motionTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                cameraFeedView
                controlBar
            }
        }
        .onAppear(perform: startAnimations)
        .onDisappear { motionTimer?.invalidate() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(accessory.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(roomName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if accessory.isRecording {
                HStack(spacing: 5) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                        .opacity(scanLine > 0.5 ? 1 : 0.3) // blink using scanLine anim
                    Text("REC").font(.caption.bold()).foregroundStyle(.red)
                }
            }
            Button("Done") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.leading, 16)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(white: 0.07))
    }

    // MARK: - Camera Feed

    private var cameraFeedView: some View {
        GeometryReader { geo in
            ZStack {
                // Simulated room perspective
                Canvas { ctx, size in
                    drawSimulatedFeed(&ctx, size: size, nightVision: isNightVision)
                }

                // Scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, (isNightVision ? Color.green : Color.white).opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 4)
                    .offset(y: scanLine * geo.size.height - geo.size.height / 2)

                // Motion detection box
                if accessory.hasMotionAlert {
                    MotionDetectionBox()
                        .opacity(motionBoxOpacity)
                        .frame(width: geo.size.width * 0.35, height: geo.size.height * 0.45)
                        .offset(x: -geo.size.width * 0.10, y: geo.size.height * 0.05)
                }

                // Snapshot flash
                if showSnapshotFlash {
                    Color.white.ignoresSafeArea()
                        .transition(.opacity)
                }

                // HUD overlays
                VStack {
                    HStack {
                        // Timestamp
                        Text(currentTimestamp())
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                        // Status
                        Text(accessory.isPowered ? "LIVE" : "OFFLINE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accessory.isPowered ? .green : .red)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .padding(10)
                    Spacer()
                    if accessory.hasMotionAlert {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text("Motion Detected")
                            Spacer()
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                    }
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(16)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                camButton(icon: "moon.fill", label: "Night Vision",
                          active: isNightVision, color: .green) {
                    isNightVision.toggle()
                }
                camButton(icon: "camera.fill", label: "Snapshot",
                          active: false, color: .white) {
                    takeSnapshot()
                }
                camButton(icon: "record.circle", label: accessory.isRecording ? "Stop" : "Record",
                          active: accessory.isRecording, color: .red) {
                    accessory.isRecording.toggle()
                    onUpdate(accessory)
                }
                camButton(icon: "power", label: accessory.isPowered ? "Online" : "Offline",
                          active: accessory.isPowered, color: .orange) {
                    accessory.isPowered.toggle()
                    onUpdate(accessory)
                }
            }

            // Motion sensitivity
            VStack(alignment: .leading, spacing: 6) {
                Label("Motion Alerts", systemImage: "figure.walk")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.65))
                Toggle("", isOn: Binding(
                    get: { accessory.hasMotionAlert },
                    set: { v in accessory.hasMotionAlert = v; onUpdate(accessory) }
                ))
                .labelsHidden()
                .tint(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(20)
        .background(Color(white: 0.07))
    }

    private func camButton(icon: String, label: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(active ? color.opacity(0.2) : Color.white.opacity(0.07))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(active ? color : .white.opacity(0.6))
                }
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Canvas: Simulated Feed

    private func drawSimulatedFeed(_ ctx: inout GraphicsContext, size: CGSize, nightVision: Bool) {
        let bg = nightVision
            ? Color(red: 0.02, green: 0.08, blue: 0.02)
            : Color(red: 0.06, green: 0.06, blue: 0.10)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))

        let lineColor = nightVision
            ? Color.green.opacity(0.12)
            : Color.white.opacity(0.06)

        // Perspective floor lines
        let vanishX = size.width * 0.50
        let vanishY = size.height * 0.42
        let lineCount = 12
        for i in 0...lineCount {
            let t = CGFloat(i) / CGFloat(lineCount)
            let bottomX = t * size.width
            var path = Path()
            path.move(to: CGPoint(x: vanishX, y: vanishY))
            path.addLine(to: CGPoint(x: bottomX, y: size.height))
            ctx.stroke(path, with: .color(lineColor), lineWidth: 0.8)
        }
        // Horizontal floor lines
        for i in 1...6 {
            let y = vanishY + CGFloat(i) / 6.0 * (size.height - vanishY)
            let spread = CGFloat(i) / 6.0 * size.width * 0.5
            var path = Path()
            path.move(to: CGPoint(x: vanishX - spread, y: y))
            path.addLine(to: CGPoint(x: vanishX + spread, y: y))
            ctx.stroke(path, with: .color(lineColor), lineWidth: 0.8)
        }
        // Wall outlines
        let wallColor = nightVision
            ? Color.green.opacity(0.20)
            : Color.white.opacity(0.10)
        var walls = Path()
        walls.move(to: CGPoint(x: 0, y: 0))
        walls.addLine(to: CGPoint(x: 0, y: size.height))
        walls.addLine(to: CGPoint(x: size.width, y: size.height))
        walls.addLine(to: CGPoint(x: size.width, y: 0))
        walls.move(to: CGPoint(x: vanishX - size.width * 0.22, y: vanishY))
        walls.addLine(to: CGPoint(x: vanishX + size.width * 0.22, y: vanishY))
        ctx.stroke(walls, with: .color(wallColor), lineWidth: 1)

        // Noise grain
        if nightVision {
            for _ in 0..<300 {
                let nx = CGFloat.random(in: 0..<size.width)
                let ny = CGFloat.random(in: 0..<size.height)
                let nr = CGFloat.random(in: 0.5...1.5)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: nx, y: ny, width: nr, height: nr)),
                    with: .color(Color.green.opacity(Double.random(in: 0.05...0.20)))
                )
            }
        }
    }

    // MARK: - Helpers

    private func startAnimations() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            scanLine = 1.0
        }
        if accessory.hasMotionAlert {
            motionTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) { motionBoxOpacity = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeOut(duration: 0.5)) { motionBoxOpacity = 0.15 }
                }
            }
        }
    }

    private func takeSnapshot() {
        withAnimation(.easeIn(duration: 0.05)) { showSnapshotFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.35)) { showSnapshotFlash = false }
        }
    }

    private func currentTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - Motion Detection Box

private struct MotionDetectionBox: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.red.opacity(0.85), lineWidth: 1.5)
            VStack {
                HStack {
                    cornerMark(.topLeading)
                    Spacer()
                    cornerMark(.topTrailing)
                }
                Spacer()
                HStack {
                    cornerMark(.bottomLeading)
                    Spacer()
                    cornerMark(.bottomTrailing)
                }
            }
            .padding(4)
        }
    }

    private func cornerMark(_ alignment: Alignment) -> some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: 8, height: 2)
    }
}
