import SwiftUI

// MARK: - Thermostat Mode

enum ThermostatMode: String, CaseIterable, Identifiable {
    case heat, cool, auto, off
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .heat: return "flame.fill"
        case .cool: return "snowflake"
        case .auto: return "a.circle.fill"
        case .off:  return "power"
        }
    }
    var color: Color {
        switch self {
        case .heat: return .orange
        case .cool: return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .auto: return .green
        case .off:  return .gray
        }
    }
}

// MARK: - Floor Models

struct FloorAccessory: Identifiable {
    var id = UUID()
    var name: String
    var category: AccessoryCategory
    var relX: CGFloat           // 0–1 relative to room
    var relY: CGFloat
    var isPowered: Bool

    // Light
    var brightness: Float = 100     // 0–100
    var colorTemperature: Float = 3000  // 2700–6500 K

    // Thermostat
    var currentTemp: Float  = 21.5
    var targetTemp: Float   = 22.0
    var thermostatMode: ThermostatMode = .auto
    var fanMode: String     = "Auto"  // "Auto" | "On"

    // Camera
    var hasMotionAlert: Bool = false
    var isRecording: Bool    = false
}

struct FurniturePiece {
    var gx: CGFloat; var gy: CGFloat
    var gw: CGFloat; var gh: CGFloat
    var color: Color
}

struct FloorRoom: Identifiable {
    var id = UUID()
    var name: String
    var gridX: CGFloat; var gridY: CGFloat
    var gridW: CGFloat; var gridH: CGFloat
    var floorColor: Color
    var accessories: [FloorAccessory]
    var furniture: [FurniturePiece] = []
}

// MARK: - ViewModel

final class FloorPlanViewModel: ObservableObject {
    @Published var rooms: [FloorRoom]
    @Published var scale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero

    let tileW: CGFloat = 84
    let tileH: CGFloat = 42
    let wallH: CGFloat = 64

    init() { rooms = Self.defaultRooms() }

    // MARK: Projection

    func iso(_ gx: CGFloat, _ gy: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (gx - gy) * tileW / 2 + size.width  * 0.50,
            y: (gx + gy) * tileH / 2 + size.height * 0.10
        )
    }

    func accessoryScreenPos(room: FloorRoom, acc: FloorAccessory, in size: CGSize) -> CGPoint {
        iso(room.gridX + acc.relX * room.gridW,
            room.gridY + acc.relY * room.gridH,
            in: size)
    }

    // MARK: Mutations

    func update(accID: UUID, transform: (inout FloorAccessory) -> Void) {
        for ri in rooms.indices {
            for ai in rooms[ri].accessories.indices where rooms[ri].accessories[ai].id == accID {
                transform(&rooms[ri].accessories[ai])
                return
            }
        }
    }

    func toggleAccessory(id: UUID)               { update(accID: id) { $0.isPowered.toggle() } }
    func setBrightness(_ v: Float, id: UUID)      { update(accID: id) { $0.brightness = v } }
    func setColorTemp(_ v: Float, id: UUID)       { update(accID: id) { $0.colorTemperature = v } }
    func setTargetTemp(_ v: Float, id: UUID)      { update(accID: id) { $0.targetTemp = v } }
    func setThermostatMode(_ m: ThermostatMode, id: UUID) { update(accID: id) { $0.thermostatMode = m } }
    func setFanMode(_ m: String, id: UUID)        { update(accID: id) { $0.fanMode = m } }
    func setRecording(_ v: Bool, id: UUID)        { update(accID: id) { $0.isRecording = v } }

    func addRoom(_ room: FloorRoom) { rooms.append(room) }
    func deleteRoom(id: UUID)       { rooms.removeAll { $0.id == id } }

    func nextAutoPosition(w: CGFloat) -> (CGFloat, CGFloat) {
        let maxX = rooms.map { $0.gridX + $0.gridW }.max() ?? 0
        return (maxX + 0.5, 0)
    }

    func resetCamera() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            scale = 1.0; panOffset = .zero
        }
    }

    // MARK: - Default Layout (realistic house floor plan)

    static func defaultRooms() -> [FloorRoom] {
        let sofaBrown   = Color(red: 0.42, green: 0.33, blue: 0.24)
        let tableBrown  = Color(red: 0.55, green: 0.44, blue: 0.30)
        let bedWhite    = Color(red: 0.96, green: 0.94, blue: 0.90)
        let headboard   = Color(red: 0.30, green: 0.22, blue: 0.16)
        let counterGray = Color(red: 0.70, green: 0.70, blue: 0.65)
        let islandGray  = Color(red: 0.60, green: 0.60, blue: 0.55)

        return [
            // ── Living Room ───────────────────────────────────────
            FloorRoom(
                name: "Living Room", gridX: 0, gridY: 0, gridW: 6, gridH: 5,
                floorColor: Color(red: 0.95, green: 0.88, blue: 0.72),
                accessories: [
                    FloorAccessory(name: "Ceiling Light",  category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: true,  brightness: 85),
                    FloorAccessory(name: "Floor Lamp",     category: .lightbulb,  relX: 0.88, relY: 0.12, isPowered: false, brightness: 50),
                    FloorAccessory(name: "TV",             category: .switch,     relX: 0.12, relY: 0.10, isPowered: true),
                    FloorAccessory(name: "Thermostat",     category: .thermostat, relX: 0.88, relY: 0.50, isPowered: true,  currentTemp: 21.5, targetTemp: 22.0),
                ],
                furniture: [
                    FurniturePiece(gx: 0.3, gy: 3.5, gw: 5.4, gh: 0.9, color: sofaBrown.opacity(0.75)),  // sofa
                    FurniturePiece(gx: 2.0, gy: 2.5, gw: 2.0, gh: 0.8, color: tableBrown.opacity(0.65)), // coffee table
                    FurniturePiece(gx: 0.4, gy: 0.2, gw: 5.2, gh: 0.6, color: headboard.opacity(0.55)),  // TV unit
                ]
            ),
            // ── Master Bedroom ────────────────────────────────────
            FloorRoom(
                name: "Master Bedroom", gridX: 6, gridY: 0, gridW: 5, gridH: 5,
                floorColor: Color(red: 0.72, green: 0.84, blue: 0.97),
                accessories: [
                    FloorAccessory(name: "Ceiling Light",  category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: false, brightness: 30),
                    FloorAccessory(name: "Bedside Lamp",   category: .lightbulb,  relX: 0.88, relY: 0.65, isPowered: false, brightness: 20),
                    FloorAccessory(name: "AC Unit",        category: .thermostat, relX: 0.10, relY: 0.10, isPowered: true,  currentTemp: 20.0, targetTemp: 21.0, thermostatMode: .cool),
                    FloorAccessory(name: "Door Lock",      category: .lock,       relX: 0.50, relY: 0.05, isPowered: true),
                    FloorAccessory(name: "Security Cam",   category: .camera,     relX: 0.88, relY: 0.10, isPowered: true),
                ],
                furniture: [
                    FurniturePiece(gx: 6.5, gy: 2.8, gw: 4.0, gh: 1.8, color: bedWhite.opacity(0.85)),   // mattress
                    FurniturePiece(gx: 6.5, gy: 2.5, gw: 4.0, gh: 0.4, color: headboard.opacity(0.70)),  // headboard
                    FurniturePiece(gx: 9.6, gy: 0.3, gw: 1.2, gh: 3.8, color: sofaBrown.opacity(0.50)),  // wardrobe
                ]
            ),
            // ── Second Bedroom ────────────────────────────────────
            FloorRoom(
                name: "Bedroom 2", gridX: 11, gridY: 0, gridW: 4, gridH: 4,
                floorColor: Color(red: 0.88, green: 0.80, blue: 0.97),
                accessories: [
                    FloorAccessory(name: "Ceiling Light",  category: .lightbulb,  relX: 0.50, relY: 0.50, isPowered: false, brightness: 70),
                    FloorAccessory(name: "Desk Lamp",      category: .lightbulb,  relX: 0.80, relY: 0.80, isPowered: false, brightness: 40),
                    FloorAccessory(name: "Fan",            category: .fan,        relX: 0.20, relY: 0.20, isPowered: false),
                ],
                furniture: [
                    FurniturePiece(gx: 11.3, gy: 1.8, gw: 3.4, gh: 1.6, color: bedWhite.opacity(0.75)),
                    FurniturePiece(gx: 11.3, gy: 1.5, gw: 3.4, gh: 0.4, color: headboard.opacity(0.60)),
                    FurniturePiece(gx: 13.6, gy: 0.2, gw: 1.2, gh: 1.4, color: tableBrown.opacity(0.50)), // desk
                ]
            ),
            // ── Kitchen ───────────────────────────────────────────
            FloorRoom(
                name: "Kitchen", gridX: 0, gridY: 5, gridW: 5, gridH: 4,
                floorColor: Color(red: 0.78, green: 0.95, blue: 0.80),
                accessories: [
                    FloorAccessory(name: "Ceiling Light",  category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: true, brightness: 100),
                    FloorAccessory(name: "Coffee Maker",   category: .outlet,     relX: 0.88, relY: 0.15, isPowered: false),
                    FloorAccessory(name: "Motion Sensor",  category: .sensor,     relX: 0.15, relY: 0.88, isPowered: true),
                    FloorAccessory(name: "Window Shade",   category: .window,     relX: 0.50, relY: 0.10, isPowered: true),
                ],
                furniture: [
                    FurniturePiece(gx: 0.2, gy: 5.1, gw: 4.6, gh: 0.9, color: counterGray.opacity(0.70)), // north counter
                    FurniturePiece(gx: 0.2, gy: 5.1, gw: 0.9, gh: 3.6, color: counterGray.opacity(0.70)), // west counter
                    FurniturePiece(gx: 1.5, gy: 6.5, gw: 2.0, gh: 1.0, color: islandGray.opacity(0.65)),  // island
                ]
            ),
            // ── Entry / Hallway ───────────────────────────────────
            FloorRoom(
                name: "Entry", gridX: 5, gridY: 5, gridW: 6, gridH: 4,
                floorColor: Color(red: 0.90, green: 0.86, blue: 0.80),
                accessories: [
                    FloorAccessory(name: "Entry Light",    category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: true, brightness: 60),
                    FloorAccessory(name: "Video Doorbell", category: .doorbell,   relX: 0.90, relY: 0.15, isPowered: true),
                    FloorAccessory(name: "Front Door Lock",category: .lock,       relX: 0.90, relY: 0.50, isPowered: true),
                    FloorAccessory(name: "Entry Camera",   category: .camera,     relX: 0.10, relY: 0.10, isPowered: true, hasMotionAlert: true),
                    FloorAccessory(name: "Garage Door",    category: .garageDoor, relX: 0.10, relY: 0.80, isPowered: false),
                ]
            ),
            // ── Bathroom ─────────────────────────────────────────
            FloorRoom(
                name: "Bathroom", gridX: 11, gridY: 4, gridW: 4, gridH: 5,
                floorColor: Color(red: 0.78, green: 0.92, blue: 0.96),
                accessories: [
                    FloorAccessory(name: "Mirror Light",   category: .lightbulb,  relX: 0.50, relY: 0.15, isPowered: false, brightness: 90, colorTemperature: 5500),
                    FloorAccessory(name: "Exhaust Fan",    category: .fan,        relX: 0.80, relY: 0.80, isPowered: false),
                    FloorAccessory(name: "Heated Floor",   category: .thermostat, relX: 0.20, relY: 0.80, isPowered: false, currentTemp: 18.0, targetTemp: 26.0, thermostatMode: .heat),
                ],
                furniture: [
                    FurniturePiece(gx: 11.2, gy: 4.1, gw: 3.6, gh: 0.7, color: counterGray.opacity(0.65)), // sink counter
                    FurniturePiece(gx: 11.2, gy: 6.5, gw: 1.8, gh: 2.3, color: Color(red: 0.85, green: 0.92, blue: 0.98).opacity(0.8)), // bathtub
                    FurniturePiece(gx: 13.2, gy: 6.3, gw: 1.8, gh: 2.5, color: counterGray.opacity(0.55)), // shower
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
