import Foundation

struct AlkoStoreAvailabilityResponse: Sendable, Codable {
    let id: String
    let count: String?
    let availability: String?
    let store: Store

    struct Store: Sendable, Codable {
        let id: String
        let address: String
        let city: String
        let latitude: Double
        let longitude: Double
        let outletType: String
        let name: String
        let postalCode: String
        let openDays: [OpenDay]

        struct OpenDay: Sendable, Codable {
            let hours: String
            let date: String
        }
    }
}
