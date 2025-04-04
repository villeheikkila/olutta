import ClusterMap
import MapKit
import SwiftUI
import CryptoKit
import OluttaShared
import HTTPTypes
import HTTPTypesFoundation

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
    var data: ResponseEntity?
    var isLoading = true
    var error: Error?
    var s: [AlkoStoreEntity] = []

    var stores: [StoreEntity] {
        guard let data else { return [] }
        return data.stores.values.sorted { $0.name < $1.name }
    }

    var webStoreItems: [BeerEntity] {
        guard let data else { return [] }
        return data.webstore.compactMap { key, _ in
            data.beers[key]
        }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    func getBeersForStore(store: StoreEntity) -> [BeerEntity] {
        guard let data else { return [] }
        return store.beers.compactMap { beerId in
            data.beers[beerId]
        }
    }
    
    func loadStores() async {
        isLoading = true
        let startTime = Date()
        let urlString = "http://localhost:3000/v1/stores"
        guard let url = URL(string: urlString) else {
            self.error = NSError(domain: "AppError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            isLoading = false
            return
        }
        do {
            var httpFields = HTTPFields()
            httpFields.append(.init(name: .init("Content-Type")!, value: "application/json"))
            let signatureService = SignatureService(secretKey: "a1b2c3d4e5f6g7h8i9j0k")
            let signatureResult = try signatureService.createSignature(
                method: .get,
                path: url.path,
                headers: httpFields,
                body: nil
            )
            httpFields.append(.init(name: .requestSignature, value: signatureResult.signature))
            if let bodyHash = signatureResult.bodyHash {
                httpFields.append(.init(name: .bodyHash, value: bodyHash))
            }
            let httpRequest = HTTPRequest(
                method: .get,
                scheme: url.scheme,
                authority: url.host != nil ? "\(url.host!):\(url.port ?? 3000)" : nil,
                path: url.path,
                headerFields: httpFields
            )
            let request = URLRequest(httpRequest: httpRequest)!
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
            }
            if let responseText = String(data: data, encoding: .utf8) {
                print("Response as text:")
                print(responseText)
            } else {
                print("Could not convert response data to text")
            }
            let decoder = JSONDecoder()
            let r = try decoder.decode([AlkoStoreEntity].self, from: data)
            let fetchDuration = Date().timeIntervalSince(startTime)
            s = r
            print("Fetch completed in \(String(format: "%.2f", fetchDuration)) seconds")
            isLoading = false
        } catch {
            print("Error: \(error)")
            print("Error details: \(error.localizedDescription)")
            self.error = error
            isLoading = false
        }
    }

    func fetchBeerStoreData() async {
        isLoading = true
        let startTime = Date()

        guard let url = URL(string: "https://zitrqsmhoedlmujospzt.supabase.co/functions/v1/query-alko-beers") else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(ResponseEntity.self, from: data)
            self.data = response
            let fetchDuration = Date().timeIntervalSince(startTime)
            print("Fetch completed in \(String(format: "%.2f", fetchDuration)) seconds")
            isLoading = false
        } catch {
            print(error)
            self.error = error
        }
    }

    var storeAnnotations: [StoreAnnotation] = []
    var clusters: [StoreClusterAnnotation] = []

    private let clusterManager = ClusterManager<StoreAnnotation>()

    func initializeClusters() async {
        guard let data else { return }
        let annotations = data.stores.values.map { store in
            StoreAnnotation(
                id: store.id,
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
