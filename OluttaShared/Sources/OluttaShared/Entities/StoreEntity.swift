import Foundation
import Tagged

public enum Store {
    public typealias Id = Tagged<Self, UUID>
}

public extension Store {
    struct Entity: Codable, Hashable, Identifiable {
        public let id: Store.Id
        public let alkoStoreId: String
        public let name: String
        public let address: String
        public let city: String
        public let postalCode: String
        public let latitude: Double
        public let longitude: Double

        public init(id: Store.Id, alkoStoreId: String, name: String, address: String, city: String, postalCode: String, latitude: Double, longitude: Double) {
            self.id = id
            self.alkoStoreId = alkoStoreId
            self.name = name
            self.address = address
            self.city = city
            self.postalCode = postalCode
            self.latitude = latitude
            self.longitude = longitude
        }
    }
}
