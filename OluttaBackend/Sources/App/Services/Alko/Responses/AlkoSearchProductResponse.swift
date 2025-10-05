import Foundation

struct AlkoSearchProductResponse: Decodable {
    let id: String
    let taste: String
    let additionalInfo: String
    let abv: Double
    let beerStyleId: [String]
    let beerStyleName: [String]
    let beerSubstyleId: [String]?
    let countryName: String
    let foodSymbolId: [String]?
    let mainGroupId: [String]
    let name: String
    let price: Double
    let productGroupId: [String]
    let productGroupName: [String]
    let volume: Double
    let onlineAvailabilityDatetimeTs: Int
    let description: String
    let certificateId: [String]?
}
