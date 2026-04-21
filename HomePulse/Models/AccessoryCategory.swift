import SwiftUI
import HomeKit

enum AccessoryCategory: String, CaseIterable {
    case lightbulb, `switch`, thermostat, lock, fan, outlet, sensor, camera, doorbell, garageDoor, window, unknown

    var systemImage: String {
        switch self {
        case .lightbulb:   return "lightbulb.fill"
        case .switch:      return "switch.2"
        case .thermostat:  return "thermometer"
        case .lock:        return "lock.fill"
        case .fan:         return "fanblades.fill"
        case .outlet:      return "poweroutlet.type.b.fill"
        case .sensor:      return "sensor.tag.radiowaves.forward.fill"
        case .camera:      return "camera.fill"
        case .doorbell:    return "bell.fill"
        case .garageDoor:  return "car.fill"
        case .window:      return "rectangle.split.2x1"
        case .unknown:     return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .lightbulb:   return .yellow
        case .switch:      return .blue
        case .thermostat:  return .orange
        case .lock:        return .red
        case .fan:         return .cyan
        case .outlet:      return .green
        case .sensor:      return .purple
        case .camera:      return .indigo
        case .doorbell:    return .mint
        case .garageDoor:  return .teal
        case .window:      return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .unknown:     return .gray
        }
    }

    static func from(_ category: HMAccessoryCategory) -> AccessoryCategory {
        switch category.categoryType {
        case HMAccessoryCategoryTypeLightbulb:         return .lightbulb
        case HMAccessoryCategoryTypeSwitch:            return .switch
        case HMAccessoryCategoryTypeThermostat:        return .thermostat
        case HMAccessoryCategoryTypeDoor,
             HMAccessoryCategoryTypeDoorLock:          return .lock
        case HMAccessoryCategoryTypeFan:               return .fan
        case HMAccessoryCategoryTypeOutlet:            return .outlet
        case HMAccessoryCategoryTypeSensor:            return .sensor
        case HMAccessoryCategoryTypeIPCamera:          return .camera
        case HMAccessoryCategoryTypeVideoDoorbell:     return .doorbell
        case HMAccessoryCategoryTypeGarageDoorOpener:  return .garageDoor
        case HMAccessoryCategoryTypeWindow,
             HMAccessoryCategoryTypeWindowCovering:    return .window
        default:                                        return .unknown
        }
    }
}
