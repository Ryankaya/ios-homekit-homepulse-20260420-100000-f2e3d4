import SwiftUI

// MARK: - Models

struct FloorRoom: Identifiable {
    var id = UUID()
    var name: String
    var gridX: CGFloat
    var gridY: CGFloat
    var gridW: CGFloat
    var gridH: CGFloat
    var floorColor: Color
    var accessories: [FloorAccessory]
}

struct FloorAccessory: Identifiable {
    var id = UUID()
    var name: String
    var category: AccessoryCategory
    var relX: CGFloat   // 0–1 relative to room
    var relY: CGFloat
    var isPowered: Bool
}

// MARK: - ViewModel

final class FloorPlanViewModel: ObservableObject {
    @Published var rooms: [FloorRoom]
    @Published var scale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero

    let tileW: CGFloat = 72
    let tileH: CGFloat = 36
    let wallH: CGFloat = 56

    init() {
        rooms = Self.defaultRooms()
    }

    // Isometric projection: grid (gx, gy) → screen point
    func iso(_ gx: CGFloat, _ gy: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (gx - gy) * tileW / 2 + size.width  * 0.50,
            y: (gx + gy) * tileH / 2 + size.height * 0.12
        )
    }

    func accessoryScreenPos(room: FloorRoom, acc: FloorAccessory, in size: CGSize) -> CGPoint {
        iso(room.gridX + acc.relX * room.gridW,
            room.gridY + acc.relY * room.gridH,
            in: size)
    }

    func toggleAccessory(id: UUID) {
        for ri in rooms.indices {
            for ai in rooms[ri].accessories.indices where rooms[ri].accessories[ai].id == id {
                rooms[ri].accessories[ai].isPowered.toggle()
                return
            }
        }
    }

    func addRoom(_ room: FloorRoom) {
        rooms.append(room)
    }

    func deleteRoom(id: UUID) {
        rooms.removeAll { $0.id == id }
    }

    // Place new room to the right of existing rooms, at y = 0
    func nextAutoPosition(w: CGFloat) -> (CGFloat, CGFloat) {
        let maxX = rooms.map { $0.gridX + $0.gridW }.max() ?? 0
        return (maxX + 0.5, 0)
    }

    func resetCamera() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            scale = 1.0
            panOffset = .zero
        }
    }

    // MARK: - Default Layout

    static func defaultRooms() -> [FloorRoom] {
        [
            FloorRoom(
                name: "Living Room", gridX: 0, gridY: 0, gridW: 6, gridH: 5,
                floorColor: Color(red: 0.95, green: 0.88, blue: 0.72),
                accessories: [
                    FloorAccessory(name: "Ceiling Light", category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: true),
                    FloorAccessory(name: "Floor Lamp",    category: .lightbulb,  relX: 0.82, relY: 0.15, isPowered: false),
                    FloorAccessory(name: "Smart TV",      category: .switch,     relX: 0.12, relY: 0.52, isPowered: true),
                    FloorAccessory(name: "Thermostat",    category: .thermostat, relX: 0.80, relY: 0.80, isPowered: true),
                ]
            ),
            FloorRoom(
                name: "Bedroom", gridX: 6, gridY: 0, gridW: 4, gridH: 5,
                floorColor: Color(red: 0.72, green: 0.84, blue: 0.97),
                accessories: [
                    FloorAccessory(name: "Bedside Lamp", category: .lightbulb,  relX: 0.15, relY: 0.75, isPowered: false),
                    FloorAccessory(name: "Ceiling Fan",  category: .fan,        relX: 0.50, relY: 0.45, isPowered: false),
                    FloorAccessory(name: "Door Lock",    category: .lock,       relX: 0.50, relY: 0.10, isPowered: true),
                    FloorAccessory(name: "AC Unit",      category: .thermostat, relX: 0.15, relY: 0.18, isPowered: true),
                ]
            ),
            FloorRoom(
                name: "Kitchen", gridX: 0, gridY: 5, gridW: 5, gridH: 4,
                floorColor: Color(red: 0.78, green: 0.95, blue: 0.78),
                accessories: [
                    FloorAccessory(name: "Ceiling Light", category: .lightbulb, relX: 0.50, relY: 0.45, isPowered: true),
                    FloorAccessory(name: "Coffee Maker",  category: .outlet,    relX: 0.15, relY: 0.18, isPowered: false),
                    FloorAccessory(name: "Motion Sensor", category: .sensor,    relX: 0.82, relY: 0.80, isPowered: true),
                    FloorAccessory(name: "Window Shade",  category: .window,    relX: 0.82, relY: 0.18, isPowered: true),
                ]
            ),
            FloorRoom(
                name: "Entry", gridX: 5, gridY: 5, gridW: 5, gridH: 4,
                floorColor: Color(red: 0.88, green: 0.82, blue: 0.97),
                accessories: [
                    FloorAccessory(name: "Video Doorbell", category: .doorbell,  relX: 0.50, relY: 0.12, isPowered: true),
                    FloorAccessory(name: "Door Lock",      category: .lock,      relX: 0.50, relY: 0.88, isPowered: true),
                    FloorAccessory(name: "Security Cam",   category: .camera,    relX: 0.15, relY: 0.18, isPowered: true),
                    FloorAccessory(name: "Garage Door",    category: .garageDoor,relX: 0.82, relY: 0.82, isPowered: false),
                ]
            ),
        ]
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(_ range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
