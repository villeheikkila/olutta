import Foundation

public struct StoreEntity: Codable {
    public let id: UUID
    public let alkoStoreId: String
    public let name: String
    public let address: String
    public let city: String
    public let postalCode: String
    public let latitude: Decimal
    public let longitude: Decimal
}
