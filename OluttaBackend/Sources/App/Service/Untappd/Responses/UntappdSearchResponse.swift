import Foundation

public struct UntappdSearchResponse: Codable {
    public let message: String
    public let timeTaken: Double
    public let breweryId: Int
    public let searchType: String
    public let typeId: Int
    public let searchVersion: Int
    public let found: Int
    public let offset: Int
    public let limit: Int
    public let term: String
    public let parsedTerm: String
    public let beers: BeerSearchResults
    public let homebrew: HomebrewResults
    public let breweries: BreweryResults

    private enum CodingKeys: String, CodingKey {
        case message
        case timeTaken = "time_taken"
        case breweryId = "brewery_id"
        case searchType = "search_type"
        case typeId = "type_id"
        case searchVersion = "search_version"
        case found
        case offset
        case limit
        case term
        case parsedTerm = "parsed_term"
        case beers
        case homebrew
        case breweries
    }

    public struct BeerSearchResults: Codable {
        public let count: Int
        public let items: [BeerItem]
    }

    public struct HomebrewResults: Codable {
        public let count: Int
        public let items: [BeerItem]
    }

    public struct BreweryResults: Codable {
        public let count: Int
    }

    public struct BeerItem: Codable {
        public let checkinCount: Int
        public let haveHad: Bool
        public let yourCount: Int
        public let beer: Beer
        public let brewery: Brewery

        private enum CodingKeys: String, CodingKey {
            case checkinCount = "checkin_count"
            case haveHad = "have_had"
            case yourCount = "your_count"
            case beer
            case brewery
        }
    }

    public struct Beer: Codable {
        public let bid: Int
        public let beerName: String
        public let beerLabel: String
        public let beerAbv: Double
        public let beerSlug: String
        public let beerIbu: Int
        public let beerDescription: String
        public let createdAt: String
        public let beerStyle: String
        public let inProduction: Int
        public let authRating: Int
        public let wishList: Bool

        private enum CodingKeys: String, CodingKey {
            case bid
            case beerName = "beer_name"
            case beerLabel = "beer_label"
            case beerAbv = "beer_abv"
            case beerSlug = "beer_slug"
            case beerIbu = "beer_ibu"
            case beerDescription = "beer_description"
            case createdAt = "created_at"
            case beerStyle = "beer_style"
            case inProduction = "in_production"
            case authRating = "auth_rating"
            case wishList = "wish_list"
        }
    }

    public struct Brewery: Codable {
        public let breweryId: Int
        public let breweryName: String
        public let brewerySlug: String
        public let breweryPageUrl: String
        public let breweryType: String
        public let breweryLabel: String
        public let countryName: String
        public let contact: BreweryContact
        public let location: BreweryLocation
        public let breweryActive: Int

        private enum CodingKeys: String, CodingKey {
            case breweryId = "brewery_id"
            case breweryName = "brewery_name"
            case brewerySlug = "brewery_slug"
            case breweryPageUrl = "brewery_page_url"
            case breweryType = "brewery_type"
            case breweryLabel = "brewery_label"
            case countryName = "country_name"
            case contact
            case location
            case breweryActive = "brewery_active"
        }
    }

    public struct BreweryContact: Codable {
        public let twitter: String?
        public let facebook: String?
        public let instagram: String?
        public let url: String?
    }

    public struct BreweryLocation: Codable {
        public let breweryCity: String
        public let breweryState: String
        public let lat: Double
        public let lng: Double

        private enum CodingKeys: String, CodingKey {
            case breweryCity = "brewery_city"
            case breweryState = "brewery_state"
            case lat
            case lng
        }
    }
}
