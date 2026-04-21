import SwiftUI

struct LightSheet: View {
    @Binding var accessory: FloorAccessory
    let roomName: String
    let onUpdate: (FloorAccessory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var glowPulse = false

    // Colour temperature to RGB
    private var lightColor: Color {
        let t = accessory.colorTemperature
        if t < 3000 { return Color(red: 1.0, green: 0.75, blue: 0.40) }
        if t < 4000 { return Color(red: 1.0, green: 0.88, blue: 0.68) }
        if t < 5000 { return Color(red: 1.0, green: 0.96, blue: 0.88) }
        if t < 5500 { return Color(red: 1.0, green: 1.00, blue: 0.96) }
        return       Color(red: 0.88, green: 0.94, blue: 1.00)
    }

    private var glowRadius: CGFloat {
        accessory.isPowered ? CGFloat(accessory.brightness) * 1.2 : 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.09).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        glowPreview
                        powerRow
                        brightnessSection
                        colorTempSection
                        presetsSection
                        timerSection
                    }
                    .padding(.bottom, 32)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Glow Preview

    private var glowPreview: some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [lightColor.opacity(accessory.isPowered ? Double(accessory.brightness / 100) * 0.55 : 0), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(glowPulse && accessory.isPowered ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowPulse)

            // Bulb icon
            ZStack {
                Circle()
                    .fill(accessory.isPowered ? lightColor.opacity(0.25) : Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                Image(systemName: accessory.isPowered ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(accessory.isPowered ? lightColor : .white.opacity(0.3))
            }
            .shadow(color: accessory.isPowered ? lightColor.opacity(0.8) : .clear,
                    radius: CGFloat(accessory.brightness) * 0.3)

            // Brightness ring
            Circle()
                .trim(from: 0, to: accessory.isPowered ? CGFloat(accessory.brightness / 100) : 0)
                .stroke(
                    AngularGradient(
                        colors: [lightColor.opacity(0.3), lightColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 118, height: 118)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: accessory.brightness)
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.4), value: accessory.isPowered)
    }

    // MARK: - Power

    private var powerRow: some View {
        HStack {
            Label("Power", systemImage: "power")
                .font(.body.bold())
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: Binding(
                get: { accessory.isPowered },
                set: { v in
                    withAnimation(.spring(response: 0.35)) { accessory.isPowered = v }
                    onUpdate(accessory)
                }
            ))
            .labelsHidden()
            .tint(lightColor)
        }
        .padding(18)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: - Brightness

    private var brightnessSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "sun.min.fill").foregroundStyle(.yellow.opacity(0.6))
                    Text("Brightness")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(accessory.brightness))%")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(lightColor)
                }
                Slider(
                    value: Binding(
                        get: { Double(accessory.brightness) },
                        set: { v in
                            accessory.brightness = Float(v)
                            if !accessory.isPowered && v > 0 { accessory.isPowered = true }
                            onUpdate(accessory)
                        }
                    ),
                    in: 0...100
                )
                .tint(lightColor)
                .disabled(!accessory.isPowered)

                // Quick brightness presets
                HStack(spacing: 8) {
                    ForEach([25, 50, 75, 100], id: \.self) { val in
                        Button {
                            accessory.brightness = Float(val)
                            if !accessory.isPowered { accessory.isPowered = true }
                            onUpdate(accessory)
                        } label: {
                            Text("\(val)%")
                                .font(.caption)
                                .foregroundStyle(Int(accessory.brightness) == val ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Int(accessory.brightness) == val ? lightColor : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Colour Temperature

    private var colorTempSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "thermometer").foregroundStyle(.orange.opacity(0.8))
                    Text("Color Temperature")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(accessory.colorTemperature)) K")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(lightColor)
                }

                // Gradient track slider
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.25),
                            Color(red: 1.0, green: 0.92, blue: 0.70),
                            Color(red: 0.85, green: 0.92, blue: 1.00)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 6)
                    .clipShape(Capsule())

                    Slider(
                        value: Binding(
                            get: { Double(accessory.colorTemperature) },
                            set: { v in accessory.colorTemperature = Float(v); onUpdate(accessory) }
                        ),
                        in: 2700...6500
                    )
                    .tint(.clear)
                    .opacity(0.011)
                    .overlay(alignment: .leading) {
                        Circle()
                            .fill(lightColor)
                            .frame(width: 22, height: 22)
                            .shadow(color: lightColor, radius: 5)
                            .offset(x: CGFloat((accessory.colorTemperature - 2700) / (6500 - 2700)) * 260)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 22)
                .disabled(!accessory.isPowered)

                HStack {
                    Text("Warm 2700K").font(.caption2).foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("Cool 6500K").font(.caption2).foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Presets

    private let presets: [(String, String, Float, Float)] = [
        ("Relax",   "moon.stars.fill",   30,   2700),
        ("Reading", "book.fill",         80,   4000),
        ("Focus",   "brain.head.profile",100,  5500),
        ("Vivid",   "sun.max.fill",      100,  6500),
    ]

    private var presetsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scenes")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(presets, id: \.0) { name, icon, bright, kelvin in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                accessory.brightness = bright
                                accessory.colorTemperature = kelvin
                                accessory.isPowered = true
                            }
                            onUpdate(accessory)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(lightColor)
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Auto Turn-Off Timer")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                HStack(spacing: 10) {
                    ForEach(["30 min", "1 hr", "2 hr", "Morning"], id: \.self) { label in
                        Button {
                            // In production: schedule HMTimerTrigger
                        } label: {
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(18)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 20)
    }
}
