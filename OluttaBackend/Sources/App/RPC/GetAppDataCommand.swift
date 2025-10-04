import Foundation
import HummingbirdRedis
import Logging
import OluttaShared
import PostgresNIO

extension GetAppDataCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity _: UserIdentity,
        pg: PostgresClient,
        request _: Request,
    ) async throws -> Response {
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
                longitude: store.longitude,
            )
        }
        return Response(stores: storeEntities)
    }
}
