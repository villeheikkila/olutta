import Foundation
import PostgresNIO

struct UntappdRepository: Sendable {
    @discardableResult
    func upsertBeer(
        _ connection: PostgresConnection,
        logger: Logger,
        beer: UntappdBeerResponse.Beer,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO products_untappd (
                product_external_id, name, label_url, label_hd_url, abv, ibu,
                description, style, is_in_production, slug, is_homebrew,
                external_created_at, rating_count, rating_score,
                stats_total_count, stats_monthly_count, stats_total_user_count, stats_user_count,
                brewery_id, brewery_name, brewery_slug, brewery_type, brewery_page_url,
                brewery_label, brewery_country, brewery_city, brewery_state,
                brewery_lat, brewery_lng
            )
            VALUES (
                \(beer.bid), \(beer.beerName), \(beer.beerLabel.absoluteString),
                \(beer.beerLabelHd.absoluteString), \(beer.beerAbv), \(beer.beerIbu),
                \(beer.beerDescription), \(beer.beerStyle), \(beer.isInProduction),
                \(beer.beerSlug), \(beer.isHomebrew), \(beer.createdAt),
                \(beer.ratingCount), \(beer.ratingScore),
                \(beer.stats.totalCount), \(beer.stats.monthlyCount),
                \(beer.stats.totalUserCount), \(beer.stats.userCount),
                \(beer.brewery.breweryId), \(beer.brewery.breweryName),
                \(beer.brewery.brewerySlug), \(beer.brewery.breweryType),
                \(beer.brewery.breweryPageUrl), \(beer.brewery.breweryLabel.absoluteString),
                \(beer.brewery.countryName), \(beer.brewery.location.breweryCity),
                \(beer.brewery.location.breweryState), \(beer.brewery.location.lat),
                \(beer.brewery.location.lng)
            )
            ON CONFLICT (product_external_id) DO UPDATE SET
                name = EXCLUDED.name,
                label_url = EXCLUDED.label_url,
                label_hd_url = EXCLUDED.label_hd_url,
                abv = EXCLUDED.abv,
                ibu = EXCLUDED.ibu,
                description = EXCLUDED.description,
                style = EXCLUDED.style,
                is_in_production = EXCLUDED.is_in_production,
                slug = EXCLUDED.slug,
                is_homebrew = EXCLUDED.is_homebrew,
                external_created_at = EXCLUDED.external_created_at,
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
                brewery_country = EXCLUDED.brewery_country,
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
        _ connection: PostgresConnection,
        logger: Logger,
        alkoProductId: UUID,
        untappdProductId: UUID,
        confidenceScore: Int,
        isVerified: Bool,
        reasoning: String,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO products_alko_untappd_mapping (
                alko_product_id, untappd_product_id, confidence_score, is_verified, reasoning
            )
            VALUES (
                \(alkoProductId), \(untappdProductId), 
                \(confidenceScore), \(isVerified), \(reasoning)
            )
            ON CONFLICT (alko_product_id, untappd_product_id) DO UPDATE SET
                confidence_score = EXCLUDED.confidence_score,
                is_verified = EXCLUDED.is_verified,
                reasoning = EXCLUDED.reasoning,
                updated_at = now()
            RETURNING id
        """, logger: logger)

        for try await id in result.decode(UUID.self) {
            return id
        }
        throw RepositoryError.noData
    }
}
