import SwiftUI
import HomeKit

struct AccessoryDetailSheet: View {
    let accessory: HMAccessory
    @StateObject private var vm: AccessoryViewModel
    @Environment(\.dismiss) private var dismiss

    init(accessory: HMAccessory) {
        self.accessory = accessory
        _vm = StateObject(wrappedValue: AccessoryViewModel(accessory: accessory))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        iconHeader
                        if !vm.isReachable {
                            offlineBanner
                        }
                        controlsSection
                        infoSection
                    }
                    .padding()
                }
            }
            .navigationTitle(vm.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Icon Header

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(vm.category.color.opacity(vm.isPowered ? 0.2 : 0.06))
                .frame(width: 110, height: 110)
            Image(systemName: vm.category.systemImage)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(vm.isPowered && vm.isReachable ? vm.category.color : .gray)
        }
        .padding(.top, 8)
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        Label("Accessory is offline or unreachable", systemImage: "wifi.slash")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            .padding(12)
            .background(Color.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Power toggle
            if vm.powerCharacteristic != nil {
                controlRow {
                    Toggle(isOn: Binding(get: { vm.isPowered }, set: { _ in vm.togglePower() })) {
                        Label("Power", systemImage: "power")
                            .foregroundStyle(.white)
                    }
                    .tint(vm.category.color)
                    .disabled(!vm.isReachable)
                }
            }

            // Brightness slider
            if vm.hasBrightness {
                controlRow {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Brightness  \(Int(vm.brightness))%", systemImage: "sun.max.fill")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { Double(vm.brightness) },
                                set: { vm.setBrightness(Float($0)) }
                            ),
                            in: 0...100, step: 5
                        )
                        .tint(vm.category.color)
                        .disabled(!vm.isReachable || !vm.isPowered)
                    }
                }
            }

            // Temperature
            if vm.hasTemperature {
                controlRow {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Target  \(Int(vm.targetTemperature))°C  (Current: \(Int(vm.currentTemperature))°C)",
                              systemImage: "thermometer")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { Double(vm.targetTemperature) },
                                set: { vm.setTargetTemperature(Float($0)) }
                            ),
                            in: 16...30, step: 0.5
                        )
                        .tint(.orange)
                        .disabled(!vm.isReachable)
                    }
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            infoRow(label: "Category", value: vm.category.rawValue.capitalized)
            infoRow(label: "Services", value: "\(accessory.services.count)")
            infoRow(label: "Room", value: accessory.room?.name ?? "Unassigned")
            infoRow(label: "Firmware", value: accessory.firmwareVersion ?? "Unknown")
            infoRow(label: "Manufacturer", value: accessory.manufacturer ?? "Unknown")
            infoRow(label: "Model", value: accessory.model ?? "Unknown")
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func controlRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
