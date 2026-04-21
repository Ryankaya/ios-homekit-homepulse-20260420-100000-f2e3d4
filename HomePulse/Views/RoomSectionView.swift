import SwiftUI
import HomeKit

struct RoomSectionView: View {
    let room: HMRoom
    let accessories: [HMAccessory]
    let onSelectAccessory: (HMAccessory) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            roomHeader
            if isExpanded && !accessories.isEmpty {
                accessoryGrid
                    .padding(.top, 12)
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

    private var roomHeader: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack {
                Text(room.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(accessories.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 14)
        }
    }

    private var accessoryGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(accessories, id: \.uniqueIdentifier) { accessory in
                AccessoryCardView(accessory: accessory) {
                    onSelectAccessory(accessory)
                }
            }
        }
    }
}

struct UnassignedSectionView: View {
    let accessories: [HMAccessory]
    let onSelectAccessory: (HMAccessory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unassigned")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 16)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(accessories, id: \.uniqueIdentifier) { accessory in
                    AccessoryCardView(accessory: accessory) {
                        onSelectAccessory(accessory)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
