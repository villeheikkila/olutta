import Foundation
import OluttaShared
import Tagged

struct AlkoStoreEntity: Codable {
    let id: Store.Id
    let alkoStoreId: String
    let name: String
    let address: String
    let city: String
    let postalCode: String
    let latitude: Double
    let longitude: Double
}
