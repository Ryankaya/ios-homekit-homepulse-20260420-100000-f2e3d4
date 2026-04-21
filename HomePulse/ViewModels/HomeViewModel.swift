import HomeKit
import Combine

final class HomeViewModel: NSObject, ObservableObject {
    @Published var rooms: [HMRoom] = []
    @Published var scenes: [HMActionSet] = []
    @Published var unassignedAccessories: [HMAccessory] = []
    @Published var isExecutingScene = false

    let home: HMHome

    var allAccessories: [HMAccessory] { home.accessories }
    var reachableCount: Int { allAccessories.filter(\.isReachable).count }
    var totalCount: Int { allAccessories.count }
    var healthRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(reachableCount) / Double(totalCount)
    }

    init(home: HMHome) {
        self.home = home
        super.init()
        home.delegate = self
        refresh()
    }

    func refresh() {
        rooms = home.rooms.sorted { $0.name < $1.name }
        scenes = home.actionSets
        let assignedIDs = Set(home.rooms.flatMap(\.accessories).map(\.uniqueIdentifier))
        unassignedAccessories = home.accessories.filter {
            !assignedIDs.contains($0.uniqueIdentifier)
        }
    }

    func activateScene(_ scene: HMActionSet) {
        isExecutingScene = true
        home.executeActionSet(scene) { [weak self] _ in
            DispatchQueue.main.async { self?.isExecutingScene = false }
        }
    }

    func accessories(in room: HMRoom) -> [HMAccessory] {
        room.accessories.sorted { $0.name < $1.name }
    }

    func readAllCharacteristics() {
        for accessory in allAccessories {
            let readable = accessory.services.flatMap(\.characteristics).filter {
                $0.properties.contains(HMCharacteristicPropertyReadable)
            }
            for char in readable {
                char.readValue { _ in }
            }
        }
    }
}

extension HomeViewModel: HMHomeDelegate {
    func homeDidUpdateName(_ home: HMHome)                                           { refresh() }
    func home(_ home: HMHome, didAdd room: HMRoom)                                   { refresh() }
    func home(_ home: HMHome, didRemove room: HMRoom)                               { refresh() }
    func home(_ home: HMHome, didAdd accessory: HMAccessory)                        { refresh() }
    func home(_ home: HMHome, didRemove accessory: HMAccessory)                     { refresh() }
    func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory)   { refresh() }
    func home(_ home: HMHome, didAdd actionSet: HMActionSet)                        { refresh() }
    func home(_ home: HMHome, didRemove actionSet: HMActionSet)                     { refresh() }
    func home(_ home: HMHome, didExecute actionSet: HMActionSet, error: Error?)     { refresh() }
}
