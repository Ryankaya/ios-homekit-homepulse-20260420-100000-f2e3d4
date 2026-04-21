import HomeKit
import Combine

final class AccessoryViewModel: NSObject, ObservableObject {
    @Published var isPowered: Bool = false
    @Published var brightness: Float = 100
    @Published var targetTemperature: Float = 22
    @Published var currentTemperature: Float = 20
    @Published var isReachable: Bool = false
    @Published var isWorking: Bool = false

    let accessory: HMAccessory

    var category: AccessoryCategory { AccessoryCategory.from(accessory.category) }
    var name: String { accessory.name }

    var primaryService: HMService? {
        let excluded = [HMServiceTypeAccessoryInformation, HMServiceTypeBattery]
        return accessory.services.first { !excluded.contains($0.serviceType) }
    }

    var powerCharacteristic: HMCharacteristic? {
        allCharacteristics.first { $0.characteristicType == HMCharacteristicTypePowerState }
    }
    var brightnessCharacteristic: HMCharacteristic? {
        allCharacteristics.first { $0.characteristicType == HMCharacteristicTypeBrightness }
    }
    var targetTempCharacteristic: HMCharacteristic? {
        allCharacteristics.first { $0.characteristicType == HMCharacteristicTypeTargetTemperature }
    }
    var currentTempCharacteristic: HMCharacteristic? {
        allCharacteristics.first { $0.characteristicType == HMCharacteristicTypeCurrentTemperature }
    }

    var hasBrightness: Bool { brightnessCharacteristic != nil }
    var hasTemperature: Bool { targetTempCharacteristic != nil || currentTempCharacteristic != nil }

    private var allCharacteristics: [HMCharacteristic] {
        accessory.services.flatMap(\.characteristics)
    }

    init(accessory: HMAccessory) {
        self.accessory = accessory
        super.init()
        accessory.delegate = self
        isReachable = accessory.isReachable
        readValues()
    }

    func readValues() {
        let chars = allCharacteristics.filter { $0.properties.contains(HMCharacteristicPropertyReadable) }
        let group = DispatchGroup()
        for char in chars {
            group.enter()
            char.readValue { _ in group.leave() }
        }
        group.notify(queue: .main) { [weak self] in self?.syncFromCharacteristics() }
    }

    func togglePower() {
        guard let char = powerCharacteristic, char.properties.contains(HMCharacteristicPropertyWritable) else { return }
        let newValue = !isPowered
        isWorking = true
        char.writeValue(newValue) { [weak self] error in
            DispatchQueue.main.async {
                self?.isWorking = false
                if error == nil { self?.isPowered = newValue }
            }
        }
    }

    func setBrightness(_ value: Float) {
        guard let char = brightnessCharacteristic, char.properties.contains(HMCharacteristicPropertyWritable) else { return }
        let intValue = Int(value)
        char.writeValue(intValue) { [weak self] error in
            DispatchQueue.main.async {
                if error == nil { self?.brightness = value }
            }
        }
    }

    func setTargetTemperature(_ value: Float) {
        guard let char = targetTempCharacteristic, char.properties.contains(HMCharacteristicPropertyWritable) else { return }
        char.writeValue(Double(value)) { [weak self] error in
            DispatchQueue.main.async {
                if error == nil { self?.targetTemperature = value }
            }
        }
    }

    private func syncFromCharacteristics() {
        if let v = powerCharacteristic?.value as? Bool { isPowered = v }
        if let v = brightnessCharacteristic?.value {
            if let i = v as? Int { brightness = Float(i) }
            else if let f = v as? Float { brightness = f }
        }
        if let v = targetTempCharacteristic?.value {
            if let d = v as? Double { targetTemperature = Float(d) }
        }
        if let v = currentTempCharacteristic?.value {
            if let d = v as? Double { currentTemperature = Float(d) }
        }
    }
}

extension AccessoryViewModel: HMAccessoryDelegate {
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        DispatchQueue.main.async { [weak self] in self?.isReachable = accessory.isReachable }
    }

    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        DispatchQueue.main.async { [weak self] in self?.syncFromCharacteristics() }
    }
}
