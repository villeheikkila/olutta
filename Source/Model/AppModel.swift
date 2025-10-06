import ClusterMap
import CryptoKit
import HTTPTypes
import HTTPTypesFoundation
import MapKit
import OluttaShared
import OSLog
import SwiftUI

enum Status {
    case unauthenticated
    case loading
    case ready
    case error(Error)
}

@Observable
class AppModel {
    let logger = Logger(subsystem: "", category: "AppModel")
    // auth
    var status: Status = .unauthenticated
    // app
    var error: Error?
    var stores: [Store.Entity] = []
    var productsByStore: [Store.Id: [ProductEntity]] = [:]
    var subscribedStoreIds = [Store.Id]()
    var selectedStore: Store.Entity? {
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
    let authManager: AuthManager
    let rpcClient: AuthenticatedRPCClient

    init(rpcClient: RPCClientProtocol, keychain: Keychain) {
        // initialize session storage
        let sessionStorage = KeychainSessionStorage(keychain: keychain)
        let deviceIdentifierStorage = KeychainDeviceIdentifierStorage(keychain: keychain)
        // auth
        authManager = AuthManager(storage: sessionStorage, deviceIdentifierStorage: deviceIdentifierStorage, rpcClient: rpcClient)
        // rpc
        self.rpcClient = AuthenticatedRPCClient(
            rpcClient: rpcClient,
            authManager: authManager,
        )
    }

    // methods available when unauthenticated
    func initializeAuthManager() async {
        await authManager.initialize()
        let authStatus = Observations { self.authManager.authStatus }
        for await status in authStatus {
            switch status {
            case .unauthenticated:
                self.status = .unauthenticated
            case .authenticated:
                self.status = .ready
            }
        }
    }

    func signIn(authenticationType: AuthenticateCommand.AuthenticationType) async {
        do {
            try await authManager.signIn(authenticationType: authenticationType)
            status = .ready
        } catch {
            logger.error("Failed to sign in \(error)")
            status = .error(error)
        }
    }

    func signOut() async {
        await authManager.signOut()
        status = .unauthenticated
    }

    // authenticated methods
    func intializeAppData() async {
        do {
            let appData = try await rpcClient.call(GetAppDataCommand.self, with: .init())
            stores = appData.stores
        } catch {
            logger.error("Failed to load stores: \(error.localizedDescription)")
        }
    }

    func updatePushNotificationToken(_ token: String) async {
        do {
            try await rpcClient.call(
                RefreshDeviceCommand.self,
                with: .init(pushNotificationToken: token),
            )
        } catch {
            logger.error("Failed to update push notification token: \(error)")
        }
    }

    func getProductsByStoreId(id: Store.Id) async {
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

    // annotations
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

    // subscriptions
    func toggleSubscription() async throws {
        guard let selectedStore else { return }
        if subscribedStoreIds.contains(selectedStore.id) {
            do {
                try await rpcClient.call(
                    UnsubscribeFromStoreCommand.self,
                    with: .init(storeId: selectedStore.id),
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
                    with: .init(storeId: selectedStore.id),
                )
                subscribedStoreIds.append(selectedStore.id)
            } catch {
                logger.error("Failed to subscribe to store: \(error)")
                throw error
            }
        }
    }
}
