import Foundation

public struct UntappdBeerResponse: Codable {
    let beer: Beer

    struct Beer: Codable {
        let bid: Int
        let beerName: String
        let beerLabel: URL
        let beerLabelHd: URL
        let beerAbv: Double
        let beerIbu: Int
        let beerDescription: String
        let beerStyle: String
        let isInProduction: Int
        let beerSlug: String
        let isHomebrew: Int
        let createdAt: String
        let ratingCount: Int
        let ratingScore: Double
        let stats: Stats
        let brewery: Brewery

        enum CodingKeys: String, CodingKey {
            case bid
            case beerName = "beer_name"
            case beerLabel = "beer_label"
            case beerLabelHd = "beer_label_hd"
            case beerAbv = "beer_abv"
            case beerIbu = "beer_ibu"
            case beerDescription = "beer_description"
            case beerStyle = "beer_style"
            case isInProduction = "is_in_production"
            case beerSlug = "beer_slug"
            case isHomebrew = "is_homebrew"
            case createdAt = "created_at"
            case ratingCount = "rating_count"
            case ratingScore = "rating_score"
            case stats
            case brewery
        }

        struct Stats: Codable {
            let totalCount: Int
            let monthlyCount: Int
            let totalUserCount: Int
            let userCount: Int

            enum CodingKeys: String, CodingKey {
                case totalCount = "total_count"
                case monthlyCount = "monthly_count"
                case totalUserCount = "total_user_count"
                case userCount = "user_count"
            }
        }

        struct Brewery: Codable {
            let breweryId: Int
            let breweryName: String
            let brewerySlug: String
            let breweryType: String
            let breweryPageUrl: String
            let breweryLabel: URL
            let countryName: String
            let location: Location

            enum CodingKeys: String, CodingKey {
                case breweryId = "brewery_id"
                case breweryName = "brewery_name"
                case brewerySlug = "brewery_slug"
                case breweryType = "brewery_type"
                case breweryPageUrl = "brewery_page_url"
                case breweryLabel = "brewery_label"
                case countryName = "country_name"
                case location
            }

            struct Location: Codable {
                let breweryCity: String
                let breweryState: String
                let lat: Double
                let lng: Double

                enum CodingKeys: String, CodingKey {
                    case breweryCity = "brewery_city"
                    case breweryState = "brewery_state"
                    case lat
                    case lng
                }
            }
        }
    }
}
