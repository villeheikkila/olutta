import Foundation

public struct ProductEntity: Codable, Identifiable, Hashable {
    public let id: UUID
    public let alkoId: String
    public let untappdId: Int?
    public let name: String
    public let manufacturer: String?
    public let price: Double?
    public let alcoholPercentage: Double?
    public let beerStyle: String?

    public init(id: UUID, alkoId: String, untappdId: Int?, name: String, manufacturer: String?, price: Double?, alcoholPercentage: Double?, beerStyle: String?) {
        self.id = id
        self.alkoId = alkoId
        self.untappdId = untappdId
        self.name = name
        self.manufacturer = manufacturer
        self.price = price
        self.alcoholPercentage = alcoholPercentage
        self.beerStyle = beerStyle
    }
}
