import SwiftUI

struct ThermostatSheet: View {
    @Binding var accessory: FloorAccessory
    let roomName: String
    let onUpdate: (FloorAccessory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var animatedCurrent: Double = 0
    @State private var animatedTarget: Double  = 0

    private let minTemp: Double = 14
    private let maxTemp: Double = 32

    var body: some View {
        NavigationView {
            ZStack {
                thermostatBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        modeSelector
                        tempDial
                        tempAdjustRow
                        fanSection
                        statsRow
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(accessory.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(thermostatBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(roomName).font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedCurrent = Double(accessory.currentTemp)
                animatedTarget  = Double(accessory.targetTemp)
            }
        }
    }

    // MARK: - Background (changes with mode)

    private var thermostatBackground: Color {
        switch accessory.thermostatMode {
        case .heat: return Color(red: 0.12, green: 0.07, blue: 0.03)
        case .cool: return Color(red: 0.03, green: 0.07, blue: 0.14)
        case .auto: return Color(red: 0.05, green: 0.10, blue: 0.07)
        case .off:  return Color(red: 0.08, green: 0.08, blue: 0.08)
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ThermostatMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        accessory.thermostatMode = mode
                    }
                    onUpdate(accessory)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18))
                        Text(mode.label)
                            .font(.caption2)
                    }
                    .foregroundStyle(accessory.thermostatMode == mode ? .black : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accessory.thermostatMode == mode ? mode.color : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Temperature Dial

    private var tempDial: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accessory.thermostatMode.color.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 90,
                        endRadius: 160
                    )
                )
                .frame(width: 300, height: 300)

            // Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(90))

            // Progress arc
            let norm = (animatedTarget - minTemp) / (maxTemp - minTemp)
            Circle()
                .trim(from: 0.15, to: 0.15 + 0.70 * norm)
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(144),
                        endAngle: .degrees(396)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(90))
                .animation(.spring(response: 0.45), value: animatedTarget)

            // Thumb dot
            let angle = 144.0 + 252.0 * norm
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .shadow(color: accessory.thermostatMode.color, radius: 6)
                .offset(y: -110)
                .rotationEffect(.degrees(angle))
                .animation(.spring(response: 0.45), value: animatedTarget)

            // Center
            VStack(spacing: 6) {
                Text(String(format: "%.1f°C", animatedCurrent))
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("Current")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(2)
                    .textCase(.uppercase)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(String(format: "%.1f°C", animatedTarget))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accessory.thermostatMode.color)
                .animation(.spring(response: 0.45), value: animatedTarget)
            }
        }
    }

    private var gradientColors: [Color] {
        switch accessory.thermostatMode {
        case .heat: return [Color(red: 1, green: 0.6, blue: 0.1), .orange, .red]
        case .cool: return [Color(red: 0.3, green: 0.8, blue: 1.0), .blue, Color(red: 0.2, green: 0.4, blue: 0.9)]
        case .auto: return [.green, .teal, .cyan]
        case .off:  return [.gray, .gray.opacity(0.4)]
        }
    }

    // MARK: - +/– Adjustment

    private var tempAdjustRow: some View {
        HStack(spacing: 0) {
            adjustButton(icon: "minus", step: -0.5)
            Spacer()
            VStack(spacing: 2) {
                Text(String(format: "%.1f°C", accessory.targetTemp))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: accessory.targetTemp)
                Text("Target")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(2)
                    .textCase(.uppercase)
            }
            Spacer()
            adjustButton(icon: "plus", step: 0.5)
        }
        .padding(.horizontal, 32)
    }

    private func adjustButton(icon: String, step: Float) -> some View {
        Button {
            let newVal = (accessory.targetTemp + step).clamped(Float(minTemp)...Float(maxTemp))
            accessory.targetTemp = newVal
            withAnimation(.spring(response: 0.3)) { animatedTarget = Double(newVal) }
            onUpdate(accessory)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(accessory.thermostatMode == .off)
        .opacity(accessory.thermostatMode == .off ? 0.4 : 1)
    }

    // MARK: - Fan

    private var fanSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Fan Mode", systemImage: "fanblades.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 12) {
                ForEach(["Auto", "On", "Low", "High"], id: \.self) { mode in
                    Button {
                        accessory.fanMode = mode
                        onUpdate(accessory)
                    } label: {
                        Text(mode)
                            .font(.subheadline)
                            .foregroundStyle(accessory.fanMode == mode ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(accessory.fanMode == mode ? Color.white : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(icon: "thermometer.low",   label: "Min",     value: "\(Int(minTemp))°C", color: .blue)
            statCard(icon: "thermometer.high",  label: "Max",     value: "\(Int(maxTemp))°C", color: .red)
            statCard(icon: "arrow.up.arrow.down",label: "Delta",
                     value: String(format: "%.1f°", abs(accessory.currentTemp - accessory.targetTemp)),
                     color: .orange)
        }
        .padding(.horizontal, 20)
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
