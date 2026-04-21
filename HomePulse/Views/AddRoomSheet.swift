import SwiftUI

struct AddRoomSheet: View {
    let vm: FloorPlanViewModel
    let onAdd: (FloorRoom) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var width: CGFloat = 4
    @State private var height: CGFloat = 4
    @State private var selectedColorIndex = 0
    @State private var selectedAccessories: Set<AccessoryCategory> = []

    private let colorOptions: [(String, Color)] = [
        ("Warm",   Color(red: 0.95, green: 0.88, blue: 0.72)),
        ("Sky",    Color(red: 0.72, green: 0.84, blue: 0.97)),
        ("Green",  Color(red: 0.78, green: 0.95, blue: 0.78)),
        ("Lavender", Color(red: 0.88, green: 0.82, blue: 0.97)),
        ("Rose",   Color(red: 0.97, green: 0.80, blue: 0.83)),
        ("Sand",   Color(red: 0.92, green: 0.90, blue: 0.82)),
        ("Mint",   Color(red: 0.78, green: 0.96, blue: 0.92)),
        ("Peach",  Color(red: 0.97, green: 0.87, blue: 0.75)),
    ]

    private let accessoryOptions: [(AccessoryCategory, String)] = [
        (.lightbulb, "Ceiling Light"),
        (.switch,    "Wall Switch"),
        (.thermostat,"Thermostat"),
        (.outlet,    "Smart Plug"),
        (.sensor,    "Motion Sensor"),
        (.camera,    "Camera"),
        (.lock,      "Door Lock"),
        (.fan,       "Fan"),
    ]

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        previewSection
                        nameSection
                        sizeSection
                        colorSection
                        accessoriesSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { addRoom() }
                        .foregroundStyle(isValid ? Color.orange : Color.gray)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        let color = colorOptions[selectedColorIndex].1
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.25))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.5), lineWidth: 1.5)
                )
            VStack(spacing: 6) {
                Text(name.isEmpty ? "Room Name" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? .white.opacity(0.3) : .white)
                Text("\(Int(width)) × \(Int(height)) units")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 6) {
                    ForEach(accessoryOptions.filter { selectedAccessories.contains($0.0) }, id: \.0) { cat, _ in
                        Image(systemName: cat.systemImage)
                            .font(.caption)
                            .foregroundStyle(color)
                    }
                }
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        section("Room Name") {
            TextField("e.g. Bathroom, Office…", text: $name)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        section("Size (grid units)") {
            HStack(spacing: 16) {
                stepperField(label: "Width", value: $width, range: 2...12)
                stepperField(label: "Depth", value: $height, range: 2...10)
            }
        }
    }

    private func stepperField(label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 0) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus").frame(width: 40, height: 40)
                }
                Text("\(Int(value.wrappedValue))")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 40)
                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus").frame(width: 40, height: 40)
                }
            }
            .foregroundStyle(.orange)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Color

    private var colorSection: some View {
        section("Floor Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(colorOptions.indices, id: \.self) { i in
                    let (cname, color) = colorOptions[i]
                    VStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(selectedColorIndex == i ? Color.orange : Color.clear, lineWidth: 2.5)
                            )
                            .overlay(
                                selectedColorIndex == i
                                ? Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.black)
                                : nil
                            )
                            .onTapGesture { selectedColorIndex = i }
                        Text(cname)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Accessories

    private var accessoriesSection: some View {
        section("Pre-add Accessories (optional)") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                ForEach(accessoryOptions, id: \.0) { category, accName in
                    let isOn = selectedAccessories.contains(category)
                    Button {
                        if isOn { selectedAccessories.remove(category) }
                        else { selectedAccessories.insert(category) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 14))
                                .foregroundStyle(isOn ? .black : category.color)
                                .frame(width: 20)
                            Text(accName)
                                .font(.caption)
                                .foregroundStyle(isOn ? .black : .white.opacity(0.8))
                            Spacer()
                        }
                        .padding(10)
                        .background(isOn ? category.color : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Build Room

    private func addRoom() {
        let (ax, ay) = vm.nextAutoPosition(w: width)
        let color = colorOptions[selectedColorIndex].1

        let accs: [FloorAccessory] = accessoryOptions
            .filter { selectedAccessories.contains($0.0) }
            .enumerated()
            .map { idx, pair in
                let col = CGFloat(idx % 2) * 0.6 + 0.20
                let row = CGFloat(idx / 2) * 0.5 + 0.20
                return FloorAccessory(
                    name: pair.1,
                    category: pair.0,
                    relX: col,
                    relY: row,
                    isPowered: false
                )
            }

        let room = FloorRoom(
            name: name.trimmingCharacters(in: .whitespaces),
            gridX: ax, gridY: ay,
            gridW: width, gridH: height,
            floorColor: color,
            accessories: accs
        )
        onAdd(room)
        dismiss()
    }

    // MARK: - Helpers

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            content()
        }
    }
}
