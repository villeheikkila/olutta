import ClusterMap
import CryptoKit
import HTTPTypes
import HTTPTypesFoundation
import MapKit
import OluttaShared
import OSLog
import SwiftUI

struct AlkoStoreEntity: Codable {
    let id: UUID
    let alkoStoreId: String
    let name: String
    let address: String
    let city: String
    let postalCode: String
    let latitude: Decimal
    let longitude: Decimal
    let outletType: String
}

enum Status {
    case unauthenticated
    case authenticating
    case loading
    case ready
    case error(Error)
}

@Observable
class AppModel {
    let logger = Logger(subsystem: "", category: "AppModel")
    // auth
    var status: Status = .unauthenticated
    var isAuthenticated: Bool = false
    var pushNotificationToken: String?
    private var accessToken: String?
    // app
    var data: ResponseEntity?
    var error: Error?
    var stores: [StoreEntity] = []
    var productsByStore: [UUID: [ProductEntity]] = [:]
    var subscribedStoreIds = [UUID]()
    var selectedStore: StoreEntity? {
        didSet {
            guard let selectedStore else { return }
            Task {
                await getProductsByStoreId(id: selectedStore.id)
            }
        }
    }

    // mapkit
    var storeAnnotations: [StoreAnnotation] = []
    var clusters: [StoreClusterAnnotation] = []
    private let clusterManager = ClusterManager<StoreAnnotation>()
    // deps
    private let httpClient: HTTPClient
    private let keychain: Keychain
    let rpcClient: RPCClient

    init(httpClient: HTTPClient, keychain: Keychain) {
        self.httpClient = httpClient
        self.keychain = keychain
        self.rpcClient = RPCClient(httpClient: httpClient)
        rpcClient.setTokenProvider { [weak self] in
            self?.accessToken
        }
    }
        
    func initialize() async {
        await authenticate()
        guard isAuthenticated else {
            logger.error("Failed to authenticate")
            return
        }
        await loadStores()
    }
        
    private func authenticate() async {
        status = .authenticating
        if let token = getExistingAccessToken() {
            accessToken = token
            isAuthenticated = true
            status = .loading
            return
        }
        if let deviceId = getExistingDeviceId() {
            await refreshAuthentication(deviceId: deviceId)
            return
        }
        await createAnonymousUser()
    }
    
    private func createAnonymousUser() async {
        let deviceId = UUID()
        status = .authenticating
        
        do {
            let response = try await rpcClient.call(
                CreateAnonymousUserCommand.self,
                with: .init(deviceId: deviceId, pushNotificationToken: pushNotificationToken)
            )
            
            try saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                deviceId: deviceId.uuidString
            )
            
            accessToken = response.accessToken
            isAuthenticated = true
            status = .loading
        } catch {
            logger.error("Failed to create anonymous user: \(error)")
            status = .error(error)
        }
    }
    
    private func refreshAuthentication(deviceId: String) async {
        guard let refreshToken = getExistingRefreshToken() else {
            await createAnonymousUser()
            return
        }
        status = .authenticating
        do {
            let response = try await rpcClient.call(
                RefreshTokensCommand.self,
                with: .init(refreshToken: refreshToken)
            )
            try saveTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                deviceId: deviceId
            )
            accessToken = response.accessToken
            isAuthenticated = true
            status = .loading
        } catch {
            logger.error("Failed to refresh token: \(error)")
            await createAnonymousUser()
        }
    }
    
    func updatePushNotificationToken(_ token: String) async {
        pushNotificationToken = token
        if isAuthenticated {
            do {
                try await rpcClient.call(
                    RefreshDeviceCommand.self,
                    with: .init(pushNotificationToken: token)
                )
            } catch {
                logger.error("Failed to update push notification token: \(error)")
            }
        }
    }
    
    func signOut() async {
        do {
            try keychain.deleteItem(forKey: "access_token")
            try keychain.deleteItem(forKey: "refresh_token")
            try keychain.deleteItem(forKey: "device-id")
        } catch {
            logger.error("Failed to clear keychain: \(error)")
        }
        
        accessToken = nil
        isAuthenticated = false
        stores = []
        productsByStore = [:]
        subscribedStoreIds = []
        selectedStore = nil
        status = .unauthenticated
    }
        
    private func loadStores() async {
        status = .loading
        do {
            stores = try await rpcClient.call(GetStoresCommand.self, with: .init()).stores
            status = .ready
        } catch {
            logger.error("Failed to load stores: \(error.localizedDescription)")
            self.error = error
            status = .error(error)
        }
    }

    var webStoreItems: [BeerEntity] {
        guard let data else { return [] }
        return data.webstore.compactMap { key, _ in
            data.beers[key]
        }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    func getProductsByStoreId(id: UUID) async {
        do {
            let products: [ProductEntity] = try await rpcClient.call(
                GetProductsByStoreIdCommand.self,
                with: .init(storeId: id)
            ).products
            productsByStore[id] = products
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }
    
    func initializeClusters() async {
        let annotations = stores.map { store in
            StoreAnnotation(
                id: store.id.uuidString,
                coordinate: store.location,
                store: store
            )
        }
        await clusterManager.add(annotations)
    }

    func reloadAnnotations(mapSize: CGSize, region: MKCoordinateRegion) async {
        async let changes = clusterManager.reload(mapViewSize: mapSize, coordinateRegion: region)
        await applyChanges(changes)
    }

    func applyChanges(_ difference: ClusterManager<StoreAnnotation>.Difference) {
        for removal in difference.removals {
            switch removal {
            case let .annotation(annotation):
                storeAnnotations.removeAll { $0 == annotation }
            case let .cluster(clusterAnnotation):
                clusters.removeAll { $0.id == clusterAnnotation.id }
            }
        }

        for insertion in difference.insertions {
            switch insertion {
            case let .annotation(newItem):
                storeAnnotations.append(newItem)
            case let .cluster(newItem):
                clusters.append(StoreClusterAnnotation(
                    id: newItem.id,
                    coordinate: newItem.coordinate,
                    count: newItem.memberAnnotations.count
                ))
            }
        }
    }
    
    func toggleSubscription() async throws {
        guard let selectedStore else { return }
        
        if subscribedStoreIds.contains(selectedStore.id) {
            do {
                try await rpcClient.call(
                    UnsubscribeFromStoreCommand.self,
                    with: .init(storeId: selectedStore.id)
                )
                subscribedStoreIds = subscribedStoreIds.filter { $0 != selectedStore.id }
            } catch {
                logger.error("Failed to unsubscribe from store: \(error)")
                throw error
            }
        } else {
            do {
                try await rpcClient.call(
                    SubscribeToStoreCommand.self,
                    with: .init(storeId: selectedStore.id)
                )
                subscribedStoreIds.append(selectedStore.id)
            } catch {
                logger.error("Failed to subscribe to store: \(error)")
                throw error
            }
        }
    }
        
    private func getExistingAccessToken() -> String? {
        do {
            let data = try keychain.data(forKey: "access_token")
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func getExistingRefreshToken() -> String? {
        do {
            let data = try keychain.data(forKey: "refresh_token")
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func getExistingDeviceId() -> String? {
        do {
            let data = try keychain.data(forKey: "device-id")
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func saveTokens(accessToken: String, refreshToken: String, deviceId: String) throws {
        try keychain.set(accessToken.data(using: .utf8)!, forKey: "access_token")
        try keychain.set(refreshToken.data(using: .utf8)!, forKey: "refresh_token")
        try keychain.set(deviceId.data(using: .utf8)!, forKey: "device-id")
    }
}

struct StoreAnnotation: Identifiable, CoordinateIdentifiable, Hashable {
    let id: String
    var coordinate: CLLocationCoordinate2D
    let store: StoreEntity

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StoreAnnotation, rhs: StoreAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

struct StoreClusterAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let count: Int
}
