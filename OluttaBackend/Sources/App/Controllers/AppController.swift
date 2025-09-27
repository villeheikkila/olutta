import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

struct AppController {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let alkoRepository: AlkoRepository
    let jwtKeyCollection: JWTKeyCollection

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection))
            .patch(.user, use: updateUser)
            .get(.stores, use: stores)
            .get(.productsByStoreId(UUID()), use: productsByStoreId)
    }
}

extension AppController {
    func stores(request _: Request, context: AppRequestContext) async throws -> [StoreEntity] {
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
    func productsByStoreId(request _: Request, context: AppRequestContext) async throws -> [ProductEntity] {
        guard let id = context.parameters.get("id", as: UUID.self) else { throw HTTPError(.badRequest) }
        let products = try await pg.withTransaction { tx in
            try await alkoRepository.getProductsByStoreId(tx, id: id)
        }
        return products.map {
            ProductEntity(
                id: $0.alkoProduct.id, alkoId: $0.alkoProduct.productExternalId, untappdId: $0.untappdProduct?.productExternalId, name: $0.alkoProduct.name, manufacturer: $0.untappdProduct?.breweryName, price: $0.alkoProduct.price, alcoholPercentage: $0.alkoProduct.abv, beerStyle: $0.untappdProduct?.style,
            )
        }
    }
}

extension AppController {
    func updateUser(request: Request, context: AppRequestContext) async throws -> Response {
        let requestBody = try await request.decode(as: UserPatchRequest.self, context: context)
        let responseBody = UserPatchResponse()
        let data = try JSONEncoder().encode(responseBody)
        return Response(
            status: .ok,
            headers: [
                .contentType: "application/json; charset=utf-8",
                .contentLength: "\(data.count)",
            ],
            body: .init(byteBuffer: ByteBuffer(data: data)),
        )
    }
}
