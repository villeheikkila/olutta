import Foundation
import Hummingbird
import HummingbirdRedis
import Logging
import PostgresNIO

struct AppController {
    let logger: Logger
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let alkoRepository: AlkoRepository

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .get("stores", use: stores)
    }
}

extension AppController {
    func stores(request _: Request, context _: some RequestContext) async throws -> [AlkoStoreEntity] {
        let key = "stores::v1"
        let cachedValue = try await persist.get(key: key, as: [AlkoStoreEntity].self)
        if let cachedValue {
            logger.info("returning cached stores")
            return cachedValue
        }
        let stores = try await pg.withTransaction { tx in
            try await alkoRepository.getStores(tx)
        }
        try await persist.set(key: key, value: stores, expires: .seconds(60))
        return stores
    }
}
