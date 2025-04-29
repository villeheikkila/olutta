import Foundation

struct AlkoStoreEntity: Codable {
    let id: UUID
    let alkoStoreId: String
    let name: String
    let address: String
    let city: String
    let postalCode: String
    let latitude: Double
    let longitude: Double
}
