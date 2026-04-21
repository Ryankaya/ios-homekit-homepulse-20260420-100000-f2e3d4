import Foundation

struct DemoRoom: Identifiable {
    let id = UUID()
    var name: String
    var accessories: [DemoAccessory]
}

struct DemoAccessory: Identifiable {
    let id = UUID()
    var name: String
    var category: AccessoryCategory
    var isPowered: Bool = true
    var brightness: Float?
    var temperature: Float?
    var isReachable: Bool = true
}

struct DemoScene: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
}

struct DemoHome {
    var name: String
    var rooms: [DemoRoom]
    var scenes: [DemoScene]

    static let sample = DemoHome(
        name: "Demo Home",
        rooms: [
            DemoRoom(name: "Living Room", accessories: [
                DemoAccessory(name: "Ceiling Light",  category: .lightbulb, isPowered: true,  brightness: 80),
                DemoAccessory(name: "Floor Lamp",     category: .lightbulb, isPowered: false, brightness: 40),
                DemoAccessory(name: "Apple TV",       category: .switch,    isPowered: true),
                DemoAccessory(name: "Thermostat",     category: .thermostat,isPowered: true,  temperature: 22),
                DemoAccessory(name: "Smart Plug",     category: .outlet,    isPowered: false),
                DemoAccessory(name: "Motion Sensor",  category: .sensor,    isPowered: true),
            ]),
            DemoRoom(name: "Bedroom", accessories: [
                DemoAccessory(name: "Bedside Lamp",   category: .lightbulb, isPowered: false, brightness: 20),
                DemoAccessory(name: "Ceiling Fan",    category: .fan,       isPowered: false),
                DemoAccessory(name: "Door Lock",      category: .lock,      isPowered: true),
                DemoAccessory(name: "AC Unit",        category: .thermostat,isPowered: true,  temperature: 24),
            ]),
            DemoRoom(name: "Kitchen", accessories: [
                DemoAccessory(name: "Ceiling Light",  category: .lightbulb, isPowered: true,  brightness: 100),
                DemoAccessory(name: "Coffee Maker",   category: .outlet,    isPowered: false),
                DemoAccessory(name: "Motion Sensor",  category: .sensor,    isPowered: true),
                DemoAccessory(name: "Window Shade",   category: .window,    isPowered: true),
            ]),
            DemoRoom(name: "Front Door", accessories: [
                DemoAccessory(name: "Video Doorbell", category: .doorbell,  isPowered: true),
                DemoAccessory(name: "Door Lock",      category: .lock,      isPowered: true),
                DemoAccessory(name: "Security Cam",   category: .camera,    isPowered: true),
                DemoAccessory(name: "Garage Door",    category: .garageDoor,isPowered: false),
            ]),
        ],
        scenes: [
            DemoScene(name: "Good Morning", icon: "sunrise.fill"),
            DemoScene(name: "Movie Time",   icon: "tv.fill"),
            DemoScene(name: "Good Night",   icon: "moon.fill"),
            DemoScene(name: "Away",         icon: "door.right.hand.open"),
            DemoScene(name: "Party Mode",   icon: "party.popper.fill"),
        ]
    )
}
