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
    case authenticating
    case loading
    case ready
    case error
}

@Observable
class AppModel {
    let logger = Logger(subsystem: "", category: "AppModel")
    var data: ResponseEntity?
    var status: Status = .authenticating
    var error: Error?
    var stores: [StoreEntity] = []
    var productsByStore: [UUID: [ProductEntity]] = [:]
    var isAuthenticated: Bool = false
    var pushNotificationToken: String?
    var selectedStore: StoreEntity? {
        didSet {
            guard let selectedStore else { return }
            Task {
                await getProductsByStoreId(id: selectedStore.id)
            }
        }
    }

    var httpClient: HTTPClient
    let keychain: Keychain

    init(httpClient: HTTPClient, keychain: Keychain) {
        self.httpClient = httpClient
        self.keychain = keychain
    }

    var webStoreItems: [BeerEntity] {
        guard let data else { return [] }
        return data.webstore.compactMap { key, _ in
            data.beers[key]
        }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    func initialize() async {
        do {
            stores = try await httpClient.get(endpoint: .stores)
            status = .ready
        } catch {
            logger.error("failed to load stores: \(error.localizedDescription)")
            self.error = error
            status = .ready
        }
    }

    func getProductsByStoreId(id: UUID) async {
        do {
            let products: [ProductEntity] = try await httpClient.get(endpoint: .productsByStoreId(id))
            productsByStore[id] = products
        } catch {
            logger.error("failed to load products: \(error.localizedDescription)")
        }
    }

    var storeAnnotations: [StoreAnnotation] = []
    var clusters: [StoreClusterAnnotation] = []

    private let clusterManager = ClusterManager<StoreAnnotation>()

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

    func createAnonymousUser() async {
        let deviceID = UUID().uuidString
        do {
            let response: AnonymousAuthResponse = try await httpClient.post(endpoint: .anonymous, body: AnonymousAuthRequest(deviceId: deviceID, platform: .ios))
            try keychain.set(response.token.data(using: .utf8)!, forKey: "token")
            try keychain.set(deviceID.data(using: .utf8)!, forKey: "device-id")
            httpClient = httpClient.copyWith(defaultHeaders: [.init(name: .authorization, value: "Bearer \(response.token)")])
            isAuthenticated = true
            status = .loading
        } catch {
            logger.error("failed to sign in: \(error.localizedDescription)")
            status = .error
        }
        guard let pushNotificationToken else { return }
        do {
            print("rtadsadasd")
            let response: UserPatchResponse = try await httpClient.patch(endpoint: .user, body: UserPatchRequest(pushNotificationToken: pushNotificationToken))
            print("resfresh push notification token success")
        } catch {
            logger.error("failed to refresh push notification token: \(error.localizedDescription)")
        }
    }

    func refreshPushNotificationToken(pushNotificationToken: String) {
        self.pushNotificationToken = pushNotificationToken
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
