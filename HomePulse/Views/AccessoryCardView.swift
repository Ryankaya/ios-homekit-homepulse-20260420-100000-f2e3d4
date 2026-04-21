import SwiftUI
import HomeKit

struct AccessoryCardView: View {
    let accessory: HMAccessory
    let onTap: () -> Void

    @StateObject private var vm: AccessoryViewModel

    init(accessory: HMAccessory, onTap: @escaping () -> Void) {
        self.accessory = accessory
        self.onTap = onTap
        _vm = StateObject(wrappedValue: AccessoryViewModel(accessory: accessory))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: vm.category.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(vm.isPowered && vm.isReachable ? vm.category.color : .gray)
                    Spacer()
                    if vm.isWorking {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        powerToggle
                    }
                }
                Text(vm.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(vm.isReachable ? .white.opacity(0.85) : .white.opacity(0.35))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !vm.isReachable {
                    Text("Offline")
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.7))
                } else if vm.hasBrightness && vm.isPowered {
                    brightnessBar
                }
            }
            .padding(12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var powerToggle: some View {
        Image(systemName: vm.isPowered ? "power.circle.fill" : "power.circle")
            .font(.system(size: 18))
            .foregroundStyle(vm.isPowered ? vm.category.color : .gray.opacity(0.5))
            .onTapGesture {
                vm.togglePower()
            }
    }

    private var brightnessBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1)).frame(height: 3)
                Capsule()
                    .fill(vm.category.color.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(vm.brightness / 100), height: 3)
            }
        }
        .frame(height: 3)
    }

    private var cardBackground: some View {
        Group {
            if vm.isPowered && vm.isReachable {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(vm.category.color.opacity(0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(vm.category.color.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }
}
