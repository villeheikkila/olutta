import Foundation
import PostgresNIO

struct UntappdRepository: Sendable {
    let logger: Logger

    @discardableResult
    func upsertBeer(
        _ connection: PostgresConnection,
        beer: UntappdBeerResponse
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO products_untappd (
                bid, beer_name, beer_label, beer_label_hd, beer_abv, beer_ibu,
                beer_description, beer_style, is_in_production, beer_slug, is_homebrew,
                created_at, rating_count, rating_score,
                stats_total_count, stats_monthly_count, stats_total_user_count, stats_user_count,
                brewery_id, brewery_name, brewery_slug, brewery_type, brewery_page_url,
                brewery_label, brewery_country_name, brewery_city, brewery_state,
                brewery_lat, brewery_lng
            )
            VALUES (
                \(beer.beer.bid), \(beer.beer.beerName), \(beer.beer.beerLabel.absoluteString),
                \(beer.beer.beerLabelHd.absoluteString), \(beer.beer.beerAbv), \(beer.beer.beerIbu),
                \(beer.beer.beerDescription), \(beer.beer.beerStyle), \(beer.beer.isInProduction),
                \(beer.beer.beerSlug), \(beer.beer.isHomebrew), \(beer.beer.createdAt),
                \(beer.beer.ratingCount), \(beer.beer.ratingScore),
                \(beer.beer.stats.totalCount), \(beer.beer.stats.monthlyCount),
                \(beer.beer.stats.totalUserCount), \(beer.beer.stats.userCount),
                \(beer.beer.brewery.breweryId), \(beer.beer.brewery.breweryName),
                \(beer.beer.brewery.brewerySlug), \(beer.beer.brewery.breweryType),
                \(beer.beer.brewery.breweryPageUrl), \(beer.beer.brewery.breweryLabel.absoluteString),
                \(beer.beer.brewery.countryName), \(beer.beer.brewery.location.breweryCity),
                \(beer.beer.brewery.location.breweryState), \(beer.beer.brewery.location.lat),
                \(beer.beer.brewery.location.lng)
            )
            ON CONFLICT (bid) DO UPDATE SET
                beer_name = EXCLUDED.beer_name,
                beer_label = EXCLUDED.beer_label,
                beer_label_hd = EXCLUDED.beer_label_hd,
                beer_abv = EXCLUDED.beer_abv,
                beer_ibu = EXCLUDED.beer_ibu,
                beer_description = EXCLUDED.beer_description,
                beer_style = EXCLUDED.beer_style,
                is_in_production = EXCLUDED.is_in_production,
                beer_slug = EXCLUDED.beer_slug,
                is_homebrew = EXCLUDED.is_homebrew,
                created_at = EXCLUDED.created_at,
                rating_count = EXCLUDED.rating_count,
                rating_score = EXCLUDED.rating_score,
                stats_total_count = EXCLUDED.stats_total_count,
                stats_monthly_count = EXCLUDED.stats_monthly_count,
                stats_total_user_count = EXCLUDED.stats_total_user_count,
                stats_user_count = EXCLUDED.stats_user_count,
                brewery_id = EXCLUDED.brewery_id,
                brewery_name = EXCLUDED.brewery_name,
                brewery_slug = EXCLUDED.brewery_slug,
                brewery_type = EXCLUDED.brewery_type,
                brewery_page_url = EXCLUDED.brewery_page_url,
                brewery_label = EXCLUDED.brewery_label,
                brewery_country_name = EXCLUDED.brewery_country_name,
                brewery_city = EXCLUDED.brewery_city,
                brewery_state = EXCLUDED.brewery_state,
                brewery_lat = EXCLUDED.brewery_lat,
                brewery_lng = EXCLUDED.brewery_lng
            RETURNING id
        """, logger: logger)
        for try await id in result.decode(UUID.self) {
            return id
        }
        throw RepositoryError.noData
    }

    @discardableResult
    func createProductMapping(
        _ connection: PostgresConnection, alkoProductId: UUID, untappdProductId: UUID, confidenceScore: Double?, isVerified: Bool
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO products_alko_untappd_mapping (
                alko_product_id, untappd_product_id, confidence_score, is_verified
            )
            VALUES (
                \(alkoProductId), \(untappdProductId), 
                \(confidenceScore), \(isVerified)
            )
            ON CONFLICT (alko_product_id, untappd_product_id) DO UPDATE SET
                confidence_score = EXCLUDED.confidence_score,
                is_verified = EXCLUDED.is_verified,
                updated_at = now()
            RETURNING id
        """, logger: logger)

        for try await id in result.decode(UUID.self) {
            return id
        }
        throw RepositoryError.noData
    }
}
