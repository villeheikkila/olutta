import Foundation

struct AlkoStoreEntity: Encodable {
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
