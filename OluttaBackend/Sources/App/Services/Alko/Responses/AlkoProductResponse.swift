import Foundation

struct AlkoProductResponse: Decodable {
    let abv: String
    let agentName: String
    let beerBitternessEbu: String
    let beerStyleName: [String]
    let beerStyleId: [String]
    let beerSubstyleName: [String]
    let beerWortPlato: String
    let certificateId: [String]?
    let certificateName: [String]?
    let closureId: [String]
    let closureName: [String]
    let countryId: String
    let countryName: String
    let energyPerDlKcal: String
    let foodSymbolId: [String]
    let id: String
    let mainGroupName: [String]
    let mainGroupId: [String]
    let moreInfo: String
    let moreInfo2: String
    let name: String
    let onlineAvailability: Bool
    let packageTypeName: [String]
    let packageTypeId: [String]
    let price: String
    let pricePerLitre: String
    let producer: String
    let productGroupName: [String]
    let productGroupId: [String]
    let regionName: String
    let selectionTypeName: [String]
    let selectionTypeId: [String]
    let status: String
    let taste: String
    let volume: String
    let ingredients: String
    let tasteInfo: [TasteInfo]?
    let description: String
    let seasonalProductName: [String]?
    let seasonalProductId: [String]?
    let newProduct: Bool?
    let deposit: String?

    struct TasteInfo: Decodable {
        let title: String
        let paragraphs: [String]
    }
}
