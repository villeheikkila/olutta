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
    private let keychain: Keychain
    let authManager: AuthManager
    let rpcClient: AuthenticatedRPCClient

    init(rpcClient: RPCClientProtocol, keychain: Keychain) {
        self.keychain = keychain
        // initialize session storage
        let sessionStorage = KeychainSessionStorage(
            service: Bundle.main.bundleIdentifier ?? "com.olutta.app",
            key: "token_session",
        )
        // auth
        authManager = AuthManager(storage: sessionStorage, rpcClient: rpcClient)
        // rpc
        self.rpcClient = AuthenticatedRPCClient(
            rpcClient: rpcClient,
            authManager: authManager,
        )
    }

    func initialize() async {
        await authManager.initialize()
    }

    func createAnonymousUser() async {
        status = .authenticating
        do {
            try await authManager.createAnonymousUser()
            status = .loading
        } catch {
            logger.error("Failed to create anonymous user: \(error)")
            status = .error(error)
        }
    }

    func updatePushNotificationToken(_ token: String) async {
        let deviceId = UUID()

        pushNotificationToken = token
        do {
            try await rpcClient.call(
                RefreshDeviceCommand.self,
                with: .init(pushNotificationToken: token, deviceId: deviceId),
            )
        } catch {
            logger.error("Failed to update push notification token: \(error)")
        }
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
                with: .init(storeId: id),
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
                store: store,
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
                    count: newItem.memberAnnotations.count,
                ))
            }
        }
    }

    func toggleSubscription() async throws {
        guard let selectedStore else { return }
        let deviceId = UUID()

        if subscribedStoreIds.contains(selectedStore.id) {
            do {
                try await rpcClient.call(
                    UnsubscribeFromStoreCommand.self,
                    with: .init(storeId: selectedStore.id, deviceId: deviceId),
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
                    with: .init(storeId: selectedStore.id, deviceId: deviceId),
                )
                subscribedStoreIds.append(selectedStore.id)
            } catch {
                logger.error("Failed to subscribe to store: \(error)")
                throw error
            }
        }
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
