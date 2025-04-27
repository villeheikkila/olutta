import Foundation
import PostgresNIO

struct AlkoRepository: Sendable {
    let logger: Logger

    func getStores(_ connection: PostgresConnection) async throws -> [AlkoStoreEntity] {
        let stream = try await connection.query(
            """
            SELECT "id", "store_external_id", "name", "address", "city", 
                   "postal_code", "latitude", "longitude", "outlet_type"
            FROM stores_alko
            """,
            logger: logger
        )

        var stores: [AlkoStoreEntity] = []
        for try await (id, storeExternalId, name, address, city, postalCode, latitude, longitude)
            in stream.decode((UUID, String, String, String, String, String, Double, Double).self, context: .default)
        {
            let store = AlkoStoreEntity(
                id: id,
                alkoStoreId: storeExternalId,
                name: name,
                address: address,
                city: city,
                postalCode: postalCode,
                latitude: latitude,
                longitude: longitude
            )
            stores.append(store)
        }
        return stores
    }

    func getProductById(
        _ connection: PostgresConnection,
        id: UUID
    ) async throws -> AlkoProductEntity {
        let result = try await connection.query(
            """
                SELECT "id", "product_external_id", "name", "taste", "additional_info", 
                       "abv", "beer_style_id", "beer_style_name", "beer_substyle_id", 
                       "country_name", "food_symbol_id", "main_group_id", "price", 
                       "product_group_id", "product_group_name", "volume", 
                       "online_availability_datetime_ts", "description", "certificate_id"
                FROM products_alko
                WHERE id = \(id)
            """,
            logger: logger
        )
        for try await (id, externalId, name, taste, additionalInfo, abv, beerStyleId,
                       beerStyleName, beerSubstyleId, countryName, foodSymbolId, mainGroupId,
                       price, productGroupId, productGroupName, volume,
                       onlineAvailabilityDatetimeTs, description, certificateId)
            in result.decode((UUID, String, String, String?, String?, Double?,
                              [String], [String], [String]?, String?, [String]?,
                              [String], Double?, [String], [String], Double?,
                              Int64?, String?, [String]?).self)
        {
            return AlkoProductEntity(
                id: id,
                productExternalId: externalId,
                name: name,
                taste: taste,
                additionalInfo: additionalInfo,
                abv: abv,
                beerStyleId: beerStyleId,
                beerStyleName: beerStyleName,
                beerSubstyleId: beerSubstyleId,
                countryName: countryName,
                foodSymbolId: foodSymbolId,
                mainGroupId: mainGroupId,
                price: price,
                productGroupId: productGroupId,
                productGroupName: productGroupName,
                volume: volume,
                onlineAvailabilityDatetimeTs: onlineAvailabilityDatetimeTs,
                description: description,
                certificateId: certificateId
            )
        }
        throw RepositoryError.recordNotFound
    }

    func upsertAlkoProducts(
        _ connection: PostgresConnection,
        products: [AlkoSearchProductResponse]
    ) async throws -> [(id: UUID, isNewRecord: Bool)] {
        let columns = [
            "product_external_id",
            "taste",
            "additional_info",
            "abv",
            "beer_style_id",
            "beer_style_name",
            "beer_substyle_id",
            "country_name",
            "food_symbol_id",
            "main_group_id",
            "name",
            "price",
            "product_group_id",
            "product_group_name",
            "volume",
            "online_availability_datetime_ts",
            "description",
            "certificate_id",
        ]
        var bindings: PostgresBindings = .init()
        var placeholders: [String] = []
        for (index, product) in products.enumerated() {
            bindings.append(product.id)
            bindings.append(product.taste)
            bindings.append(product.additionalInfo)
            bindings.append(product.abv)
            bindings.append(product.beerStyleId)
            bindings.append(product.beerStyleName)
            bindings.append(product.beerSubstyleId ?? [])
            bindings.append(product.countryName)
            bindings.append(product.foodSymbolId ?? [])
            bindings.append(product.mainGroupId)
            bindings.append(product.name)
            bindings.append(product.price)
            bindings.append(product.productGroupId)
            bindings.append(product.productGroupName)
            bindings.append(product.volume)
            bindings.append(product.onlineAvailabilityDatetimeTs)
            bindings.append(product.description)
            bindings.append(product.certificateId ?? [])
            let base = index * columns.count
            let paramIndices = (1 ... columns.count).map { "$\(base + $0)" }
            let placeholder = "(\(paramIndices.joined(separator: ", ")))"
            placeholders.append(placeholder)
        }
        let query = """
            INSERT INTO products_alko (\(columns.joined(separator: ", ")))
            VALUES \(placeholders.joined(separator: ", "))
            ON CONFLICT (product_external_id) DO UPDATE SET
                taste = EXCLUDED.taste,
                additional_info = EXCLUDED.additional_info,
                abv = EXCLUDED.abv,
                beer_style_id = EXCLUDED.beer_style_id,
                beer_style_name = EXCLUDED.beer_style_name,
                beer_substyle_id = EXCLUDED.beer_substyle_id,
                country_name = EXCLUDED.country_name,
                food_symbol_id = EXCLUDED.food_symbol_id,
                main_group_id = EXCLUDED.main_group_id,
                name = EXCLUDED.name,
                price = EXCLUDED.price,
                product_group_id = EXCLUDED.product_group_id,
                product_group_name = EXCLUDED.product_group_name,
                volume = EXCLUDED.volume,
                online_availability_datetime_ts = EXCLUDED.online_availability_datetime_ts,
                description = EXCLUDED.description,
                certificate_id = EXCLUDED.certificate_id,
                updated_at = NOW()
            RETURNING id, (xmax = 0) AS is_new_record;
        """
        let result = try await connection.query(.init(unsafeSQL: query, binds: bindings), logger: logger)
        var productResults: [(id: UUID, isNewRecord: Bool)] = []
        for try await (id, isNewRecord) in result.decode((UUID, Bool).self) {
            productResults.append((id: id, isNewRecord: isNewRecord))
        }
        return productResults
    }

    func upsertStores(_ connection: PostgresConnection, stores: [AlkoStoreResponse]) async throws -> [(id: String, isNewRecord: Bool)] {
        let columns = [
            "store_external_id",
            "name",
            "address",
            "city",
            "postal_code",
            "latitude",
            "longitude",
            "outlet_type",
        ]
        var bindings: PostgresBindings = .init()
        var placeholders: [String] = []
        for (index, store) in stores.enumerated() {
            bindings.append(store.id)
            bindings.append(store.name)
            bindings.append(store.address)
            bindings.append(store.city)
            bindings.append(store.postalCode)
            bindings.append(store.latitude)
            bindings.append(store.longitude)
            bindings.append(store.outletType)
            let base = index * columns.count
            let paramIndices = (1 ... columns.count).map { "$\(base + $0)" }
            let placeholder = "(\(paramIndices.joined(separator: ", ")))"
            placeholders.append(placeholder)
        }
        let query = """
            INSERT INTO stores_alko (\(columns.joined(separator: ", ")))
            VALUES \(placeholders.joined(separator: ", "))
            ON CONFLICT (store_external_id) DO UPDATE SET
                name = EXCLUDED.name,
                address = EXCLUDED.address,
                city = EXCLUDED.city,
                postal_code = EXCLUDED.postal_code,
                latitude = EXCLUDED.latitude,
                longitude = EXCLUDED.longitude,
                outlet_type = EXCLUDED.outlet_type,
                updated_at = NOW()
            RETURNING id, (xmax = 0) AS is_new_record;
        """
        let result = try await connection.query(.init(unsafeSQL: query, binds: bindings), logger: logger)
        var storeResults: [(id: String, isNewRecord: Bool)] = []
        for try await (id, isNewRecord) in result.decode((String, Bool).self) {
            storeResults.append((id: id, isNewRecord: isNewRecord))
        }
        return storeResults
    }

    func upsertWebstoreInventory(_ connection: PostgresConnection, productId: UUID, availabilities: [AlkoWebAvailabilityResponse]) async throws -> [(id: UUID, isNewRecord: Bool)] {
        let columns = [
            "product_id",
            "status_code",
            "message_code",
            "estimated_availability_date",
            "delivery_min",
            "delivery_max",
            "status_en",
            "status_fi",
            "status_sv",
            "status_message",
        ]
        var bindings: PostgresBindings = .init()
        var placeholders: [String] = []
        for (index, availability) in availabilities.enumerated() {
            bindings.append(productId)
            bindings.append(availability.statusCode)
            bindings.append(availability.messageCode)
            bindings.append(availability.estimatedAvailabilityDate)
            bindings.append(availability.delivery?.min)
            bindings.append(availability.delivery?.max)
            bindings.append(availability.status.en)
            bindings.append(availability.status.fi)
            bindings.append(availability.status.sv)
            bindings.append(availability.statusMessage)
            let base = index * columns.count
            let paramIndices = (1 ... columns.count).map { "$\(base + $0)" }
            let placeholder = "(\(paramIndices.joined(separator: ", ")))"
            placeholders.append(placeholder)
        }
        let query = """
            INSERT INTO availability_alko_webstore (\(columns.joined(separator: ", ")))
            VALUES \(placeholders.joined(separator: ", "))
            ON CONFLICT (product_id) DO UPDATE SET
                status_code = EXCLUDED.status_code,
                message_code = EXCLUDED.message_code,
                estimated_availability_date = EXCLUDED.estimated_availability_date,
                delivery_min = EXCLUDED.delivery_min,
                delivery_max = EXCLUDED.delivery_max,
                status_en = EXCLUDED.status_en,
                status_fi = EXCLUDED.status_fi,
                status_sv = EXCLUDED.status_sv,
                status_message = EXCLUDED.status_message,
                updated_at = now()
            RETURNING product_id, (xmax = 0) AS is_new_record;
        """
        let result = try await connection.query(.init(unsafeSQL: query, binds: bindings), logger: logger)
        var inventoryResults: [(id: UUID, isNewRecord: Bool)] = []
        for try await (id, isNewRecord) in result.decode((UUID, Bool).self) {
            inventoryResults.append((id: id, isNewRecord: isNewRecord))
        }
        return inventoryResults
    }

    func upsertStoreInventory(
        _ connection: PostgresConnection,
        productId: UUID,
        availabilities: [(storeId: UUID, count: String?)]
    ) async throws -> [(id: (UUID, UUID), isNewRecord: Bool)] {
        let columns = [
            "store_id",
            "product_id",
            "product_count",
        ]
        var bindings: PostgresBindings = .init()
        var placeholders: [String] = []

        for (index, availability) in availabilities.enumerated() {
            bindings.append(availability.storeId)
            bindings.append(productId)
            bindings.append(availability.count)

            let base = index * columns.count
            let paramIndices = (1 ... columns.count).map { "$\(base + $0)" }
            let placeholder = "(\(paramIndices.joined(separator: ", ")))"
            placeholders.append(placeholder)
        }

        let query = """
            INSERT INTO availability_alko_store (\(columns.joined(separator: ", ")))
            VALUES \(placeholders.joined(separator: ", "))
            ON CONFLICT (store_id, product_id) DO UPDATE SET
                product_count = EXCLUDED.product_count,
                updated_at = NOW()
            RETURNING store_id, product_id, (xmax = 0) AS is_new_record;
        """
        let result = try await connection.query(.init(unsafeSQL: query, binds: bindings), logger: logger)
        var inventoryResults: [(id: (UUID, UUID), isNewRecord: Bool)] = []
        for try await (storeId, productId, isNewRecord) in result.decode((UUID, UUID, Bool).self) {
            inventoryResults.append((id: (storeId, productId), isNewRecord: isNewRecord))
        }
        if inventoryResults.isEmpty {
            throw RepositoryError.noData
        }
        return inventoryResults
    }

    func linkAlkoProductToUntappdBeer(
        _ connection: PostgresConnection,
        alkoProductId: UUID,
        untappdId: UUID
    ) async throws {
        let result = try await connection.query("""
            UPDATE products_alko 
            SET untappd_id = \(untappdId)
            WHERE id = \(alkoProductId)
            RETURNING id
        """, logger: logger)
        for try await _ in result.decode(UUID.self) {
            return
        }
        throw RepositoryError.recordNotFound
    }
}

enum RepositoryError: Error {
    case noData
    case recordNotFound
}
