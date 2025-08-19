import Foundation
import Hummingbird
import HummingbirdRedis
import Logging
import OluttaShared
import PostgresNIO

struct AppController {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let alkoRepository: AlkoRepository

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .get(.stores, use: stores)
            .get(.productsByStoreId(UUID()), use: productsByStoreId)
    }
}

extension AppController {
    func stores(request _: Request, context: some RequestContext) async throws -> [StoreEntity] {
        let key = "stores::v2"
        let cachedValue = try await persist.get(key: key, as: [StoreEntity].self)
        if let cachedValue {
            context.logger.info("returning cached stores")
            return cachedValue
        }
        let stores = try await pg.withTransaction { tx in
            try await alkoRepository.getStores(tx)
        }
        let res: [StoreEntity] = stores.map { store in
            StoreEntity(
                id: store.id,
                alkoStoreId: store.alkoStoreId,
                name: store.name,
                address: store.address,
                city: store.city,
                postalCode: store.postalCode,
                latitude: store.latitude,
                longitude: store.longitude,
            )
        }
        try await persist.set(key: key, value: res, expires: .seconds(60))
        return res
    }
}

extension AppController {
    func productsByStoreId(request _: Request, context: some RequestContext) async throws -> [ProductEntity] {
        guard let id = context.parameters.get("id", as: UUID.self) else { throw HTTPError(.badRequest) }
        let products = try await pg.withTransaction { tx in
            try await alkoRepository.getProductsByStoreId(tx, id: id)
        }
        return products.map {
            ProductEntity(
                id: $0.alkoProduct.id, alkoId: $0.alkoProduct.productExternalId, untappdId: $0.untappdProduct?.productExternalId, name: $0.alkoProduct.name, manufacturer: $0.untappdProduct?.breweryName ?? "", price: $0.alkoProduct.price, alcoholPercentage: $0.alkoProduct.abv, beerStyle: $0.untappdProduct?.style ?? "",
            )
        }
    }
}
