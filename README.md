# HomePulse

A production-level SwiftUI iOS app demonstrating **HomeKit** — Apple's framework for integrating with smart home accessories.

## Feature: HomeKit

HomePulse is a smart home command center that discovers, monitors, and controls all HomeKit accessories in your home. The app features an animated **Pulse Ring** that visualises your home's health (the ratio of reachable to total accessories), real-time accessory state updates via delegate callbacks, scene activation, per-room grouping, and detailed accessory controls with brightness and temperature sliders.

### Key HomeKit APIs Used

| API | Purpose |
|-----|---------|
| `HMHomeManager` | Discovers and manages all configured homes |
| `HMHomeManagerDelegate` | Receives home updates and authorization changes |
| `HMHome` | Represents a single home, contains rooms, accessories, and action sets |
| `HMHomeDelegate` | Live updates when accessories are added/removed or rooms change |
| `HMRoom` | Logical grouping of accessories within a home |
| `HMAccessory` | Represents a physical smart home device |
| `HMAccessoryDelegate` | Real-time reachability and characteristic value updates |
| `HMService` | A functional service provided by an accessory (e.g., lightbulb service) |
| `HMCharacteristic` | A controllable property (power state, brightness, temperature) |
| `HMActionSet` | A scene — a named collection of actions to run together |
| `HMAccessoryCategory` | Categorises accessories by type (light, lock, thermostat, etc.) |

## Architecture

Strict **MVVM** throughout:

```
Models/
  AccessoryCategory.swift   — category enum with icons and colors
  DemoData.swift            — sample data for simulator / demo mode

ViewModels/
  HomeKitManager.swift      — HMHomeManager wrapper, @Published homes list
  HomeViewModel.swift       — per-home rooms/scenes/accessories, HMHomeDelegate
  AccessoryViewModel.swift  — per-accessory power/brightness/temperature control

Views/
  ContentView.swift             — root: loading / permission / real home / demo
  DashboardView.swift           — main screen for real HomeKit homes
  DemoDashboardView.swift       — fully interactive demo for Simulator/no-home state
  RoomSectionView.swift         — expandable room accordion with accessory grid
  AccessoryCardView.swift       — card with live state, power toggle, brightness bar
  AccessoryDetailSheet.swift    — full controls: power, brightness slider, temp slider
  Components/
    PulseRingView.swift         — animated home-health ring (green/orange/red)
    StatPillView.swift          — quick-stat pill (accessories, online, scenes)
```

## Demo Mode

When no HomeKit homes are configured (typical in Simulator), the app automatically enters **Demo Mode** showing a fully interactive sample home with 4 rooms, 14+ accessories, and 5 scenes. All controls work on in-memory state.

## Requirements

- iOS 16.2+
- Xcode 15+
- `com.apple.developer.homekit` entitlement (requires Apple Developer account for real devices)
- HomeKit Accessory Simulator (optional, for Simulator testing with real HomeKit API)

## Apple Documentation

- [HomeKit Framework](https://developer.apple.com/documentation/homekit)
- [HMHomeManager](https://developer.apple.com/documentation/homekit/hmhomemanager)
- [HMAccessory](https://developer.apple.com/documentation/homekit/hmaccessory)
- [HMCharacteristic](https://developer.apple.com/documentation/homekit/hmcharacteristic)
- [Enabling HomeKit in Your App](https://developer.apple.com/documentation/homekit/enabling_homekit_in_your_app)
- [Testing Your App with the HomeKit Accessory Simulator](https://developer.apple.com/documentation/homekit/testing_your_app_with_the_homekit_accessory_simulator)

## Setup

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open HomePulse.xcodeproj
```

To test with real accessories, add the `com.apple.developer.homekit` entitlement to your provisioning profile and run on a physical device.
