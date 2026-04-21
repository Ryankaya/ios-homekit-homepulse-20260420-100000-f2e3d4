import SwiftUI
import HomeKit

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

struct FloorScene: Identifiable {
    var id   = UUID()
    var name: String
    var icon: String
}

struct FurniturePiece {
    var gx: CGFloat; var gy: CGFloat
    var gw: CGFloat; var gh: CGFloat
    var color: Color
}

struct FloorAccessory: Identifiable {
    var id = UUID()
    var name: String
    var category: AccessoryCategory
    var relX: CGFloat           // 0–1 relative to room
    var relY: CGFloat
    var isPowered: Bool

    // Light
    var brightness: Float       = 100
    var colorTemperature: Float = 3000  // 2700–6500 K

    // Thermostat
    var currentTemp: Float      = 21.5
    var targetTemp: Float       = 22.0
    var thermostatMode: ThermostatMode = .auto
    var fanMode: String         = "Auto"

    // Camera
    var hasMotionAlert: Bool    = false
    var isRecording: Bool       = false
}

struct FloorRoom: Identifiable {
    var id        = UUID()
    var name: String
    var gridX: CGFloat; var gridY: CGFloat
    var gridW: CGFloat; var gridH: CGFloat
    var floorColor: Color
    var accessories: [FloorAccessory]
    var furniture: [FurniturePiece] = []
}

// MARK: - ViewModel (single source of truth for all home state)

final class FloorPlanViewModel: NSObject, ObservableObject {
    @Published var rooms: [FloorRoom]
    @Published var scenes: [FloorScene]
    @Published var scale: CGFloat   = 1.0
    @Published var panOffset: CGSize = .zero

    var homeName: String = "My Home"

    // Bridge to real HomeKit (set by ContentView when a real home is available)
    weak var homeKitVM: HomeViewModel?

    let tileW: CGFloat = 84
    let tileH: CGFloat = 42
    let wallH: CGFloat = 64

    override init() {
        rooms  = Self.defaultRooms()
        scenes = Self.defaultScenes()
        super.init()
    }

    // MARK: - Projection

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

    // MARK: - State mutations (drive both UI and real HomeKit)

    func update(accID: UUID, transform: (inout FloorAccessory) -> Void) {
        for ri in rooms.indices {
            for ai in rooms[ri].accessories.indices where rooms[ri].accessories[ai].id == accID {
                transform(&rooms[ri].accessories[ai])
                bridgeToHomeKit(rooms[ri], rooms[ri].accessories[ai])
                return
            }
        }
    }

    func toggleAccessory(id: UUID) {
        update(accID: id) { $0.isPowered.toggle() }
    }

    func setBrightness(_ v: Float, id: UUID) {
        update(accID: id) { $0.brightness = v }
    }

    func setColorTemp(_ v: Float, id: UUID) {
        update(accID: id) { $0.colorTemperature = v }
    }

    func setTargetTemp(_ v: Float, id: UUID) {
        update(accID: id) { $0.targetTemp = v }
    }

    func setThermostatMode(_ m: ThermostatMode, id: UUID) {
        update(accID: id) { $0.thermostatMode = m }
    }

    func setFanMode(_ m: String, id: UUID) {
        update(accID: id) { $0.fanMode = m }
    }

    func setRecording(_ v: Bool, id: UUID) {
        update(accID: id) { $0.isRecording = v }
    }

    // MARK: - Scene activation

    func activateScene(_ scene: FloorScene) {
        switch scene.name {
        case "Good Morning":
            allLights { $0.isPowered = true;  $0.brightness = 80;  $0.colorTemperature = 4000 }
            allThermostats { $0.isPowered = true; $0.targetTemp = 22 }
        case "Movie Time":
            for ri in rooms.indices {
                for ai in rooms[ri].accessories.indices {
                    if rooms[ri].accessories[ai].category == .lightbulb {
                        let isLiving = rooms[ri].name.lowercased().contains("living")
                        rooms[ri].accessories[ai].isPowered    = isLiving
                        rooms[ri].accessories[ai].brightness   = isLiving ? 25 : 0
                        rooms[ri].accessories[ai].colorTemperature = 2700
                    }
                    bridgeToHomeKit(rooms[ri], rooms[ri].accessories[ai])
                }
            }
        case "Good Night":
            allLights { $0.isPowered = false }
            allThermostats { $0.targetTemp = 18 }
        case "Away":
            allLights     { $0.isPowered = false }
            allThermostats { $0.isPowered = false; $0.thermostatMode = .off }
        case "Party Mode":
            allLights { $0.isPowered = true; $0.brightness = 100; $0.colorTemperature = 3500 }
        default: break
        }
    }

    // MARK: - Room management

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

    // MARK: - HomeKit sync (called by ContentView when real HomeKit loads)

    func syncFromHomeKit(_ homeKitVM: HomeViewModel) {
        self.homeKitVM = homeKitVM
        homeName = homeKitVM.home.name

        for ri in rooms.indices {
            let floorRoomName = rooms[ri].name
            guard let hmRoom = homeKitVM.rooms.first(where: { nameMatches($0.name, floorRoomName) }) else { continue }
            let hmAccs = homeKitVM.accessories(in: hmRoom)
            for ai in rooms[ri].accessories.indices {
                let floorAccName = rooms[ri].accessories[ai].name
                guard let hmAcc = hmAccs.first(where: { nameMatches($0.name, floorAccName) }) else { continue }
                pullState(from: hmAcc, into: &rooms[ri].accessories[ai])
            }
        }
    }

    // MARK: - HomeKit bridge (write floor plan state → real HomeKit)

    func bridgeToHomeKit(_ room: FloorRoom, _ acc: FloorAccessory) {
        guard let homeKitVM = homeKitVM else { return }
        guard let hmRoom = homeKitVM.rooms.first(where: { nameMatches($0.name, room.name) }) else { return }
        let hmAccs = homeKitVM.accessories(in: hmRoom)
        guard let hmAcc = hmAccs.first(where: { nameMatches($0.name, acc.name) }) else { return }

        let chars = hmAcc.services.flatMap(\.characteristics)

        func write(_ type: String, _ value: Any) {
            guard let c = chars.first(where: { $0.characteristicType == type }),
                  c.properties.contains(HMCharacteristicPropertyWritable) else { return }
            c.writeValue(value) { _ in }
        }

        write(HMCharacteristicTypePowerState, acc.isPowered)

        if acc.category == .lightbulb {
            write(HMCharacteristicTypeBrightness, Int(acc.brightness))
        }
        if acc.category == .thermostat {
            write(HMCharacteristicTypeTargetTemperature, Double(acc.targetTemp))
        }
    }

    // MARK: - Pull real HomeKit state into floor plan accessory

    private func pullState(from hmAcc: HMAccessory, into acc: inout FloorAccessory) {
        let chars = hmAcc.services.flatMap(\.characteristics)
        func read(_ type: String) -> Any? { chars.first { $0.characteristicType == type }?.value }

        if let v = read(HMCharacteristicTypePowerState)    as? Bool  { acc.isPowered  = v }
        if let v = read(HMCharacteristicTypeBrightness)    as? Int   { acc.brightness = Float(v) }
        if let v = read(HMCharacteristicTypeTargetTemperature) as? Double { acc.targetTemp  = Float(v) }
        if let v = read(HMCharacteristicTypeCurrentTemperature) as? Double { acc.currentTemp = Float(v) }
    }

    // MARK: - Helpers

    private func nameMatches(_ a: String, _ b: String) -> Bool {
        a.lowercased().trimmingCharacters(in: .whitespaces) ==
        b.lowercased().trimmingCharacters(in: .whitespaces)
    }

    private func allLights(_ transform: (inout FloorAccessory) -> Void) {
        for ri in rooms.indices {
            for ai in rooms[ri].accessories.indices where rooms[ri].accessories[ai].category == .lightbulb {
                transform(&rooms[ri].accessories[ai])
                bridgeToHomeKit(rooms[ri], rooms[ri].accessories[ai])
            }
        }
    }

    private func allThermostats(_ transform: (inout FloorAccessory) -> Void) {
        for ri in rooms.indices {
            for ai in rooms[ri].accessories.indices where rooms[ri].accessories[ai].category == .thermostat {
                transform(&rooms[ri].accessories[ai])
                bridgeToHomeKit(rooms[ri], rooms[ri].accessories[ai])
            }
        }
    }

    // MARK: - Default Layout

    static func defaultScenes() -> [FloorScene] {
        [
            FloorScene(name: "Good Morning", icon: "sunrise.fill"),
            FloorScene(name: "Movie Time",   icon: "tv.fill"),
            FloorScene(name: "Good Night",   icon: "moon.fill"),
            FloorScene(name: "Away",         icon: "door.right.hand.open"),
            FloorScene(name: "Party Mode",   icon: "party.popper.fill"),
        ]
    }

    static func defaultRooms() -> [FloorRoom] {
        let sofaBrown   = Color(red: 0.42, green: 0.33, blue: 0.24)
        let tableBrown  = Color(red: 0.55, green: 0.44, blue: 0.30)
        let bedWhite    = Color(red: 0.96, green: 0.94, blue: 0.90)
        let headboard   = Color(red: 0.30, green: 0.22, blue: 0.16)
        let counterGray = Color(red: 0.70, green: 0.70, blue: 0.65)
        let islandGray  = Color(red: 0.60, green: 0.60, blue: 0.55)

        return [
            FloorRoom(
                name: "Living Room", gridX: 0, gridY: 0, gridW: 6, gridH: 5,
                floorColor: Color(red: 0.95, green: 0.88, blue: 0.72),
                accessories: [
                    FloorAccessory(name: "Ceiling Light", category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: true,  brightness: 85),
                    FloorAccessory(name: "Floor Lamp",    category: .lightbulb,  relX: 0.88, relY: 0.12, isPowered: false, brightness: 50),
                    FloorAccessory(name: "TV",            category: .switch,     relX: 0.12, relY: 0.10, isPowered: true),
                    FloorAccessory(name: "Thermostat",    category: .thermostat, relX: 0.88, relY: 0.50, isPowered: true,  currentTemp: 21.5, targetTemp: 22.0),
                ],
                furniture: [
                    FurniturePiece(gx: 0.3, gy: 3.5, gw: 5.4, gh: 0.9, color: sofaBrown.opacity(0.75)),
                    FurniturePiece(gx: 2.0, gy: 2.5, gw: 2.0, gh: 0.8, color: tableBrown.opacity(0.65)),
                    FurniturePiece(gx: 0.4, gy: 0.2, gw: 5.2, gh: 0.6, color: headboard.opacity(0.55)),
                ]
            ),
            FloorRoom(
                name: "Master Bedroom", gridX: 6, gridY: 0, gridW: 5, gridH: 5,
                floorColor: Color(red: 0.72, green: 0.84, blue: 0.97),
                accessories: [
                    FloorAccessory(name: "Ceiling Light", category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: false, brightness: 30),
                    FloorAccessory(name: "Bedside Lamp",  category: .lightbulb,  relX: 0.88, relY: 0.65, isPowered: false, brightness: 20),
                    FloorAccessory(name: "AC Unit",       category: .thermostat, relX: 0.10, relY: 0.10, isPowered: true,  currentTemp: 20.0, targetTemp: 21.0, thermostatMode: .cool),
                    FloorAccessory(name: "Door Lock",     category: .lock,       relX: 0.50, relY: 0.05, isPowered: true),
                    FloorAccessory(name: "Security Cam",  category: .camera,     relX: 0.88, relY: 0.10, isPowered: true),
                ],
                furniture: [
                    FurniturePiece(gx: 6.5, gy: 2.8, gw: 4.0, gh: 1.8, color: bedWhite.opacity(0.85)),
                    FurniturePiece(gx: 6.5, gy: 2.5, gw: 4.0, gh: 0.4, color: headboard.opacity(0.70)),
                    FurniturePiece(gx: 9.6, gy: 0.3, gw: 1.2, gh: 3.8, color: sofaBrown.opacity(0.50)),
                ]
            ),
            FloorRoom(
                name: "Bedroom 2", gridX: 11, gridY: 0, gridW: 4, gridH: 4,
                floorColor: Color(red: 0.88, green: 0.80, blue: 0.97),
                accessories: [
                    FloorAccessory(name: "Ceiling Light", category: .lightbulb, relX: 0.50, relY: 0.50, isPowered: false, brightness: 70),
                    FloorAccessory(name: "Desk Lamp",     category: .lightbulb, relX: 0.80, relY: 0.80, isPowered: false, brightness: 40),
                    FloorAccessory(name: "Fan",           category: .fan,       relX: 0.20, relY: 0.20, isPowered: false),
                ],
                furniture: [
                    FurniturePiece(gx: 11.3, gy: 1.8, gw: 3.4, gh: 1.6, color: bedWhite.opacity(0.75)),
                    FurniturePiece(gx: 11.3, gy: 1.5, gw: 3.4, gh: 0.4, color: headboard.opacity(0.60)),
                    FurniturePiece(gx: 13.6, gy: 0.2, gw: 1.2, gh: 1.4, color: tableBrown.opacity(0.50)),
                ]
            ),
            FloorRoom(
                name: "Kitchen", gridX: 0, gridY: 5, gridW: 5, gridH: 4,
                floorColor: Color(red: 0.78, green: 0.95, blue: 0.80),
                accessories: [
                    FloorAccessory(name: "Ceiling Light", category: .lightbulb, relX: 0.50, relY: 0.45, isPowered: true, brightness: 100),
                    FloorAccessory(name: "Coffee Maker",  category: .outlet,    relX: 0.88, relY: 0.15, isPowered: false),
                    FloorAccessory(name: "Motion Sensor", category: .sensor,    relX: 0.15, relY: 0.88, isPowered: true),
                    FloorAccessory(name: "Window Shade",  category: .window,    relX: 0.50, relY: 0.10, isPowered: true),
                ],
                furniture: [
                    FurniturePiece(gx: 0.2, gy: 5.1, gw: 4.6, gh: 0.9, color: counterGray.opacity(0.70)),
                    FurniturePiece(gx: 0.2, gy: 5.1, gw: 0.9, gh: 3.6, color: counterGray.opacity(0.70)),
                    FurniturePiece(gx: 1.5, gy: 6.5, gw: 2.0, gh: 1.0, color: islandGray.opacity(0.65)),
                ]
            ),
            FloorRoom(
                name: "Entry", gridX: 5, gridY: 5, gridW: 6, gridH: 4,
                floorColor: Color(red: 0.90, green: 0.86, blue: 0.80),
                accessories: [
                    FloorAccessory(name: "Entry Light",     category: .lightbulb,  relX: 0.50, relY: 0.45, isPowered: true, brightness: 60),
                    FloorAccessory(name: "Video Doorbell",  category: .doorbell,   relX: 0.90, relY: 0.15, isPowered: true),
                    FloorAccessory(name: "Front Door Lock", category: .lock,       relX: 0.90, relY: 0.50, isPowered: true),
                    FloorAccessory(name: "Entry Camera",    category: .camera,     relX: 0.10, relY: 0.10, isPowered: true, hasMotionAlert: true),
                    FloorAccessory(name: "Garage Door",     category: .garageDoor, relX: 0.10, relY: 0.80, isPowered: false),
                ]
            ),
            FloorRoom(
                name: "Bathroom", gridX: 11, gridY: 4, gridW: 4, gridH: 5,
                floorColor: Color(red: 0.78, green: 0.92, blue: 0.96),
                accessories: [
                    FloorAccessory(name: "Mirror Light",  category: .lightbulb,  relX: 0.50, relY: 0.15, isPowered: false, brightness: 90, colorTemperature: 5500),
                    FloorAccessory(name: "Exhaust Fan",   category: .fan,        relX: 0.80, relY: 0.80, isPowered: false),
                    FloorAccessory(name: "Heated Floor",  category: .thermostat, relX: 0.20, relY: 0.80, isPowered: false, currentTemp: 18.0, targetTemp: 26.0, thermostatMode: .heat),
                ],
                furniture: [
                    FurniturePiece(gx: 11.2, gy: 4.1, gw: 3.6, gh: 0.7, color: counterGray.opacity(0.65)),
                    FurniturePiece(gx: 11.2, gy: 6.5, gw: 1.8, gh: 2.3, color: Color(red: 0.85, green: 0.92, blue: 0.98).opacity(0.80)),
                    FurniturePiece(gx: 13.2, gy: 6.3, gw: 1.8, gh: 2.5, color: counterGray.opacity(0.55)),
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
