import Foundation

struct AlkoProductEntity: Sendable, Identifiable {
    let id: UUID
    let productExternalId: String
    let name: String
    let taste: String?
    let additionalInfo: String?
    let abv: Double?
    let beerStyleId: [String]
    let beerStyleName: [String]
    let beerSubstyleId: [String]?
    let countryName: String?
    let foodSymbolId: [String]?
    let mainGroupId: [String]
    let price: Double?
    let productGroupId: [String]
    let productGroupName: [String]
    let volume: Double?
    let onlineAvailabilityDatetimeTs: Int64?
    let description: String?
    let certificateId: [String]?
}
