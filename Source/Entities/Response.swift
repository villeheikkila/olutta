import Foundation
import MapKit

struct ResponseEntity: Codable {
    let beers: [String: BeerEntity]
    let webstore: [String: WebstoreAvailabilityEntity]
}

struct BeerEntity: Codable, Identifiable, Hashable {
    let id: String
    let alkoId: String
    let untappdId: Int?
    let name: String
    let manufacturer: String
    let price: Double
    let alcoholPercentage: Double
    let beerStyle: String
    let rating: Double?
    let ratingCount: Int?
    let packageType: String
    let containerSize: String
    let pricePerLiter: Double
    let bitternessIbu: Int?
    let imageUrl: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case alkoId = "alko_id"
        case untappdId = "untappd_id"
        case name
        case manufacturer
        case price
        case alcoholPercentage = "alcohol_percentage"
        case beerStyle = "beer_style"
        case rating
        case ratingCount = "rating_count"
        case packageType = "package_type"
        case containerSize = "container_size"
        case pricePerLiter = "price_per_liter"
        case bitternessIbu = "bitterness_ibu"
        case imageUrl = "image_url"
    }

    var alkoUrl: URL {
        URL(string: "https://www.alko.fi/tuotteet/\(alkoId)")!
    }

    var untappdUrl: URL? {
        guard let untappdId else { return nil }
        return URL(string: "https://untappd.com/b/_/\(untappdId)")
    }
}

extension [BeerEntity] {
    var groupedBeerStyles: [StyleGroup] {
        let styles = compactMap(\.beerStyle)
        let uniqueStyles = Set(styles)
        let grouped = Dictionary(grouping: uniqueStyles) { style -> String in
            let components = style.components(separatedBy: " - ")
            return components.first ?? style
        }
        return grouped.map { category, styles in
            let categoryCount = self.filter { beer in
                beer.beerStyle.starts(with: category)
            }.count
            let stylesWithCount = styles.sorted().map { style in
                (name: style, count: self.filter { $0.beerStyle == style }.count)
            }
            return StyleGroup(
                category: category,
                categoryCount: categoryCount,
                styles: stylesWithCount
            )
        }
        .sorted { $0.category < $1.category }
    }
}

struct StyleGroup {
    let category: String
    let categoryCount: Int
    let styles: [(name: String, count: Int)]
}

struct WebstoreAvailabilityEntity: Codable {
    let statusCode: String
    let messageCode: String
    let estimatedAvailabilityDate: String?
    let deliveryMin: Int?
    let deliveryMax: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case messageCode = "message_code"
        case estimatedAvailabilityDate = "estimated_availability_date"
        case deliveryMin = "delivery_min"
        case deliveryMax = "delivery_max"
        case status
    }
}
