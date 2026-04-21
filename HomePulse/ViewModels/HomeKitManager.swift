import HomeKit
import Combine

final class HomeKitManager: NSObject, ObservableObject {
    @Published var homes: [HMHome] = []
    @Published var selectedHome: HMHome?
    @Published var isLoading = true
    @Published var authorizationStatus: HMHomeManagerAuthorizationStatus = .determined

    private let manager = HMHomeManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func selectHome(_ home: HMHome) {
        selectedHome = home
    }

    func addHome(named name: String) {
        manager.addHome(withName: name) { [weak self] home, error in
            guard error == nil, let home = home else { return }
            DispatchQueue.main.async {
                self?.homes.append(home)
                if self?.selectedHome == nil { self?.selectedHome = home }
            }
        }
    }
}

extension HomeKitManager: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.homes = manager.homes
            if self.selectedHome == nil || !manager.homes.contains(where: {
                $0.uniqueIdentifier == self.selectedHome?.uniqueIdentifier
            }) {
                self.selectedHome = manager.primaryHome ?? manager.homes.first
            }
            self.isLoading = false
        }
    }

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
            self?.isLoading = false
        }
    }
}
