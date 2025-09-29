import Foundation
import HummingbirdRedis
import Logging
import OluttaShared
import PostgresNIO

extension GetStoresCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        persist: RedisPersistDriver,
        request: Request
    ) async throws -> Response {
        let key = "stores::v2"
        let cachedValue = try await persist.get(key: key, as: [StoreEntity].self)
        if let cachedValue {
            logger.info("returning cached stores")
            return Response(stores: cachedValue)
        }
        let stores = try await pg.withTransaction { tx in
            try await AlkoRepository.getStores(tx, logger: logger)
        }
        let storeEntities: [StoreEntity] = stores.map { store in
            StoreEntity(
                id: store.id,
                alkoStoreId: store.alkoStoreId,
                name: store.name,
                address: store.address,
                city: store.city,
                postalCode: store.postalCode,
                latitude: store.latitude,
                longitude: store.longitude
            )
        }
        try await persist.set(key: key, value: storeEntities, expires: .seconds(60))
        return Response(stores: storeEntities)
    }
}
