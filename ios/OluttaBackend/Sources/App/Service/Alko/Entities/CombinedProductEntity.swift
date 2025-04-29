import Foundation

struct UntappdProductEntity: Sendable, Identifiable {
    let id: UUID
    let productExternalId: Int
    let name: String
    let labelUrl: String
    let labelHdUrl: String
    let abv: Decimal
    let ibu: Int
    let description: String
    let style: String
    let isInProduction: Int
    let slug: String
    let isHomebrew: Int
    let externalCreatedAt: String
    let ratingCount: Int
    let ratingScore: Decimal
    let statsTotalCount: Int
    let statsMonthlyCount: Int
    let statsTotalUserCount: Int
    let statsUserCount: Int
    let breweryId: Int
    let breweryName: String
    let brewerySlug: String
    let breweryType: String
    let breweryPageUrl: String
    let breweryLabel: String
    let breweryCountry: String
    let breweryCity: String
    let breweryState: String
    let breweryLat: Decimal
    let breweryLng: Decimal
}

struct MappingInfo: Sendable {
    let confidenceScore: Int
    let isVerified: Bool
    let reasoning: String
}

struct CombinedProductEntity: Sendable, Identifiable {
    var id: UUID { alkoProduct.id }
    let alkoProduct: AlkoProductEntity
    let untappdProduct: UntappdProductEntity?
    let mappingInfo: MappingInfo?
    let productCount: String?
}
