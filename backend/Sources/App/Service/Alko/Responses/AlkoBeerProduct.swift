import Foundation
import PostgresNIO

struct AlkoStoreResponse: Decodable {
    let id: String
    let address: String
    let city: String
    let latitude: Double
    let longitude: Double
    let outletType: String
    let name: String
    let postalCode: String
    let openDays: [OpenDay]

    struct OpenDay: Decodable {
        let hours: String
        let date: String
    }
}
