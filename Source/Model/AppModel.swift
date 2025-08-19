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

@Observable
class AppModel {
    let logger = Logger(subsystem: "", category: "AppModel")
    var data: ResponseEntity?
    var isLoading = true
    var error: Error?
    var stores: [StoreEntity] = []
    var productsByStore: [UUID: [ProductEntity]] = [:]
    var selectedStore: StoreEntity? {
        didSet {
            guard let selectedStore else { return }
            Task {
                await getProductsByStoreId(id: selectedStore.id)
            }
        }
    }

    let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    var webStoreItems: [BeerEntity] {
        guard let data else { return [] }
        return data.webstore.compactMap { key, _ in
            data.beers[key]
        }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    func initialize() async {
        isLoading = true
        do {
            stores = try await httpClient.get(endpoint: .stores)
            isLoading = false
        } catch {
            logger.error("failed to load stores: \(error.localizedDescription)")
            self.error = error
            isLoading = false
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
